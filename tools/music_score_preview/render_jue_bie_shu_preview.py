#!/usr/bin/env python
from __future__ import annotations

import argparse
import json
import shutil
import struct
import subprocess
import sys
import tempfile
import wave
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable


DEFAULT_SOUNDFONT_PATH = Path(r"E:\soundfont2\FluidR3 GM.sf2")
DEFAULT_FLUIDSYNTH_BIN = Path(r"C:\tools\fluidsynth\bin\fluidsynth.exe")
DEFAULT_SAMPLE_RATE = 44100


@dataclass(frozen=True)
class RawMidiEvent:
    tick: int
    track_index: int
    order_index: int
    kind: str
    code: int
    payload: bytes


@dataclass(frozen=True)
class ActiveNote:
    start_sec: float
    velocity: int
    track_index: int
    order_index: int


@dataclass(frozen=True)
class NoteEvent:
    event_index: int
    track_index: int
    channel: int
    midi_note: int
    velocity: int
    start_sec: float
    end_sec: float

    @property
    def duration_sec(self) -> float:
        return self.end_sec - self.start_sec

    def to_payload(self) -> dict[str, object]:
        note_id = f"midi_{self.midi_note:03d}"
        return {
            "event_index": self.event_index,
            "track_index": self.track_index,
            "channel": self.channel,
            "midi_note": self.midi_note,
            "note_id": note_id,
            "sample_id": f"grand_piano_{self.midi_note:03d}",
            "velocity": self.velocity,
            "start_sec": round(self.start_sec, 6),
            "duration_sec": round(self.duration_sec, 6),
        }


def read_vlq(buffer: bytes, position: int) -> tuple[int, int]:
    value = 0
    while True:
        byte = buffer[position]
        position += 1
        value = (value << 7) | (byte & 0x7F)
        if not (byte & 0x80):
            return value, position


def parse_track_events(track_bytes: bytes, track_index: int) -> list[RawMidiEvent]:
    events: list[RawMidiEvent] = []
    position = 0
    tick = 0
    running_status: int | None = None
    order_index = 0
    while position < len(track_bytes):
        delta_ticks, position = read_vlq(track_bytes, position)
        tick += delta_ticks
        status = track_bytes[position]
        if status < 0x80:
            if running_status is None:
                raise ValueError("encountered running status without previous status")
            status = running_status
        else:
            position += 1
            running_status = status if status < 0xF0 else None
        if status == 0xFF:
            meta_type = track_bytes[position]
            position += 1
            payload_length, position = read_vlq(track_bytes, position)
            payload = track_bytes[position : position + payload_length]
            position += payload_length
            events.append(
                RawMidiEvent(
                    tick=tick,
                    track_index=track_index,
                    order_index=order_index,
                    kind="meta",
                    code=meta_type,
                    payload=payload,
                )
            )
            order_index += 1
            continue
        if status in (0xF0, 0xF7):
            payload_length, position = read_vlq(track_bytes, position)
            payload = track_bytes[position : position + payload_length]
            position += payload_length
            events.append(
                RawMidiEvent(
                    tick=tick,
                    track_index=track_index,
                    order_index=order_index,
                    kind="sysex",
                    code=status,
                    payload=payload,
                )
            )
            order_index += 1
            continue
        event_type = status & 0xF0
        if event_type in (0xC0, 0xD0):
            payload = bytes([track_bytes[position]])
            position += 1
        else:
            payload = bytes(track_bytes[position : position + 2])
            position += 2
        events.append(
            RawMidiEvent(
                tick=tick,
                track_index=track_index,
                order_index=order_index,
                kind="midi",
                code=status,
                payload=payload,
            )
        )
        order_index += 1
    return events


def parse_midi_events(source_midi_path: Path) -> tuple[int, list[RawMidiEvent]]:
    data = source_midi_path.read_bytes()
    if data[:4] != b"MThd":
        raise ValueError(f"{source_midi_path} is not a standard MIDI file")
    header_length = struct.unpack(">I", data[4:8])[0]
    file_format, track_count, division = struct.unpack(">HHH", data[8:14])
    if file_format not in (0, 1):
        raise ValueError(f"unsupported midi format {file_format}")
    if division & 0x8000:
        raise ValueError("SMPTE time division is not supported")
    position = 8 + header_length
    merged_events: list[RawMidiEvent] = []
    for track_index in range(track_count):
        if data[position : position + 4] != b"MTrk":
            raise ValueError(f"missing MTrk header for track {track_index}")
        track_length = struct.unpack(">I", data[position + 4 : position + 8])[0]
        track_start = position + 8
        track_end = track_start + track_length
        merged_events.extend(parse_track_events(data[track_start:track_end], track_index))
        position = track_end
    merged_events.sort(key=lambda item: (item.tick, item.track_index, item.order_index))
    return division, merged_events


def build_note_events(source_midi_path: Path) -> tuple[list[NoteEvent], float]:
    ticks_per_quarter, raw_events = parse_midi_events(source_midi_path)
    tempo_us_per_quarter = 500_000
    current_tick = 0
    current_sec = 0.0
    active_notes: dict[tuple[int, int], list[ActiveNote]] = {}
    note_events: list[NoteEvent] = []
    note_index = 0
    for event in raw_events:
        delta_ticks = event.tick - current_tick
        current_sec += (delta_ticks * tempo_us_per_quarter) / 1_000_000.0 / ticks_per_quarter
        current_tick = event.tick
        if event.kind == "meta" and event.code == 0x51 and len(event.payload) == 3:
            tempo_us_per_quarter = int.from_bytes(event.payload, "big")
            continue
        if event.kind != "midi":
            continue
        status = event.code
        event_type = status & 0xF0
        channel = status & 0x0F
        if event_type == 0x90:
            midi_note = event.payload[0]
            velocity = event.payload[1]
            if velocity == 0:
                note_index = close_active_note(
                    active_notes=active_notes,
                    note_events=note_events,
                    note_index=note_index,
                    channel=channel,
                    midi_note=midi_note,
                    end_sec=current_sec,
                )
            else:
                active_notes.setdefault((channel, midi_note), []).append(
                    ActiveNote(
                        start_sec=current_sec,
                        velocity=velocity,
                        track_index=event.track_index,
                        order_index=event.order_index,
                    )
                )
            continue
        if event_type == 0x80:
            note_index = close_active_note(
                active_notes=active_notes,
                note_events=note_events,
                note_index=note_index,
                channel=channel,
                midi_note=event.payload[0],
                end_sec=current_sec,
            )
    for (channel, midi_note), active_stack in list(active_notes.items()):
        for active_note in active_stack:
            if current_sec > active_note.start_sec:
                note_events.append(
                    NoteEvent(
                        event_index=note_index,
                        track_index=active_note.track_index,
                        channel=channel,
                        midi_note=midi_note,
                        velocity=active_note.velocity,
                        start_sec=active_note.start_sec,
                        end_sec=current_sec,
                    )
                )
                note_index += 1
    note_events.sort(key=lambda item: (item.start_sec, item.track_index, item.event_index, item.midi_note))
    reindexed = [
        NoteEvent(
            event_index=index,
            track_index=note.track_index,
            channel=note.channel,
            midi_note=note.midi_note,
            velocity=note.velocity,
            start_sec=note.start_sec,
            end_sec=note.end_sec,
        )
        for index, note in enumerate(note_events)
    ]
    song_end_sec = max((note.end_sec for note in reindexed), default=0.0)
    return reindexed, song_end_sec


def close_active_note(
    active_notes: dict[tuple[int, int], list[ActiveNote]],
    note_events: list[NoteEvent],
    note_index: int,
    channel: int,
    midi_note: int,
    end_sec: float,
) -> int:
    key = (channel, midi_note)
    active_stack = active_notes.get(key)
    if not active_stack:
        return note_index
    active_note = active_stack.pop(0)
    if not active_stack:
        del active_notes[key]
    if end_sec <= active_note.start_sec:
        return note_index
    note_events.append(
        NoteEvent(
            event_index=note_index,
            track_index=active_note.track_index,
            channel=channel,
            midi_note=midi_note,
            velocity=active_note.velocity,
            start_sec=active_note.start_sec,
            end_sec=end_sec,
        )
    )
    return note_index + 1


def apply_optional_trim(note_events: Iterable[NoteEvent], trim_seconds: float | None) -> tuple[list[NoteEvent], bool]:
    if trim_seconds is None:
        return list(note_events), False
    trimmed: list[NoteEvent] = []
    was_trimmed = False
    for note in note_events:
        if note.start_sec >= trim_seconds:
            was_trimmed = True
            continue
        clipped_end = min(note.end_sec, trim_seconds)
        if clipped_end <= note.start_sec:
            was_trimmed = True
            continue
        if clipped_end != note.end_sec:
            was_trimmed = True
        trimmed.append(
            NoteEvent(
                event_index=len(trimmed),
                track_index=note.track_index,
                channel=note.channel,
                midi_note=note.midi_note,
                velocity=note.velocity,
                start_sec=note.start_sec,
                end_sec=clipped_end,
            )
        )
    return trimmed, was_trimmed


def resolve_binary(path_hint: Path | None, fallback_name: str) -> Path:
    if path_hint is not None:
        if not path_hint.exists():
            raise FileNotFoundError(f"required binary not found: {path_hint}")
        return path_hint
    resolved = shutil.which(fallback_name)
    if resolved is None:
        raise FileNotFoundError(f"required binary not found in PATH: {fallback_name}")
    return Path(resolved)


def render_preview_audio(
    source_midi_path: Path,
    output_preview_wav_path: Path,
    soundfont_path: Path,
    fluidsynth_bin: Path,
    ffmpeg_bin: Path,
    sample_rate_hz: int,
    trim_seconds: float | None,
) -> float:
    with tempfile.TemporaryDirectory(prefix="music-road-preview-") as temp_dir_raw:
        temp_dir = Path(temp_dir_raw)
        stereo_wav_path = temp_dir / "fluidsynth_render.wav"
        mono_wav_path = temp_dir / "preview_mono.wav"
        render_command = [
            str(fluidsynth_bin),
            "-ni",
            "-q",
            "-F",
            str(stereo_wav_path),
            "-T",
            "wav",
            "-O",
            "s16",
            "-r",
            str(sample_rate_hz),
            str(soundfont_path),
            str(source_midi_path),
        ]
        run_command(render_command, "fluidsynth render")
        downmix_command = [
            str(ffmpeg_bin),
            "-y",
            "-loglevel",
            "error",
            "-i",
            str(stereo_wav_path),
            "-ac",
            "1",
            "-ar",
            str(sample_rate_hz),
            "-c:a",
            "pcm_s16le",
        ]
        if trim_seconds is not None:
            downmix_command.extend(["-t", f"{trim_seconds + 3.0:.3f}"])
        downmix_command.append(str(mono_wav_path))
        run_command(downmix_command, "ffmpeg downmix")
        shutil.copyfile(mono_wav_path, output_preview_wav_path)
    return read_wav_duration(output_preview_wav_path)


def run_command(command: list[str], label: str) -> None:
    result = subprocess.run(command, capture_output=True, text=True, check=False)
    if result.returncode == 0:
        return
    raise RuntimeError(
        f"{label} failed with exit code {result.returncode}\n"
        f"stdout:\n{result.stdout}\n"
        f"stderr:\n{result.stderr}"
    )


def read_wav_duration(wav_path: Path) -> float:
    with wave.open(str(wav_path), "rb") as wav_file:
        return wav_file.getnframes() / float(wav_file.getframerate())


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Render the frozen jue_bie_shu MIDI into a QA preview artifact.")
    parser.add_argument("--source-midi", required=True, type=Path)
    parser.add_argument("--song-id", required=True)
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument("--trim-seconds", type=float, default=None)
    parser.add_argument("--soundfont", type=Path, default=DEFAULT_SOUNDFONT_PATH)
    parser.add_argument("--fluidsynth-bin", type=Path, default=DEFAULT_FLUIDSYNTH_BIN)
    parser.add_argument("--ffmpeg-bin", type=Path, default=None)
    parser.add_argument("--sample-rate", type=int, default=DEFAULT_SAMPLE_RATE)
    return parser.parse_args()


def build_sequence_payload(
    song_id: str,
    source_midi_path: Path,
    note_events: list[NoteEvent],
    source_note_end_sec: float,
    trim_seconds: float | None,
    was_trimmed: bool,
) -> dict[str, object]:
    rendered_note_end_sec = max((note.end_sec for note in note_events), default=0.0)
    return {
        "song_id": song_id,
        "source_kind": "midi",
        "source_midi_name": source_midi_path.name,
        "source_note_end_sec": round(source_note_end_sec, 6),
        "rendered_note_end_sec": round(rendered_note_end_sec, 6),
        "was_trimmed": was_trimmed,
        "trim_seconds": trim_seconds,
        "note_events": [note.to_payload() for note in note_events],
    }


def build_metadata_payload(
    song_id: str,
    source_midi_path: Path,
    note_events: list[NoteEvent],
    source_note_end_sec: float,
    preview_duration_sec: float,
    trim_seconds: float | None,
    was_trimmed: bool,
    soundfont_path: Path,
    fluidsynth_bin: Path,
    ffmpeg_bin: Path,
    sample_rate_hz: int,
) -> dict[str, object]:
    rendered_note_end_sec = max((note.end_sec for note in note_events), default=0.0)
    return {
        "song_id": song_id,
        "source_kind": "midi",
        "source_midi_name": source_midi_path.name,
        "note_count": len(note_events),
        "source_note_end_sec": round(source_note_end_sec, 6),
        "rendered_note_end_sec": round(rendered_note_end_sec, 6),
        "preview_duration_sec": round(preview_duration_sec, 6),
        "was_trimmed": was_trimmed,
        "trim_seconds": trim_seconds,
        "sample_rate_hz": sample_rate_hz,
        "soundfont_path": str(soundfont_path),
        "fluidsynth_bin": str(fluidsynth_bin),
        "ffmpeg_bin": str(ffmpeg_bin),
        "generated_at_utc": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
    }


def main() -> int:
    args = parse_args()
    source_midi_path = args.source_midi.resolve()
    output_dir = args.output_dir.resolve()
    soundfont_path = args.soundfont.resolve()
    fluidsynth_bin = resolve_binary(args.fluidsynth_bin.resolve(), "fluidsynth")
    ffmpeg_bin = resolve_binary(args.ffmpeg_bin.resolve() if args.ffmpeg_bin else None, "ffmpeg")
    if not source_midi_path.exists():
        raise FileNotFoundError(f"source midi not found: {source_midi_path}")
    if not soundfont_path.exists():
        raise FileNotFoundError(f"soundfont not found: {soundfont_path}")
    if args.sample_rate <= 0:
        raise ValueError("sample rate must be greater than zero")
    if args.trim_seconds is not None and args.trim_seconds <= 0:
        raise ValueError("trim seconds must be greater than zero")
    output_dir.mkdir(parents=True, exist_ok=True)
    sequence_path = output_dir / f"{args.song_id}_sequence.json"
    metadata_path = output_dir / f"{args.song_id}_preview.metadata.json"
    preview_wav_path = output_dir / f"{args.song_id}_preview.wav"

    source_note_events, source_note_end_sec = build_note_events(source_midi_path)
    normalized_note_events, was_trimmed = apply_optional_trim(source_note_events, args.trim_seconds)
    preview_duration_sec = render_preview_audio(
        source_midi_path=source_midi_path,
        output_preview_wav_path=preview_wav_path,
        soundfont_path=soundfont_path,
        fluidsynth_bin=fluidsynth_bin,
        ffmpeg_bin=ffmpeg_bin,
        sample_rate_hz=args.sample_rate,
        trim_seconds=args.trim_seconds,
    )
    sequence_payload = build_sequence_payload(
        song_id=args.song_id,
        source_midi_path=source_midi_path,
        note_events=normalized_note_events,
        source_note_end_sec=source_note_end_sec,
        trim_seconds=args.trim_seconds,
        was_trimmed=was_trimmed,
    )
    metadata_payload = build_metadata_payload(
        song_id=args.song_id,
        source_midi_path=source_midi_path,
        note_events=normalized_note_events,
        source_note_end_sec=source_note_end_sec,
        preview_duration_sec=preview_duration_sec,
        trim_seconds=args.trim_seconds,
        was_trimmed=was_trimmed,
        soundfont_path=soundfont_path,
        fluidsynth_bin=fluidsynth_bin,
        ffmpeg_bin=ffmpeg_bin,
        sample_rate_hz=args.sample_rate,
    )
    sequence_path.write_text(json.dumps(sequence_payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    metadata_path.write_text(json.dumps(metadata_payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(
        json.dumps(
            {
                "song_id": args.song_id,
                "note_count": len(normalized_note_events),
                "rendered_note_end_sec": metadata_payload["rendered_note_end_sec"],
                "preview_duration_sec": metadata_payload["preview_duration_sec"],
                "preview_wav": str(preview_wav_path),
            },
            ensure_ascii=False,
        )
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:  # pragma: no cover - CLI failure path
        print(str(exc), file=sys.stderr)
        raise SystemExit(1)

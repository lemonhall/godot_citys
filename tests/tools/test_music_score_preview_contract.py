import json
import shutil
import subprocess
import sys
import tempfile
import unittest
import wave
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[2]
SOURCE_MIDI_PATH = PROJECT_ROOT / "reports" / "v23" / "music_road" / "source_private" / "jue_bie_shu_aigei_source.mid"
RENDER_SCRIPT_PATH = PROJECT_ROOT / "tools" / "music_score_preview" / "render_jue_bie_shu_preview.py"
EXPECTED_MIN_NOTE_COUNT = 900
EXPECTED_MIN_DURATION_SEC = 108.0
EXPECTED_MAX_DURATION_SEC = 108.75
EXPECTED_MAX_PREVIEW_DURATION_SEC = 111.5


class MusicScorePreviewContractTest(unittest.TestCase):
    def test_render_preview_from_local_mid(self) -> None:
        self.assertTrue(
            SOURCE_MIDI_PATH.exists(),
            f"expected local archived midi source at {SOURCE_MIDI_PATH}",
        )
        self.assertTrue(
            RENDER_SCRIPT_PATH.exists(),
            f"expected preview renderer script at {RENDER_SCRIPT_PATH}",
        )

        output_root = Path(tempfile.mkdtemp(prefix="music-road-preview-", dir=str(PROJECT_ROOT)))
        try:
            output_dir = output_root / "render"
            sequence_path = output_dir / "jue_bie_shu_sequence.json"
            metadata_path = output_dir / "jue_bie_shu_preview.metadata.json"
            preview_wav_path = output_dir / "jue_bie_shu_preview.wav"

            result = subprocess.run(
                [
                    sys.executable,
                    str(RENDER_SCRIPT_PATH),
                    "--source-midi",
                    str(SOURCE_MIDI_PATH),
                    "--song-id",
                    "jue_bie_shu",
                    "--output-dir",
                    str(output_dir),
                ],
                cwd=str(PROJECT_ROOT),
                capture_output=True,
                text=True,
                check=False,
            )

            self.assertEqual(
                result.returncode,
                0,
                msg="preview renderer must exit cleanly\nstdout:\n%s\nstderr:\n%s"
                % (result.stdout, result.stderr),
            )
            self.assertTrue(sequence_path.exists(), "renderer must export a normalized note sequence json")
            self.assertTrue(metadata_path.exists(), "renderer must export preview metadata json")
            self.assertTrue(preview_wav_path.exists(), "renderer must export a wav preview for human listening QA")

            sequence_payload = json.loads(sequence_path.read_text(encoding="utf-8"))
            metadata_payload = json.loads(metadata_path.read_text(encoding="utf-8"))

            self.assertEqual(sequence_payload.get("song_id"), "jue_bie_shu")
            self.assertEqual(sequence_payload.get("source_kind"), "midi")
            self.assertEqual(sequence_payload.get("source_midi_name"), SOURCE_MIDI_PATH.name)
            self.assertFalse(bool(sequence_payload.get("was_trimmed", False)))
            self.assertGreaterEqual(
                len(sequence_payload.get("note_events", [])),
                EXPECTED_MIN_NOTE_COUNT,
                "normalized sequence must keep the full local MIDI instead of a truncated subset",
            )

            last_note_end_sec = 0.0
            for note_event in sequence_payload.get("note_events", []):
                self.assertIn("start_sec", note_event)
                self.assertIn("duration_sec", note_event)
                self.assertIn("note_id", note_event)
                self.assertGreaterEqual(float(note_event["start_sec"]), 0.0)
                self.assertGreater(float(note_event["duration_sec"]), 0.0)
                last_note_end_sec = max(
                    last_note_end_sec,
                    float(note_event["start_sec"]) + float(note_event["duration_sec"]),
                )
            self.assertGreaterEqual(
                last_note_end_sec,
                EXPECTED_MIN_DURATION_SEC,
                "normalized note sequence must cover the full-length local MIDI arrangement",
            )
            self.assertLessEqual(
                last_note_end_sec,
                EXPECTED_MAX_DURATION_SEC,
                "normalized note sequence duration drifted outside the frozen full-source range",
            )

            self.assertEqual(metadata_payload.get("song_id"), "jue_bie_shu")
            self.assertEqual(metadata_payload.get("source_midi_name"), SOURCE_MIDI_PATH.name)
            self.assertGreaterEqual(int(metadata_payload.get("note_count", 0)), EXPECTED_MIN_NOTE_COUNT)
            self.assertGreaterEqual(
                float(metadata_payload.get("rendered_note_end_sec", 0.0)),
                EXPECTED_MIN_DURATION_SEC,
                "preview metadata must confirm the audible result covers the full local MIDI",
            )
            self.assertLessEqual(
                float(metadata_payload.get("rendered_note_end_sec", 0.0)),
                EXPECTED_MAX_DURATION_SEC,
                "preview metadata duration drifted outside the frozen full-source range",
            )

            with wave.open(str(preview_wav_path), "rb") as wav_file:
                self.assertEqual(wav_file.getnchannels(), 1, "preview wav should stay mono for deterministic QA")
                self.assertEqual(wav_file.getsampwidth(), 2, "preview wav should use 16-bit PCM")
                self.assertGreater(wav_file.getframerate(), 0)
                duration_sec = wav_file.getnframes() / float(wav_file.getframerate())
            self.assertGreaterEqual(
                duration_sec,
                EXPECTED_MIN_DURATION_SEC,
                "preview wav must keep the full local MIDI rather than a trimmed tail",
            )
            self.assertLessEqual(
                duration_sec,
                EXPECTED_MAX_PREVIEW_DURATION_SEC,
                "preview wav duration drifted outside the frozen full-source range",
            )
        finally:
            shutil.rmtree(output_root, ignore_errors=True)


if __name__ == "__main__":
    unittest.main()

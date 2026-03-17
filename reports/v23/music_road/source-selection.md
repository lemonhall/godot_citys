# V23 Music Road Source Selection

## Frozen Source

- Song ID: `jue_bie_shu`
- Root input: `E:\development\godot_citys\诀别书（Cover 邓垚）_爱给网_aigei_com.mid`
- Archived input: `reports/v23/music_road/source_private/jue_bie_shu_aigei_source.mid`
- Freeze basis: [ECN-0023](../../docs/ecn/ECN-0023-music-road-full-midi-source-freeze.md)

## Rationale

- 用户在 `2026-03-17` 明确指定使用这个 `Cover 邓垚` 版本。
- 用户随后明确说明这个版本“很完美，不需要裁切”。
- 当前 `v23` 的 score preview QA gate 与后续音乐公路 runtime sequence 都以这份完整 MIDI 为正式输入。

## Rendering Chain

- Preview renderer: `tools/music_score_preview/render_jue_bie_shu_preview.py`
- Piano soundfont: `E:\soundfont2\FluidR3 GM.sf2`
- Offline synth binary: `C:\tools\fluidsynth\bin\fluidsynth.exe`
- Mono conversion: `ffmpeg`

## Notes

- 当前冻结口径是不裁切完整 MIDI，而不是沿用早期 `110` 秒临时假设。
- 如果未来更换谱源或重新引入裁切，需要新增 ECN，而不是修改这份冻结说明的历史口径。

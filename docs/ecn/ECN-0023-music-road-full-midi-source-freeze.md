# ECN-0023 V23 Music Road Full MIDI Source Freeze

## Why

`v23` 早期口径曾基于用户先前提供的较差 MIDI 质量，临时冻结了“只取前 `1:50`（`110` 秒）有效段”的裁切约束，并把 score preview QA gate 设计成“必须 trim 到 110 秒”。

随后用户在 `2026-03-17` 提供了一个新的本地 MIDI 源：

- `E:\development\godot_citys\诀别书（Cover 邓垚）_爱给网_aigei_com.mid`

用户明确说明这个新版本“很完美，不需要裁切”。这意味着旧的 `110` 秒裁切约束已经不再反映当前冻结需求。如果继续沿用旧约束，后续 score preview 工具、normalized note sequence 与游戏内音乐公路 runtime 都会被错误地设计成“默认截断版”。

## Change

- `v23` 当前正式谱源冻结为用户提供的完整本地 MIDI：
  - 根目录输入：`诀别书（Cover 邓垚）_爱给网_aigei_com.mid`
  - 仓库内稳定归档输入：`reports/v23/music_road/source_private/jue_bie_shu_aigei_source.mid`
- score preview QA gate 与后续 runtime sequence 都必须以这份完整 MIDI 为正式输入，不再要求 `110` 秒裁切。
- `tools/music_score_preview/render_jue_bie_shu_preview.py` 的正式验收口径改为：
  - 从完整 MIDI 导出 normalized note sequence
  - 输出 metadata
  - 输出可试听 `wav`
  - 当前正式 artifact 不依赖 `--trim-seconds`
- 如未来又出现需要裁切的谱源，应另行新增 ECN，而不是复活这次已废弃的 `110` 秒假设。

## Still Out Of Scope

- 本 ECN 不改变 `v23` 当前唯一 `song_id = jue_bie_shu` 的范围。
- 本 ECN 不改变“必须提供试听 QA 产物”的要求。
- 本 ECN 不改变“游戏运行时不得直接依赖 `refs/`”的资产边界。

## Affected Docs

- `docs/prd/PRD-0013-music-road-landmark-and-song-trigger.md`
- `docs/plan/v23-index.md`
- `docs/plan/v23-music-road-landmark.md`
- `docs/plans/2026-03-17-v23-music-road-design.md`
- `tests/tools/test_music_score_preview_contract.py`

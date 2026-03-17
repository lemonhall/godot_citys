# V23 Index

## 愿景

PRD 入口：[PRD-0013 Music Road Landmark And Song Trigger](../prd/PRD-0013-music-road-landmark-and-song-trigger.md)

设计入口：[2026-03-17-v23-music-road-design.md](../plans/2026-03-17-v23-music-road-design.md)

依赖入口：

- [PRD-0004 Vehicle Hijack Driving](../prd/PRD-0004-vehicle-hijack-driving.md)
- [PRD-0011 Custom Building Full-Map Icons](../prd/PRD-0011-custom-building-full-map-icons.md)
- [PRD-0012 World Feature Ground Probe And Landmark Overrides](../prd/PRD-0012-world-feature-ground-probe-and-landmark-overrides.md)
- [v18-index.md](./v18-index.md)
- [v21-index.md](./v21-index.md)

`v23` 的目标是把“钢琴道路”正式做成一个可发现、可驾驶、可演奏的世界体验点。当前推荐路线不是动 existing `road_graph`，而是新增一个独立 authored 的 `scene_landmark` 音乐公路：它像喷泉和铁塔一样通过 `registry -> manifest -> scene` 被 lazy mount，full map 上用 `music_road` 图标暴露起点，玩家驾车进入后沿正式方向和正式速度窗口依次触发音符，最终完整演奏当前唯一支持的曲目《诀别书》。这条链必须从第一版起就冻结 future-ready 的 `music_road_definition` contract，避免把歌曲、速度和触发条都硬编码进脚本；同时，逆向通过要能逆序出音，减速要真的把旋律拉慢，键位 shader 预点亮也直接属于 `v23` 范围。[已由 ECN-0022 变更]

当前状态：`v23` 处于文档冻结阶段，尚未进入 TDD Red / Green。

## 决策冻结

- `v23` 首版采用“独立 authored 音乐公路 scene_landmark”路线，不改 procedural `road_graph / lane graph` 主链。
- 音乐公路当前只支持一个正式 `song_id`：`jue_bie_shu`。
- 音乐公路的 full-map pin `icon_id` 冻结为 `music_road`，UI glyph 冻结为 `🎵`。
- 音乐公路 pin 默认只进入 `full_map`，不进入 minimap。
- 正式 run 必须由 `entry_gate + entry_direction + player driving state + vehicle world position + speed window` 联合决定。
- reverse traversal 必须产生 reverse audition，但不计为 canonical `song_success`。
- note timing 必须来自真实 crossing 时间，不能量化成固定节拍。
- 视觉 cue 冻结为“钢琴键提示 + shader 预点亮/命中/衰减”，不是机械可动琴键。
- `music_road_definition` 必须独立存在，不允许把歌曲数据硬编码进 landmark script。
- 高速路视觉资产优先复用 `refs/godot-road-generator` 中可稳定抽取的 mesh / material 体系，但正式运行时不得直接依赖 `res://refs/...`。
- 必须新增中间试听 QA gate：把最终采用的 normalized 《诀别书》音符序列渲染成可试听 `wav` 产物，供用户用听觉检查。
- 最终 placement 的 `chunk_id / world_position.y` 需在实现阶段通过 fresh `ground_probe` 冻结。

## 里程碑

| 里程碑 | 范围 | DoD | 验证命令/测试 | 状态 |
|---|---|---|---|---|
| M0 docs freeze | PRD、design、v23 plan、traceability | `PRD-0013`、`v23-index`、`v23-music-road-landmark`、design doc 全部落地且 Req ID 可追溯 | `rg -n "REQ-0013" docs/prd/PRD-0013-music-road-landmark-and-song-trigger.md docs/plan/v23-index.md docs/plan/v23-music-road-landmark.md` | done |
| M1 score-source QA gate | 官方音频锚点、机读谱源候选、人类可读谱预览、试听产物 | 选定 normalized 《诀别书》音符序列；导出 `wav` 试听产物供人工验耳 | `tools/music_score_preview/render_jue_bie_shu_preview.py`、`reports/v23/music_road/jue_bie_shu_preview.wav` | todo |
| M2 landmark placement + map pin | 音乐公路 registry/manifest/scene、full-map 起点 pin | 音乐公路可作为 scene_landmark mount，full map 出现 `music_road` 起点 icon，minimap 不泄漏 | `tests/world/test_city_music_road_manifest_contract.gd`、`tests/e2e/test_city_music_road_full_map_flow.gd` | todo |
| M3 visual road cue | 独立 authored 直线道路、钢琴键视觉、shader 预点亮、ground alignment | 驾驶视角下可读出钢琴道路语义；键位具备 `approach / active / decay` 视觉相位 | `tests/world/test_city_music_road_visual_envelope.gd`、`tests/world/test_city_music_road_visual_phase_contract.gd` | todo |
| M4 song trigger runtime | definition contract、entry gate、真实 timing、`诀别书` 正反向 audition | 正向目标速度窗口内完整 run 触发正式 note sequence 并标记 success；逆向与变速产生真实可听结果 | `tests/world/test_city_music_road_definition_contract.gd`、`tests/world/test_city_music_road_runtime_sequence_contract.gd`、`tests/world/test_city_music_road_speed_window_contract.gd`、`tests/world/test_city_music_road_reverse_traversal_contract.gd`、`tests/e2e/test_city_music_road_drive_song_flow.gd` | todo |
| M5 verification | landmark / map / driving / profiling 回归 | 受影响主链不回退，profiling 三件套产出 fresh evidence | `tests/world/test_city_chunk_setup_profile_breakdown.gd`、`tests/e2e/test_city_runtime_performance_profile.gd`、`tests/e2e/test_city_first_visit_performance_profile.gd` | todo |

## 计划索引

- [v23-music-road-landmark.md](./v23-music-road-landmark.md)

## 追溯矩阵

| Req ID | v23 Plan | 单元/集成测试 | E2E / 验证命令 | 证据 | 状态 |
|---|---|---|---|---|---|
| REQ-0013-001 | `v23-music-road-landmark.md` | `tests/world/test_city_music_road_manifest_contract.gd` | `--script res://tests/e2e/test_city_music_road_full_map_flow.gd` | — | todo |
| REQ-0013-002 | `v23-music-road-landmark.md` | `tests/world/test_city_music_road_definition_contract.gd` | `--script res://tests/world/test_city_music_road_runtime_sequence_contract.gd` | — | todo |
| REQ-0013-003 | `v23-music-road-landmark.md` | `tests/world/test_city_music_road_visual_envelope.gd`、`tests/world/test_city_music_road_visual_phase_contract.gd` | `--script res://tests/e2e/test_city_music_road_drive_song_flow.gd` | — | todo |
| REQ-0013-004 | `v23-music-road-landmark.md` | `tests/world/test_city_music_road_runtime_sequence_contract.gd`、`tests/world/test_city_music_road_speed_window_contract.gd`、`tests/world/test_city_music_road_reverse_traversal_contract.gd` | `--script res://tests/e2e/test_city_music_road_drive_song_flow.gd` | — | todo |
| REQ-0013-005 | `v23-music-road-landmark.md` | `tests/world/test_city_scene_landmark_registry_runtime.gd`、`tests/world/test_city_player_vehicle_drive_mode.gd` | `--script res://tests/world/test_city_chunk_setup_profile_breakdown.gd`、`--script res://tests/e2e/test_city_runtime_performance_profile.gd`、`--script res://tests/e2e/test_city_first_visit_performance_profile.gd` | — | todo |
| REQ-0013-006 | `v23-music-road-landmark.md` | `tools/music_score_preview/render_jue_bie_shu_preview.py` | `reports/v23/music_road/jue_bie_shu_preview.wav` | — | todo |

## ECN 索引

- [ECN-0022 Music Road Runtime Authenticity And Score Preview](../ecn/ECN-0022-music-road-runtime-authenticity-and-score-preview.md)

## 差异列表

- `v23` 当前只完成文档冻结，尚未开始 Red / Green / E2E。
- `v23` 不把音乐公路接入 route query / place search / fast travel / autodrive。
- `v23` 当前只支持 `song_id = jue_bie_shu`，但 data contract 从第一版起必须支持 future song library 扩展。
- 《诀别书》最终采用哪一份 normalized arrangement，必须以试听 QA gate 结果为准，而不是凭肉眼看谱直接冻结。
- 最终 placement chunk 与 absolute `y` 高度需要在实现阶段通过 fresh `ground_probe` 取证后冻结。

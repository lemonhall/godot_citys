# V23 Music Road Landmark

## Goal

交付一条正式的“scene landmark 音乐公路”实现计划：它以独立 authored 公路 scene 的形式挂进世界，在 full map 上以 `music_road` 起点 pin 暴露位置，玩家驾车沿正式方向和正式速度窗口通过时，依次触发《诀别书》的音符序列，而不破坏现有 landmark / driving / map / profiling 主链。

## PRD Trace

- Direct consumer: REQ-0013-001
- Direct consumer: REQ-0013-002
- Direct consumer: REQ-0013-003
- Direct consumer: REQ-0013-004
- Guard / Performance: REQ-0013-005

## Dependencies

- 依赖 `v21` 已冻结 `scene_landmark registry -> manifest -> near chunk mount -> optional full_map_pin` 主链。
- 依赖 `v18` 已冻结 full-map `icon_id -> glyph` UI contract。
- 依赖 `v9` / `PRD-0004` 已冻结玩家 driving state 暴露。
- 依赖 `refs/godot-road-generator` 作为只读道路 authoring 参考，但不直接 vendoring 其插件或 runtime。

## Contract Freeze

- 音乐公路的正式 feature family 继续复用 `scene_landmark`。
- 音乐公路的 full-map pin `icon_id` 在 `v23` 冻结为 `music_road`。
- `music_road` 的 UI glyph 在 `v23` 冻结为 `🎵`。
- 新增正式 sidecar：`music_road_definition`。
- `music_road_definition` 最小字段冻结为：
  - `experience_kind`
  - `song_id`
  - `display_name`
  - `target_speed_mps`
  - `speed_tolerance_mps`
  - `entry_direction`
  - `entry_gate`
  - `note_strips`
- `experience_kind` 冻结为 `music_road`。
- `song_id` 在 `v23` 冻结为 `jue_bie_shu`。
- `note_strips` 最小字段冻结为：
  - `strip_id`
  - `order_index`
  - `local_center`
  - `trigger_width_m`
  - `trigger_length_m`
  - `note_id`
  - `sample_id`
  - `visual_key_kind`
- run success 的正式语义冻结为：玩家处于 `driving = true`，从 `entry_gate` 以 `entry_direction` 正向进入，并在 `target_speed_mps ± speed_tolerance_mps` 窗口内依序通过全部 strip。
- 音乐公路 pin 保持 `visibility_scope = full_map`，不进入 minimap。
- 音乐公路不接入 `road_graph / vehicle lane graph / place_query` 正式 contract。

## Scope

做什么：

- 通过 `scene_landmark` 链新增音乐公路 consumer
- 为音乐公路补齐 manifest / registry / full-map pin
- author 一段独立 straight corridor road scene，并提供钢琴键视觉 cue
- 新增 `music_road_definition` sidecar
- 新增 driving-position-based note trigger runtime
- 为《诀别书》冻结当前唯一曲目配置
- 补齐 manifest / definition / visual / runtime / e2e / profiling 计划

不做什么：

- 不改现有 procedural 道路生成器
- 不把音乐公路接进导航、搜索、瞬移或自动驾驶
- 不做机械式琴键碰撞件
- 不做多曲库 UI
- 不做节奏评分系统

## Acceptance

1. 自动化测试必须证明：音乐公路沿正式 `scene_landmark` 主链接入，registry / manifest / scene path 口径一致。
2. 自动化测试必须证明：打开 full map 后，render state 出现 `icon_id = music_road` 且 `icon_glyph = 🎵` 的起点 marker；minimap 不泄漏。
3. 自动化测试必须证明：`music_road_definition` 作为独立 sidecar 存在，`song_id = jue_bie_shu` 与 `note_strips` 正式解码，而不是脚本里硬编码。
4. 自动化测试必须证明：音乐公路 visual envelope 可读、贴地、可驾驶，并同时存在 `white` 与 `black` 两类钢琴键 cue。
5. 自动化测试必须证明：synthetic target-speed driving run 会按 `order_index` 依序触发全部 note，并产生 `song_success = true`。
6. 自动化测试必须证明：速度超窗、逆向进入、非 driving 状态都不会被误判成正式成功 run。
7. 自动化测试必须证明：同一条 strip 在同一 run 内不会 double-fire。
8. 自动化测试必须证明：scene landmark / map pin / driving 既有主链不回退。
9. profiling 三件套必须串行给出 fresh 结果。
10. 反作弊条款：不得通过“run 开始即播放整段音频”“脚本硬编码《诀别书》全部条带”“把地图 glyph 直接写死在 UI 不走 icon_id”“把音乐公路塞进 road_graph 测试夹具”来宣称完成。

## Proposed Files

- Create: `docs/prd/PRD-0013-music-road-landmark-and-song-trigger.md`
- Create: `docs/plan/v23-index.md`
- Create: `docs/plan/v23-music-road-landmark.md`
- Create: `docs/plans/2026-03-17-v23-music-road-design.md`
- Future Create: `city_game/serviceability/landmarks/generated/landmark_v23_music_road_<chunk>/music_road_landmark.tscn`
- Future Create: `city_game/serviceability/landmarks/generated/landmark_v23_music_road_<chunk>/landmark_manifest.json`
- Future Create: `city_game/serviceability/landmarks/generated/landmark_v23_music_road_<chunk>/music_road_definition.json`
- Future Modify: `city_game/serviceability/landmarks/generated/landmark_override_registry.json`
- Future Modify: `city_game/ui/CityMapScreen.gd`
- Future Create: `city_game/world/features/music_road/CityMusicRoadRunState.gd`
- Future Create: `city_game/world/features/music_road/CityMusicRoadDefinition.gd`
- Future Create: `city_game/world/features/music_road/CityMusicRoadNotePlayer.gd`
- Future Create: `city_game/world/features/music_road/CityMusicRoadRuntime.gd`
- Future Create: `tests/world/test_city_music_road_manifest_contract.gd`
- Future Create: `tests/world/test_city_music_road_definition_contract.gd`
- Future Create: `tests/world/test_city_music_road_visual_envelope.gd`
- Future Create: `tests/world/test_city_music_road_runtime_sequence_contract.gd`
- Future Create: `tests/world/test_city_music_road_speed_window_contract.gd`
- Future Create: `tests/e2e/test_city_music_road_full_map_flow.gd`
- Future Create: `tests/e2e/test_city_music_road_drive_song_flow.gd`

## Steps

1. Analysis
   - 用 fresh `ground_probe` 锁定最终挂载 chunk、absolute `world_position` 与 entry 朝向
   - 盘点 driving state、scene landmark runtime、full-map pin、audio 路径的现有 consumer
   - 记录 `refs/godot-road-generator` 可借鉴点：独立道路 scene、custom material、museum demo；明确不直接接插件
2. Design
   - 冻结“独立 authored straight corridor music road”路线
   - 冻结 `music_road_definition` 最小字段与《诀别书》唯一 `song_id`
   - 冻结 `music_road` full-map pin 语义
3. Plan
   - 写 `PRD-0013`
   - 写 `v23-index.md`
   - 写 `v23-music-road-landmark.md`
   - 写 design doc，解释为什么不走 existing `road_graph` takeover
4. TDD Red
   - 先写 manifest / full-map pin contract test
   - 再写 definition contract test
   - 再写 visual envelope test
   - 再写 runtime sequence / speed window tests
   - 最后写 full-map flow 与 drive-song flow e2e
5. TDD Green
   - author landmark scene / manifest / registry
   - author `music_road_definition`
   - 实现 runtime sequence trigger 与 note playback
   - 接上 full-map pin glyph 与 debug state
6. Refactor
   - 收口 note strip parsing、run state、audio note player，避免 `CityPrototype` 膨胀
   - 确保 mounted-only update，不做全城 per-frame scan
7. E2E
   - 跑 `test_city_music_road_full_map_flow.gd`
   - 跑 `test_city_music_road_drive_song_flow.gd`
   - 检查 drive-song flow 对逆向、异常速度与重复进入的 reset 行为
8. Review
   - 回填 `v23-index` 追溯矩阵
   - 写 verification artifact
   - 对照 `PRD-0013` 检查是否仍只支持 `jue_bie_shu` 且没有偷偷扩 scope
9. Ship
   - `v23: doc: freeze music road scope and plan`
   - 后续实现按 `test / feat / fix / refactor` 切小提交

## Risks

- 如果把音乐公路做成 existing `road_graph` 的正式道路 consumer，会直接污染导航、lane graph 和 perf 口径。
- 如果条带顺序与音符写死在脚本里，未来 song library 会立刻返工。
- 如果触发逻辑依赖 `Area3D` 碰撞而没有 formal run state，可能出现高速漏触发或 double-fire；实现阶段要优先用可测试的“车辆世界位置 -> 条带 crossing” contract 校验。
- 如果只做地图 pin，不做清晰路面 cue，玩家到场后仍然读不出“钢琴道路”的玩法语义。
- 如果 audio 方案偷懒为整段预录音频，曲目就不再由位置和速度驱动，会直接违反核心产品语义。

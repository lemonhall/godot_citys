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
- 依赖 `refs/godot-road-generator` 作为只读道路 authoring 参考与 highway 资产候选来源，但不直接 vendoring 其插件或 runtime。

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
  - `approach_glow_distance_m`
  - `hit_flash_duration_sec`
  - `release_decay_duration_sec`
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
- reverse traversal 必须按真实 crossing 顺序逆序触发音符，但不计为 canonical `song_success`。
- note timing 必须来自真实 crossing 时间，而不是固定节拍。
- visual phase 最小语义冻结为：`idle / approach / active / decay`。
- 高速路视觉资产优先复用 `refs/godot-road-generator` 可稳定抽取的 mesh / material 体系；但 `refs/` 里的候选资源一旦经视觉级验证后被采用，就必须复制到 `city_game/assets/environment/source/music_road/road_generator_frozen/`，正式运行时不得直接依赖 `res://refs/...`。
- 必须新增 authoring QA gate：基于选定 normalized note sequence 渲染 `wav` 试听产物供用户验耳。
- run success 的正式语义冻结为：玩家处于 `driving = true`，从 `entry_gate` 以 `entry_direction` 正向进入，并在 `target_speed_mps ± speed_tolerance_mps` 窗口内依序通过全部 strip。
- 音乐公路 pin 保持 `visibility_scope = full_map`，不进入 minimap。
- 音乐公路不接入 `road_graph / vehicle lane graph / place_query` 正式 contract。

## Scope

做什么：

- 通过 `scene_landmark` 链新增音乐公路 consumer
- 为音乐公路补齐 manifest / registry / full-map pin
- author 一段独立 straight corridor road scene，并提供钢琴键视觉 cue
- 优先复用 `refs/godot-road-generator` 的 mesh / material 体系作为 straight-highway 视觉底座
- 视觉验证通过的 refs-lineage highway 资产必须冻结到 `city_game/assets/environment/source/music_road/road_generator_frozen/`
- 新增 `music_road_definition` sidecar
- 新增 driving-position-based note trigger runtime
- 把 shader 预点亮 / 命中发光 / 衰减熄灭直接纳入 `v23`
- 新增《诀别书》试听渲染 QA 工具与中间产物
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
4. 自动化测试必须证明：音乐公路 visual envelope 可读、贴地、可驾驶，并同时存在 `white` 与 `black` 两类钢琴键 cue；若采用 refs-lineage highway 资产，则正式 scene 只引用项目自有复制件。
5. 自动化测试必须证明：每条 key strip 都具备 `approach / active / decay` 视觉相位，shader 可直接消费。
6. 自动化测试必须证明：synthetic target-speed driving run 会按 `order_index` 依序触发全部 note，并产生 `song_success = true`。
7. 自动化测试必须证明：reverse traversal 会按真实 crossing 顺序逆序触发音符；慢速与快速 run 会产出不同的 note event 时间间隔。
8. 自动化测试必须证明：速度超窗、逆向进入、非 driving 状态都不会被误判成正式成功 run。
9. 自动化测试必须证明：同一条 strip 在同一 run 内不会 double-fire。
10. 自动化测试必须证明：存在《诀别书》试听渲染 QA 工具与 `wav` 中间产物，且 drive runtime 与试听工具消费的是同一份 normalized note sequence。
11. 自动化测试必须证明：scene landmark / map pin / driving 既有主链不回退。
12. profiling 三件套必须串行给出 fresh 结果。
13. 反作弊条款：不得通过“run 开始即播放整段音频”“脚本硬编码《诀别书》全部条带”“把地图 glyph 直接写死在 UI 不走 icon_id”“把音乐公路塞进 road_graph 测试夹具”“只给曲谱截图不给试听产物”来宣称完成。

## Proposed Files

- Create: `docs/prd/PRD-0013-music-road-landmark-and-song-trigger.md`
- Create: `docs/ecn/ECN-0022-music-road-runtime-authenticity-and-score-preview.md`
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
- Future Create: `city_game/assets/environment/source/music_road/road_generator_frozen/`
- Future Create: `tools/music_score_preview/render_jue_bie_shu_preview.py`
- Future Create: `reports/v23/music_road/source-selection.md`
- Future Create: `reports/v23/music_road/jue_bie_shu_preview.wav`
- Future Create: `tests/world/test_city_music_road_manifest_contract.gd`
- Future Create: `tests/world/test_city_music_road_definition_contract.gd`
- Future Create: `tests/world/test_city_music_road_visual_envelope.gd`
- Future Create: `tests/world/test_city_music_road_visual_phase_contract.gd`
- Future Create: `tests/world/test_city_music_road_runtime_sequence_contract.gd`
- Future Create: `tests/world/test_city_music_road_speed_window_contract.gd`
- Future Create: `tests/world/test_city_music_road_reverse_traversal_contract.gd`
- Future Create: `tests/e2e/test_city_music_road_full_map_flow.gd`
- Future Create: `tests/e2e/test_city_music_road_drive_song_flow.gd`

## Steps

1. Analysis
   - 用 fresh `ground_probe` 锁定最终挂载 chunk、absolute `world_position` 与 entry 朝向
   - 盘点 driving state、scene landmark runtime、full-map pin、audio 路径的现有 consumer
   - 记录 `refs/godot-road-generator` 可借鉴点：独立道路 scene、custom material、museum demo；明确不直接接插件
   - 筛选可用 highway mesh / material 候选，并约定一旦视觉级验证通过就复制到 `city_game/assets/environment/source/music_road/road_generator_frozen/`
   - 自行搜索《诀别书》谱源，采用“官方音频锚点 + 机读谱源 + 人类可读谱预览”三角校验
2. Design
   - 冻结“独立 authored straight corridor music road”路线
   - 冻结 `music_road_definition` 最小字段、shader 相位字段与《诀别书》唯一 `song_id`
   - 冻结 `music_road` full-map pin 语义
   - 冻结 reverse audition 与真实 timing 语义
3. Plan
   - 写 `PRD-0013`
   - 写 `ECN-0022`
   - 写 `v23-index.md`
   - 写 `v23-music-road-landmark.md`
   - 写 design doc，解释为什么不走 existing `road_graph` takeover
4. TDD Red
   - 先写 score preview QA gate 的最小检查
   - 先写 manifest / full-map pin contract test
   - 再写 definition contract test
   - 再写 visual envelope / visual phase tests
   - 再写 runtime sequence / speed window / reverse traversal tests
   - 最后写 full-map flow 与 drive-song flow e2e
5. TDD Green
   - 固定谱源与 normalized note sequence，并导出 `wav` 试听产物
   - author landmark scene / manifest / registry
   - 把通过视觉验证的 refs-lineage highway mesh / material 复制并整理到 `city_game/assets/environment/source/music_road/road_generator_frozen/`
   - author `music_road_definition`
   - 实现 runtime sequence trigger、reverse audition 与 note playback
   - 实现 shader 预点亮 / 命中 / 衰减相位输出
   - 接上 full-map pin glyph 与 debug state
6. Refactor
   - 收口 note strip parsing、run state、audio note player、visual phase state，避免 `CityPrototype` 膨胀
   - 确保 mounted-only update，不做全城 per-frame scan
   - 确保试听工具与 runtime 消费同一份 normalized note sequence
7. E2E
   - 跑 `test_city_music_road_full_map_flow.gd`
   - 跑 `test_city_music_road_drive_song_flow.gd`
   - 检查 drive-song flow 对逆向、异常速度、重复进入与 shader 相位的 reset 行为
8. Review
   - 回填 `v23-index` 追溯矩阵
   - 写 verification artifact
   - 对照 `PRD-0013` 检查是否仍只支持 `jue_bie_shu` 且没有偷偷扩 scope
   - 用 `reports/v23/music_road/jue_bie_shu_preview.wav` 做人工听觉验收锚点
9. Ship
   - `v23: doc: freeze music road scope and plan`
   - 后续实现按 `test / feat / fix / refactor` 切小提交

## Risks

- 如果把音乐公路做成 existing `road_graph` 的正式道路 consumer，会直接污染导航、lane graph 和 perf 口径。
- 如果条带顺序与音符写死在脚本里，未来 song library 会立刻返工。
- 如果没有试听 QA gate，就很难让不识谱的用户确认最终 note sequence 是否正确。
- 如果触发逻辑依赖 `Area3D` 碰撞而没有 formal run state，可能出现高速漏触发或 double-fire；实现阶段要优先用可测试的“车辆世界位置 -> 条带 crossing” contract 校验。
- 如果 shader 相位和 note trigger 不是同一套 strip state，视觉和音频会很容易漂移。
- 如果视觉上采用了 refs-lineage 资产却不先复制进项目自有 `assets` 目录，后续 import、引用稳定性和正式交付边界都会变得含糊。
- 如果只做地图 pin，不做清晰路面 cue，玩家到场后仍然读不出“钢琴道路”的玩法语义。
- 如果 audio 方案偷懒为整段预录音频，曲目就不再由位置和速度驱动，会直接违反核心产品语义。

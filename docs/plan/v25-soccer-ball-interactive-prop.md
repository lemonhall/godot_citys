# V25 Soccer Ball Interactive Prop

## Goal

交付一条正式的 `scene_interactive_prop` 实现计划：把仓库根目录的足球模型归置为正式资产，通过 `registry -> manifest -> near chunk mount -> scene` 挂进 `chunk_129_139`，并让玩家通过 `E` 键对足球执行最小可用的真实物理 kick 交互，而不污染现有 landmark、地图 pin、NPC prompt 与 streaming 主链。

## PRD Trace

- Direct consumer: REQ-0015-001
- Direct consumer: REQ-0015-002
- Direct consumer: REQ-0015-003
- Guard / Performance: REQ-0015-004

## Dependencies

- 依赖 `v21` 已冻结 `scene_landmark registry -> manifest -> near chunk mount` 的 authored 世界接入思路，但本版不复用其语义。
- 依赖 NPC interaction 主链已冻结 `E` 键 prompt + HUD prompt contract。
- 依赖 `CityChunkRenderer / CityChunkScene` 现有 chunk mount 事件链。

## Contract Freeze

- 新增正式 family：`scene_interactive_prop`。
- registry entry 最小字段冻结为：
  - `prop_id`
  - `feature_kind`
  - `manifest_path`
  - `scene_path`
- `feature_kind` 在 `v25` 冻结为 `scene_interactive_prop`。
- manifest 最小字段冻结为：
  - `prop_id`
  - `display_name`
  - `feature_kind`
  - `anchor_chunk_id`
  - `anchor_chunk_key`
  - `world_position`
  - `surface_normal`
  - `scene_root_offset`
  - `scene_path`
  - `manifest_path`
- 足球正式 `prop_id` 冻结为 `prop:v25:soccer_ball:chunk_129_139`。
- 足球 authored anchor 冻结为：
  - `world_position = (-1877.94, 2.52, 618.57)`
  - `surface_normal = (-0.02, 1.00, -0.02)`
- `world_position` 语义冻结为地面 anchor，`scene_root_offset` 负责把真实球心抬高到物理 resting 高度。
- [已由 ECN-0024 变更] 足球尺寸冻结为 oversized 可读玩法尺寸：
  - `target_diameter_m = 1.20`
  - `scene_root_offset.y = 0.60`
- 足球交互 prompt 最小语义冻结为：
  - 带 `E`
  - 明确“踢球”
  - driving mode 下不可激活
- kick 行为最小语义冻结为：
  - 基于玩家与球的平面方向或朝向
  - 施加 forward impulse
  - 施加可读 upward lift
  - 不允许 teleport / 关键帧直写终点
- 足球不进入 full map / minimap pin registry。

## Scope

做什么：

- 新增 interactive prop registry/runtime
- 在 chunk renderer / chunk scene 增加 interactive prop mount 入口
- 归置足球 `glb` 到正式资产目录
- author 足球 manifest / scene / registry entry
- 新增 interactive prop interaction runtime
- 把足球踢球接到 `E` 键 primary interaction 合流
- 补 manifest/runtime/kick/e2e 测试

不做什么：

- 不做球门、比分、规则或 AI
- 不做地图 pin
- 不做跨 session 足球位置持久化
- 不做跨 chunk ownership 迁移
- 不做专门踢腿动画

## Acceptance

1. 自动化测试必须证明：interactive prop registry/runtime 能正式读取足球 entry，并按 `chunk_129_139` 索引。
2. 自动化测试必须证明：足球 manifest / registry / scene path 三者口径一致，且保存用户给定的 authored anchor 与 normal。
3. 自动化测试必须证明：足球在目标 chunk near mount 时会被实例化，并带稳定 `prop_id` 元数据。
4. 自动化测试必须证明：足球 mounted 后视觉包围盒达到冻结的 oversized 尺寸区间，且 visual bottom 与地面基本对齐。
5. 自动化测试必须证明：靠近足球时 HUD 会显示带 `E` 的踢球 prompt。
6. 自动化测试必须证明：触发 kick 后，足球 `linear_velocity` 或实际位移显著变化，且变化来自真实物理 body。
7. 自动化测试必须证明：超出交互半径或 driving mode 下不会误踢球。
8. 受影响的 NPC interaction、scene landmark mount 与 streaming 相关测试必须继续通过。
9. 反作弊条款：不得把足球重新挂成 `scene_landmark`；不得把 kick 实现成 teleport 或脚本写死终点；不得只保留根目录 `glb` 而不做正式资产归置；不得用每帧 registry scan 冒充 runtime。

## Files

- Create: `docs/prd/PRD-0015-soccer-ball-interactive-prop.md`
- Create: `docs/plan/v25-index.md`
- Create: `docs/plan/v25-soccer-ball-interactive-prop.md`
- Create: `docs/plans/2026-03-18-v25-interactive-prop-design.md`
- Move/Create: `city_game/assets/environment/source/interactive_props/soccer_ball/`
- Create: `city_game/world/features/CitySceneInteractivePropRegistry.gd`
- Create: `city_game/world/features/CitySceneInteractivePropRuntime.gd`
- Create: `city_game/world/interactions/CityInteractivePropRuntime.gd`
- Create: `city_game/serviceability/interactive_props/generated/interactive_prop_registry.json`
- Create: `city_game/serviceability/interactive_props/generated/prop_v25_soccer_ball_chunk_129_139/interactive_prop_manifest.json`
- Create: `city_game/serviceability/interactive_props/generated/prop_v25_soccer_ball_chunk_129_139/soccer_ball_prop.tscn`
- Create: `city_game/serviceability/interactive_props/generated/prop_v25_soccer_ball_chunk_129_139/SoccerBallProp.gd`
- Modify: `city_game/scripts/CityPrototype.gd`
- Modify: `city_game/world/rendering/CityChunkRenderer.gd`
- Modify: `city_game/world/rendering/CityChunkScene.gd`
- Modify: `city_game/ui/PrototypeHud.gd` only if prompt contract absolutely requires
- Create: `tests/world/test_city_scene_interactive_prop_registry_runtime.gd`
- Create: `tests/world/test_city_soccer_ball_manifest_contract.gd`
- Create: `tests/world/test_city_soccer_ball_visual_envelope.gd`
- Create: `tests/world/test_city_soccer_ball_kick_contract.gd`
- Create: `tests/e2e/test_city_soccer_ball_interaction_flow.gd`

## Steps

1. Analysis
   - 固定足球 `prop_id`、registry path、manifest path、scene path、asset path。
   - 固定 `world_position / surface_normal / scene_root_offset` 语义。
   - 审计现有 NPC prompt 与 `E` 键链，决定如何做 primary interaction 合流。
2. Design
   - 写 `PRD-0015`
   - 写 `v25-index.md`
   - 写 `v25-soccer-ball-interactive-prop.md`
   - 写 design doc，明确为什么不能继续叫 landmark
3. TDD Red
   - 先写 interactive prop registry/runtime contract test
   - 再写 soccer manifest contract / visual envelope test
   - 再写 kick contract
   - 最后写 interaction flow e2e
4. Run Red
   - 逐条运行新测试，确认失败原因是 family / registry / scene / interaction 尚未实现，而不是测试拼写错误
5. TDD Green
   - 归置足球资产
   - 实现 registry/runtime
   - author soccer manifest / scene / script
   - 接入 chunk mount
   - 实现 interactive prop runtime 与 `E` 键 kick
6. Refactor
   - 收口 primary interaction 合流逻辑，避免 `CityPrototype.gd` 继续堆满特判
   - 冷路径保留完整 entry snapshot，热路径只保留当前 active interaction summary
7. E2E
   - 跑足球 interaction flow
   - 补跑受影响 NPC / landmark / streaming tests
8. Review
   - 更新 `v25-index` traceability
   - 写差异列表与 verification evidence
9. Ship
   - `v25: doc: freeze interactive prop scope`
   - 后续红绿 slices 分别 `test / feat / refactor`

## Risks

- 如果把足球 family 直接做成 `scene_landmark`，后面所有可推道具都会被错误建模成“地图地标”。
- 如果只依赖 CharacterBody 自然碰撞，没有正式 kick contract，体验会不可控且难以测试。
- 如果球心/地面 anchor 语义不分开，最容易出现“用户给的 y 是对的，但球还是埋地或悬浮”。
- 如果 primary interaction 合流做得粗暴，NPC dialogue prompt 很容易被足球抢焦点。
- 如果球体作为 chunk-local 道具滚出 near window，首版会丢失它；这属于已知范围，不应在 `v25` 偷偷扩成持久化系统。

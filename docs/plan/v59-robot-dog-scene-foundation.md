# V59 Robot Dog Scene Foundation

## Goal

把用户刚手工拆件完成的机械狗模型正式纳入仓库 creature 资产链，交付可复用的 `CityRobotDog.tscn` 与 `RobotDogLab.tscn`，并冻结 8 个腿部关节锚点的 scene-first contract。

## PRD Trace

- `REQ-0031-001`
- `REQ-0031-002`
- `REQ-0031-003`
- `REQ-0031-004`

## Dependencies

- reference pattern：
  - `res://city_game/world/creatures/arthropods/CityLobsterCrawler.tscn`
  - `res://city_game/scenes/labs/LobsterCrawlerLab.tscn`
  - `res://tests/world/test_lobster_crawler_lab_scene_contract.gd`
- incoming asset：
  - `robot dog_02.glb`
  - `robot dog_02_militaryquadrobot3dmodel_basecolor.jpg`

## Scope

做什么：

- 搬运机械狗 glb 与贴图到正式 creature 资产目录
- 创建 `CityRobotDog.tscn` / `CityRobotDog.gd`
- 创建 `RobotDogLab.tscn` / `RobotDogLab.gd`
- 在 creature scene 中 author `JointAnchors` 与 8 个腿部关节锚点
- 新增 focused contract tests

不做什么：

- 不做 quadruped locomotion / IK / gait
- 不做主世界接入
- 不做战斗 / hurtbox / AI
- 不改 glb 内部模型拓扑

## Acceptance

1. 自动化测试必须证明：正式 glb 已存在于 creature 资产目录，而不是继续引用根目录。
2. 自动化测试必须证明：`CityRobotDog.tscn` 存在，且 `BodyPivot/Model` 挂载正式 glb。
3. 自动化测试必须证明：`CityRobotDog.tscn` 中存在 `JointAnchors` 与 8 个真实 `Marker3D`。
4. 自动化测试必须证明：creature scene root 暴露 `get_debug_state()`、`get_joint_anchor_state()`、`get_joint_anchor_names()`、`reset_robot_dog_pose()`。
5. 自动化测试必须证明：`RobotDogLab.tscn` 挂载的是正式 `CityRobotDog.tscn`，而不是直接挂 glb。
6. 自动化测试必须证明：lab scene author 了 ground / fixture / player / camera / hud / robot dog root 的 scene-first 层级。
7. 反作弊条款：不得通过 runtime 动态生成 8 个锚点来伪装 scene authoring 已完成。

## Files

- Create: `docs/prd/PRD-0031-robot-dog-scene-foundation.md`
- Create: `docs/plans/2026-03-26-v59-robot-dog-scene-foundation-design.md`
- Create: `docs/plan/v59-index.md`
- Create: `docs/plan/v59-robot-dog-scene-foundation.md`
- Move: `robot dog_02.glb`
- Move: `robot dog_02_militaryquadrobot3dmodel_basecolor.jpg`
- Create: `city_game/world/creatures/quadrupeds/CityRobotDog.gd`
- Create: `city_game/world/creatures/quadrupeds/CityRobotDog.tscn`
- Create: `city_game/scenes/labs/RobotDogLab.gd`
- Create: `city_game/scenes/labs/RobotDogLab.tscn`
- Create: `tests/world/test_robot_dog_scene_contract.gd`
- Create: `tests/world/test_robot_dog_lab_scene_contract.gd`
- Create: `docs/plan/v59-m3-verification-2026-03-26.md`

## Steps

1. Docs Freeze
   - 冻结正式资产路径、scene 层级、lab 层级与 8 个关节锚点合同。
2. TDD Red
   - 先写：
     - `test_robot_dog_scene_contract.gd`
     - `test_robot_dog_lab_scene_contract.gd`
3. Run Red
   - 预期第一轮失败原因：
     - 正式资产路径不存在
     - `CityRobotDog.tscn` 不存在
     - `RobotDogLab.tscn` 不存在
4. TDD Green
   - 搬资产
   - 建 creature scene
   - 建 lab scene
   - author 8 个锚点
5. Verification
   - 跑 focused tests + parse check
   - 回填 `v59-m3-verification-2026-03-26.md`

## Risks

- 外部贴图路径如果搬错，glb 会导入异常或丢材质。
- 如果现在不把锚点 author 成 scene 节点，后续 quadruped runtime 会失去稳定的 authored 真源。
- 如果 lab 直接绑 glb，未来任何 quadruped runtime 都会被 lab-only 层级绑死。

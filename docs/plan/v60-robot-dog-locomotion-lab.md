# V60 Robot Dog Locomotion Lab

## Goal

在正式 `CityRobotDog.tscn` 主链上建立第一版机械狗单轴铰链 runtime，让机械狗在 `RobotDogLab` 中接到 `P` 键指令后完成一次“爬下/起身”姿态切换，并暴露 joint axis、joint limit、姿态状态与 reset 主链。

## PRD Trace

- `REQ-0032-001`
- `REQ-0032-002`
- `REQ-0032-003`
- `REQ-0032-004`
- `REQ-0032-005`
- `REQ-0032-006`
- `REQ-0032-007`

## Dependencies

- 正式资产与锚点基础：
  - `docs/prd/PRD-0031-robot-dog-scene-foundation.md`
  - `docs/plan/v59-index.md`
- research：
  - `docs/plans/2026-03-26-robot-dog-github-reference-research.md`

## Contract Freeze

- 8 个关节全部只绕 local `Z` 轴旋转。
- joint limit 按“相对 editor 初始姿态的本地 `Z` 角度偏移”定义。
- `P` 是正式爬下/起身切换键。
- `RobotDogLab` 只消费正式 `CityRobotDog.gd` runtime，不写第二套 pose 逻辑。

## Scope

做什么：

- 新增 joint constraint contract
- 新增 `P` 键爬下/起身动作
- 驱动真实大腿/小腿模型节点
- 更新 lab HUD 与 reset 主链
- 新增 focused tests 与一条 lab flow e2e

不做什么：

- 不做 walking gait
- 不做前进/转向
- 不做主世界接入
- 不做 AI / 战斗
- 不上 GodotIK

## Acceptance

1. 自动化测试必须证明：8 个 joint 的轴向合同全部为 local `Z`。
2. 自动化测试必须证明：8 个 joint 都存在显式限位，当前角度不会越界。
3. 自动化测试必须证明：`P` 触发后，机械狗进入爬下姿态；再触发一次回到站立姿态。
4. 自动化测试必须证明：爬下后 `body_height_offset_m > 0.10`，并且四条大腿 `body_to_thigh_angle_deg` 的平均值不大于 `10`。
5. 自动化测试必须证明：小腿角度会联动变化，而不是停在初始值。
6. 反作弊条款：不得通过 clip、lab-only 逻辑、改 authored 锚点或绕 `X/Y` 轴补动作来伪装通过。

## Files

- Update: `docs/prd/PRD-0032-robot-dog-locomotion-lab.md`
- Update: `docs/plans/2026-03-26-v60-robot-dog-locomotion-lab-design.md`
- Update: `docs/plan/v60-index.md`
- Update: `docs/plan/v60-robot-dog-locomotion-lab.md`
- Update: `city_game/world/creatures/quadrupeds/CityRobotDog.gd`
- Update: `city_game/scenes/labs/RobotDogLab.gd`
- Create: `tests/world/test_robot_dog_joint_contract.gd`
- Create: `tests/world/test_robot_dog_crouch_pose_contract.gd`
- Create: `tests/e2e/test_robot_dog_lab_prone_flow.gd`
- Create: `docs/plan/v60-m3-verification-2026-03-26.md`

## Steps

1. Analysis
   - 固定“只做单轴铰链 + P 键爬下/起身”的版本边界。
   - 固定“8 个关节都只绕 local `Z` 轴”的总口径。
2. Docs Freeze
   - 修订 `PRD-0032`
   - 修订 design
   - 修订 `v60-index`
   - 修订本计划文档
3. TDD Red: Joint Contract
   - 先写 joint contract test，锁 axis、limit、最小 API。
4. Run Red
   - 预期第一轮失败原因：
     - 缺少 `get_joint_constraint_contract()`
     - joint axis 不是显式合同
     - 缺少 joint limit/debug state
5. TDD Green: Joint Contract
   - 在 `CityRobotDog.gd` 落 joint constraint table 与 debug state。
6. TDD Red: Crouch Pose
   - 写爬下姿态 contract test，锁 `P` 切换、躯干降姿、大腿夹角、小腿联动。
7. TDD Green: Crouch Pose
   - 落姿态插值、joint angle clamp、躯干下沉与大小腿联动。
8. TDD Red: Lab Flow
   - 写 `RobotDogLab` e2e，锁 `P` / `F5` 输入主链。
9. TDD Green: Lab Flow
   - 更新 `RobotDogLab.gd` 与 HUD。
10. Verification
   - 跑 focused tests + parse check
   - 回填 `v60-m3-verification-2026-03-26.md`

## Risks

- 如果 local `Z` 方向理解反了，爬下动作会直接反着走。
- 如果只转大腿不联动小腿，姿态会很假。
- 如果 `body_to_thigh_angle_deg` 没做成显式 debug state，后面无法稳定验收“接近 0°”。

# V61 Robot Dog Ground Locomotion

## Goal

在正式 `CityRobotDog.gd` 主链与 `CityPrototype` 世界 wrapper 上，交付一条机械狗可接管的地面 locomotion 链：小键盘 `4` 召唤/回收、第三人称镜头接管、`Player` 冻结，以及 `idle / walk / run / backward / turn / prone` 这些 ground states。

## PRD Trace

- `REQ-0033-001`
- `REQ-0033-002`
- `REQ-0033-003`
- `REQ-0033-004`
- `REQ-0033-005`
- `REQ-0033-006`
- `REQ-0033-007`

## Dependencies

- 机械狗正式资产与 scene foundation：
  - `docs/prd/PRD-0031-robot-dog-scene-foundation.md`
  - `docs/plan/v59-index.md`
- 机械狗关节与 pose foundation：
  - `docs/prd/PRD-0032-robot-dog-locomotion-lab.md`
  - `docs/plan/v60-index.md`
- 现有世界级小键盘召唤模式参考：
  - `city_game/scripts/CityPrototype.gd` 中的小键盘 `5` 无人机
  - `city_game/scripts/CityPrototype.gd` 中的小键盘 `8` 火炮

## Contract Freeze

- 小键盘 `4` 是机械狗正式召唤/回收热键。
- 机械狗生成在 `Player` 前方约 `2m`，朝向与 `Player` 一致。
- 召唤成功后立刻切到机械狗第三人称镜头。
- 机械狗控制态下，`W/A/S/D/Shift/P` 只归机械狗消费。
- `P` 不再是全局 lab 热键，而是机械狗控制态内的 prone toggle。
- `v61` 只做地面态，不做 `pounce / jump / landing / attack`。
- `RobotDogLab` 与主世界 consumer 必须共用同一条正式控制/runtime 主链。

## Scope

做什么：

- 新增机械狗召唤/回收世界 wrapper
- 新增机械狗第三人称控制态
- 新增 `Player` freeze / input ownership 合同
- 新增 ground locomotion state machine
- 更新 `RobotDogLab` 到正式控制态口径
- 新增 focused tests 与一条 world e2e

不做什么：

- 不做 `pounce / jump / landing / attack`
- 不做战斗 AI
- 不做高难地形 traversal
- 不做 clip-only 动画旁路

## Acceptance

1. 自动化测试必须证明：只有小键盘 `4` 能正式召唤/回收机械狗。
2. 自动化测试必须证明：机械狗召唤后，第三人称镜头和控制权都切到机械狗。
3. 自动化测试必须证明：机械狗控制态下，`Player` 被冻结，不再消费 `W/A/S/D/Shift/P`。
4. 自动化测试必须证明：机械狗至少存在显式的 `idle / walk / run / backward / turn / prone` runtime state。
5. 自动化测试必须证明：`walk` 和 `run` 在速度或步频上存在明确差异。
6. 自动化测试必须证明：`backward` 与 `turn` 是独立语义，不是 forward 根节点滑行的变种。
7. 自动化测试必须证明：`RobotDogLab` 与主世界 wrapper 不会分叉成两套不同的机械狗控制主链。
8. 反作弊条款：不得通过镜头假切换、根节点滑行、lab-only 私有逻辑或破坏 `v60` joint/pivot 合同来伪装通过。

## Files

- Create: `docs/prd/PRD-0033-robot-dog-ground-locomotion-control.md`
- Create: `docs/plans/2026-03-26-v61-robot-dog-ground-locomotion-design.md`
- Create: `docs/plan/v61-index.md`
- Create: `docs/plan/v61-robot-dog-ground-locomotion.md`
- Update: `city_game/scripts/CityPrototype.gd`
- Update: `city_game/world/creatures/quadrupeds/CityRobotDog.gd`
- Update: `city_game/world/creatures/quadrupeds/CityRobotDog.tscn`
- Update: `city_game/scenes/labs/RobotDogLab.gd`
- Update: `city_game/scenes/labs/RobotDogLab.tscn`
- Create: `city_game/world/creatures/quadrupeds/CityRobotDogControlRuntime.gd`
- Create: `city_game/world/creatures/quadrupeds/CityRobotDogControlRuntime.tscn`
- Create: `tests/world/test_city_player_robot_dog_toggle_contract.gd`
- Create: `tests/world/test_city_player_robot_dog_camera_takeover_contract.gd`
- Create: `tests/world/test_city_player_robot_dog_ground_locomotion_contract.gd`
- Create: `tests/world/test_robot_dog_lab_control_contract.gd`
- Create: `tests/e2e/test_city_player_robot_dog_flow.gd`
- Create: `docs/plan/v61-m3-verification-2026-03-26.md`

## Steps

1. Analysis
   - 固定“召唤/回收 + 第三人称接管 + ground locomotion”的版本边界。
   - 固定“`pounce / jump / attack` 不进入 `v61`”。
2. Docs Freeze
   - 写 `PRD-0033`
   - 写 design
   - 写 `v61-index`
   - 写本计划文档
3. TDD Red: Toggle Contract
   - 先写机械狗召唤/回收 focused test，锁小键盘 `4`、spawn pose、recall。
4. TDD Green: Toggle Contract
   - 在 `CityPrototype.gd` 落机械狗正式 wrapper。
5. TDD Red: Camera And Ownership
   - 写第三人称接管、player freeze、输入所有权 focused test。
6. TDD Green: Camera And Ownership
   - 落控制态切换与 camera takeover。
7. TDD Red: Ground Locomotion
   - 写 `idle / walk / run / backward / turn / prone` focused contract。
8. TDD Green: Ground Locomotion
   - 在 `CityRobotDog.gd` 落地面 locomotion state machine。
9. TDD Red: Lab Parity
   - 写 `RobotDogLab` 控制态 contract，锁住不分叉。
10. TDD Green: Lab Parity
   - 更新 `RobotDogLab.gd` / `.tscn` 对齐正式控制态。
11. E2E
   - 写并运行 `test_city_player_robot_dog_flow.gd`。
12. Verification
   - 跑 focused tests + parse check
   - 回填 `docs/plan/v61-m3-verification-2026-03-26.md`

## Risks

- 如果 `Player` freeze 做得不完整，机械狗和玩家会出现双写输入。
- 如果第三人称接管只做 camera，不做 ownership，体感会非常混乱。
- 如果 ground locomotion 只是根节点滑行，用户会立即把它识别成假动作。
- 如果 `RobotDogLab` 不跟正式控制态收口，后面调试会再次掉进“两套主链”的坑里。

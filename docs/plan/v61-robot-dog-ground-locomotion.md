# V61 Robot Dog Ground Locomotion

## Goal

在正式 `CityRobotDog.gd` 主链与 `CityPrototype` 世界 wrapper 上，交付一条机械狗伴随 + 可接管的地面 locomotion 链：小键盘 `4` 召唤/回收默认进入伴随态、`Insert` 显式切换到机械狗第三人称控制态、再次 `Insert` 退回伴随态，以及 `idle / walk / run / backward / turn / prone` 这些 ground states。

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
- 机械狗生成在 `Player` 右侧伴随槽位，朝向与 `Player` 一致。
- 召唤成功后默认保持 `Player` 控制权与玩家镜头，不立刻接管。
- `Insert` 在 `follow <-> controlled` 间切换；`controlled` 时才切到机械狗第三人称镜头并冻结 `Player`。
- 机械狗伴随态下，`W/A/S/D/Shift/P` 继续归 `Player`；机械狗控制态下，这些输入才归机械狗消费。
- `P` 不再是全局 lab 热键，而是机械狗控制态内的 prone toggle。
- `v61` 只做地面态，不做 `pounce / jump / landing / attack`。
- `RobotDogLab` 与主世界 consumer 必须共用同一条正式控制/runtime 主链。

## Scope

做什么：

- 新增机械狗召唤/回收世界 wrapper
- 新增机械狗伴随态与第三人称控制态
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
2. 自动化测试必须证明：机械狗召唤后默认进入右侧伴随态，不立刻接管第三人称镜头和控制权。
3. 自动化测试必须证明：按下 `Insert` 后才进入机械狗控制态；再次按下 `Insert` 能退回伴随态。
4. 自动化测试必须证明：机械狗控制态下，`Player` 被冻结，不再消费 `W/A/S/D/Shift/P`；伴随态下这些输入仍归 `Player`。
5. 自动化测试必须证明：机械狗至少存在显式的 `idle / walk / run / backward / turn / prone` runtime state。
6. 自动化测试必须证明：`walk` 和 `run` 在速度或步频上存在明确差异。
7. 自动化测试必须证明：`backward` 与 `turn` 是独立语义，不是 forward 根节点滑行的变种。
8. 自动化测试必须证明：`RobotDogLab` 与主世界 wrapper 不会分叉成两套不同的机械狗控制主链。
9. 反作弊条款：不得通过镜头假切换、根节点滑行、lab-only 私有逻辑或破坏 `v60` joint/pivot 合同来伪装通过。

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
- Create: `tests/world/test_city_player_robot_dog_follow_contract.gd`
- Create: `tests/world/test_city_player_robot_dog_ground_locomotion_contract.gd`
- Create: `tests/world/test_city_player_robot_dog_presentation_contract.gd`
- Create: `tests/world/test_robot_dog_lab_control_contract.gd`
- Create: `tests/e2e/test_city_player_robot_dog_flow.gd`
- Create: `docs/plan/v61-m3-verification-2026-03-26.md`
- Create: `docs/plan/v61-m4-verification-2026-03-26.md`

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
   - 先写机械狗召唤/回收 focused test，锁小键盘 `4`、右侧伴随 slot、recall。
4. TDD Green: Toggle Contract
   - 在 `CityPrototype.gd` 落机械狗正式 wrapper。
5. TDD Red: Follow And Ownership
   - 写默认伴随、`Insert` 接管/退出、player freeze、输入所有权 focused test。
6. TDD Green: Follow And Ownership
   - 落 `follow / controlled` 双模式、右侧伴随 slot、camera takeover。
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
   - 如 closeout 语义发生变化，追加新的 verification artifact，而不是篡改旧 closeout

## Risks

- 如果 `Player` freeze 做得不完整，机械狗和玩家会出现双写输入。
- 如果第三人称接管只做 camera，不做 ownership，体感会非常混乱。
- 如果 ground locomotion 只是根节点滑行，用户会立即把它识别成假动作。
- 如果 `RobotDogLab` 不跟正式控制态收口，后面调试会再次掉进“两套主链”的坑里。

## 2026-03-26 Post-Closeout Corrections

- 机械狗控制态补齐了鼠标 yaw / pitch，自此 `W/A/S/D` 不再是唯一控制手段；俯仰继续保持限位，避免 chase camera 翻转。
- `A = 左转`、`D = 右转` 已被明确冻结为输入合同，并同步回写到 `CityRobotDogControlRuntime.gd -> CityRobotDog.gd` 的 locomotion/gait 符号链，防止再次出现“物理朝向与 locomotion_state 名义相反”的问题。
- 共享指南针 / 小地图 player marker / 世界 focus 已在机械狗控制态下切到 active robot dog runtime，不再读取被冻结的 `Player` 朝向。
- `CityRobotDogControlRuntime.tscn` 的正式展示口径已更新为更大的机械狗尺寸和更高的俯视第三人称机位；这条口径由 `tests/world/test_city_player_robot_dog_presentation_contract.gd` 持续锁定。
- 低速 `W` 已冻结为单腿依次换步的四拍 crawl，不再允许 paired front-leg shove；更快的 `Shift+W` 继续保留对角 trot。对应合同已补进 `tests/world/test_city_player_robot_dog_ground_locomotion_contract.gd`。
- 常速 `W` 已从最初过慢的散步档抬到旧 sprint 档位附近；现在“快一点的日常跑动”和“更快 sprint”不再共用同一套节奏和速度口径。
- 主世界 `KP_4` 已从“召唤即接管”改为“默认伴随”；机械狗默认生成在玩家右侧伴随槽位，`Insert` 才会进入正式 dog-control 语义，再按一次 `Insert` 退回伴随态。
- 主世界伴随态已冻结为“右后侧伴随走廊，不贴身，也不敌对锁头盯玩家”；对应 `tests/world/test_city_player_robot_dog_follow_contract.gd` 现锁最小/最大伴随距离、非敌对 look-at，以及连续移动时不得出现 flash-teleport。
- 伴随 recover 现已收口为“只有极端掉队且玩家已基本停稳时才允许硬恢复”；正常 walking / turning 期间不再使用 7 米级短距瞬移补位。
- `CityRobotDogControlRuntime.gd` 的 follow steering 已补上“大偏角先摆正再跟进、近距先咬住槽位再对齐玩家朝向”的合同，避免伴随态一边拧头一边朝错误方向跑出跳闪感。
- `CityRobotDogControlRuntime.gd` 的 `visual_scale` 已微调下收，避免继续维持用户反馈里“稍微有点大”的展示口径；主世界同时新增 summon / mode-toggle 的 focus message 提示 `Insert / KP4` 用法。

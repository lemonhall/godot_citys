# ECN-0025: V26 Scoreboard And Ambient Freeze

## 基本信息

- **ECN 编号**：ECN-0025
- **关联 PRD**：PRD-0016
- **关联 Req ID**：REQ-0016-003、REQ-0016-005、新增 REQ-0016-006
- **发现阶段**：v26 docs freeze 后的需求补充
- **日期**：2026-03-18

## 变更原因

用户在 `v26` docs freeze 完成后补充了三条关键要求：

1. 计分不只存在于 HUD，场馆旁边应树立一个大型计分板。
2. 为了性能，进入足球 minigame 后，希望把整个世界的行人与车辆都静止掉。
3. 实现第 2 条时，不能把车载收音机一起停掉。

原 `PRD-0016` 虽然已经冻结了比分、HUD 和 reset loop，但还没有明确“大型世界空间计分板”与“只冻结 ambient crowd/traffic、但不触发全局 world pause”的正式 contract。如果不补这条 ECN，后续实现很容易走错成：

- 只有小 HUD，没有明确的场馆级计分板。
- 直接复用 `CityPrototype._apply_world_simulation_pause()`，把足球玩法 runtime 和收音机一并停掉。
- 或者继续让全城 crowd/traffic 常态运行，给场馆玩法增加不必要的性能负担。

## 变更内容

### 原设计

- `REQ-0016-003` 只要求两侧球门、goal detection 与比分更新，没有冻结“大型场边计分板”。
- `REQ-0016-005` 只要求完整可玩流程与守住 `v21/v25` 主链，没有明确“场馆激活时的 ambient performance mode”。
- 计划中没有单独的 ambient freeze / radio continuity 测试与文件改动口径。

### 新设计

- `REQ-0016-003` 扩展为：场馆必须提供两侧球门、正式进球检测、比分更新，以及一个大型场边计分板。该计分板是世界空间主显示面，HUD 只作为辅助显示。
- 新增 `REQ-0016-006`：当玩家进入足球场馆有效玩法态时，系统必须进入专用 `ambient_simulation_freeze` 模式。
  - 该模式只冻结行人模拟与 ambient 车辆模拟。
  - 该模式必须保留玩家、足球、球场 venue runtime、HUD、输入与收音机 runtime。
  - 该模式不得复用现有 `world_simulation_pause` 主链。
  - 该模式采用迟滞型双圈层：进入比赛场地立即冻结；只有离开赛场边界后再退出一圈约 `24m` 的 release buffer 才允许解冻，避免边界抖动。
- `v26` 的实现与测试计划同步增加：
  - scoreboard visual / runtime contract
  - ambient freeze contract
  - radio continuity under ambient freeze contract

## 影响范围

- 受影响的 Req ID：
  - REQ-0016-003
  - REQ-0016-005
  - REQ-0016-006（新增）
- 受影响的 vN 计划：
  - `docs/plan/v26-index.md`
  - `docs/plan/v26-soccer-minigame-venue-foundation.md`
  - `docs/plans/2026-03-18-v26-soccer-minigame-venue-design.md`
- 受影响的测试：
  - `tests/world/test_city_soccer_scoreboard_contract.gd`
  - `tests/world/test_city_soccer_scoreboard_visual_contract.gd`
  - `tests/world/test_city_soccer_venue_ambient_freeze_contract.gd`
  - `tests/world/test_city_soccer_venue_radio_survives_ambient_freeze.gd`
  - `tests/e2e/test_city_soccer_minigame_goal_flow.gd`
- 受影响的代码文件：
  - `city_game/scripts/CityPrototype.gd`
  - `city_game/world/pedestrians/simulation/CityPedestrianTierController.gd`
  - `city_game/world/vehicles/simulation/CityVehicleTierController.gd`
  - `city_game/world/radio/CityVehicleRadioController.gd`（仅在 continuity contract 需要显式护栏时）

## 处置方式

- [x] PRD 已同步更新（标注 ECN-0025）
- [x] vN 计划已同步更新
- [x] 追溯矩阵已同步更新
- [ ] 相关测试已同步更新

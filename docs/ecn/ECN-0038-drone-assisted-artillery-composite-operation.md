# ECN-0038: Drone-Assisted Artillery Composite Operation

## 基本信息

- **ECN 编号**：ECN-0038
- **关联 PRD**：
  - `PRD-0027`
  - `PRD-0029`
- **关联 Req ID**：
  - `REQ-0027-005`
  - `REQ-0029-022`
  - `REQ-0029-023`
- **发现阶段**：`v53` observer closeout 落地后的玩法复盘
- **日期**：2026-03-26

## 变更原因

`v53` 已经建立 howitzer `solver -> fire -> observer closeout` 的正式闭环，但用户在实玩中确认了一个更优的玩法现实：

- 当玩家已经进入 howitzer 操炮态时，再放飞无人机，第三人称无人机本身就能更自然地承担“炮击观察”职责；
- 当前无人机把 `Space` 当作上升输入，会和 howitzer 操炮链里的 `Space` 击发直接抢输入；
- 当前 accepted fire 总会进入 observer closeout，会把“无人机观察炮击”的玩法强行打断。

因此本轮需要正式冻结一条新的复合模式口径：`无人机 active + howitzer 操炮 active` 时，玩家继续用 howitzer 完整操炮，`Space` 继续击发，而镜头不再切入 observer closeout，鼓励玩家直接用无人机观察弹着。

## 变更内容

### 原设计

- active drone 的垂直输入包含：
  - `E`
  - `Space`
- 主世界 howitzer accepted fire 后：
  - 无论当前是否存在 active drone
  - 都会启动 artillery observer closeout

### 新设计

- `REQ-0027-005` 调整为：
  - active drone 垂直输入仅保留 `E` 上升、`Q` 下降；
  - `Space` 不再承担无人机抬升语义。
- `REQ-0029-022` 调整为：
  - 主世界 accepted fire 仅在“非无人机复合操炮”场景下启动 observer closeout；
  - 若当前同时满足 `howitzer operation active` 与 `drone active`，则必须跳过 observer closeout。
- 复合模式输入所有权进一步冻结为：
  - `E` 在“操炮 + 无人机 active”时必须完全让给无人机上升；
  - 该场景下 `E` 不得再触发 howitzer 退出操炮。
- `REQ-0029-023` 调整为：
  - free fire 仍然默认兼容 observer closeout；
  - 但一旦处于“无人机 active + howitzer 操炮 active”的复合模式，free fire 也必须遵守“跳过 observer closeout，由无人机承担观察职责”的新口径。

## 影响范围

- 受影响的 vN 计划：
  - `docs/plan/v54-index.md`
  - `docs/plan/v54-drone-assisted-artillery-operation.md`
- 受影响的设计文档：
  - `docs/plans/2026-03-26-v54-drone-assisted-artillery-operation-design.md`
- 受影响的代码文件：
  - `city_game/combat/drone/CityPlayerDroneFlightController.gd`
  - `city_game/scripts/CityPrototype.gd`
- 受影响的测试：
  - `tests/world/test_city_player_drone_space_input_contract.gd`
  - `tests/world/test_city_world_howitzer_drone_composite_contract.gd`
  - `tests/e2e/test_city_drone_assisted_artillery_operation_flow.gd`

## 处置方式

- [x] PRD 已同步更新
- [x] v54 计划已同步更新
- [x] 追溯矩阵已同步更新
- [ ] 相关测试已同步更新

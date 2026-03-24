# ECN-0030: Artillery Lab Operation Interaction

## 基本信息

- **ECN 编号**：ECN-0030
- **关联 PRD**：PRD-0029
- **关联 Req ID**：新增 `REQ-0029-007`
- **发现阶段**：v44 closeout 后的 lab 交互细化
- **日期**：2026-03-24

## 变更原因

`M777HowitzerLab` 当前把 `J/L/I/K` 直接暴露成全局热键，玩家一进场就能调炮。这与主世界已有的近距交互口径不一致，也会让未来接入主世界时出现“人在远处走路却还在转炮”的全局输入污染问题。

## 变更内容

### 原设计

`lab` 只要求存在最小调角 API 和调试入口，但没有冻结“靠近火炮 -> HUD prompt -> `E` 进入操炮态 -> 才能启用 `J/L/I/K`”这条交互链。

### 新设计

- `M777HowitzerLab` 近距约 `5m` 时，HUD 必须出现共享 prompt：`按 E 操作炮`。
- 玩家按下 `E` 后进入操炮态；再次按下 `E` 退出。
- 只有在操炮态激活时，`J/L/I/K` 才能驱动 howitzer yaw / pitch。
- `lab` 的交互提示必须复用主世界既有的 HUD prompt contract，而不是发明 lab-only 提示协议。
- 这轮只解决“上下文化操炮输入所有权”，不解决火炮绝对方位角、世界 bearing 映射或火控解算。

## 影响范围

- 受影响的 Req ID：
  - `REQ-0029-007`
- 受影响的 vN 计划：
  - `docs/plan/v46-index.md`
  - `docs/plan/v46-artillery-lab-operation-interaction.md`
- 受影响的测试：
  - `tests/world/test_city_m777_howitzer_lab_interaction_contract.gd`
  - `tests/world/test_city_m777_howitzer_lab_scene_contract.gd`
- 受影响的代码文件：
  - `city_game/scenes/labs/M777HowitzerLab.gd`
  - `city_game/scenes/labs/M777HowitzerLab.tscn`

## 处置方式

- [x] PRD 已同步更新
- [x] v46 计划已同步更新
- [x] 追溯矩阵已同步更新
- [x] 相关测试已同步更新

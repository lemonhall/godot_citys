# ECN-0031: Artillery Fire Presentation

## 基本信息

- **ECN 编号**：ECN-0031
- **关联 PRD**：PRD-0029
- **关联 Req ID**：新增 `REQ-0029-008`
- **发现阶段**：v46 closeout 后的 artillery fire planning
- **日期**：2026-03-24

## 变更原因

`v44-v46` 已经把 M777 的正式 scene、pitch/yaw contract、lab 交互和 compass 语义收口好了，但火炮仍然只能“转得动”，不能“打得响”。用户已经明确冻结了下一步目标：先做逼真的正式开火演出，不做硬核火控，也暂时不做炮弹实体/弹道/落点/爆炸链。如果继续把 howitzer 停在“只能调角、没有 fire contract”的状态，后续接主世界、音效或任务时仍然没有一条正式 runtime 真源。

## 变更内容

### 原设计

PRD-0029 的 `Non-Goals` 明确写着“不在本轮实现开火、弹道、装填、炮口焰、后坐、炮弹爆炸”，也没有正式 fire API、开火演出锚点或 `Space` 触发 contract。

### 新设计

- 正式 `CityM777Howitzer` runtime 新增 fire presentation contract，而不是把开火逻辑塞进 `M777HowitzerLab`：
  - `Anchors/MuzzleFxAnchor`
  - `Anchors/LanyardAnchor`
  - `can_fire()`
  - `request_fire()`
  - `get_fire_state()`
- accepted fire 的冻结语义：
  - 默认 `6.0s` 冷却
  - 炮口火光
  - 短寿命烟尘
  - 拉火绳常显、平时略松、击发时瞬间绷紧
  - 轻微后坐
  - formal weapon fire audio
- `M777HowitzerLab` 新增 `Space` 触发 howitzer fire API，但前提仍然是玩家已进入操炮态；玩家继续保留自由移动，只在离炮约 `20m` 后自动退出操炮态。
- HUD 冷却表现冻结为：
  - 冷却中：`装填中 X.Xs...`
  - 冷却完成：`可击发`
- 本轮明确不做：
  - projectile / grenade / missile 节点
  - 弹道、落点、爆炸、伤害判定
  - yaw 与世界 bearing 的火控换算

## 影响范围

- 受影响的 Req ID：
  - `REQ-0029-005`
  - `REQ-0029-006`
  - `REQ-0029-007`
  - `REQ-0029-008`
- 受影响的 vN 计划：
  - `docs/plan/v47-index.md`
  - `docs/plan/v47-artillery-fire-presentation.md`
- 受影响的测试：
  - `tests/world/test_city_m777_howitzer_scene_contract.gd`
  - `tests/world/test_city_m777_howitzer_lab_scene_contract.gd`
  - `tests/world/test_city_m777_howitzer_fire_contract.gd`
  - `tests/world/test_city_m777_howitzer_lab_fire_interaction_contract.gd`
- 受影响的代码文件：
  - `city_game/combat/artillery/CityM777Howitzer.gd`
  - `city_game/combat/artillery/CityM777Howitzer.tscn`
  - `city_game/scenes/labs/M777HowitzerLab.gd`

## 处置方式

- [x] PRD 已同步更新
- [x] v47 计划已同步更新
- [x] 追溯矩阵已同步更新
- [x] 相关测试已同步更新

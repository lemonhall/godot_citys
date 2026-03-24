# ECN-0033: Artillery Fire Cooldown Retune

## 基本信息

- **ECN 编号**：ECN-0033
- **关联 PRD**：PRD-0029
- **关联 Req ID**：
  - `REQ-0029-008`
- **发现阶段**：v48 closeout 后的实机手感调优
- **日期**：2026-03-24

## 变更原因

当前 howitzer 的默认 fire cooldown 冻结为 `6.0s`。这在“真实火炮节奏”语义上可以自洽，但与当前 lab 目标不匹配。用户明确反馈是“6 秒太长，打得不爽”，而本项目当前阶段的 howitzer 仍处在“逼真反馈，但不硬核操作”的玩法原型期，不做真实装填班组流程，也不做完整火控链。因此 cooldown 需要朝“更爽、更顺手”的方向收紧。

## 变更内容

### 原设计

- 默认 fire cooldown：`6.0s`
- HUD 冷却文案继续显示剩余秒数

### 新设计

- 默认 fire cooldown 从 `6.0s` 调整为 `2.0s`
- 其余 fire contract 保持不变：
  - `Space` 仍是操炮态 fire key
  - rejected fire 仍返回 `cooldown_active`
  - HUD 仍显示 `装填中 X.Xs...` / `可击发`
  - 不引入 projectile / 弹道 / 爆炸链

## 影响范围

- 受影响的 Req ID：
  - `REQ-0029-008`
- 受影响的 vN 计划：
  - `docs/plan/v49-index.md`
  - `docs/plan/v49-artillery-fire-cooldown-retune.md`
- 受影响的测试：
  - `tests/world/test_city_m777_howitzer_scene_contract.gd`
  - `tests/world/test_city_m777_howitzer_fire_contract.gd`
- 受影响的代码文件：
  - `city_game/combat/artillery/CityM777Howitzer.gd`

## 处置方式

- [x] PRD 已同步更新
- [x] v49 计划已同步更新
- [x] 追溯矩阵已同步更新
- [x] 相关测试已同步更新

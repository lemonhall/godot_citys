# ECN-0040: Drone Squadron Summon Control

## 基本信息

- **ECN 编号**：ECN-0040
- **关联 PRD**：
  - `PRD-0027`
- **关联 Req ID**：
  - `REQ-0027-002`
  - `REQ-0027-004`
  - `REQ-0027-007`
  - `REQ-0027-008`
  - `REQ-0027-009`
- **发现阶段**：`v55` 完成后的无人机交互扩展设计
- **日期**：2026-03-26

## 变更原因

当前无人机主链已经能稳定完成：

- `KP_5` 放飞单架长机
- 长机 takeover camera / input
- 与 howitzer 复合操炮共存

但用户进一步冻结了一个更自然的机群入口：

- `KP_5` 不能再只是“单架 toggle”；
- 用户希望保留“5 就是无人机系统键”的心智模型；
- 机群首版不求战术 AI，只求：
  - 短按逐架增援
  - 长按全部回收
  - 模型层面不挤在一块
  - 不破坏现有长机控制权与 howitzer 复合态。

## 变更内容

### 原设计

- `KEY_KP_5` 只承担单架无人机 `deploy/recover toggle`
- active drone 时再次按 `KP_5` 会直接回收长机
- 系统不存在正式的 wingman / squadron count / formation spacing contract

### 新设计

- `KEY_KP_5` 保持为无人机系统唯一正式入口，但语义升级为：
  - `短按`：逐架召唤
  - `长按`：全部回收
- 首架仍是当前 formal `PlayerDroneRuntime` 长机：
  - takeover camera / input
  - 保留既有 FPV、suicide strike、howitzer composite 链
- 后续新增个体改为僚机：
  - 不抢 camera / input
  - 只做默认分散编队
  - 首版不实现战术命令、攻击、独立 FPV 或 flocking AI
- 当前总编制上限冻结为：
  - `10` 架总数（含长机）
- 长按全收后必须恢复到收回前的正式交互上下文：
  - 普通模式 -> 玩家
  - `howitzer 操炮 + drone` 复合态 -> howitzer 操炮态

## 影响范围

- 受影响的 vN 计划：
  - `docs/plan/v56-index.md`
  - `docs/plan/v56-drone-squadron-summon-control.md`
- 受影响的设计文档：
  - `docs/plans/2026-03-26-v56-drone-squadron-summon-control-design.md`
- 受影响的代码文件：
  - `city_game/scripts/CityPrototype.gd`
  - `city_game/combat/drone/CityPlayerDroneRuntime.gd`
  - `city_game/combat/drone/*`
- 受影响的测试：
  - 现有 drone toggle / camera takeover / e2e flow
  - 新增 squadron summon contract tests
  - 复合操炮 context regressions

## 处置方式

- [x] PRD 已同步更新
- [x] v56 计划已同步更新
- [x] 追溯矩阵已同步更新
- [ ] 相关测试已同步更新

# ECN-0041: Drone Squadron Strike Orders

## 基本信息

- **ECN 编号**：ECN-0041
- **关联 PRD**：
  - `PRD-0027`
- **关联 Req ID**：
  - `REQ-0027-010`
  - `REQ-0027-011`
- **发现阶段**：`v56` 完成后的机群攻击交互扩展设计
- **日期**：2026-03-26

## 变更原因

当前无人机链路已经稳定支持：

- 长机 FPV/ADS
- 左键长机自杀冲锋
- `NO SIGNAL` closeout
- `KP_5` 机群召唤 / 回收

但机群攻击仍停留在“只有长机能自爆”的单机心智模型。用户现在冻结了新的攻击合同：

- 有僚机时，左键优先派 1 架僚机去冲锋；
- 长机继续留在空中观察，不播 `NO SIGNAL`；
- 中键可以命令所有僚机对准星周围整片区域发起阶梯式冲锋；
- 不允许所有僚机同时砸向同一个点。

## 变更内容

### 原设计

- `MOUSE_BUTTON_LEFT + FPV ADS`
  - 永远由长机自己执行自杀冲锋
- 冲锋后固定进入：
  - `signal_loss`
  - `NO SIGNAL`
- 系统不存在正式的：
  - 单架僚机 strike dispatch contract
  - area strike wave contract
  - wingman strike attrition contract

### 新设计

- `MOUSE_BUTTON_LEFT + FPV ADS`：
  - 当机群仍有可用僚机时，优先派 1 架僚机执行自杀冲锋；
  - 长机保留 camera/input/FPV owner；
  - 不进入 `NO SIGNAL`；
  - 只有当机群只剩长机时，才回退到旧的 leader kamikaze 链。
- `MOUSE_BUTTON_MIDDLE + FPV ADS`：
  - 对准星目标周围半径 `12m` 区域下达面域打击命令；
  - 僚机按 `1 -> 2 -> 3` 的波次规模循环 dispatch；
  - 相邻批次间隔最小 `0.6s`；
  - 长机不加入自动冲锋名单。

## 影响范围

- 受影响的 vN 计划：
  - `docs/plan/v57-index.md`
  - `docs/plan/v57-drone-squadron-strike-orders.md`
- 受影响的设计文档：
  - `docs/plans/2026-03-26-v57-drone-squadron-strike-orders-design.md`
- 受影响的代码文件：
  - `city_game/combat/drone/CityPlayerDroneRuntime.gd`
  - `city_game/combat/drone/CityPlayerDroneSquadronRuntime.gd`
  - `city_game/combat/drone/CityPlayerDroneWingman.gd`
  - `city_game/scripts/CityPrototype.gd`
- 受影响的测试：
  - 现有 leader-only suicide strike / kamikaze flow regressions
  - 新增 squadron single-strike / area-strike contract tests

## 处置方式

- [x] PRD 已同步更新
- [x] v57 计划已同步更新
- [x] 追溯矩阵已同步更新
- [ ] 相关测试已同步更新

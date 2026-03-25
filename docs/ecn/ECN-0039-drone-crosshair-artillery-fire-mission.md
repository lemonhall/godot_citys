# ECN-0039: Drone Crosshair Artillery Fire Mission

## 基本信息

- **ECN 编号**：ECN-0039
- **关联 PRD**：
  - `PRD-0029`
- **关联 Req ID**：
  - `REQ-0029-019`
  - `REQ-0029-020`
  - `REQ-0029-024`
- **发现阶段**：`v54` 完成后的炮击玩法复盘
- **日期**：2026-03-26

## 变更原因

`v53-v54` 已经把地图右键 `炮击标记 -> 解算诸元 -> howitzer 操炮 / 无人机观察` 主链跑通，但用户在实玩里确认了一个更直接的校炮需求：

- 玩家放飞无人机后，实际已经拥有一个稳定的地面准星；
- 重新打开 full map 再右键标点，操作链太绕；
- 玩家希望在无人机观察态里，直接用准星把新的炮击点“焊”进现有黄叉主链，形成正式的校准炮击流程。

因此本轮需要冻结一个新的正式入口：`player drone active + FPV 准星可用` 时，按 `T` 直接创建或更新 artillery fire mission，并且必须与 full map 右键 `炮击标记` 完全同链。

## 变更内容

### 原设计

- artillery fire mission 只有 full map 右键上下文菜单入口；
- active drone 虽然已经有 FPV 准星与 world target，但该数据尚未接入 howitzer fire mission 主链；
- `T` 仅承担既有快捷语义，不承担无人机炮击校准入口。

### 新设计

- 新增 `REQ-0029-024`：
  - `player drone active + FPV ADS active` 时，按 `T` 必须直接把准星落点送入正式 artillery fire mission 主链；
  - 首次按 `T` 创建单个 active 黄叉；
  - 已有 marker 时，再按 `T` 更新同一个 formal active mission，而不是新建第二套状态；
  - 若当前 live howitzer 操炮 active，则新的 target 必须立即刷新 solved bearing / pitch；
  - 若 howitzer 尚未操炮，则保持 `requires_live_howitzer_operation` 的 pending 口径；
  - full map / pin registry / focus message 必须继续消费同一份 fire mission state，不得出现 drone-only marker。
- `T` 的抢占边界冻结为：
  - 仅在 `drone active + FPV ADS active` 时，`T` 优先归无人机炮击标定；
  - 其他情况下，`T` 保持既有原语义。

## 影响范围

- 受影响的 vN 计划：
  - `docs/plan/v55-index.md`
  - `docs/plan/v55-drone-crosshair-artillery-fire-mission.md`
- 受影响的设计文档：
  - `docs/plans/2026-03-26-v55-drone-crosshair-artillery-fire-mission-design.md`
- 受影响的代码文件：
  - `city_game/scripts/CityPrototype.gd`
- 受影响的测试：
  - `tests/world/test_city_drone_artillery_target_marking_contract.gd`
  - `tests/e2e/test_city_drone_artillery_recalibration_flow.gd`
  - `tests/world/test_city_fast_travel_shortcut_contract.gd`

## 处置方式

- [x] PRD 已同步更新
- [x] v55 计划已同步更新
- [x] 追溯矩阵已同步更新
- [x] 相关测试已同步更新

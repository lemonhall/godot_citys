# V9 Index

## 愿景

PRD 入口：[PRD-0004 Vehicle Hijack Driving](../prd/PRD-0004-vehicle-hijack-driving.md)

设计入口：[2026-03-15-v9-vehicle-hijack-design.md](../plans/2026-03-15-v9-vehicle-hijack-design.md)

依赖入口：

- [PRD-0003 Vehicle Traffic Foundation](../prd/PRD-0003-vehicle-traffic-foundation.md)
- [v8-index.md](./v8-index.md)

`v9` 的目标不是把当前项目瞬间扩成“完整 GTA 载具体系”，也不是为了抢车玩法把 `v8` 的 ambient traffic foundation 回退成全时刚体/节点海。`v9` 要做的是：在现有近景 traffic runtime 上补一条最小但完整的 `截停 -> 接管 -> 驾驶` 玩家玩法链，并继续守住 combined runtime 红线。

## 里程碑

| 里程碑 | 范围 | DoD | 验证命令/测试 | 状态 |
|---|---|---|---|---|
| M1 近景车辆截停与接管 | 子弹/手榴弹可截停 `Tier 2 / Tier 3` 车辆，`F` 可接管近距已截停车辆 | projectile / grenade 都能把近景车辆切到 `stopped`；`F` 接管后同一 `vehicle_id` 从 ambient runtime 退出并进入玩家 driving state | `tests/world/test_city_vehicle_hijack_contract.gd`、`tests/world/test_city_vehicle_grenade_stop_contract.gd`、`docs/plan/v9-m3-verification-2026-03-15.md` | done |
| M2 玩家驾驶模式 | 隐藏步行模型、挂载被接管车辆模型、基础驾驶控制与 HUD 状态 | driving mode 可移动、可转向、禁用步行 combat/traversal，并保持 hijacked vehicle continuity | `tests/world/test_city_player_vehicle_drive_mode.gd`、`tests/e2e/test_city_vehicle_hijack_drive_flow.gd`、`docs/plan/v9-m3-verification-2026-03-15.md` | done |
| M3 红线复验 | vehicle runtime guard、combined runtime、first-visit redline | 不引入 duplicate page load / node budget 回退，warm 与 first-visit 继续守线 | `tests/world/test_city_vehicle_runtime_node_budget.gd`、`tests/e2e/test_city_runtime_performance_profile.gd`、`tests/e2e/test_city_first_visit_performance_profile.gd`、`docs/plan/v9-m3-verification-2026-03-15.md` | done |

## 计划索引

- [v9-vehicle-hijack-driving.md](./v9-vehicle-hijack-driving.md)
- [v9-m3-verification-2026-03-15.md](./v9-m3-verification-2026-03-15.md)

## 追溯矩阵

| Req ID | v9 Plan | 单元/集成测试 | E2E / 验证命令 | 证据 | 状态 |
|---|---|---|---|---|---|
| REQ-0004-001 | `v9-vehicle-hijack-driving.md` | `tests/world/test_city_vehicle_hijack_contract.gd`、`tests/world/test_city_vehicle_grenade_stop_contract.gd` | `--script res://tests/world/test_city_vehicle_hijack_contract.gd`、`--script res://tests/world/test_city_vehicle_grenade_stop_contract.gd` | 2026-03-15 fresh closeout 已证明 projectile / grenade 都能把近景车辆切到 `stopped`，且不会全局冻结 traffic；详见 `v9-m3-verification-2026-03-15.md` | done |
| REQ-0004-002 | `v9-vehicle-hijack-driving.md` | `tests/world/test_city_vehicle_hijack_contract.gd` | `--script res://tests/e2e/test_city_vehicle_hijack_drive_flow.gd` | 2026-03-15 live hijack flow 已证明 `F` 只会接管近距已截停车辆，且接管后原 `vehicle_id` 从 ambient runtime 可见集合退出；详见 `v9-m3-verification-2026-03-15.md` | done |
| REQ-0004-003 | `v9-vehicle-hijack-driving.md` | `tests/world/test_city_player_vehicle_drive_mode.gd`、`tests/world/test_city_player_combat.gd`、`tests/world/test_city_player_traversal.gd` | `--script res://tests/e2e/test_city_vehicle_hijack_drive_flow.gd` | 2026-03-15 driving mode 已证明会隐藏步行模型、挂载 hijacked vehicle 模型，并禁用步行 combat/traversal；详见 `v9-m3-verification-2026-03-15.md` | done |
| REQ-0004-004 | `v9-vehicle-hijack-driving.md` | `tests/world/test_city_vehicle_runtime_node_budget.gd`、`tests/world/test_city_vehicle_page_cache.gd`、`tests/world/test_city_pedestrian_page_cache.gd` | `--script res://tests/e2e/test_city_vehicle_performance_profile.gd`、`--script res://tests/e2e/test_city_runtime_performance_profile.gd`、`--script res://tests/e2e/test_city_first_visit_performance_profile.gd` | 2026-03-15 final closeout evidence：vehicle first-visit `update_streaming_avg_usec = 12392`，combined runtime `wall_frame_avg_usec = 8468`，combined first-visit `update_streaming_avg_usec = 13726` / `wall_frame_avg_usec = 14536`；详见 `v9-m3-verification-2026-03-15.md` | done |

## ECN 索引

- 当前无 `v9` 专属 ECN

## 差异列表

- 2026-03-15 `v9` 明确只做近景 `Tier 2 / Tier 3` 互动，不要求把 `Tier 1` 远景 traffic 也升级成可命中/可接管对象。
- 2026-03-15 `v9` 明确不做下车系统、车辆破坏、wanted/police chase；这些都不属于本轮 DoD。
- 2026-03-15 `v9` 的驾驶方案默认复用现有 `PlayerController` 单体角色底盘，只新增最小 driving mode；禁止引入独立 full-physics 载具 runtime。
- 2026-03-15 closeout 期间为守住 `first-visit` 红线，额外做了两类非 scope 扩张的热路径收口：车辆 cached-assignment 去掉无效 ranking / render snapshot 冗余字段，远景行人 tier0 改为更低频更新并跳过逐步地表重采样；这些都没有改变 traffic density、预算阈值或玩法范围。

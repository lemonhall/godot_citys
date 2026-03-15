# V11 Index

## 愿景

PRD 入口：[PRD-0005 Vehicle Pedestrian Impact](../prd/PRD-0005-vehicle-pedestrian-impact.md)

设计入口：[2026-03-15-v11-vehicle-pedestrian-impact-plan.md](../plans/2026-03-15-v11-vehicle-pedestrian-impact-plan.md)

依赖入口：

- [PRD-0002 Pedestrian Crowd Foundation](../prd/PRD-0002-pedestrian-crowd-foundation.md)
- [PRD-0004 Vehicle Hijack Driving](../prd/PRD-0004-vehicle-hijack-driving.md)
- [v6-index.md](./v6-index.md)
- [v9-index.md](./v9-index.md)

`v11` 的目标不是把整个城市的车辆都升级成事故仿真器，而是把“只有玩家当前正在驾驶的那辆 hijacked vehicle 才能撞死近景行人”这条玩法语义做成正式 contract，并且继续服从 `v6 + v9` 的 crowd/runtime 性能边界。ambient traffic、玩家下车后的空车和 parked hijacked visual 都必须保持现状，不允许偷偷获得撞人能力。

## 里程碑

| 里程碑 | 范围 | DoD | 验证命令/测试 | 状态 |
|---|---|---|---|---|
| M1 撞击致死与创飞 | driving mode 下命中近景 pedestrian 会死亡、创飞并播放 death 动画 | 只有玩家当前驾驶的车辆能杀死目标；目标从 live crowd 退出；death visual 带创飞落点且继续播放 death/dead clip | `tests/world/test_city_player_vehicle_pedestrian_impact.gd`、`tests/world/test_city_player_vehicle_death_visual_launch.gd`、`tests/world/test_city_pedestrian_death_visual_persistence.gd` | done |
| M2 降速与局部恐慌 | 撞击后玩家车速降到个位数，附近近层 pedestrian 触发缩小版 60% 局部逃亡 | 撞击后 `speed_mps < 10` 且可重新加速；只有近层候选参与；响应比例约 60%，远层保持 calm | `tests/world/test_city_player_vehicle_pedestrian_impact.gd`、`tests/world/test_city_pedestrian_vehicle_impact_panic.gd`、`tests/e2e/test_city_vehicle_pedestrian_impact_flow.gd` | done |
| M3 红线复验 | combined runtime、page cache、first-visit redline | 不引入 duplicate page load / node budget 回退；warm 与 first-visit 继续守线 | `tests/world/test_city_vehicle_runtime_node_budget.gd`、`tests/e2e/test_city_runtime_performance_profile.gd`、`tests/e2e/test_city_first_visit_performance_profile.gd` | done |

## 计划索引

- [v11-vehicle-pedestrian-impact.md](./v11-vehicle-pedestrian-impact.md)

## 追溯矩阵

| Req ID | v11 Plan | 单元/集成测试 | E2E / 验证命令 | 证据 | 状态 |
|---|---|---|---|---|---|
| REQ-0005-001 | `v11-vehicle-pedestrian-impact.md` | `tests/world/test_city_player_vehicle_pedestrian_impact.gd`、`tests/world/test_city_player_vehicle_death_visual_launch.gd`、`tests/world/test_city_pedestrian_death_visual_persistence.gd` | `--script res://tests/e2e/test_city_vehicle_pedestrian_impact_flow.gd` | 2026-03-15 fresh 结果：撞击致死、创飞落点、death/dead clip 与 chunk retire 后保活全部 PASS | done |
| REQ-0005-002 | `v11-vehicle-pedestrian-impact.md` | `tests/world/test_city_player_vehicle_pedestrian_impact.gd` | `--script res://tests/e2e/test_city_vehicle_pedestrian_impact_flow.gd` | 2026-03-15 fresh 结果：`vehicle_speed_after_mps < 10` 且继续 driving/exit 流程 PASS | done |
| REQ-0005-003 | `v11-vehicle-pedestrian-impact.md` | `tests/world/test_city_pedestrian_vehicle_impact_panic.gd` | `--script res://tests/e2e/test_city_vehicle_pedestrian_impact_flow.gd` | 2026-03-15 fresh 结果：近层局部 panic、deterministic 60% 公式与圈外 calm 全部 PASS | done |
| REQ-0005-004 | `v11-vehicle-pedestrian-impact.md` | `tests/world/test_city_vehicle_runtime_node_budget.gd`、`tests/world/test_city_chunk_setup_profile_breakdown.gd` | `--script res://tests/e2e/test_city_runtime_performance_profile.gd`、`--script res://tests/e2e/test_city_first_visit_performance_profile.gd` | 2026-03-15 fresh 结果：`update_streaming_avg_usec = 7853 / 12836`、`wall_frame_avg_usec = 8685 / 13673`（warm / first-visit）全部守线 | done |

## ECN 索引

- 当前无 `v11` 专属 ECN

## 差异列表

- `v11` 明确只做“玩家当前 driving mode 的车撞近景行人”，不回收 `v8` deferred 的 ambient traffic 行人冲突计划。
- `v11` 明确不做玩家下车后的空车/parked hijacked vehicle 撞人，避免玩法语义从“我正在开车撞人”漂成“场景里任何车壳都能杀人”。
- `v11` 的 crowd response 明确是缩小版事故恐慌：只看最近 player 的近层候选，约 `60%` 响应，不做 gunshot/explosion 同等级全域广播。
- 2026-03-15 closeout 证据：功能回归 fresh PASS 包含 `test_city_player_vehicle_pedestrian_impact.gd`、`test_city_pedestrian_vehicle_impact_panic.gd`、`test_city_player_vehicle_death_visual_launch.gd`、`test_city_pedestrian_death_visual_persistence.gd`、`test_city_vehicle_pedestrian_impact_flow.gd`、`test_city_vehicle_hijack_drive_flow.gd`、`test_city_pedestrian_character_visual_presence.gd`、`test_city_pedestrian_combat_flow.gd`。
- 2026-03-15 性能 closeout 证据：`test_city_chunk_setup_profile_breakdown.gd` `total_usec = 3316`；`test_city_runtime_performance_profile.gd` `wall_frame_avg_usec = 8685`、`update_streaming_avg_usec = 7853`；`test_city_first_visit_performance_profile.gd` `wall_frame_avg_usec = 13673`、`update_streaming_avg_usec = 12836`。

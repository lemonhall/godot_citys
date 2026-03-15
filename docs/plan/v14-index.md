# V14 Index

## 愿景

PRD 入口：[PRD-0007 Task And Mission System](../prd/PRD-0007-task-and-mission-system.md)

研究入口：[2026-03-15-v14-gta5-task-system-research.md](../research/2026-03-15-v14-gta5-task-system-research.md)

设计入口：[2026-03-15-v14-task-system-design.md](../plans/2026-03-15-v14-task-system-design.md)

依赖入口：

- [PRD-0006 Landmark Navigation System](../prd/PRD-0006-landmark-navigation-system.md)
- [v12-index.md](./v12-index.md)
- [v13-index.md](./v13-index.md)

`v14` 的目标不是把 `register_task_pin()` 包一层 UI，而是把 `任务定义 / 任务状态 / 地图任务页签 / 世界任务圈 / 开始触发` 正式接到 `v12` 的地图与导航主链上。closeout 口径不是“地图上看见几个任务点”，而是：任务在大地图与任务页签里有正式状态，在世界里有共享火焰圈语义，玩家步行或驾驶车辆进入 start slot 能开始任务，并且整个系统仍走 shared pin / route / marker contract。

## 决策冻结

- `v14` 只允许沿 `task catalog -> task runtime -> task pin / task brief / world ring -> map/minimap/route` 这条主链推进；不允许再造 task-only map state、task-only marker stack 或 task-only route solver。
- 任务最小状态集冻结为 `available`、`active`、`completed`；`locked/failed` 不是 `v14` 里程碑前置。
- `M` 打开的 full map 继续保持地图画布常驻；任务页签以“地图旁的 `Tasks` 面板/页签”实现，不强行做整页切换。
- world task marker 必须复用当前火焰圈模型族：`available start = green`、`active objective = blue`、`destination = existing orange theme`。
- 玩家步行或正在驾驶的车辆进入 `start slot` 即可开始任务；默认不增加额外交互键。
- `v14` 首版冻结为 session-local runtime；不把存档/跨 session 持久化塞进本轮。

## 执行顺序与 Gate

- M1 是 M2/M3 的硬前置：没有正式 `task catalog / slot / runtime`，后续 map tab 和 world ring 都只能是假 UI。
- M2 是 M3 的数据前置：没有正式 `task brief + task pin projection + tracked task`，世界里的 ring marker 会失去稳定上游。
- M3 closeout 前必须串行重跑性能三件套；任务系统不允许通过降低 active tasks 到 0 或关闭 marker 来“过线”。

## 主链约束

`task catalog + slot index -> task runtime -> task pin projection / task brief view model -> full map / minimap / world ring / route target`

- `v14` 只允许在这条主链上增加 consumer。
- 任务系统不得反向侵入 `route solver`；它只能消费 `resolved_target / route_result`。
- world ring runtime 只能处理 `tracked active objective` 与 `nearby available starts`，不允许全量常亮。

## 里程碑

| 里程碑 | 范围 | DoD | 验证命令/测试 | 状态 |
|---|---|---|---|---|
| M1 Task Catalog 与 Runtime | 正式 `task definition / task slot / task runtime / tracked task` | fixed seed 下 `task_id/slot_id/world_anchor` 稳定；状态机最小集 `available/active/completed` 跑通；active task 唯一；不得每帧全量扫描任务 | `tests/world/test_city_task_catalog_contract.gd`、`tests/world/test_city_task_slot_seed_stability.gd`、`tests/world/test_city_task_runtime_state_machine.gd` | todo |
| M2 Full Map Tasks 页签与 Task Pins | `M` 地图旁任务页签、状态分组、任务 pin 与 tracked task 同步 | full map 显示 `available/active` 任务；`Tasks` 面板来自 runtime；选择任务会同步 tracked task 与 route target；不得开第二套 task-only map state | `tests/world/test_city_task_map_tab_contract.gd`、`tests/world/test_city_task_pin_projection.gd`、`tests/world/test_city_task_brief_view_model.gd`、`tests/e2e/test_city_task_tab_selection_flow.gd` | todo |
| M3 World Trigger Rings 与任务开始 E2E | 绿色/蓝色共享火焰圈、步行/驾车触发开始、objective 完成链 | task ring 与 destination ring 共享模型族；步行/驾车进入 start slot 都会开始任务；objective 完成后状态与 marker 清理正确；性能三件套不过线不算完成 | `tests/world/test_city_task_world_ring_marker_contract.gd`、`tests/world/test_city_task_trigger_start_contract.gd`、`tests/world/test_city_task_vehicle_trigger_start_contract.gd`、`tests/e2e/test_city_task_start_flow.gd`、`tests/world/test_city_chunk_setup_profile_breakdown.gd`、`tests/e2e/test_city_runtime_performance_profile.gd`、`tests/e2e/test_city_first_visit_performance_profile.gd` | todo |

## 计划索引

- [v14-task-runtime-and-slot-contract.md](./v14-task-runtime-and-slot-contract.md)
- [v14-task-map-and-brief-ui.md](./v14-task-map-and-brief-ui.md)
- [v14-task-world-triggers-and-ring-markers.md](./v14-task-world-triggers-and-ring-markers.md)

## 追溯矩阵

| Req ID | v14 Plan | 单元/集成测试 | E2E / 验证命令 | 证据 | 状态 |
|---|---|---|---|---|---|
| REQ-0007-001 | `v14-task-runtime-and-slot-contract.md` | `tests/world/test_city_task_catalog_contract.gd`、`tests/world/test_city_task_slot_seed_stability.gd` | `--script res://tests/world/test_city_task_catalog_contract.gd` | 待实现 | todo |
| REQ-0007-002 | `v14-task-runtime-and-slot-contract.md` | `tests/world/test_city_task_runtime_state_machine.gd` | `--script res://tests/world/test_city_task_runtime_state_machine.gd` | 待实现 | todo |
| REQ-0007-003 | `v14-task-map-and-brief-ui.md` | `tests/world/test_city_task_pin_projection.gd`、`tests/world/test_city_task_map_tab_contract.gd` | `--script res://tests/e2e/test_city_task_tab_selection_flow.gd` | 待实现 | todo |
| REQ-0007-004 | `v14-task-map-and-brief-ui.md` | `tests/world/test_city_task_map_tab_contract.gd`、`tests/world/test_city_task_brief_view_model.gd` | `--script res://tests/e2e/test_city_task_tab_selection_flow.gd` | 待实现 | todo |
| REQ-0007-005 | `v14-task-world-triggers-and-ring-markers.md` | `tests/world/test_city_task_world_ring_marker_contract.gd` | `--script res://tests/world/test_city_task_world_ring_marker_contract.gd` | 待实现 | todo |
| REQ-0007-006 | `v14-task-world-triggers-and-ring-markers.md` | `tests/world/test_city_task_trigger_start_contract.gd`、`tests/world/test_city_task_vehicle_trigger_start_contract.gd` | `--script res://tests/e2e/test_city_task_start_flow.gd` | 待实现 | todo |
| REQ-0007-007 | `v14-task-map-and-brief-ui.md`、`v14-task-world-triggers-and-ring-markers.md` | `tests/world/test_city_task_brief_view_model.gd`、`tests/world/test_city_task_trigger_start_contract.gd` | `--script res://tests/e2e/test_city_task_start_flow.gd` | 待实现 | todo |
| REQ-0007-008 | `v14-task-runtime-and-slot-contract.md`、`v14-task-map-and-brief-ui.md`、`v14-task-world-triggers-and-ring-markers.md` | `tests/world/test_city_task_slot_seed_stability.gd`、`tests/world/test_city_chunk_setup_profile_breakdown.gd` | `--script res://tests/e2e/test_city_runtime_performance_profile.gd`、`--script res://tests/e2e/test_city_first_visit_performance_profile.gd` | 待实现 | todo |

## Closeout 证据口径

- 这一次只做文档工程，不写实现代码；因此本页所有 milestone 当前都保持 `todo`。
- 后续任何 `todo -> doing -> done` 的状态变化，都必须伴随 fresh test / profile 证据；没有 fresh 输出，禁止改成 `done`。
- `v14` 的 closeout 证据必须统一落在 `docs/plan/v14-mN-verification-YYYY-MM-DD.md`，不允许只留在聊天记录里。
- 性能三件套必须严格串行：`test_city_chunk_setup_profile_breakdown.gd` -> `test_city_runtime_performance_profile.gd` -> `test_city_first_visit_performance_profile.gd`。

## ECN 索引

- 当前无 `v14` 专属 ECN

## 差异列表

- `emoji` 是否直接用于 UI 仍待实现期拍板；当前文档冻结的是 `icon_id + color_theme`，不是具体字体方案。
- `completed` 任务的大地图默认显示策略仍保留细化空间；当前建议默认进页签，不默认铺图。
- `v14` 首版只承诺单 active task、单 active objective，不包含复杂多阶段剧情系统。
- `v14` 首版只承诺 session-local runtime，不包含正式存档。

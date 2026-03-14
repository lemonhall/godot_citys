# V8 Index

## 愿景

PRD 入口：[PRD-0003 Vehicle Traffic Foundation](../prd/PRD-0003-vehicle-traffic-foundation.md)

设计入口：[2026-03-14-v8-vehicle-system-design.md](../plans/2026-03-14-v8-vehicle-system-design.md)

依赖入口：

- [PRD-0001 Large City Foundation](../prd/PRD-0001-large-city-foundation.md)
- [PRD-0002 Pedestrian Crowd Foundation](../prd/PRD-0002-pedestrian-crowd-foundation.md)
- [v6-index.md](./v6-index.md)
- [v7-index.md](./v7-index.md)

`v8` 的目标不是把当前项目直接扩成“玩家可驾驶 + 全城复杂交通”的大包版本，也不是把车辆系统重新实现成一棵 `Path3D` / per-lane scene tree。`v8` 要做的是：把已经在 `v7` 收口的 shared road semantics 和已经在 `v6` 建起来的 layered runtime 方法论，组合成一套可 streaming、可 profiling、可守红线的 ambient traffic foundation，并且只收最小必要的人车耦合。

## 里程碑

| 里程碑 | 范围 | DoD | 验证命令/测试 | 状态 |
|---|---|---|---|---|
| M0 车辆素材归档与尺度审计 | 8 个车辆 `glb` 归档、manifest、现实长度基线 | 根目录不再散落车辆素材；`vehicle_model_manifest.json` 覆盖全部 8 个模型并记录尺度基线 | `rg --files city_game/assets/vehicles`、`Get-ChildItem *.glb`、后续 `tests/world/test_city_vehicle_asset_manifest.gd` | done |
| M1 Vehicle World Model | deterministic vehicle config、density profile、vehicle query、drivable lane/turn graph | fixed seed 下 lane IDs / spawn slots / roster signatures 稳定；lane graph 只从 shared road semantics 派生 | `tests/world/test_city_vehicle_world_model.gd`、`tests/world/test_city_vehicle_lane_graph.gd`、`tests/world/test_city_vehicle_query_chunk_contract.gd`、`tests/world/test_city_vehicle_intersection_turn_contract.gd`、`tests/world/test_city_vehicle_headway_contract.gd` | done |
| M2 Ambient Traffic Layered Runtime | Tier 0-3 车辆表示、streaming budget、batched renderer、identity continuity | 当前已被 `2026-03-14` 手玩反馈阻塞：shadow Tier1、道路可视错位、单向偏置与 live FPS 回退均未收口，需先按 `v8-m2-handplay-feedback-and-replan.md` 重做 | `tests/world/test_city_vehicle_lod_contract.gd`、`tests/world/test_city_vehicle_batch_rendering.gd`、`tests/world/test_city_vehicle_streaming_budget.gd`、`tests/world/test_city_vehicle_identity_continuity.gd`、`tests/world/test_city_vehicle_runtime_node_budget.gd`、`tests/e2e/test_city_vehicle_travel_flow.gd` | blocked |
| M3 Pedestrian Coupling 与红线共存 | crosswalk yield、debug/profile、同配置 redline、first-visit guard | 行人与车辆在 crossing candidate 上形成最小必要 stop/yield；同配置下有人且有车仍守住 `16.67ms/frame` | `tests/world/test_city_vehicle_crossing_yield.gd`、`tests/world/test_city_vehicle_pedestrian_conflict_budget.gd`、`tests/world/test_city_vehicle_profile_stats.gd`、`tests/e2e/test_city_vehicle_performance_profile.gd`、`tests/e2e/test_city_runtime_performance_profile.gd`、`tests/e2e/test_city_first_visit_performance_profile.gd` | todo |

## 计划索引

- [v8-vehicle-asset-foundation.md](./v8-vehicle-asset-foundation.md)
- [v8-vehicle-query-and-lane-graph.md](./v8-vehicle-query-and-lane-graph.md)
- [v8-ambient-traffic-layered-runtime.md](./v8-ambient-traffic-layered-runtime.md)
- [v8-m2-handplay-feedback-and-replan.md](./v8-m2-handplay-feedback-and-replan.md)
- [v8-pedestrian-vehicle-conflict-guard.md](./v8-pedestrian-vehicle-conflict-guard.md)

## 追溯矩阵

| Req ID | v8 Plan | 单元/集成测试 | E2E / 验证命令 | 证据 | 状态 |
|---|---|---|---|---|---|
| REQ-0003-001 | `v8-vehicle-asset-foundation.md` | `tests/world/test_city_vehicle_asset_manifest.gd` | `rg --files city_game/assets/vehicles`、`Get-ChildItem *.glb` | 2026-03-14 当前工作区已把 8 个 `glb` 从仓库根目录归档到 `city_game/assets/vehicles/`，并新增 `vehicle_model_manifest.json` 与 `README.md` | done |
| REQ-0003-002 | `v8-vehicle-query-and-lane-graph.md` | `tests/world/test_city_vehicle_world_model.gd`、`tests/world/test_city_vehicle_query_chunk_contract.gd` | `--script res://tests/world/test_city_vehicle_world_model.gd` | 2026-03-14 `vehicle_query` 已接入 `CityWorldGenerator`，固定 seed 下 chunk lane IDs / spawn slot IDs / roster signature 稳定；详见 `v8-m1-verification-2026-03-14.md` | done |
| REQ-0003-003 | `v8-vehicle-query-and-lane-graph.md` | `tests/world/test_city_vehicle_lane_graph.gd`、`tests/world/test_city_vehicle_intersection_turn_contract.gd` | `--script res://tests/world/test_city_vehicle_lane_graph.gd` | 2026-03-14 `CityVehicleLaneGraph` 已从 `section_semantics.lane_schema` 与交叉口 topology contract 派生 drivable lane / turn contract；详见 `v8-m1-verification-2026-03-14.md` | done |
| REQ-0003-004 | `v8-ambient-traffic-layered-runtime.md`、`v8-m2-handplay-feedback-and-replan.md` | `tests/world/test_city_vehicle_lod_contract.gd`、`tests/world/test_city_vehicle_batch_rendering.gd`、`tests/world/test_city_vehicle_identity_continuity.gd` | `--script res://tests/world/test_city_vehicle_batch_rendering.gd` | 当前 world contracts 已有基础，但 `2026-03-14` 手玩反馈已明确否决 shadow Tier1 与当前视觉比例；详见 `v8-m2-handplay-feedback-and-replan.md` | blocked |
| REQ-0003-005 | `v8-ambient-traffic-layered-runtime.md`、`v8-m2-handplay-feedback-and-replan.md` | `tests/world/test_city_vehicle_streaming_budget.gd`、`tests/world/test_city_vehicle_page_cache.gd` | `--script res://tests/e2e/test_city_vehicle_travel_flow.gd` | 当前 page/cache 与 streaming budget contract 已有基础，但道路可视覆盖与 live travel 仍未建立可信 closeout；详见 `v8-m2-handplay-feedback-and-replan.md` | blocked |
| REQ-0003-006 | `v8-vehicle-query-and-lane-graph.md` | `tests/world/test_city_vehicle_headway_contract.gd`、`tests/world/test_city_vehicle_intersection_turn_contract.gd` | `--script res://tests/world/test_city_vehicle_headway_contract.gd` | 2026-03-14 `vehicle_query` 已输出 deterministic `min_headway_m` / `distance_along_lane_m`，同 lane spawn spacing 与基础路口 turn choice contract 已通过 world tests；详见 `v8-m1-verification-2026-03-14.md` | done |
| REQ-0003-007 | `v8-pedestrian-vehicle-conflict-guard.md` | `tests/world/test_city_vehicle_crossing_yield.gd`、`tests/world/test_city_vehicle_pedestrian_conflict_budget.gd` | `--script res://tests/e2e/test_city_vehicle_pedestrian_travel_flow.gd` | 待实现 | todo |
| REQ-0003-008 | `v8-pedestrian-vehicle-conflict-guard.md`、`v8-m2-handplay-feedback-and-replan.md` | `tests/world/test_city_vehicle_profile_stats.gd` | `--script res://tests/e2e/test_city_vehicle_performance_profile.gd` | 当前 profiling 字段已接入，但 hand-play 与 fresh isolated 性能仍不能作为 closeout 证据；详见 `v8-m2-handplay-feedback-and-replan.md` | blocked |
| REQ-0003-009 | `v8-ambient-traffic-layered-runtime.md`、`v8-pedestrian-vehicle-conflict-guard.md`、`v8-m2-handplay-feedback-and-replan.md` | `tests/world/test_city_vehicle_profile_stats.gd`、`tests/world/test_city_vehicle_runtime_node_budget.gd` | `--script res://tests/e2e/test_city_vehicle_performance_profile.gd`、`--script res://tests/e2e/test_city_runtime_performance_profile.gd`、`--script res://tests/e2e/test_city_first_visit_performance_profile.gd` | `2026-03-14` 当前工作区仍存在 live FPS 回退、warm / first-visit 波动与道路覆盖错位，暂不能诚实描述为 closeout；详见 `v8-m2-handplay-feedback-and-replan.md` | blocked |

## ECN 索引

- 当前无 `v8` 专属 ECN

## 差异列表

- 2026-03-14 `M0` 已先行完成：8 个车辆 `glb` 已从仓库根目录迁入正式资产目录，并建立了 manifest / 尺度基线。这是 `v8` 开工的前置清场动作，不代表 runtime 已存在。
- 2026-03-14 `M1` 已完成：`CityWorldGenerator` 已正式输出 `vehicle_query`，并新增 `CityVehicleConfig`、`CityVehicleLaneGraph`、`CityVehicleQuery`、`CityVehicleWorldBuilder` 与 5 条 world tests，把 shared road semantics 的第一条车辆 consumer 链接通。
- 2026-03-14 用户手玩反馈已把 `M2` 默认 `lite` 车流重调为“比上一轮翻倍，但仍要避免双车贴屁股和同模扎堆”，因此后续 world/e2e 验收必须以 `max_spawn_slots_per_chunk = 2`、`tier1/tier2/tier3 <= 4/2/1`，并叠加 world-space 近距去重与更强的车型扰动。
- 2026-03-14 最新手玩反馈进一步确认：当前 `M2` 的真正 blocker 不只是 density / spacing，而是 `Tier 1 shadow` 方案本身不合理、车辆与 pedestrian 呈现比例失衡、经常只看到单向车流、以及 minimap / lane graph 与主画面 road overlay 的覆盖明显脱节，导致“车在草坪上跑”。因此 `M2` 已正式转入 `blocked / replan required`，详见 `v8-m2-handplay-feedback-and-replan.md`。
- 2026-03-14 `v8` 的实现必须把 `v6` 当前仍在活跃收口的 crowd redline 当作硬依赖，尤其是 first-visit cold-path；不得把“有车了”建立在 pedestrian/fidelity 回退之上。
- 2026-03-14 `v8` 明确只做 ambient traffic foundation。玩家驾驶、刚体碰撞、完整 traffic signal / wanted / police chase 不在本期 DoD 内。
- 2026-03-14 shared road graph 已具备 `section_semantics`、`intersection_type`、`ordered_branches`、`branch_connection_semantics`；但这些 richer contract 目前还没有车辆 consumer，`v8` 的核心价值就是补上这条 consumer 链。

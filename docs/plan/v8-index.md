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
| M0 车辆素材归档与尺度审计 | 9 个车辆 `glb` 归档、manifest、现实长度基线 | 根目录不再散落车辆素材；`vehicle_model_manifest.json` 覆盖全部 9 个模型并记录尺度基线 | `rg --files city_game/assets/vehicles`、`Get-ChildItem *.glb`、后续 `tests/world/test_city_vehicle_asset_manifest.gd` | done |
| M1 Vehicle World Model | deterministic vehicle config、density profile、vehicle query、drivable lane/turn graph | fixed seed 下 lane IDs / spawn slots / roster signatures 稳定；lane graph 只从 shared road semantics 派生 | `tests/world/test_city_vehicle_world_model.gd`、`tests/world/test_city_vehicle_lane_graph.gd`、`tests/world/test_city_vehicle_query_chunk_contract.gd`、`tests/world/test_city_vehicle_intersection_turn_contract.gd`、`tests/world/test_city_vehicle_headway_contract.gd` | done |
| M2 Ambient Traffic Layered Runtime | Tier 0-3 车辆表示、streaming budget、batched renderer、identity continuity | 当前远景方案、双向车流、道路对齐与 combined runtime redline 已全部拿到 fresh closeout 证据 | `tests/world/test_city_vehicle_lod_contract.gd`、`tests/world/test_city_vehicle_batch_rendering.gd`、`tests/world/test_city_vehicle_streaming_budget.gd`、`tests/world/test_city_vehicle_identity_continuity.gd`、`tests/world/test_city_vehicle_runtime_node_budget.gd`、`tests/world/test_city_vehicle_direction_coverage.gd`、`tests/world/test_city_vehicle_service_presence.gd`、`tests/world/test_city_vehicle_taxi_presence.gd`、`tests/e2e/test_city_vehicle_performance_profile.gd`、`tests/e2e/test_city_runtime_performance_profile.gd`、`tests/e2e/test_city_first_visit_performance_profile.gd` | done |
| M3 Pedestrian Coupling 与红线共存 | crosswalk yield、debug/profile、同配置 redline、first-visit guard | 最新手玩决策已明确：当前阶段允许车辆与行人穿模，`M3` 不再作为 `v8` 当前 closeout 前置项，保留为未来可选增强 | `tests/world/test_city_vehicle_crossing_yield.gd`、`tests/world/test_city_vehicle_pedestrian_conflict_budget.gd`、`tests/e2e/test_city_vehicle_pedestrian_travel_flow.gd` | deferred |

## 计划索引

- [v8-vehicle-asset-foundation.md](./v8-vehicle-asset-foundation.md)
- [v8-vehicle-query-and-lane-graph.md](./v8-vehicle-query-and-lane-graph.md)
- [v8-ambient-traffic-layered-runtime.md](./v8-ambient-traffic-layered-runtime.md)
- [v8-m2-handplay-feedback-and-replan.md](./v8-m2-handplay-feedback-and-replan.md)
- [v8-pedestrian-vehicle-conflict-guard.md](./v8-pedestrian-vehicle-conflict-guard.md)

## 追溯矩阵

| Req ID | v8 Plan | 单元/集成测试 | E2E / 验证命令 | 证据 | 状态 |
|---|---|---|---|---|---|
| REQ-0003-001 | `v8-vehicle-asset-foundation.md` | `tests/world/test_city_vehicle_asset_manifest.gd` | `rg --files city_game/assets/vehicles`、`Get-ChildItem *.glb` | 2026-03-14 当前工作区已把 9 个 `glb` 从仓库根目录归档到 `city_game/assets/vehicles/`，并新增 `vehicle_model_manifest.json` 与 `README.md`；`taxi_a` 已补进正式 civilian 资产目录 | done |
| REQ-0003-002 | `v8-vehicle-query-and-lane-graph.md` | `tests/world/test_city_vehicle_world_model.gd`、`tests/world/test_city_vehicle_query_chunk_contract.gd` | `--script res://tests/world/test_city_vehicle_world_model.gd` | 2026-03-14 `vehicle_query` 已接入 `CityWorldGenerator`，固定 seed 下 chunk lane IDs / spawn slot IDs / roster signature 稳定；详见 `v8-m1-verification-2026-03-14.md` | done |
| REQ-0003-003 | `v8-vehicle-query-and-lane-graph.md` | `tests/world/test_city_vehicle_lane_graph.gd`、`tests/world/test_city_vehicle_intersection_turn_contract.gd` | `--script res://tests/world/test_city_vehicle_lane_graph.gd` | 2026-03-14 `CityVehicleLaneGraph` 已从 `section_semantics.lane_schema` 与交叉口 topology contract 派生 drivable lane / turn contract；详见 `v8-m1-verification-2026-03-14.md` | done |
| REQ-0003-004 | `v8-ambient-traffic-layered-runtime.md`、`v8-m2-verification-2026-03-14.md` | `tests/world/test_city_vehicle_lod_contract.gd`、`tests/world/test_city_vehicle_batch_rendering.gd`、`tests/world/test_city_vehicle_identity_continuity.gd`、`tests/world/test_city_vehicle_direction_coverage.gd`、`tests/world/test_city_vehicle_service_presence.gd`、`tests/world/test_city_vehicle_taxi_presence.gd` | `--script res://tests/world/test_city_vehicle_batch_rendering.gd` | 默认 `lite` 车流的远中景外观、双向覆盖、整体分布、警车 service slice 与出租车 civilian slice 已进入可接受状态；详见 `v8-m2-verification-2026-03-14.md` | done |
| REQ-0003-005 | `v8-ambient-traffic-layered-runtime.md`、`v8-m2-verification-2026-03-14.md` | `tests/world/test_city_vehicle_streaming_budget.gd`、`tests/world/test_city_vehicle_page_cache.gd`、`tests/world/test_city_bridge_midfar_visibility.gd`、`tests/world/test_city_vehicle_drive_surface_grounding.gd` | `--script res://tests/world/test_city_vehicle_drive_surface_grounding.gd` | 道路可视 coverage 已重新对齐，bridge deck / road surface grounding 与中远景桥面 proxy 均已通过 fresh world tests | done |
| REQ-0003-006 | `v8-vehicle-query-and-lane-graph.md` | `tests/world/test_city_vehicle_headway_contract.gd`、`tests/world/test_city_vehicle_intersection_turn_contract.gd` | `--script res://tests/world/test_city_vehicle_headway_contract.gd` | 2026-03-14 `vehicle_query` 已输出 deterministic `min_headway_m` / `distance_along_lane_m`，同 lane spawn spacing 与基础路口 turn choice contract 已通过 world tests；详见 `v8-m1-verification-2026-03-14.md` | done |
| REQ-0003-007 | `v8-pedestrian-vehicle-conflict-guard.md` | `tests/world/test_city_vehicle_crossing_yield.gd`、`tests/world/test_city_vehicle_pedestrian_conflict_budget.gd` | `--script res://tests/e2e/test_city_vehicle_pedestrian_travel_flow.gd` | 2026-03-14 最新手玩决策已明确：当前阶段允许车辆与行人穿模，M3 暂不作为 v8 closeout 前置要求 | deferred |
| REQ-0003-008 | `v8-ambient-traffic-layered-runtime.md`、`v8-m2-verification-2026-03-14.md` | `tests/world/test_city_vehicle_profile_stats.gd` | `--script res://tests/e2e/test_city_vehicle_performance_profile.gd` | fresh isolated evidence 已证明 `traffic_update/spawn/render_commit` 预算可独立采集，且与 combined runtime 一起守住当前红线 | done |
| REQ-0003-009 | `v8-ambient-traffic-layered-runtime.md`、`v8-m2-verification-2026-03-14.md` | `tests/world/test_city_vehicle_profile_stats.gd`、`tests/world/test_city_vehicle_runtime_node_budget.gd`、`tests/world/test_city_chunk_setup_profile_breakdown.gd` | `--script res://tests/e2e/test_city_runtime_performance_profile.gd`、`--script res://tests/e2e/test_city_first_visit_performance_profile.gd` | fresh isolated evidence：`chunk setup total_usec = 4808`、warm `wall_frame_avg_usec = 9319`、first-visit `wall_frame_avg_usec = 14056` / `update_streaming_avg_usec = 13188` / `streaming_mount_setup_avg_usec = 3714` | done |

## ECN 索引

- 当前无 `v8` 专属 ECN

## 差异列表

- 2026-03-14 `M0` 已先行完成：9 个车辆 `glb` 已从仓库根目录迁入正式资产目录，并建立了 manifest / 尺度基线；其中 `taxi_a` 作为后补 civilian 车型已正式接入默认 ambient traffic 资产池。这是 `v8` 开工的前置清场动作，不代表 runtime 已存在。
- 2026-03-14 `M1` 已完成：`CityWorldGenerator` 已正式输出 `vehicle_query`，并新增 `CityVehicleConfig`、`CityVehicleLaneGraph`、`CityVehicleQuery`、`CityVehicleWorldBuilder` 与 5 条 world tests，把 shared road semantics 的第一条车辆 consumer 链接通。
- 2026-03-14 用户手玩反馈已把 `M2` 默认 `lite` 车流重调为“比上一轮翻倍，但仍要避免双车贴屁股和同模扎堆”，因此后续 world/e2e 验收必须以 `max_spawn_slots_per_chunk = 2`、`tier1/tier2/tier3 <= 4/2/1`，并叠加 world-space 近距去重与更强的车型扰动。
- 2026-03-14 最新手玩反馈已经进一步收口：当前 `M2` 不再被 `Tier 1` 远景方案、双向可见性或整体分布状态阻塞；剩余 blocker 只剩 `road overlay` 覆盖错位与 combined runtime 性能红线。详见 `v8-m2-handplay-feedback-and-replan.md`。
- 2026-03-14 默认 ambient traffic 已开放小比例 `service` 车流切片，因此 `police_car_a` 会在主干路/次干路交通中偶发出现；这不代表已经实现完整 police system。
- 2026-03-14 最新手玩决策已明确：`M3 Pedestrian Coupling` 当前不是 `v8` closeout 前置项，车辆与行人穿模可接受，相关计划保留为未来增强而非当前 blocker。
- 2026-03-14 `v8` 的实现必须把 `v6` 当前仍在活跃收口的 crowd redline 当作硬依赖，尤其是 first-visit cold-path；不得把“有车了”建立在 pedestrian/fidelity 回退之上。
- 2026-03-14 `v8` 明确只做 ambient traffic foundation。玩家驾驶、刚体碰撞、完整 traffic signal / wanted / police chase 不在本期 DoD 内。
- 2026-03-14 shared road graph 已具备 `section_semantics`、`intersection_type`、`ordered_branches`、`branch_connection_semantics`；但这些 richer contract 目前还没有车辆 consumer，`v8` 的核心价值就是补上这条 consumer 链。

# V13 Index

## 愿景

PRD 入口：[PRD-0001 Large City Foundation](../prd/PRD-0001-large-city-foundation.md)

ECN 入口：[ECN-0019 City Morphology and PNG Acceptance](../ecn/ECN-0019-city-morphology-and-png-acceptance.md)

设计入口：[2026-03-15-v13-city-morphology-design.md](../plans/2026-03-15-v13-city-morphology-design.md)

`v13` 的目标不是再给现有 dense grid 补一点自然扰动，而是把整城的世界级形态拉回正确轨道：`road_graph` 必须先像“主城区 + 卫星城 + 干道连接”的城市，随后 chunk building 也必须沿着这套道路骨架长出来。`v13` 的 closeout 不再只看 world tests 是否通过，还必须输出 deterministic 的 2D 总览 PNG，让人工验收能直接判断整城形态是否过关。

## 决策冻结

- `district graph` 继续作为世界分块元数据存在，但不得再直接成为正式可见道路主骨架。
- `v13` 默认不推翻 `block_layout / place_index / address grammar`；本轮先修世界 morphology 与沿街 building layout。
- PNG 验收产物必须由当前 `road_graph + building layout` 直接导出，禁止静态素材或离线手工图。
- `v13` 的 world overview 默认以“有效城市范围”构图，而不是盲目把整个 `70km x 70km` 世界硬塞满画面。

## 里程碑

| 里程碑 | 范围 | DoD | 验证命令/测试 | 状态 |
|---|---|---|---|---|
| M1 多中心道路骨架接管 | `CityWorldGenerator` 不再产出 world-filling district lattice，`CityReferenceRoadGraphBuilder` 直接生成多中心连续路网 | fixed seed 下 `road_graph` 明显低于 full-grid 边数基线；growth stats 显式报告 `population_center_count >= 3` 与 corridor 统计；中心城与至少两个卫星窗口都有正式道路；主城到卫星城 trunk corridor 连续不断 | `tests/world/test_city_world_generator.gd`、`tests/world/test_city_reference_road_graph.gd`、`tests/world/test_city_road_network_continuity.gd` | done |
| M2 沿街 building layout | chunk building 主体来自 streetfront candidate，而不是规则格点均匀打点 | building layout 输出 streetfront 统计；中心 chunk 仍保持密度，但大多数 building 与最近道路保持沿街取向与合理退距；`no-road chunk => 0 building` | `tests/world/test_city_building_collision.gd`、`tests/world/test_city_streetfront_building_layout.gd` | done |
| M3 PNG 世界级验收链 | deterministic overview PNG + metadata | headless 导出 `PNG + metadata`；metadata 含 morphology 统计；导出结果可供人工 review；`active_bounds` 达到世界级尺度；反作弊条款写硬 | `tests/world/test_city_overview_png_export.gd` + overview artifact | done |
| M4 导航 contract 收口 | 地图点选在扩大后的路网上仍能稳定出正式 route contract | 可见城市区附近点选返回非空 `selection_contract` 与 route polyline；degree=2 continuation 不再切断导航图 | `tests/world/test_city_map_destination_contract.gd`、`tests/world/test_city_route_query_contract.gd`、`tests/e2e/test_city_map_destination_selection_flow.gd`、`tests/e2e/test_city_navigation_flow.gd` | done |

## 计划索引

- [v13-city-morphology-and-overview-png.md](./v13-city-morphology-and-overview-png.md)

## 追溯矩阵

| Req ID | v13 Plan | 单元/集成测试 | E2E / 验证命令 | 证据 | 状态 |
|---|---|---|---|---|---|
| REQ-0001-002 | `v13-city-morphology-and-overview-png.md` | `tests/world/test_city_world_generator.gd`、`tests/world/test_city_reference_road_graph.gd`、`tests/world/test_city_road_network_continuity.gd` | `--script res://tests/world/test_city_world_generator.gd` | overview metadata: `population_center_count=7`、`corridor_count=12`、`road_edge_count=4200` | done |
| REQ-0001-004 | `v13-city-morphology-and-overview-png.md` | `tests/world/test_city_building_collision.gd`、`tests/world/test_city_streetfront_building_layout.gd` | `--script res://tests/world/test_city_streetfront_building_layout.gd` | streetfront ratio 仍达标；`no-road chunk => 0 building` 已锁死 | done |
| REQ-0001-006 | `v13-city-morphology-and-overview-png.md` | `tests/world/test_city_overview_png_export.gd` | `--script res://tests/world/test_city_overview_png_export.gd` | `E:\development\godot_citys\reports\v13\test_city_overview_seed_424242.png` + sidecar JSON | done |
| REQ-0001-013 | `v13-city-morphology-and-overview-png.md` | `tests/world/test_city_overview_png_export.gd`、`tests/world/test_city_road_intersection_topology.gd` | `--script res://tests/world/test_city_overview_png_export.gd` | `active_bounds = (-29807.96, -35000.0, 57361.90, 68454.08)`；deterministic morphology PNG 已更新 | done |

## ECN 索引

- [ECN-0019-city-morphology-and-png-acceptance.md](../ecn/ECN-0019-city-morphology-and-png-acceptance.md)

## 验证产物

- PNG：`E:\development\godot_citys\reports\v13\test_city_overview_seed_424242.png`
- Metadata：`E:\development\godot_citys\reports\v13\test_city_overview_seed_424242.json`
- Metadata 摘要：
  - `population_center_count = 7`
  - `corridor_count = 12`
  - `road_edge_count = 4200`
  - `road_pixel_count = 121294`
  - `building_pixel_count = 21293`
  - `building_footprint_count = 45827`
  - `active_bounds = (-29807.96, -35000.0, 57361.90, 68454.08)`

## 性能护栏复验

- `test_city_chunk_setup_profile_breakdown.gd`
  - `total_usec = 2923`
  - `buildings_usec = 1712`
  - `ground_usec = 899`
- `test_city_runtime_performance_profile.gd`
  - `wall_frame_avg_usec = 9132`
  - `update_streaming_avg_usec = 7331`
  - `streaming_mount_setup_avg_usec = 2534`
- `test_city_first_visit_performance_profile.gd`
  - `wall_frame_avg_usec = 12582`
  - `update_streaming_avg_usec = 11736`
  - `streaming_mount_setup_avg_usec = 3702`

## 差异列表

- 代码与自动化 contract 已收口，但 `v13` 的最终 closeout 仍取决于人工 PNG 看图验收；如果你认为主城/卫星城/建筑纹理仍不自然，下一轮继续围绕同一 PNG 验收链迭代。
- 当前这轮优先满足的是“路网更大 + 无路不长楼 + trunk 连续 + 导航 contract 不回退”；更细的土地利用、山脉木屋、无路区散点建筑留到后续版本。

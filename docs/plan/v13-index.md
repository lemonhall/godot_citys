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
| M1 多中心道路骨架接管 | `CityWorldGenerator` 不再产出 world-filling district lattice，`CityReferenceRoadGraphBuilder` 直接生成多中心连续路网 | fixed seed 下 `road_graph` 明显低于 full-grid 边数基线；growth stats 显式报告 `population_center_count >= 3` 与 corridor 统计；中心城与至少两个卫星窗口都有正式道路 | `tests/world/test_city_world_generator.gd`、`tests/world/test_city_reference_road_graph.gd`、`tests/world/test_city_road_network_continuity.gd` | done |
| M2 沿街 building layout | chunk building 主体来自 streetfront candidate，而不是规则格点均匀打点 | building layout 输出 streetfront 统计；中心 chunk 仍保持密度，但大多数 building 与最近道路保持沿街取向与合理退距 | `tests/world/test_city_building_collision.gd`、`tests/world/test_city_streetfront_building_layout.gd` | done |
| M3 PNG 世界级验收链 | deterministic overview PNG + metadata | headless 导出 `PNG + metadata`；metadata 含 morphology 统计；导出结果可供人工 review；反作弊条款写硬 | `tests/world/test_city_overview_png_export.gd` + overview artifact | done |

## 计划索引

- [v13-city-morphology-and-overview-png.md](./v13-city-morphology-and-overview-png.md)

## 追溯矩阵

| Req ID | v13 Plan | 单元/集成测试 | E2E / 验证命令 | 证据 | 状态 |
|---|---|---|---|---|---|
| REQ-0001-002 | `v13-city-morphology-and-overview-png.md` | `tests/world/test_city_world_generator.gd`、`tests/world/test_city_reference_road_graph.gd`、`tests/world/test_city_road_network_continuity.gd` | `--script res://tests/world/test_city_world_generator.gd` | overview metadata: `population_center_count=4`、`corridor_count=3`、`road_edge_count=2600` | done |
| REQ-0001-004 | `v13-city-morphology-and-overview-png.md` | `tests/world/test_city_building_collision.gd`、`tests/world/test_city_streetfront_building_layout.gd` | `--script res://tests/world/test_city_building_collision.gd` | streetfront ratio `0.7333`；center chunk building count `>= 12` | done |
| REQ-0001-006 | `v13-city-morphology-and-overview-png.md` | `tests/world/test_city_overview_png_export.gd` | `--script res://tests/world/test_city_overview_png_export.gd` | `E:\development\godot_citys\reports\v13\test_city_overview_seed_424242.png` + sidecar JSON | done |
| REQ-0001-013 | `v13-city-morphology-and-overview-png.md` | `tests/world/test_city_overview_png_export.gd`、`tests/world/test_city_road_intersection_topology.gd` | `--script res://tests/world/test_city_overview_png_export.gd` | deterministic morphology PNG 已生成，可进入人工看图验收 | done |

## ECN 索引

- [ECN-0019-city-morphology-and-png-acceptance.md](../ecn/ECN-0019-city-morphology-and-png-acceptance.md)

## 验证产物

- PNG：`E:\development\godot_citys\reports\v13\test_city_overview_seed_424242.png`
- Metadata：`E:\development\godot_citys\reports\v13\test_city_overview_seed_424242.json`
- Metadata 摘要：
  - `population_center_count = 4`
  - `corridor_count = 3`
  - `road_edge_count = 2600`
  - `road_pixel_count = 156079`
  - `building_pixel_count = 31718`
  - `building_footprint_count = 20170`
  - `active_bounds = (-19022.89, -11177.44, 41740.39, 27544.26)`

## 差异列表

- 代码与自动化 contract 已收口，但 `v13` 的最终 closeout 仍取决于人工 PNG 看图验收；如果你认为主城/卫星城/建筑纹理仍不自然，下一轮继续围绕同一 PNG 验收链迭代。

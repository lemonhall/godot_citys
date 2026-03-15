# V12 Index

## 愿景

PRD 入口：[PRD-0006 Landmark Navigation System](../prd/PRD-0006-landmark-navigation-system.md)

研究入口：[2026-03-15-v12-landmark-navigation-gta5-research.md](../research/2026-03-15-v12-landmark-navigation-gta5-research.md)

设计入口：[2026-03-15-v12-landmark-navigation-design.md](../plans/2026-03-15-v12-landmark-navigation-design.md)

依赖入口：

- [PRD-0001 Large City Foundation](../prd/PRD-0001-large-city-foundation.md)
- [PRD-0003 Vehicle Traffic Foundation](../prd/PRD-0003-vehicle-traffic-foundation.md)
- [PRD-0004 Vehicle Hijack Driving](../prd/PRD-0004-vehicle-hijack-driving.md)
- [v3-index.md](./v3-index.md)
- [v7-index.md](./v7-index.md)
- [v8-index.md](./v8-index.md)
- [v9-index.md](./v9-index.md)

`v12` 不是“给 minimap 多加几个 label”，而是把 `地标/地址/查询/路线/全屏地图/HUD/Task 图钉/瞬移/自动驾驶` 收束成同一条位置语义链。当前默认 seed `424242` 下，世界已有 `31,860` 条道路边、`10,621` 个交叉点、`89,679` 条 vehicle lane、`300,304` 个 block、`1,201,216` 个 parcel；因此 `v12` 必须按正式世界资产来设计，而不是按 UI demo 来设计。

## 里程碑

| 里程碑 | 范围 | DoD | 验证命令/测试 | 状态 |
|---|---|---|---|---|
| M1 数据审计与地址规则冻结 | 冻结 street cluster、地址语法、candidate pool 规模 | 正式跑出 `roads/intersections/lanes/blocks/parcels/street clusters`；命名与门牌规则写硬；AI 候选池规模明确 | `tests/world/test_city_place_index_world_counts.gd`、`tests/world/test_city_address_grammar.gd` | todo |
| M2 Place Index 与 Query | world generation/caches 产出 `place_index/place_query` | `world_data` 暴露正式 query；按 road/address/landmark 可反查稳定目标点；chunk 卸载后仍可查询 | `tests/world/test_city_place_query_resolution.gd`、`tests/world/test_city_place_index_cache.gd` | todo |
| M3 Lane-Based Routing | 基于 lane graph 与 turn contract 的正式 route result | route 不再是 chunk Manhattan；输出 `polyline + steps + maneuvers + reroute_generation` | `tests/world/test_city_route_query_contract.gd`、`tests/world/test_city_route_reroute.gd`、`tests/e2e/test_city_navigation_flow.gd` | todo |
| M4 Full Map / Minimap / HUD / Pins | `M` 全屏地图、暂停世界、选点、pin overlay、minimap 与 HUD 同源 | 打开地图世界暂停、地图可选点；minimap/HUD 共享同一 route result；支持至少两类 pin | `tests/world/test_city_full_map_pause_contract.gd`、`tests/world/test_city_minimap_navigation_hud.gd`、`tests/e2e/test_city_map_destination_selection_flow.gd` | todo |
| M5 Fast Travel 与 Auto-Drive | 同一目标支持瞬移与 player-only 自动驾驶 | teleport 与 auto-drive 消费同一 `resolved_target/route_result`；auto-drive 可中断；性能红线不破 | `tests/e2e/test_city_fast_travel_map_flow.gd`、`tests/e2e/test_city_autodrive_flow.gd`、`tests/e2e/test_city_runtime_performance_profile.gd`、`tests/e2e/test_city_first_visit_performance_profile.gd` | todo |

## 计划索引

- [v12-landmark-audit-and-addressing.md](./v12-landmark-audit-and-addressing.md)
- [v12-place-index-and-query.md](./v12-place-index-and-query.md)
- [v12-route-contract-and-routing.md](./v12-route-contract-and-routing.md)
- [v12-map-ui-hud-task-pins.md](./v12-map-ui-hud-task-pins.md)
- [v12-fast-travel-and-autodrive.md](./v12-fast-travel-and-autodrive.md)

## 追溯矩阵

| Req ID | v12 Plan | 单元/集成测试 | E2E / 验证命令 | 证据 | 状态 |
|---|---|---|---|---|---|
| REQ-0006-001 | `v12-place-index-and-query.md` | `tests/world/test_city_place_index_world_counts.gd`、`tests/world/test_city_place_index_cache.gd` | `--script res://tests/world/test_city_place_query_resolution.gd` | 待实现 | todo |
| REQ-0006-002 | `v12-landmark-audit-and-addressing.md` | `tests/world/test_city_address_grammar.gd`、`tests/world/test_city_street_cluster_naming.gd` | `--script res://tests/world/test_city_place_query_resolution.gd` | 待实现 | todo |
| REQ-0006-003 | `v12-place-index-and-query.md` | `tests/world/test_city_place_query_resolution.gd` | `--script res://tests/e2e/test_city_map_destination_selection_flow.gd` | 待实现 | todo |
| REQ-0006-004 | `v12-route-contract-and-routing.md` | `tests/world/test_city_route_query_contract.gd`、`tests/world/test_city_route_reroute.gd` | `--script res://tests/e2e/test_city_navigation_flow.gd` | 待实现 | todo |
| REQ-0006-005 | `v12-map-ui-hud-task-pins.md` | `tests/world/test_city_minimap_navigation_hud.gd` | `--script res://tests/e2e/test_city_map_destination_selection_flow.gd` | 待实现 | todo |
| REQ-0006-006 | `v12-map-ui-hud-task-pins.md` | `tests/world/test_city_full_map_pause_contract.gd`、`tests/world/test_city_map_pin_overlay.gd` | `--script res://tests/e2e/test_city_map_destination_selection_flow.gd` | 待实现 | todo |
| REQ-0006-007 | `v12-fast-travel-and-autodrive.md` | `tests/world/test_city_fast_travel_target_resolution.gd` | `--script res://tests/e2e/test_city_fast_travel_map_flow.gd`、`--script res://tests/e2e/test_city_autodrive_flow.gd` | 待实现 | todo |
| REQ-0006-008 | `v12-landmark-audit-and-addressing.md`、`v12-route-contract-and-routing.md`、`v12-map-ui-hud-task-pins.md`、`v12-fast-travel-and-autodrive.md` | `tests/world/test_city_place_index_cache.gd`、`tests/world/test_city_route_query_contract.gd` | `--script res://tests/e2e/test_city_runtime_performance_profile.gd`、`--script res://tests/e2e/test_city_first_visit_performance_profile.gd`、`--script res://tests/world/test_city_chunk_setup_profile_breakdown.gd` | 待实现 | todo |

## ECN 索引

- 当前无 `v12` 专属 ECN

## 差异列表

- 当前默认命名风格按“完全虚构但沿用美式英语地址语法”起草，若后续改成中英混合，需要通过 ECN 改口径。
- 当前 `CityMacroRouteGraph` 仍是 chunk Manhattan；在 M3 完成前，仓库现有 route 行为不应被误称为正式 turn-by-turn 导航。
- 当前 world 级 building 只有 chunk-local deterministic mesh，没有正式 addressable building 索引；M1/M2 必须先把 `parcel/frontage slot` 这一层写硬。
- `v12` 把自动驾驶纳入范围，但默认口径是 player-only route follow，不等于重写 ambient traffic AI。

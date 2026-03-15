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

## 决策冻结

- 名字风格当前冻结为“完全虚构，但沿用美式英语道路/门牌语法”；如果后续改成中英混合，必须通过 ECN 改口径。
- `addressable_building` 的正式主键冻结在 `parcel_id + frontage_slot_index`，不允许直接把 chunk-local building mesh 当地址主键。
- 任意查询/地图点击都必须先生成正式 `resolved_target`，同时携带 `raw_world_anchor`（如有）与 `routable_anchor`；默认导航走 `routable_anchor`，raw point 只给显式 fast-travel/special-case consumer 使用。
- `auto-drive` 当前冻结为 player-only 的 route consumer，只控制玩家当前正在驾驶的车辆；不承担 ambient traffic AI 重写。
- `place_index` 允许磁盘缓存；`route_result` 当前口径冻结为 runtime memoization / snapped-anchor cache，不要求做磁盘化路线库。

## 执行顺序与 Gate

- M1 是 M2-M5 的硬前置：没有冻结 `street cluster / address grammar / candidate pool / frontage slot`，后续 place id 和 display name 都不可信。
- M2 是 M3-M5 的硬前置：没有正式 `place_index / place_query / route_target_index / resolved_target`，地图、HUD、pin、瞬移和自动驾驶都只能各做一套临时入口。
- M3 是 M4-M5 的硬前置：没有 lane-based `route_result`，minimap/HUD/autodrive 不允许继续消费 chunk Manhattan。
- M4 是 M5 的 UX 前置：M5 的 logic 可先由 debug/query 入口验证，但 map-triggered 主链不允许在 M4 未完成时宣称闭环。
- 任何触及 `world generation / place index / route planner / map UI / HUD / fast travel / autodrive` 的 milestone closeout，都必须串行重跑性能三件套，不得并行。

## 主链约束

`road_graph + block_layout + vehicle_query -> street_cluster/address freeze -> place_index/place_query/route_target_index -> resolved_target -> route_result -> minimap/full map/HUD/task pins/fast travel/auto-drive`

- `v12` 只允许沿这条主链增加 consumer，不允许回退成 chunk-local 名字表、UI 现场字符串查表或第二套路由图。
- `M4/M5` 只能消费 `M2/M3` 的正式上游，不允许自己补“临时 target parser / 临时 route solver”。

## 里程碑

| 里程碑 | 范围 | DoD | 验证命令/测试 | 状态 |
|---|---|---|---|---|
| M1 数据审计与地址规则冻结 | 冻结 street cluster、地址语法、candidate pool 规模 | 正式跑出 `roads/intersections/lanes/blocks/parcels/street clusters`；`parcel/frontage slot` 地址主键写硬；命名与门牌规则写硬；AI 道路名与 landmark proper-name 候选池带宽明确 | `tests/world/test_city_place_index_world_counts.gd`、`tests/world/test_city_street_cluster_naming.gd`、`tests/world/test_city_address_grammar.gd`、`tests/world/test_city_name_candidate_catalog.gd` | done |
| M2 Place Index 与 Query | world generation/caches 产出 `place_index/place_query/route_target_index` | `world_data` 暴露正式 query；`resolved_target` 至少带 `place_id/place_type/raw_world_anchor/routable_anchor/source_kind`；chunk 卸载后仍可查询；磁盘 cache key/path 冻结 | `tests/world/test_city_place_query_resolution.gd`、`tests/world/test_city_resolved_target_contract.gd`、`tests/world/test_city_place_index_cache.gd` | done |
| M3 Lane-Based Routing | 基于 lane graph 与 turn contract 的正式 route result | route 不再是 chunk Manhattan；输出 `polyline + steps + maneuvers + reroute_generation`；同源 `route_result` 可被 HUD/minimap/autodrive 共享；重复同参查询有 runtime cache/memoization contract | `tests/world/test_city_route_query_contract.gd`、`tests/world/test_city_route_reroute.gd`、`tests/world/test_city_route_result_cache.gd`、`tests/e2e/test_city_navigation_flow.gd` | done |
| M4 Full Map / Minimap / HUD / Pins | `M` 全屏地图、暂停世界、选点、pin overlay、minimap 与 HUD 同源 | 打开地图时 3D 世界暂停但地图 UI 可交互；地图点击生成正式 destination target；minimap/HUD 共享同一 route generation；支持至少两类 pin 且图例/层级可区分 | `tests/world/test_city_full_map_pause_contract.gd`、`tests/world/test_city_map_destination_contract.gd`、`tests/world/test_city_map_pin_overlay.gd`、`tests/world/test_city_minimap_navigation_hud.gd`、`tests/e2e/test_city_map_destination_selection_flow.gd` | done |
| M5 Fast Travel 与 Auto-Drive | 同一目标支持瞬移与 player-only 自动驾驶 | teleport 与 auto-drive 消费同一 `resolved_target/route_result`；auto-drive 可中断并显式返还控制权；不得新开隐藏 route solver；性能红线不破 | `tests/world/test_city_fast_travel_target_resolution.gd`、`tests/world/test_city_autodrive_interrupt_contract.gd`、`tests/e2e/test_city_fast_travel_map_flow.gd`、`tests/e2e/test_city_autodrive_flow.gd`、`tests/world/test_city_chunk_setup_profile_breakdown.gd`、`tests/e2e/test_city_runtime_performance_profile.gd`、`tests/e2e/test_city_first_visit_performance_profile.gd` | done |

## 计划索引

- [v12-landmark-audit-and-addressing.md](./v12-landmark-audit-and-addressing.md)
- [v12-place-index-and-query.md](./v12-place-index-and-query.md)
- [v12-route-contract-and-routing.md](./v12-route-contract-and-routing.md)
- [v12-map-ui-hud-task-pins.md](./v12-map-ui-hud-task-pins.md)
- [v12-fast-travel-and-autodrive.md](./v12-fast-travel-and-autodrive.md)

## 追溯矩阵

| Req ID | v12 Plan | 单元/集成测试 | E2E / 验证命令 | 证据 | 状态 |
|---|---|---|---|---|---|
| REQ-0006-001 | `v12-landmark-audit-and-addressing.md`（上游冻结）、`v12-place-index-and-query.md` | `tests/world/test_city_place_index_world_counts.gd`、`tests/world/test_city_name_candidate_catalog.gd`、`tests/world/test_city_place_index_cache.gd` | `--script res://tests/world/test_city_place_query_resolution.gd` | [v12-m1-verification-2026-03-15.md](./v12-m1-verification-2026-03-15.md)、[v12-m2-verification-2026-03-15.md](./v12-m2-verification-2026-03-15.md) | done |
| REQ-0006-002 | `v12-landmark-audit-and-addressing.md` | `tests/world/test_city_address_grammar.gd`、`tests/world/test_city_street_cluster_naming.gd`、`tests/world/test_city_name_candidate_catalog.gd` | `--script res://tests/world/test_city_place_query_resolution.gd` | [v12-m1-verification-2026-03-15.md](./v12-m1-verification-2026-03-15.md) | done |
| REQ-0006-003 | `v12-place-index-and-query.md`、`v12-map-ui-hud-task-pins.md` | `tests/world/test_city_place_query_resolution.gd`、`tests/world/test_city_resolved_target_contract.gd`、`tests/world/test_city_map_destination_contract.gd` | `--script res://tests/e2e/test_city_map_destination_selection_flow.gd` | [v12-m2-verification-2026-03-15.md](./v12-m2-verification-2026-03-15.md)、[v12-m4-verification-2026-03-15.md](./v12-m4-verification-2026-03-15.md) | done |
| REQ-0006-004 | `v12-route-contract-and-routing.md` | `tests/world/test_city_route_query_contract.gd`、`tests/world/test_city_route_reroute.gd`、`tests/world/test_city_route_result_cache.gd` | `--script res://tests/e2e/test_city_navigation_flow.gd` | [v12-m3-verification-2026-03-15.md](./v12-m3-verification-2026-03-15.md) | done |
| REQ-0006-005 | `v12-route-contract-and-routing.md`、`v12-map-ui-hud-task-pins.md` | `tests/world/test_city_route_query_contract.gd`、`tests/world/test_city_minimap_navigation_hud.gd` | `--script res://tests/e2e/test_city_navigation_flow.gd`、`--script res://tests/e2e/test_city_map_destination_selection_flow.gd` | [v12-m3-verification-2026-03-15.md](./v12-m3-verification-2026-03-15.md)、[v12-m4-verification-2026-03-15.md](./v12-m4-verification-2026-03-15.md) | done |
| REQ-0006-006 | `v12-map-ui-hud-task-pins.md` | `tests/world/test_city_full_map_pause_contract.gd`、`tests/world/test_city_map_destination_contract.gd`、`tests/world/test_city_map_pin_overlay.gd` | `--script res://tests/e2e/test_city_map_destination_selection_flow.gd` | [v12-m4-verification-2026-03-15.md](./v12-m4-verification-2026-03-15.md) | done |
| REQ-0006-007 | `v12-route-contract-and-routing.md`、`v12-fast-travel-and-autodrive.md` | `tests/world/test_city_fast_travel_target_resolution.gd`、`tests/world/test_city_autodrive_interrupt_contract.gd` | `--script res://tests/e2e/test_city_fast_travel_map_flow.gd`、`--script res://tests/e2e/test_city_autodrive_flow.gd` | [v12-m5-verification-2026-03-15.md](./v12-m5-verification-2026-03-15.md) | done |
| REQ-0006-008 | `v12-landmark-audit-and-addressing.md`、`v12-place-index-and-query.md`、`v12-route-contract-and-routing.md`、`v12-map-ui-hud-task-pins.md`、`v12-fast-travel-and-autodrive.md` | `tests/world/test_city_place_index_cache.gd`、`tests/world/test_city_route_result_cache.gd`、`tests/world/test_city_route_query_contract.gd` | `--script res://tests/world/test_city_chunk_setup_profile_breakdown.gd`、`--script res://tests/e2e/test_city_runtime_performance_profile.gd`、`--script res://tests/e2e/test_city_first_visit_performance_profile.gd` | [v12-m5-verification-2026-03-15.md](./v12-m5-verification-2026-03-15.md) | done |

## Closeout 证据口径

- `todo -> doing -> done` 的状态变化必须伴随 fresh rerun 证据；没有 fresh 输出，只能保留 `todo/doing`。
- 每个 milestone closeout 统一落在 `docs/plan/v12-mN-verification-YYYY-MM-DD.md`，并在本页回链；`v12` 不允许把 closeout 证据分散留在聊天记录里。
- 性能三件套必须严格串行：`test_city_chunk_setup_profile_breakdown.gd` -> `test_city_runtime_performance_profile.gd` -> `test_city_first_visit_performance_profile.gd`。
- 如出现“为了过线临时关闭 minimap/HUD、降低交通/人群、把地图系统做成 profiling 专用低配模式”的情况，证据视为无效。

## ECN 索引

- 当前无 `v12` 专属 ECN

## 差异列表

- 当前 `CityMacroRouteGraph` 仍是 chunk Manhattan；在 M3 完成前，仓库现有 route 行为不应被误称为正式 turn-by-turn 导航。
- 当前 world 级 building 只有 chunk-local deterministic mesh，没有正式 addressable building 索引；M1/M2 必须先把 `parcel/frontage slot` 这一层写硬。
- `v12` 把自动驾驶纳入范围，但默认口径是 player-only route follow，不等于重写 ambient traffic AI。
- 2026-03-15 closeout 证据：`M1-M5` verification artifacts 已落地为 [v12-m1-verification-2026-03-15.md](./v12-m1-verification-2026-03-15.md)、[v12-m2-verification-2026-03-15.md](./v12-m2-verification-2026-03-15.md)、[v12-m3-verification-2026-03-15.md](./v12-m3-verification-2026-03-15.md)、[v12-m4-verification-2026-03-15.md](./v12-m4-verification-2026-03-15.md)、[v12-m5-verification-2026-03-15.md](./v12-m5-verification-2026-03-15.md)。
- 2026-03-15 性能 closeout 证据：`test_city_chunk_setup_profile_breakdown.gd` `total_usec = 3164`；`test_city_runtime_performance_profile.gd` `wall_frame_avg_usec = 8191`、`update_streaming_avg_usec = 7194`；`test_city_first_visit_performance_profile.gd` `wall_frame_avg_usec = 11943`、`update_streaming_avg_usec = 11229`。

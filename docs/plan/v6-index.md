# V6 Index

## 愿景

PRD 入口：[PRD-0002 Pedestrian Crowd Foundation](../prd/PRD-0002-pedestrian-crowd-foundation.md)

research 入口：[2026-03-12-open-world-pedestrian-crowd-performance-research.md](../research/2026-03-12-open-world-pedestrian-crowd-performance-research.md)

`v6` 的目标不是把 `godot_citys` 直接升级为“全城人人都是完整 NPC”的大而化之版本，而是把街道人群先做成一套受预算约束、与 `road_graph` 同源、能守住 `16.67ms/frame` 红线的分层 crowd system。只有少量靠近玩家且有交互价值的个体，才允许升级为更贵的 reactive agent；其余 tier 必须围绕 lane graph、batched rendering、streaming budget 和 profiling guard 设计。

## 里程碑

| 里程碑 | 范围 | DoD | 验证命令/测试 | 状态 |
|---|---|---|---|---|
| M1 行人世界模型 | deterministic crowd config、density profile、spawn seed 与 chunk query API | 固定 seed 下 pedestrian roster / density / lane references 可复现；不依赖场景节点即可查询 | `tests/world/test_city_pedestrian_world_model.gd`、`tests/world/test_city_pedestrian_density_profile.gd` | todo |
| M2 Sidewalk / Crossing Lane Graph | 从 `road_graph` / `block` 派生 pedestrian lane graph，并保证 spawn grounding 与跨 chunk 连续 | sidewalk / crossing lane 拓扑连续；spawn anchors 不长在机动车路面上 | `tests/world/test_city_pedestrian_lane_graph.gd`、`tests/world/test_city_pedestrian_spawn_grounding.gd`、`tests/world/test_city_pedestrian_lane_graph_continuity.gd` | todo |
| M3 Ambient Crowd Tiering | Tier 0-2 表示、`MultiMesh` 中远景、近景 lightweight agents、identity continuity | Tier 1 batched representation 成立；tier 切换保留 `pedestrian_id`；Tier 1/2 数量不超预算 | `tests/world/test_city_pedestrian_lod_contract.gd`、`tests/world/test_city_pedestrian_batch_rendering.gd`、`tests/world/test_city_pedestrian_identity_continuity.gd` | todo |
| M4 Streaming Budget + Reactive Nearfield | promotion / demotion / despawn、near-player reaction、局部避让与 travel 稳定性 | `8` chunk travel 无 count leak；Tier 3 `<= 24`；玩家靠近/开火/爆炸可触发近场反应 | `tests/world/test_city_pedestrian_streaming_budget.gd`、`tests/world/test_city_pedestrian_reactive_behavior.gd`、`tests/e2e/test_city_pedestrian_travel_flow.gd` | todo |
| M5 红线收口与观测护栏 | crowd profile 拆项、overlay / minimap debug layer、fresh warm/first-visit profiling | `pedestrian_mode = lite` 下 warm / first-visit 都守住 `16.67ms/frame`；crowd 指标可观测 | `tests/e2e/test_city_pedestrian_performance_profile.gd`、`tests/world/test_city_pedestrian_debug_overlay.gd`、`tests/world/test_city_minimap_pedestrian_debug_layer.gd` | todo |

## 计划索引

- [v6-pedestrian-world-model.md](./v6-pedestrian-world-model.md)
- [v6-pedestrian-lane-graph.md](./v6-pedestrian-lane-graph.md)
- [v6-pedestrian-ambient-tiering.md](./v6-pedestrian-ambient-tiering.md)
- [v6-pedestrian-streaming-and-reactivity.md](./v6-pedestrian-streaming-and-reactivity.md)
- [v6-pedestrian-redline-guard.md](./v6-pedestrian-redline-guard.md)

## 追溯矩阵

| Req ID | v6 Plan | 单元/集成测试 | E2E / 验证命令 | 证据 | 状态 |
|---|---|---|---|---|---|
| REQ-0002-001 | `v6-pedestrian-world-model.md` | `tests/world/test_city_pedestrian_world_model.gd`、`tests/world/test_city_pedestrian_density_profile.gd` | `--script res://tests/world/test_city_pedestrian_world_model.gd` | 待实现 | todo |
| REQ-0002-002 | `v6-pedestrian-lane-graph.md` | `tests/world/test_city_pedestrian_lane_graph.gd`、`tests/world/test_city_pedestrian_lane_graph_continuity.gd`、`tests/world/test_city_pedestrian_spawn_grounding.gd` | `--script res://tests/world/test_city_pedestrian_lane_graph.gd` | 待实现 | todo |
| REQ-0002-003 | `v6-pedestrian-ambient-tiering.md` | `tests/world/test_city_pedestrian_lod_contract.gd`、`tests/world/test_city_pedestrian_batch_rendering.gd`、`tests/world/test_city_pedestrian_identity_continuity.gd` | `--script res://tests/world/test_city_pedestrian_lod_contract.gd` | 待实现 | todo |
| REQ-0002-004 | `v6-pedestrian-streaming-and-reactivity.md` | `tests/world/test_city_pedestrian_streaming_budget.gd`、`tests/world/test_city_pedestrian_page_cache.gd` | `--script res://tests/e2e/test_city_pedestrian_travel_flow.gd` | 待实现 | todo |
| REQ-0002-005 | `v6-pedestrian-streaming-and-reactivity.md` | `tests/world/test_city_pedestrian_reactive_behavior.gd`、`tests/world/test_city_pedestrian_projectile_reaction.gd` | `--script res://tests/e2e/test_city_pedestrian_travel_flow.gd` | 待实现 | todo |
| REQ-0002-006 | `v6-pedestrian-redline-guard.md` | `tests/world/test_city_pedestrian_debug_overlay.gd`、`tests/world/test_city_minimap_pedestrian_debug_layer.gd` | `--script res://tests/e2e/test_city_pedestrian_performance_profile.gd` | 待实现 | todo |
| REQ-0002-007 | `v6-pedestrian-redline-guard.md` | `tests/world/test_city_streaming_frame_guard.gd`、`tests/world/test_city_pedestrian_profile_stats.gd` | `--script res://tests/e2e/test_city_pedestrian_performance_profile.gd` | 待实现 | todo |

## ECN 索引

- 当前无新增 ECN。`v6` 以新 PRD 立项，暂不通过 `PRD-0001` 的局部变更来承载 pedestrian scope。

## 差异列表

- 当前项目已具备 `road_graph`、chunk streaming、terrain / road surface 性能底盘、小地图与基础 debug overlay，但街道仍缺乏可信人流。
- 当前没有与 `road_graph` 同源的 pedestrian lane graph，无法生成连续的 sidewalk / crossing crowd。
- 当前没有 crowd 的 tiered representation，若直接上完整 agent，极易重新打穿 `16.67ms/frame` 红线。
- 当前没有 crowd profile 指标、crowd minimap 调试层、crowd page/cache 命中证据，也没有“有人流时”的 E2E travel/profile 基线。
- 因此 `v6` 的主线不是“先摆人”，而是“先把 world model -> lane graph -> tiering -> streaming budget -> redline guard 一条链打通”。

# V6 Index

## 愿景

PRD 入口：[PRD-0002 Pedestrian Crowd Foundation](../prd/PRD-0002-pedestrian-crowd-foundation.md)

research 入口：[2026-03-12-open-world-pedestrian-crowd-performance-research.md](../research/2026-03-12-open-world-pedestrian-crowd-performance-research.md)

`v6` 的目标不是把 `godot_citys` 直接升级为“全城人人都是完整 NPC”的大而化之版本，而是把街道人群先做成一套受预算约束、与 `road_graph` 同源、能守住 `16.67ms/frame` 红线的分层 crowd system。只有少量靠近玩家且有交互价值的个体，才允许升级为更贵的 reactive agent；其余 tier 必须围绕 lane graph、batched rendering、streaming budget 和 profiling guard 设计。

## 里程碑

| 里程碑 | 范围 | DoD | 验证命令/测试 | 状态 |
|---|---|---|---|---|
| M1 行人世界模型 | deterministic crowd config、density profile、spawn seed 与 chunk query API | 固定 seed 下 pedestrian roster / density / lane references 可复现；不依赖场景节点即可查询 | `tests/world/test_city_pedestrian_world_model.gd`、`tests/world/test_city_pedestrian_density_profile.gd` | done |
| M2 Sidewalk / Crossing Lane Graph | 从 `road_graph` / `block` 派生 pedestrian lane graph，并保证 spawn grounding 与跨 chunk 连续 | sidewalk / crossing lane 拓扑连续；spawn anchors 不长在机动车路面上 | `tests/world/test_city_pedestrian_lane_graph.gd`、`tests/world/test_city_pedestrian_spawn_grounding.gd`、`tests/world/test_city_pedestrian_lane_graph_continuity.gd` | done |
| M3 Ambient Crowd Tiering | Tier 0-2 表示、`MultiMesh` 中远景、近景 lightweight agents、identity continuity | Tier 1 batched representation 成立；tier 切换保留 `pedestrian_id`；Tier 1/2 数量不超预算 | `tests/world/test_city_pedestrian_lod_contract.gd`、`tests/world/test_city_pedestrian_batch_rendering.gd`、`tests/world/test_city_pedestrian_identity_continuity.gd` | done |
| M4 Streaming Budget + Reactive Nearfield | promotion / demotion / despawn、near-player reaction、局部避让与 travel 稳定性 | `8` chunk travel 无 count leak；Tier 3 `<= 24`；玩家靠近/开火/爆炸可触发近场反应 | `tests/world/test_city_pedestrian_streaming_budget.gd`、`tests/world/test_city_pedestrian_page_cache.gd`、`tests/world/test_city_pedestrian_reactive_behavior.gd`、`tests/world/test_city_pedestrian_projectile_reaction.gd`、`tests/e2e/test_city_pedestrian_travel_flow.gd` | done |
| M5 红线收口与观测护栏 | crowd profile 拆项、overlay / minimap debug layer、全局 crowd/FPS 调试开关、fresh warm/first-visit profiling | `pedestrian_mode = lite` 下 warm / first-visit 都守住 `16.67ms/frame`；crowd 指标可观测；`小键盘 *` / `小键盘 -` 调试开关成立 | `tests/e2e/test_city_pedestrian_performance_profile.gd`、`tests/world/test_city_pedestrian_debug_overlay.gd`、`tests/world/test_city_fps_overlay_toggle.gd`、`tests/world/test_city_minimap_pedestrian_debug_layer.gd` | done |

## 计划索引

- [v6-pedestrian-world-model.md](./v6-pedestrian-world-model.md)
- [v6-pedestrian-lane-graph.md](./v6-pedestrian-lane-graph.md)
- [v6-pedestrian-ambient-tiering.md](./v6-pedestrian-ambient-tiering.md)
- [v6-pedestrian-streaming-and-reactivity.md](./v6-pedestrian-streaming-and-reactivity.md)
- [v6-pedestrian-redline-guard.md](./v6-pedestrian-redline-guard.md)

## 追溯矩阵

| Req ID | v6 Plan | 单元/集成测试 | E2E / 验证命令 | 证据 | 状态 |
|---|---|---|---|---|---|
| REQ-0002-001 | `v6-pedestrian-world-model.md` | `tests/world/test_city_pedestrian_world_model.gd`、`tests/world/test_city_pedestrian_density_profile.gd` | `--script res://tests/world/test_city_pedestrian_world_model.gd` | 2026-03-12 本地 headless `PASS`，已验证 deterministic query、density profile 与 lane references 可复现 | done |
| REQ-0002-002 | `v6-pedestrian-lane-graph.md` | `tests/world/test_city_pedestrian_lane_graph.gd`、`tests/world/test_city_pedestrian_lane_graph_continuity.gd`、`tests/world/test_city_pedestrian_spawn_grounding.gd` | `--script res://tests/world/test_city_pedestrian_lane_graph.gd` | 2026-03-12 本地 headless `PASS`，已验证 sidewalk / crossing lane graph 连续，spawn anchors 不落在车行道内部 | done |
| REQ-0002-003 | `v6-pedestrian-ambient-tiering.md` | `tests/world/test_city_pedestrian_lod_contract.gd`、`tests/world/test_city_pedestrian_batch_rendering.gd`、`tests/world/test_city_pedestrian_identity_continuity.gd` | `--script res://tests/world/test_city_pedestrian_lod_contract.gd` | 2026-03-12 本地 headless `PASS`，已验证 Tier 0-2、Tier 1 `MultiMesh` 合批、近景 lightweight agents 与 identity continuity | done |
| REQ-0002-004 | `v6-pedestrian-streaming-and-reactivity.md` | `tests/world/test_city_pedestrian_streaming_budget.gd`、`tests/world/test_city_pedestrian_page_cache.gd` | `--script res://tests/e2e/test_city_pedestrian_travel_flow.gd` | 2026-03-12 本地 headless `PASS`，已验证 `8` chunk travel 无 count leak、page cache 命中有效、duplicate page load 保持为 `0` | done |
| REQ-0002-005 | `v6-pedestrian-streaming-and-reactivity.md` | `tests/world/test_city_pedestrian_reactive_behavior.gd`、`tests/world/test_city_pedestrian_projectile_reaction.gd` | `--script res://tests/e2e/test_city_pedestrian_travel_flow.gd` | 2026-03-12 本地 headless `PASS`，已验证玩家靠近、开火、子弹近掠与爆炸都可触发 Tier 3 reactive nearfield，且 Tier 3 持续 `<= 24` | done |
| REQ-0002-006 | `v6-pedestrian-redline-guard.md` | `tests/world/test_city_pedestrian_debug_overlay.gd`、`tests/world/test_city_minimap_pedestrian_debug_layer.gd`、`tests/world/test_city_fps_overlay_toggle.gd` | `--script res://tests/e2e/test_city_pedestrian_performance_profile.gd` | 2026-03-12 本地 headless fresh `PASS`；overlay 默认折叠、minimap crowd debug layer 与 lane/density 同源、`小键盘 * / -` 调试开关成立；isolated pedestrian profile：warm `wall_frame_avg_usec = 15345`、first-visit `wall_frame_avg_usec = 14782` | done |
| REQ-0002-007 | `v6-pedestrian-redline-guard.md` | `tests/world/test_city_streaming_frame_guard.gd`、`tests/world/test_city_pedestrian_profile_stats.gd` | `--script res://tests/e2e/test_city_pedestrian_performance_profile.gd`、`--script res://tests/e2e/test_city_runtime_performance_profile.gd` | 2026-03-12 本地 headless fresh `PASS`；crowd update/spawn/render commit 拆项已落盘，isolated pedestrian profile：warm `15345`、first-visit `14782`，isolated runtime profile：warm `12272`，均守住 `16.67ms/frame` 红线 | done |

## ECN 索引

- 当前无新增 ECN。`v6` 以新 PRD 立项，暂不通过 `PRD-0001` 的局部变更来承载 pedestrian scope。

## 差异列表

- `v6` 已在 `pedestrian_mode = lite` 下完成 fresh isolated 红线验收：`test_city_pedestrian_performance_profile.gd` warm `wall_frame_avg_usec = 15345`、first-visit `wall_frame_avg_usec = 14782`；`test_city_runtime_performance_profile.gd` warm `wall_frame_avg_usec = 12272`。
- M5 已把 crowd profile 拆项、overlay / minimap debug layer、`小键盘 *` 行人显隐与 `小键盘 -` FPS overlay 调试开关全部接入自动化回归。
- 当前默认折叠态不会再每帧支付 full HUD/debug snapshot rebuild；profiling 命令也必须继续保持 isolated 单独执行，避免 wall-clock 被串跑噪声污染。
- 现阶段仍禁止把 reactive nearfield 扩展成全城高成本 agent；后续任何 pedestrian 新功能都必须继续服从预算、流式加载连续性和运行期性能。

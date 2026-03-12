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
| M6 运行期贴地与暴力响应 | runtime ground conformity、projectile / grenade casualty、周边 flee、重新验红线 | active pedestrian 与真实 chunk 地表一致；direct victim 会死亡；周边 pedestrian 会逃散；fresh profiling 不打穿 `16.67ms/frame` | `tests/world/test_city_pedestrian_runtime_grounding.gd`、`tests/world/test_city_pedestrian_projectile_kill.gd`、`tests/world/test_city_pedestrian_grenade_kill_and_flee.gd`、`tests/e2e/test_city_pedestrian_combat_flow.gd`、`tests/e2e/test_city_pedestrian_performance_profile.gd`、`tests/e2e/test_city_runtime_performance_profile.gd` | done |

## 计划索引

- [v6-pedestrian-world-model.md](./v6-pedestrian-world-model.md)
- [v6-pedestrian-lane-graph.md](./v6-pedestrian-lane-graph.md)
- [v6-pedestrian-ambient-tiering.md](./v6-pedestrian-ambient-tiering.md)
- [v6-pedestrian-streaming-and-reactivity.md](./v6-pedestrian-streaming-and-reactivity.md)
- [v6-pedestrian-redline-guard.md](./v6-pedestrian-redline-guard.md)
- [v6-pedestrian-runtime-grounding.md](./v6-pedestrian-runtime-grounding.md)
- [v6-pedestrian-civilian-casualty-response.md](./v6-pedestrian-civilian-casualty-response.md)

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
| REQ-0002-008 | `v6-pedestrian-runtime-grounding.md` | `tests/world/test_city_pedestrian_runtime_grounding.gd`、`tests/world/test_city_pedestrian_spawn_grounding.gd` | `--script res://tests/world/test_city_pedestrian_runtime_grounding.gd`、`--script res://tests/e2e/test_city_pedestrian_performance_profile.gd`、`--script res://tests/e2e/test_city_runtime_performance_profile.gd` | 2026-03-13 本地 headless fresh `PASS`；`test_city_pedestrian_spawn_grounding.gd` 与 `test_city_pedestrian_runtime_grounding.gd` 均通过，runtime grounding 输出 `roadbed surface_delta_m = 0.229713`、`ground_error_m = 4.35e-7`、`slope expected_height_delta_m = 0.140779`、`peak_ground_error_m = 1.14e-7`；isolated profile 继续守线：pedestrian warm `15518`、first-visit `14214`、runtime warm `15765` | done |
| REQ-0002-009 | `v6-pedestrian-civilian-casualty-response.md` | `tests/world/test_city_pedestrian_projectile_kill.gd`、`tests/world/test_city_pedestrian_grenade_kill_and_flee.gd` | `--script res://tests/e2e/test_city_pedestrian_combat_flow.gd`、`--script res://tests/e2e/test_city_pedestrian_performance_profile.gd`、`--script res://tests/e2e/test_city_runtime_performance_profile.gd` | 2026-03-13 本地 headless fresh `PASS`；`test_city_pedestrian_projectile_kill.gd`、`test_city_pedestrian_grenade_kill_and_flee.gd`、`test_city_pedestrian_combat_flow.gd` 通过，direct-hit victim 会进入 `life_state = dead` 并从 live crowd 移除，grenade lethal radius `4.0m` 会杀伤目标、threat radius `12.0m` 会把周边 civilian 推入 `flee`，`test_city_pedestrian_travel_flow.gd` 回归仍通过且 Tier 3 不泄漏；isolated profile 继续守线：pedestrian warm `15518`、first-visit `14214`、runtime warm `15765` | done |

## ECN 索引

- [ECN-0009-pedestrian-grounding-and-civilian-harm-response.md](../ecn/ECN-0009-pedestrian-grounding-and-civilian-harm-response.md)：把“运行期贴地一致性”和“玩家暴力触发的 civilian casualty / flee response”追加为 `v6` 的 M6，修正 M2/M4 之后仍存在的产品级缺口。

## 差异列表

- 2026-03-13 手玩验收 / 用户反馈确认：当前 pedestrian 仍存在两项产品级差异，分别是“运行期未稳定贴合真实 chunk 地表”和“玩家暴力只触发 reaction、不结算死亡与周边逃散”。这两项已通过 `ECN-0009` 开出 `M6`，在 `M6` 完成前，`v6` 不再视为完全收口。
- 2026-03-13 `M6` 已完成 fresh 收口：runtime grounding / projectile kill / grenade kill+flee / combat flow / travel regression 全部 headless `PASS`，并且 isolated pedestrian/runtime profile 仍守住 `16.67ms/frame` 红线。
- `v6` 已在 `pedestrian_mode = lite` 下完成 fresh isolated 红线验收：`test_city_pedestrian_performance_profile.gd` warm `wall_frame_avg_usec = 15345`、first-visit `wall_frame_avg_usec = 14782`；`test_city_runtime_performance_profile.gd` warm `wall_frame_avg_usec = 12272`。
- `M6` 为避免 runtime grounding 重复重建同一 chunk 的 road layout，引入了带 `Mutex` 的 deterministic road-layout cache；2026-03-13 fresh isolated profile：pedestrian warm `wall_frame_avg_usec = 15518`、first-visit `14214`，runtime warm `15765`，仍低于 `16667`。
- M5 已把 crowd profile 拆项、overlay / minimap debug layer、`小键盘 *` 行人显隐与 `小键盘 -` FPS overlay 调试开关全部接入自动化回归。
- 当前默认折叠态不会再每帧支付 full HUD/debug snapshot rebuild；profiling 命令也必须继续保持 isolated 单独执行，避免 wall-clock 被串跑噪声污染。
- 现阶段仍禁止把 reactive nearfield 扩展成全城高成本 agent；后续任何 pedestrian 新功能都必须继续服从预算、流式加载连续性和运行期性能。

# V6 Pedestrian Streaming And Reactivity

## Goal

把 crowd 正式接入现有 chunk streaming 生命周期，并把“只有玩家附近极少数行人才具备较高保真反应能力”这条边界落成可验证的系统行为；在 `M7` 之后，violent audible witness response 允许扩展到 `500m` 内触发 `panic / flee`，但仍不得演化成全城常驻高成本 AI。

## PRD Trace

- REQ-0002-004
- REQ-0002-005

## Scope

做什么：

- 建立 pedestrian page / cache 或等价 streaming state
- 建立 Tier 2 / Tier 3 的 promotion、demotion、despawn 规则
- 让玩家靠近、开火、投掷爆炸物或高速掠过时触发有限 reactive behavior
- 将 full-fidelity reactive behavior 严格限制在近场小数量集合；枪声 / 爆炸的 `500m` audible witness response 只能复用现有 budgeted runtime，不能演化成全图级 panic propagation

不做什么：

- 不做全城 panic propagation
- 不做 combat NPC
- 不做所有 pedestrian 的 `NavigationAgent3D + avoidance`

## Acceptance

1. 玩家跨越至少 `8` 个 chunk 的 travel E2E 中，不允许出现 crowd count leak、重复加载同一 pedestrian page 或明显的 spawn storm。
2. Tier 3 reactive pedestrian 数量必须持续 `<= 24`，离开近场后会自动降回较低 tier。
3. 自动化测试必须证明：玩家靠近、开火、子弹近掠或爆炸发生时，近场 pedestrian 会切换到等待、让路、sidestep 或 panic/flee 等 reaction state。
4. 反作弊条款：不得通过“触发反应时直接销毁 pedestrian”或“只在测试里暂时关闭人流”来伪造 reactive 行为。

## Files

- Create: `city_game/world/pedestrians/streaming/CityPedestrianBudget.gd`
- Create: `city_game/world/pedestrians/streaming/CityPedestrianStreamer.gd`
- Create: `city_game/world/pedestrians/simulation/CityPedestrianReactiveAgent.gd`
- Create: `city_game/world/pedestrians/simulation/CityPedestrianReactionModel.gd`
- Modify: `city_game/scripts/CityPrototype.gd`
- Modify: `city_game/world/pedestrians/rendering/CityPedestrianCrowdRenderer.gd`
- Modify: `city_game/world/pedestrians/simulation/CityPedestrianState.gd`
- Modify: `city_game/world/pedestrians/simulation/CityPedestrianTierController.gd`
- Modify: `city_game/world/rendering/CityChunkRenderer.gd`
- Modify: `city_game/world/rendering/CityChunkScene.gd`
- Create: `tests/world/test_city_pedestrian_streaming_budget.gd`
- Create: `tests/world/test_city_pedestrian_page_cache.gd`
- Create: `tests/world/test_city_pedestrian_reactive_behavior.gd`
- Create: `tests/world/test_city_pedestrian_projectile_reaction.gd`
- Create: `tests/e2e/test_city_pedestrian_travel_flow.gd`

## Steps

1. 写失败测试（红）
   - `test_city_pedestrian_streaming_budget.gd` 断言 Tier 2 / Tier 3 预算上限与 travel 稳定性。
   - `test_city_pedestrian_reactive_behavior.gd` 与 `test_city_pedestrian_projectile_reaction.gd` 断言近场反应状态切换。
   - `test_city_pedestrian_travel_flow.gd` 断言跨 chunk travel 期间 crowd state 不泄漏。
2. 跑到红
   - 运行上述测试，预期 FAIL，原因是 crowd 仍未接入 streaming lifecycle，也没有 reactive behavior。
3. 实现（绿）
   - 建立 pedestrian streamer / budget / page cache。
   - 将 projectile / grenade / player proximity 事件接入 reaction model，只允许极小集合升级为 Tier 3。
4. 跑到绿
   - streaming budget、page cache、reactive behavior 与 travel E2E 全部 PASS。
5. 必要重构（仍绿）
   - 收敛 crowd event 接口，避免 combat 系统和 pedestrian 系统双向强耦合。
   - 确保 reaction state 在降级或 despawn 后不会残留脏状态。
6. E2E 测试
   - 以 travel + combat 混合场景跑一轮真实 crowd lifecycle，确认人流不会越跑越多，也不会被事件永久唤醒。

## Risks

- 如果 Tier 3 promotion 没有硬预算，reactive crowd 会很快从“少量近场反应”扩散成“全城 AI”。
- 如果 crowd streamer 和 chunk lifecycle 脱节，首访与回访都可能重新变成热路径。
- 如果 reaction model 直接依赖武器脚本细节，后续玩法扩展会让 pedestrian 系统非常脆弱。

## Result

- 已落地 `CityPedestrianBudget + CityPedestrianStreamer + CityPedestrianReactionModel + CityPedestrianReactiveAgent` 的分层运行时骨架，并由 `CityPedestrianTierController` 统一做 Tier 1/2/3 分配。
- `nearfield_budget = 96`，`tier3_budget = 24`，其中 Tier 3 继续只承载玩家近身、子弹近掠与最相关的 nearfield reactive set；`M7` 新增的枪声 / 爆炸 `500m` witness escape 也必须复用这套预算，而不是把半径内所有 pedestrian 升成常驻 agent。
- `CityPrototype.gd` 已把 projectile / grenade explosion 事件接到 `CityChunkRenderer -> CityPedestrianTierController`，避免 pedestrian 系统直接耦合武器脚本实现细节。
- `CityPedestrianStreamer.gd` 已提供 page/cache 生命周期，当前以 chunk page 为单位保证 cache hit 与 duplicate page load 可观测。
- identity continuity 契约在 M4 下仍成立，但“玩家贴近 pedestrian”现在会优先升为 Tier 3 reactive nearfield，而不再沿用 M3 的纯 Tier 2 接近逻辑。

## Verification

- `res://tests/world/test_city_pedestrian_streaming_budget.gd`
- `res://tests/world/test_city_pedestrian_page_cache.gd`
- `res://tests/world/test_city_pedestrian_reactive_behavior.gd`
- `res://tests/world/test_city_pedestrian_projectile_reaction.gd`
- `res://tests/e2e/test_city_pedestrian_travel_flow.gd`

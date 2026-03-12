# V6 Pedestrian Ambient Tiering

## Goal

把行人从“有无”问题推进到“如何以分层方式存在”问题，正式建立 Tier 0-2 的 pedestrian representation、render LOD 和 identity continuity。

## PRD Trace

- REQ-0002-003
- REQ-0002-004

## Scope

做什么：

- 建立 Tier 0 occupancy / reservation 层
- 建立 Tier 1 batched ambient visuals
- 建立 Tier 2 lightweight local agents
- 建立 tier promotion / demotion 时的 identity continuity
- 为 archetype / pose / phase 提供低成本变体接口

不做什么：

- 不在本计划里引入 Tier 3 reactive behavior
- 不在本计划里引入完整骨骼动画系统
- 不在本计划里做 crowd minimap 调试层

## Acceptance

1. 默认 `lite` 预设下，Tier 1 可见实例总数必须 `<= 768`，Tier 2 总数必须 `<= 96`。
2. 自动化测试必须证明 Tier 1 使用 `MultiMesh` 或等价 batched representation，而不是把每个行人实例化为独立节点树。
3. 自动化测试必须证明同一 pedestrian 在 Tier 1/2 升降级前后的 `pedestrian_id`、route signature 和 archetype signature 保持一致。
4. 反作弊条款：不得通过把 density 设为 `0`、把 Tier 1 全部隐藏、或让 Tier 2 不再移动来宣称 tiering 已完成。

## Files

- Create: `city_game/world/pedestrians/rendering/CityPedestrianArchetypeCatalog.gd`
- Create: `city_game/world/pedestrians/rendering/CityPedestrianCrowdBatch.gd`
- Create: `city_game/world/pedestrians/rendering/CityPedestrianCrowdRenderer.gd`
- Create: `city_game/world/pedestrians/simulation/CityPedestrianState.gd`
- Create: `city_game/world/pedestrians/simulation/CityPedestrianTierController.gd`
- Modify: `city_game/world/streaming/CityChunkStreamer.gd`
- Modify: `city_game/scripts/CityPrototype.gd`
- Create: `tests/world/test_city_pedestrian_lod_contract.gd`
- Create: `tests/world/test_city_pedestrian_batch_rendering.gd`
- Create: `tests/world/test_city_pedestrian_identity_continuity.gd`

## Steps

1. 写失败测试（红）
   - `test_city_pedestrian_lod_contract.gd` 断言 Tier 0-2 与默认预算存在。
   - `test_city_pedestrian_batch_rendering.gd` 断言 Tier 1 采用 batched representation。
   - `test_city_pedestrian_identity_continuity.gd` 断言 tier 升降级前后的 identity continuity。
2. 跑到红
   - 运行上述测试，预期 FAIL，原因是 crowd tiering 与 batch rendering 尚不存在。
3. 实现（绿）
   - 建立 occupancy 数据、Tier 1 `MultiMesh` 合批和 Tier 2 lightweight agents。
   - 引入 tier controller，确保同一 pedestrian 在不同表示之间共享稳定 ID 和 route progress。
4. 跑到绿
   - LOD contract、batch rendering 与 identity continuity 测试全部 PASS。
5. 必要重构（仍绿）
   - 收敛 archetype / pose / phase / color variation 的数据接口。
   - 将 crowd renderer 与 tier controller 解耦，避免渲染层偷偷持有世界真相。
6. E2E 测试
   - 在原型场景中验证玩家移动时，街道人群从远到近过渡自然，不出现明显“凭空换人”。

## Risks

- 如果 Tier 1 没有 batch 化，scene tree 和 transform 更新很快会成为新的热点。
- 如果 tier continuity 缺稳定 ID，玩家接近时会感到“远处的人被换掉了”，体验会和此前建筑轮廓问题类似。
- 如果 archetype 变化只做颜色随机而没有体量、姿态和相位差异，重复感仍会很强。

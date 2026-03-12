# V6 Pedestrian Lane Graph

## Goal

把现有 `road_graph` 和 `block` 数据扩展为一张连续的 pedestrian lane graph，让 sidewalk / crossing crowd 有稳定、可 streaming、可验证的骨架。

## PRD Trace

- REQ-0002-002
- REQ-0002-004

## Scope

做什么：

- 从 `road_graph`、道路宽度、路口和 block 边界派生 sidewalk lanes
- 在交叉口派生 crossing lanes、等待点和接驳点
- 提供按 chunk / rect 查询 pedestrian lane subgraph 的接口
- 输出与地形 / 道路缓冲区一致的 spawn grounding / clearance 数据

不做什么：

- 不在本计划里做完整 traffic signal 系统
- 不在本计划里做楼梯、天桥、地铁与室内 lane graph
- 不在本计划里实例化 crowd visuals

## Acceptance

1. 自动化测试必须证明：主要道路两侧存在与道路方向一致的 sidewalk lanes，路口存在 crossing connections，且跨 chunk 边界连续。
2. 自动化测试必须证明：pedestrian spawn anchors 与机动车道路面保持最小退距，只允许 crossing lanes 穿越路面。
3. 自动化测试必须证明：lane graph 查询结果来自共享世界数据，而不是 per-chunk 随机散点或局部补丁。
4. 反作弊条款：不得保留“没有 lane graph，只在空地里随机摆人”作为主要 crowd 方案。

## Files

- Create: `city_game/world/pedestrians/model/CityPedestrianLaneGraph.gd`
- Create: `city_game/world/pedestrians/generation/CityPedestrianLaneGraphBuilder.gd`
- Modify: `city_game/world/model/CityRoadGraph.gd`
- Modify: `city_game/world/model/CityBlockLayout.gd`
- Modify: `city_game/world/rendering/CityChunkGroundSampler.gd`
- Create: `tests/world/test_city_pedestrian_lane_graph.gd`
- Create: `tests/world/test_city_pedestrian_lane_graph_continuity.gd`
- Create: `tests/world/test_city_pedestrian_spawn_grounding.gd`

## Steps

1. 写失败测试（红）
   - `test_city_pedestrian_lane_graph.gd` 断言 lane graph 存在 sidewalk / crossing lane 类型。
   - `test_city_pedestrian_lane_graph_continuity.gd` 断言相邻 chunk 的 lane graph 连接连续。
   - `test_city_pedestrian_spawn_grounding.gd` 断言 spawn anchors 不长在机动车路面内部。
2. 跑到红
   - 运行上述测试，预期 FAIL，原因是 pedestrian lane graph 尚不存在。
3. 实现（绿）
   - 引入 lane graph builder，从 `road_graph` / `block` 数据派生 sidewalk / crossing。
   - 让 spawn anchors 使用与道路缓冲区和地形 grounding 同源的约束。
4. 跑到绿
   - lane graph、continuity 与 spawn grounding 测试全部 PASS。
5. 必要重构（仍绿）
   - 收敛 `lane_id`、`crossing_id`、`wait_point_id` 命名和查询接口。
   - 统一与 road clearance、ground height sample 的接口契约。
6. E2E 测试
   - 在后续 travel E2E 中验证 lane graph 可跨越多个 chunk 连续使用。

## Risks

- 如果 lane graph 和 road graph 不是同源派生，最终会重新出现“道路看着连续，人却沿另一套随机路径走”的割裂感。
- 如果 spawn grounding 没和道路缓冲区共享规则，建筑、路缘和斜坡附近很容易再次出现长在路面上的人。
- 如果 crossing 只做几何连线而不做等待点，后续 reactive 行为很难自然扩展。

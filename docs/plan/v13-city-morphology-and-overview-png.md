# V13 City Morphology and Overview PNG

## Goal

把整城生成从“`district grid + collector everywhere + overlay` 的密网世界”改成“多中心连续道路骨架 + 沿街 building layout + deterministic overview PNG 验收链”。

## PRD Trace

- REQ-0001-002
- REQ-0001-004
- REQ-0001-006
- REQ-0001-013

## Scope

做什么：

- 让 `CityReferenceRoadGraphBuilder` 正式接管 world road graph 生成，不再把 `district edge + collector` 当主路网。
- 引入多中心 population / corridor field，让 road growth 自然形成主城区、卫星城和连接干道。
- 让 `CityChunkProfileBuilder` 把 building 候选改为 streetfront-first。
- 新增 deterministic overview exporter，输出 `PNG + metadata` 供人工验收。
- 更新 PRD/ECN/测试，让“像不像一座城”成为正式 contract，而不是聊天里的补充意见。

不做什么：

- 不在本轮重构 `block_layout / place_index / address grammar`。
- 不在本轮追求最终土地利用模拟、parcel 精准切分或最终美术地图风格。
- 不为过图而引入与当前 `road_graph` 脱钩的静态示意图。

## Acceptance

- 固定 seed `424242` 下，`road_graph` 必须满足：
  - `population_center_count >= 3`
  - `corridor_count >= 2`
  - `edge_count < 5000`
  - 反作弊条款：不得继续保留 world-filling `district edge + collector` lattice 作为正式可见道路主骨架
- 固定 seed `424242` 下，中心窗口与至少两个卫星窗口都能查询到正式 `local / arterial / expressway` 道路。
- chunk building layout 必须输出 streetfront 统计，且 streetfront 驱动的 building 数量占比达到正式阈值。
- headless overview exporter 必须稳定输出 `PNG + metadata` 到固定路径，metadata 必须包含：
  - `road_edge_count`
  - `population_center_count`
  - `corridor_count`
  - `building_footprint_count`
  - `road_pixel_count`
  - `building_pixel_count`
- 反作弊条款：PNG 必须直接来源于当前世界数据，不能写死参考图、不能只截中心 `5x5` chunk、不能只画道路不画建筑。

## Files

- Modify: `docs/prd/PRD-0001-large-city-foundation.md`
- Create: `docs/ecn/ECN-0019-city-morphology-and-png-acceptance.md`
- Create: `docs/plans/2026-03-15-v13-city-morphology-design.md`
- Create: `docs/plan/v13-index.md`
- Modify: `city_game/world/generation/CityWorldGenerator.gd`
- Modify: `city_game/world/generation/CityReferenceRoadGraphBuilder.gd`
- Modify: `city_game/world/generation/CityRoadGraphCache.gd`
- Modify: `city_game/world/rendering/CityChunkProfileBuilder.gd`
- Create: overview PNG exporter implementation / test files
- Modify: `tests/world/test_city_world_generator.gd`
- Modify: `tests/world/test_city_reference_road_graph.gd`
- Modify: `tests/world/test_city_building_collision.gd`
- Create: morphology / PNG exporter tests

## Steps

1. 写失败测试（红）
2. 运行到红：
   - `res://tests/world/test_city_world_generator.gd`
   - `res://tests/world/test_city_reference_road_graph.gd`
   - 新增 overview PNG exporter test
3. 实现（绿）：
   - world road graph 多中心接管
   - streetfront-first building candidate
   - PNG + metadata exporter
4. 运行到绿：
   - `res://tests/world/test_city_world_generator.gd`
   - `res://tests/world/test_city_reference_road_graph.gd`
   - `res://tests/world/test_city_building_collision.gd`
   - 新增 morphology / PNG exporter tests
5. 必要重构（仍绿）：
   - 清理旧的 dense-grid-only helper
   - bump road graph cache schema
6. E2E / 验收：
   - 串行跑相关 world tests
   - 生成 overview PNG 交给人工 review

## Risks

- 如果多中心 field 只做“多几个随机波峰”，仍可能长成另一种均匀噪声，而不是可辨识的主城/卫星城结构。
- 如果 building layout 仍主要靠 chunk 栅格筛选，即使 road graph 修好，PNG 里的建筑分布也会继续显得假。
- 如果 exporter 没有 sidecar metadata，后续容易再次回到“只看截图主观感觉”的验收方式。

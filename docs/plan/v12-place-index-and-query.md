# V12 Place Index and Query

## Goal

在 world generation 阶段产出正式 `place_index / place_query / route_target_index`，让 road/intersection/address/landmark 查询脱离 chunk 生命周期，并为地图、Task pin、导航和瞬移提供同源目标解析。

## PRD Trace

- REQ-0006-001
- REQ-0006-003
- REQ-0006-008

## Scope

做什么：

- 基于 `road_graph + block_layout + vehicle_query` 构建 `Place Index`
- 支持按 road name、intersection、landmark、full address 查询
- 缓存 `Place Index`
- 为 chunk metadata 暴露本地 place slice，但不把 query 逻辑降级到 chunk-local

不做什么：

- 不在本计划里完成 route solver
- 不在本计划里完成 map screen UI

## Acceptance

1. 自动化测试必须证明：`world_data` 暴露正式 `place_query` 或等价对象。
2. 自动化测试必须证明：`place_query` 能解析 road name、intersection name、landmark name 和 full address。
3. 自动化测试必须证明：chunk 卸载或地图未展开时，名字查询仍然有效。
4. 自动化测试必须证明：`place_index` 存在缓存命中路径，重复运行不会每次重建全量 place 数据。
5. 反作弊条款：不得通过 UI 层字符串查表、只支持少量硬编码 place、或把 query 限制在当前已加载 chunk 来宣称完成。

## Files

- Modify: `city_game/world/generation/CityWorldGenerator.gd`
- Create: `city_game/world/model/CityPlaceIndex.gd`
- Create: `city_game/world/model/CityPlaceQuery.gd`
- Create: `city_game/world/generation/CityPlaceIndexBuilder.gd`
- Create: `city_game/world/generation/CityPlaceIndexCache.gd`
- Modify: `city_game/world/rendering/CityChunkRenderer.gd`
- Modify: `city_game/world/rendering/CityChunkScene.gd`
- Create: `tests/world/test_city_place_query_resolution.gd`
- Create: `tests/world/test_city_place_index_cache.gd`
- Modify: `docs/plan/v12-index.md`

## Steps

1. 写失败测试（红）
   - query resolution、cache、chunk independence 三类测试先写。
2. 运行到红
   - 预期失败点是当前 `world_data` 没有正式 place query。
3. 实现（绿）
   - 新建 `Place Index` 数据模型、builder 和 cache。
   - 在 `CityWorldGenerator` 里把 `place_index/place_query` 接进 `world_data`。
   - 给 chunk renderer 暴露 local place slice，但只做展示，不做权威查询。
4. 运行到绿
   - 新增 query/cache tests 全绿。
5. 必要重构（仍绿）
   - `normalized_name`、tokenization、prefix lookup 独立成纯数据层。
6. E2E
   - 通过 map selection flow 或 debug search flow 验证“名字 -> 目标点”主链。

## Risks

- 如果把 canonical query 下放到 chunk runtime，地图与导航会再次依赖 streaming 时机。
- 如果 `Place Index` 不缓存，打开地图和 route query 会重复吃整张城市的数据建模成本。
- 如果 `routable_anchor` 和 `world_anchor` 不分开，任意地图点击与正式导航目标会互相污染。

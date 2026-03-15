# V12 Place Index and Query

## Goal

在 world generation 阶段产出正式 `place_index / place_query / route_target_index`，让 road/intersection/address/landmark 查询脱离 chunk 生命周期，并为地图、Task pin、导航和瞬移提供同源目标解析。

## PRD Trace

- Direct: REQ-0006-001
- Direct: REQ-0006-003
- Guard / Cache / Determinism: REQ-0006-008

## Dependencies

- 依赖 M1 已冻结 `street_cluster / address grammar / parcel-frontage-slot` 口径。
- 本计划完成前，M3-M5 不允许各自定义私有 `resolved_target` 或 UI-local lookup table。

## Contract Freeze

- `place_index` 的正式最小字段冻结为：`place_id`、`place_type`、`display_name`、`normalized_name`、`world_anchor`、`routable_anchor`、`district_id`、`search_tokens`、`source_version`。
- `resolved_target` 的正式最小字段冻结为：`source_kind`、`source_query`、`place_id`（可空） 、`raw_world_anchor`（可空） 、`world_anchor`、`routable_anchor`、`selection_mode`、`source_version`。
- `route_target_index` 是 world-level 目标解析层，不允许退回到 chunk mount 现场临时反查。
- `place_index` 的磁盘缓存路径冻结为 `user://cache/world/place_index/place_index_<world_signature>.bin`；cache key 必须显式包含 world signature / schema version。
- `CityChunkRenderer` 只允许消费 `place_index` 切片做展示，不允许成为权威 query source。

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

1. 自动化测试必须证明：`world_data` 暴露正式 `place_index / place_query / route_target_index` 或等价对象，而不是只有 minimap 绘制快照。
2. 自动化测试必须证明：`place_query` 能解析 road name、intersection name、landmark name 和 full address。
3. 自动化测试必须证明：`resolved_target` 会同时给出 `world_anchor` 与 `routable_anchor`，且 `source_kind / selection_mode / place_id` 规则稳定。
4. 自动化测试必须证明：chunk 卸载、地图未展开或当前 chunk 未激活时，名字查询仍然有效。
5. 自动化测试必须证明：`place_index` 存在缓存命中路径，重复运行不会每次重建全量 place 数据，且缓存路径/key 按冻结口径落在 `user://cache/world/place_index/`。
6. 反作弊条款：不得通过 UI 层字符串查表、只支持少量硬编码 place、或把 query 限制在当前已加载 chunk 来宣称完成。

## Files

- Modify: `city_game/world/generation/CityWorldGenerator.gd`
- Create: `city_game/world/model/CityPlaceIndex.gd`
- Create: `city_game/world/model/CityPlaceQuery.gd`
- Create: `city_game/world/model/CityResolvedTarget.gd`
- Create: `city_game/world/generation/CityPlaceIndexBuilder.gd`
- Create: `city_game/world/generation/CityPlaceIndexCache.gd`
- Modify: `city_game/world/rendering/CityChunkRenderer.gd`
- Modify: `city_game/world/rendering/CityChunkScene.gd`
- Create: `tests/world/test_city_place_query_resolution.gd`
- Create: `tests/world/test_city_resolved_target_contract.gd`
- Create: `tests/world/test_city_place_index_cache.gd`
- Modify: `docs/plan/v12-index.md`

## Steps

1. 写失败测试（红）
   - `query resolution / resolved_target contract / cache / chunk independence` 四类测试先写。
2. 运行到红
   - 预期失败点是当前 `world_data` 没有正式 place query。
3. 实现（绿）
   - 新建 `Place Index` 数据模型、builder 和 cache。
   - 在 `CityWorldGenerator` 里把 `place_index/place_query/route_target_index` 接进 `world_data`。
   - 把 `resolved_target` contract 独立出来，供 map / route / fast travel / autodrive 共用。
   - 给 chunk renderer 暴露 local place slice，但只做展示，不做权威查询。
4. 运行到绿
   - 新增 query/cache tests 全绿。
5. 必要重构（仍绿）
   - `normalized_name`、tokenization、prefix lookup 独立成纯数据层。
6. E2E
   - 通过 map selection flow 或 debug search flow 验证“名字/地址 -> resolved_target -> 目标点”主链。

## Risks

- 如果把 canonical query 下放到 chunk runtime，地图与导航会再次依赖 streaming 时机。
- 如果 `Place Index` 不缓存，打开地图和 route query 会重复吃整张城市的数据建模成本。
- 如果 `routable_anchor` 和 `world_anchor` 不分开，任意地图点击与正式导航目标会互相污染。

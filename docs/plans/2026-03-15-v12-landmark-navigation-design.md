# 2026-03-15 V12 Landmark Navigation Design

## Context

当前仓库已经有：

- shared `road_graph`
- `vehicle lane graph`
- `intersection turn contract`
- minimap 投影
- chunk streaming / page cache

但还没有：

- 正式 `Place Index`
- 正式地址系统
- lane-based route planner
- 全屏地图
- Task pin overlay contract
- 同源的 HUD / teleport / auto-drive consumer

本地盘点基线：

- `31,860` roads
- `10,621` intersections
- `7,640` current unique display names
- `89,679` vehicle lanes
- `300,304` blocks
- `1,201,216` parcels

## Option A：chunk mount 时临时起名、临时求路

做法：

- 在 `CityChunkRenderer` 或 `CityChunkScene` 里按当前活跃 chunk 临时生成 road/building 名字
- 玩家点地图时，从当前 visible data 反查最近目标并临时求路

优点：

- 初期改动面小
- 看起来最像“先做个能跑的版本”

缺点：

- chunk 卸载后名字失效
- 搜索、Task pin、HUD、teleport、auto-drive 无法共享同一份目标解析
- 会把地图系统重新做成 UI 拼装层
- 与缓存、deterministic、地址稳定性目标冲突

结论：

- 不推荐。它会把 v12 变成一堆临时 consumer，而不是正式世界资产。

## Option B：全局 `Place Index` + `Route Contract` + 多消费者

做法：

- 在 `CityWorldGenerator` 完成 `road_graph + block_layout + vehicle_query` 后，生成一份全局 `place_index`
- place 至少覆盖 `road_cluster / intersection / addressable_building / landmark / task_pin / arbitrary_map_point`
- route planner 建在 `vehicle lane graph + intersection turn contract` 上
- minimap、全屏地图、HUD、teleport、auto-drive 都消费同一份 route result

优点：

- 与现有 shared graph / cache / streaming 架构一致
- 名字查询不会随 chunk 生命周期失效
- 所有 consumer 都能复用同一份目标与路线语义
- 能天然支持后续 Task 系统、替代路线、POI 筛选

缺点：

- 前期设计量和测试量更大
- 需要把 `parcel/frontage slot` 这层世界数据补硬

结论：

- 推荐方案。这是唯一同时满足 GTA 式产品语义、可扩展性和仓库现有架构纪律的路径。

## Option C：外置 GIS/数据库式服务层

做法：

- 把地址、检索、路线求解做成半独立服务或重数据库层

优点：

- 理论上可扩展性强

缺点：

- 远超当前项目阶段
- 增加非必要复杂度
- 与仓库“一切先在本地 deterministic runtime 内闭环”的现实不符

结论：

- 当前不取。

## Recommended Design

### 1. 世界数据层

- 新增 `CityPlaceIndex.gd`
- 新增 `CityPlaceQuery.gd`
- 新增 `CityPlaceIndexBuilder.gd`
- 新增 `CityAddressGrammar.gd`
- 新增 `CityStreetClusterBuilder.gd`

数据流：

`road_graph + block_layout + vehicle_query -> street clustering -> address slot assignment -> landmark assignment -> place_index -> cache`

### 2. 路线层

- 新增 `CityRoutePlanner.gd`
- 新增 `CityRouteContract.gd`
- 逐步让 `CityChunkNavRuntime` 从 chunk-Manhattan 迁移到 lane-based route result

route result 最低字段：

- `origin_place`
- `destination_place`
- `snapped_origin`
- `snapped_destination`
- `polyline`
- `steps`
- `maneuvers`
- `distance_m`
- `estimated_time_s`
- `reroute_generation`

### 3. 消费层

- minimap：只负责 route overlay
- full map：负责 pause、选点、图钉、legend、destination select
- HUD：负责短指令与剩余距离
- teleport：消费 resolved target
- auto-drive：消费 route steps，输出车辆控制

### 4. 地址与命名规则

默认假设：

- 名字风格：完全虚构，但沿用美式英语街名与地址语法
- 路名对象：按 `street cluster` 命名
- 建筑对象：按 `parcel/frontage slot` 生成地址；只有少量 `landmark` 有 proper name

门牌规则：

- 一个交叉口块面一段百位
- 左右奇偶分离
- block 内 frontage slot 递增
- 展示样例：`1120 Jefferson Road`

### 5. 数量级决策

- canonical street cluster：目标 `6,000 +/- 1,000`
- AI road-name root pool：至少 `11,000` 到 `13,000`
- landmark proper-name pool：首轮建议 `3,000` 到 `5,000`
- addressable building：默认覆盖全部 `parcel/frontage slot`，但 proper-name landmark 只占小比例

## Error Handling

- 搜索命中多个结果时，优先返回 best match + 候选列表，不做静默随机跳转
- off-road 点击地图时，区分 `teleport_raw_point` 和 `navigate_nearest_routable_point`
- route 不可达时，返回正式错误结果，不画假线
- chunk 未加载时也必须能查名和求路，因为它们消费的是全局 place index / route graph

## Testing Direction

- deterministic world counts
- street cluster stability
- address grammar parity / numbering
- place query resolution
- lane-based route contract
- reroute
- minimap overlay consumer
- `M` 全屏地图 pause/select flow
- pin overlay
- fast travel
- auto-drive
- 既有性能三件套

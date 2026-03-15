# ECN-0019: City Morphology and PNG Acceptance

## 基本信息

- **ECN 编号**：ECN-0019
- **关联 PRD**：PRD-0001
- **关联 Req ID**：REQ-0001-002、REQ-0001-004、REQ-0001-006、新增 REQ-0001-013
- **发现阶段**：`v12` 完成后的全图人工巡检
- **日期**：2026-03-15

## 变更原因

当前主线的世界级 2D 形态已经明显偏离参考项目与此前 `v3 / ECN-0006` 锁定的目标：

1. `CityWorldGenerator.gd` 仍先构造整城 `district edge + collector` 方格主骨架，再叠加 `CityReferenceRoadGraphBuilder` 的 overlay，结果不是“参考式连续道路图接管世界”，而是“方格主网 + 自然感补丁”。
2. `CityChunkProfileBuilder.gd` 的建筑候选仍主要来自 chunk 内规则栅格扫描，只用“离路多远”做打分，没有把沿街 frontage 作为正式上游；这会把建筑布局继续推向均匀噪声，而不是街区附着。
3. 现有测试主要验证连续性、语义 contract 与性能红线，但缺少“整张世界图是否仍然像城市”的世界级证据，导致项目可以在自动化全绿的前提下，视觉上退化成一张密网。

这说明当前验收口径缺了一个关键层：**世界级 morphology 证据**。`v13` 必须把“主城区 + 卫星城 + 干道连接 + 沿街建筑布局 + 可重复 PNG 导出”正式收回到产品 contract 中。

## 变更内容

### 原设计

- world road graph 允许保留 `district edge + collector` 作为主骨架，只要求再补上非正交连续 overlay。
- chunk 建筑布局允许继续使用 chunk-local 候选格点，只要避开路面即可。
- 地图 / 全图巡检默认只依赖运行时 UI 与零散 world tests，没有 deterministic PNG 总览验收链。

### 新设计

- `v13` 把道路生成改回“多中心密度场驱动的连续道路生长”为主线：
  - `district graph` 继续作为世界分块/索引元数据存在；
  - 但整城可见道路的正式来源必须是多中心 growth graph，而不是全域 district lattice。
- `v13` 明确要求城市总体形态具备：
  - 至少 1 个主城区；
  - 至少 2 个卫星城/次中心；
  - 由主干连接走廊形成的可辨认连接关系；
  - 大面积非建成空白区，而不是全域均匀铺路。
- `v13` 的 building layout 必须显式引入沿街候选与 frontage 取向统计，不能继续只靠 chunk 内独立打点。
- `v13` 当前阶段补充一个硬约束：
  - `no-road chunk => no-building`，不得再在无路区域伪造 fallback infill 建筑；
  - 导航点选如果点在可见城市区附近，必须能吸附到真实 driving lane 并产出正式 route contract。
- 新增 deterministic 全图导出链：
  - headless 输出当前 seed 的世界级 PNG；
  - 同时输出 sidecar metadata（JSON 或等价结构）；
  - PNG 必须直接来源于当前 `road_graph + building layout`，不能是静态参考图或手工资产。

## 影响范围

- 受影响的 Req ID：
  - REQ-0001-002：城市骨架生成
  - REQ-0001-004：分块渲染降级与建筑布局
  - REQ-0001-006：运行时观测与证据输出
  - 新增 REQ-0001-013：城市总体形态与 PNG 验收输出
- 受影响的 vN 计划：
  - 新增 `docs/plan/v13-index.md`
  - 新增 `docs/plan/v13-city-morphology-and-overview-png.md`
  - 新增 `docs/plans/2026-03-15-v13-city-morphology-design.md`
- 受影响的测试：
  - `tests/world/test_city_world_generator.gd`
  - `tests/world/test_city_reference_road_graph.gd`
  - `tests/world/test_city_streetfront_building_layout.gd`
  - 新增 morphology / streetfront / PNG exporter 验证
  - `tests/world/test_city_building_collision.gd`
  - `tests/world/test_city_map_destination_contract.gd`
- 受影响的代码文件：
  - `city_game/world/generation/CityWorldGenerator.gd`
  - `city_game/world/generation/CityReferenceRoadGraphBuilder.gd`
  - `city_game/world/generation/CityRoadGraphCache.gd`
  - `city_game/world/rendering/CityChunkProfileBuilder.gd`
  - `city_game/world/generation/CityPlaceIndexBuilder.gd`
  - `city_game/world/vehicles/generation/CityVehicleWorldBuilder.gd`
  - 新增 PNG overview exporter 相关文件
  - `city_game/ui/CityMapScreen.gd`（如需默认聚焦有效城市范围）

## 处置方式

- [x] PRD 已同步更新（标注 ECN-0019）
- [x] `v13` 计划已建立
- [ ] 追溯矩阵已同步更新
- [ ] 相关测试已同步更新

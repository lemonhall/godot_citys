# ECN-0018: Road Semantic Runtime Uplift

## 基本信息

- **ECN 编号**：ECN-0018
- **关联 PRD**：PRD-0001
- **关联 Req ID**：REQ-0001-002、REQ-0001-004、REQ-0001-005、REQ-0001-006、REQ-0001-010、REQ-0001-011、新增 REQ-0001-012
- **发现阶段**：`v7` 参考仓库适配分析与规划阶段
- **日期**：2026-03-14

## 变更原因

对 `refs/godot-road-generator` 的通读结论很明确：它最值得借鉴的，不是 editor/node graph 形态，而是更完整的道路语义拆分方式，包括 road section contract、lane tagging、intersection ordered branches、edge offset 和 segment-local lazy generation 思路。

当前项目已经有成熟的 `shared road graph -> chunk road layout -> surface page / bridge mesh` 管线，并且 2026-03-14 fresh profiling 已证明这条链在 warm runtime 与 first-visit 冷路径上都守住了 `16.67ms/frame` 红线内的有效区间。此时如果直接移植参考项目的 `RoadManager / RoadSegment / RoadLane(Path3D)` 这套 runtime 节点体系，会同时破坏三件已经建立起来的硬资产：

1. `terrain overlay + surface page` 对普通地面道路的低成本表达；
2. `async prepare + page cache + chunk mount` 的 streaming hot path 边界；
3. 当前 warm / cold profiling 的红线余量。

因此，参考项目只能以“语义 contract 来源”的身份进入当前架构，不能以“运行时节点系统”的身份进入当前架构。

## 变更内容

### 原设计

- `v3` 和 `v4/v5` 已经把 shared `road_graph`、surface page、terrain overlay 与 bridge-only mesh 管线立起来，但道路语义主要仍集中在几何宽度、少量 template 字段和 chunk 侧局部推断上。
- 交叉口、lane schema、edge offsets、roadside attachment 等更细语义未被正式上游化。
- 现有 chunk road consumer 仍有机会在 layout / surface / bridge 侧重复写“几何猜测逻辑”。

### 新设计

- 新增 `REQ-0001-012`，把“道路语义契约与交叉口拓扑”正式纳入 PRD。
- `v7` 只引入 reference repo 的语义资产：
  - road section / cross-section semantics
  - intersection ordered branches / type / connection semantics
  - lane matching/tagging 的 contract 思路
  - edge curve / roadside offset contract
- `v7` 明确禁止引入 reference repo 的 runtime 资产：
  - `RoadManager / RoadContainer / RoadPoint / RoadSegment / RoadIntersection`
  - `RoadLane(Path3D)` / `RoadLaneAgent`
  - per-road / per-lane scene tree
  - per-segment `MeshInstance3D` / collision node 道路运行时
- `CityRoadGraph`、`CityReferenceRoadGraphBuilder`、`CityRoadLayoutBuilder`、`CityRoadMaskBuilder`、`CityRoadMeshBuilder` 需要升级为消费同一份 semantic contract。
- `v7` 完成时必须继续守住 fresh profiling 护栏，而不是只证明 contract 存在。

## 影响范围

- 受影响的 Req ID：
  - REQ-0001-002
  - REQ-0001-004
  - REQ-0001-005
  - REQ-0001-006
  - REQ-0001-010
  - REQ-0001-011
  - REQ-0001-012
- 受影响的 vN 计划：
  - `docs/plan/v7-index.md`
  - `docs/plan/v7-road-semantic-runtime-uplift.md`
  - `docs/plans/2026-03-14-road-generator-reference-adaptation-design.md`
- 受影响的测试：
  - `tests/world/test_city_road_semantic_contract.gd`
  - `tests/world/test_city_road_semantic_seed_stability.gd`
  - `tests/world/test_city_road_intersection_topology.gd`
  - `tests/world/test_city_road_intersection_branch_order.gd`
  - `tests/world/test_city_road_layout_semantic_takeover.gd`
  - `tests/world/test_city_road_runtime_node_budget.gd`
  - `tests/world/test_city_chunk_setup_profile_breakdown.gd`
  - `tests/e2e/test_city_runtime_performance_profile.gd`
  - `tests/e2e/test_city_first_visit_performance_profile.gd`
- 受影响的代码文件：
  - `city_game/world/generation/CityReferenceRoadGraphBuilder.gd`
  - `city_game/world/model/CityRoadGraph.gd`
  - `city_game/world/rendering/CityRoadTemplateCatalog.gd`
  - `city_game/world/rendering/CityRoadLayoutBuilder.gd`
  - `city_game/world/rendering/CityRoadMaskBuilder.gd`
  - `city_game/world/rendering/CityRoadMeshBuilder.gd`
  - `city_game/world/rendering/CityRoadSurfacePageProvider.gd`
  - `city_game/world/rendering/CityChunkProfileBuilder.gd`
  - `city_game/world/rendering/CityChunkRenderer.gd`

## 处置方式

- [x] PRD 已同步更新（标注 ECN-0018）
- [x] `v7` 计划已同步更新
- [x] 追溯矩阵已同步更新
- [ ] 相关测试已同步更新

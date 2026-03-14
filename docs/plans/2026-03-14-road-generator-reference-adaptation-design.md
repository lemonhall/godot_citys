# Road Semantic Runtime Uplift Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 把 `refs/godot-road-generator` 中真正有长期价值的道路语义与交叉口拓扑 contract 引入当前项目的共享道路管线，在不引入 runtime 节点膨胀的前提下，为 chunk road layout、road surface、bridge mesh、pedestrian lane graph 和未来 signage / vehicle 系统提供同源数据。

**Architecture:** 当前项目已经有 `CityReferenceRoadGraphBuilder -> CityRoadGraph -> CityRoadLayoutBuilder -> CityRoadMaskBuilder / CityRoadMeshBuilder -> CityRoadSurfacePageProvider / CityChunkRenderer` 的成熟分层。`v7` 只允许把参考项目里的 `section / lane / intersection semantics` 下沉为可查询数据 contract，并由现有 consumer 消费；明确禁止移植 `RoadManager / RoadSegment / RoadLane(Path3D)` 这类 node-driven runtime。

**Tech Stack:** Godot 4.x、GDScript、shared road graph、terrain overlay surface page、bridge mesh/collision pipeline、world/e2e profiling tests。

---

## 预判结论

可以借，但只能借“语义层”和“契约层”。

`godot-road-generator` 对当前项目最有价值的部分，不是它那套 editor/node graph 工作流，而是它把道路问题拆成了更清楚的语义层：道路横断面、lane tagging、交叉口分支排序、边界线/路缘线 offset、单段局部求解。这些能力如果下沉为 `road_graph` 上的 deterministic metadata，可以增强当前项目的 chunk 渲染、lane graph、signage 和未来 vehicle 系统，而且不会破坏现有 streaming/page/cache 架构。

不能直接搬的，是它那套 `RoadManager / RoadContainer / RoadPoint / RoadSegment / RoadIntersection / RoadLane` 组成的 runtime 节点体系。当前项目已经把普通道路表面压进 terrain overlay、page cache、async prepare 与 bridge-only mesh 分工里；如果再把道路重新拆回 per-road / per-lane scene tree、`Path3D` lane runtime 或 per-segment `MeshInstance3D`，warm path 和 first-visit 冷路径都会重新被打穿。

## 可借 / 不可借清单

| 参考能力 | 结论 | 在本项目中的正确落点 | 说明 |
|---|---|---|---|
| road section / cross-section semantics | 可借 | `CityRoadTemplateCatalog.gd`、`CityRoadGraph.gd` | 把 lane schema、shoulder、median、marking、edge offset 做成可查询 contract |
| intersection topology / ordered branches | 可借 | `CityReferenceRoadGraphBuilder.gd`、`CityRoadGraph.gd` | 把分支顺序、intersection type、连接语义显式化，替代纯 endpoint cluster 猜测 |
| lane matching / lane tags | 可借 | `CityRoadGraph.gd`、后续 lane graph consumer | 只保留语义 ID 和 transition contract，不引入 `RoadLane(Path3D)` |
| edge curve / roadside offset contract | 可借 | `CityRoadLayoutBuilder.gd`、`CityRoadMaskBuilder.gd`、`CityRoadMeshBuilder.gd` | 为路缘、装饰线、roadside props 留统一 contract |
| segment-local / lazy generation 思想 | 可借 | 当前 chunk layout / surface page / bridge mesh 链 | 可映射到现有缓存与分页，不必照搬实现 |
| `RoadManager` / `RoadContainer` / `RoadPoint` runtime 结构 | 不可借 | 禁止接入 | 会让运行时重新依赖 scene tree 节点膨胀 |
| `RoadLane(Path3D)` / `RoadLaneAgent` | 不可借 | 禁止接入 | 对当前 open-world runtime 来说成本过高 |
| per-segment `MeshInstance3D` / collision node 生成 | 不可借 | 禁止接入 | 与当前 terrain overlay + bridge-only mesh 分工冲突 |
| `auto_refresh` 式 transform 改动即全段 rebuild | 不可借 | 禁止接入 | 不符合 streaming / async prepare 契约 |
| `Terrain3D` connector、glTF export、demo scene 流程 | 不可借 | 不纳入 `v7` | 与当前项目边界不一致 |

## 现状基线与性能护栏

2026-03-14 fresh baseline 已证明：当前道路主链有语义升级空间，但没有任何余量可接受“节点化回退”。

- `tests/world/test_city_chunk_setup_profile_breakdown.gd`
  - `total_usec = 7238`
  - `road_overlay_usec = 1029`
  - `ground_usec = 1284`
- `tests/e2e/test_city_runtime_performance_profile.gd`
  - `wall_frame_avg_usec = 8973`
  - `streaming_mount_setup_avg_usec = 4394`
  - `update_streaming_avg_usec = 8547`
- `tests/e2e/test_city_first_visit_performance_profile.gd`
  - `wall_frame_avg_usec = 13972`
  - `streaming_mount_setup_avg_usec = 4838`
  - `update_streaming_avg_usec = 13219`

这组数据说明两件事：

1. 当前 warm runtime 已低于 `16.67ms/frame`，说明可以做“语义补强”；
2. first-visit 虽然仍在红线内，但头部空间有限，任何把道路重新节点化的设计都会直接吞掉这点余量。

因此，`v7` 的唯一正确方向是：**增强语义，不增加 runtime 形态复杂度。**

## 推荐接入面

### Task 1: 上游化道路语义契约

**Files:**
- Modify: `city_game/world/rendering/CityRoadTemplateCatalog.gd`
- Modify: `city_game/world/model/CityRoadGraph.gd`
- Modify: `city_game/world/generation/CityReferenceRoadGraphBuilder.gd`
- Test: `tests/world/test_city_road_semantic_contract.gd`
- Test: `tests/world/test_city_road_semantic_seed_stability.gd`

先把 `template_id`、directional lane schema、marking profile、edge/shoulder/median metadata 变成 shared road graph 的正式字段。contract 必须能脱离 scene node 查询，并在 fixed seed 下稳定。

### Task 2: 明确交叉口拓扑

**Files:**
- Modify: `city_game/world/model/CityRoadGraph.gd`
- Modify: `city_game/world/generation/CityReferenceRoadGraphBuilder.gd`
- Test: `tests/world/test_city_road_intersection_topology.gd`
- Test: `tests/world/test_city_road_intersection_branch_order.gd`

把 ordered branches、intersection type、branch connection semantics 写成正式 contract。目标是让交叉口不再主要依赖 endpoint cluster 的几何后处理来“猜”连接关系。

### Task 3: 让 chunk road pipeline 消费同源语义

**Files:**
- Modify: `city_game/world/rendering/CityRoadLayoutBuilder.gd`
- Modify: `city_game/world/rendering/CityRoadMaskBuilder.gd`
- Modify: `city_game/world/rendering/CityRoadMeshBuilder.gd`
- Modify: `city_game/world/rendering/CityChunkProfileBuilder.gd`
- Test: `tests/world/test_city_road_layout_semantic_takeover.gd`
- Test: `tests/world/test_city_bridge_deck_collision.gd`
- Test: `tests/world/test_city_shared_graph_road_takeover.gd`

`CityRoadLayoutBuilder`、road surface 和 bridge mesh 至少各有一条正式 consumer 链开始从 semantic contract 取数，而不是继续在 chunk 侧临时拼凑 lane/edge/inset 规则。

### Task 4: runtime 护栏与 profiling 复验

**Files:**
- Modify: `city_game/world/rendering/CityChunkRenderer.gd`
- Modify: `city_game/world/rendering/CityRoadSurfacePageProvider.gd`
- Test: `tests/world/test_city_road_runtime_node_budget.gd`
- Test: `tests/world/test_city_chunk_setup_profile_breakdown.gd`
- Test: `tests/e2e/test_city_runtime_performance_profile.gd`
- Test: `tests/e2e/test_city_first_visit_performance_profile.gd`

为 `v7` 加一条明确护栏：道路语义升级不得演化成 per-road / per-lane runtime node graph。fresh profiling 必须继续守住 warm / cold path 阈值，否则 `v7` 不允许标记完成。

## 设计裁决

`v7` 不是“把参考项目搬进来”，而是“把参考项目里真正值得继承的协议资产抽出来，嫁接到当前项目已经证明可跑的 streaming 道路底盘上”。

这意味着：

- 保留当前 `shared road graph -> chunk layout -> surface page / bridge mesh` 架构；
- 提升 `road_graph` 和 `intersection` 的语义密度；
- 让 chunk road consumer 停止重复发明 lane / branch / edge 推断逻辑；
- 用 profiling guard 明确禁止 runtime 节点回退。

如果执行时发现必须引入 `Path3D` lane tree、per-segment mesh scene graph 或 editor runtime 才能实现，那就说明方案已经偏离本设计，应直接判定为错误方向。

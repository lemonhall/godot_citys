# V7 Road Semantic Runtime Uplift

## Goal

把 `godot-road-generator` 中可复用的道路语义资产下沉到当前项目的 shared road pipeline，让 `road_graph`、chunk road layout、road surface、bridge mesh 与后续 lane graph / signage / vehicle 系统都能查询同一份 `section / lane / intersection` contract，同时继续守住 `16.67ms/frame` 的运行期红线。

## PRD Trace

- REQ-0001-002
- REQ-0001-004
- REQ-0001-005
- REQ-0001-006
- REQ-0001-010
- REQ-0001-011
- REQ-0001-012

## Scope

做什么：

- 为 `CityRoadTemplateCatalog` 和 `CityRoadGraph` 增加正式的道路语义字段，至少覆盖 `template_id`、directional lane schema、marking profile、shoulder / median / edge offset 或等价 metadata。
- 为 `CityReferenceRoadGraphBuilder` / `CityRoadGraph` 增加交叉口拓扑 contract，至少覆盖 ordered branches、intersection type、branch connection semantics。
- 让 `CityRoadLayoutBuilder`、`CityRoadMaskBuilder`、`CityRoadMeshBuilder`、`CityChunkProfileBuilder` 至少各有一条正式 consumer 链改为读取 semantic contract，而不是继续依赖 chunk 侧 ad-hoc 几何猜测。
- 建立 runtime guard，明确禁止 `v7` 把道路重新实现成 per-road / per-lane scene tree、`Path3D` lane runtime 或大量独立 road mesh。
- 重新跑 warm / first-visit / chunk setup profiling，证明语义升级没有打穿红线。

不做什么：

- 不移植 `RoadManager`、`RoadContainer`、`RoadPoint`、`RoadSegment`、`RoadIntersection`、`RoadLane` 这一套 reference runtime 节点体系。
- 不引入 `Path3D` lane runtime、`RoadLaneAgent`、per-road / per-lane scene tree。
- 不把当前普通地面道路从 terrain overlay / surface page 回退成 per-segment `MeshInstance3D` 管线。
- 不在 `v7` 直接完成车辆交通仿真、最终 signage 系统、道路编辑器工作流或 Terrain3D 集成。

## Acceptance

- 固定 seed 下，road edge / intersection semantic contract 稳定；相同 seed 多次生成时，section / lane / intersection metadata 一致。
- 自动化测试至少断言：intersection ordered branches、type 与 branch connection semantics 成立，不再主要依赖 endpoint cluster 临时猜测。
- 自动化测试至少断言：chunk layout / surface / bridge 至少各有一条正式 consumer 链从 semantic contract 读取参数。
- 自动化测试至少断言：runtime 中不存在 per-road / per-lane scene node 膨胀，也不存在 `Path3D` lane runtime 回退。
- `tests/e2e/test_city_runtime_performance_profile.gd` fresh 结果必须满足：
  - `wall_frame_avg_usec <= 11000`
  - `streaming_mount_setup_avg_usec <= 5500`
  - `update_streaming_avg_usec <= 10000`
- `tests/e2e/test_city_first_visit_performance_profile.gd` fresh 结果必须满足：
  - `wall_frame_avg_usec <= 16667`
  - `streaming_mount_setup_avg_usec <= 5500`
  - `update_streaming_avg_usec <= 14500`
- `tests/world/test_city_chunk_setup_profile_breakdown.gd` fresh 结果必须满足：
  - `total_usec <= 8500`
  - `road_overlay_usec <= 1400`
  - `ground_usec <= 1800`
- 反作弊条款：不得通过关闭道路可见性、削掉现有 bridge/surface 管线、或把道路拆回 per-road / per-lane runtime node 来伪造通过。

## Files

- `city_game/world/generation/CityReferenceRoadGraphBuilder.gd`
- `city_game/world/model/CityRoadGraph.gd`
- `city_game/world/rendering/CityRoadTemplateCatalog.gd`
- `city_game/world/rendering/CityRoadLayoutBuilder.gd`
- `city_game/world/rendering/CityRoadMaskBuilder.gd`
- `city_game/world/rendering/CityRoadMeshBuilder.gd`
- `city_game/world/rendering/CityRoadSurfacePageProvider.gd`
- `city_game/world/rendering/CityChunkProfileBuilder.gd`
- `city_game/world/rendering/CityChunkRenderer.gd`
- `tests/world/test_city_road_semantic_contract.gd`
- `tests/world/test_city_road_semantic_seed_stability.gd`
- `tests/world/test_city_road_intersection_topology.gd`
- `tests/world/test_city_road_intersection_branch_order.gd`
- `tests/world/test_city_road_layout_semantic_takeover.gd`
- `tests/world/test_city_road_runtime_node_budget.gd`
- `tests/world/test_city_reference_road_graph.gd`
- `tests/world/test_city_road_section_templates.gd`
- `tests/world/test_city_shared_graph_road_takeover.gd`
- `tests/world/test_city_bridge_deck_collision.gd`
- `tests/world/test_city_chunk_setup_profile_breakdown.gd`
- `tests/e2e/test_city_runtime_performance_profile.gd`
- `tests/e2e/test_city_first_visit_performance_profile.gd`

## Steps

1. 写失败测试（红）：补 `road_semantic_contract`、`road_semantic_seed_stability`，先把 section/lane/edge metadata contract 写硬。
2. 运行到红：`test_city_road_semantic_contract.gd`、`test_city_road_semantic_seed_stability.gd`、`test_city_road_section_templates.gd`，确认当前 shared road graph 还没有这些正式 contract。
3. 实现（绿）：升级 `CityRoadTemplateCatalog`、`CityRoadGraph`、`CityReferenceRoadGraphBuilder`，让 edge semantics 成为 shared data。
4. 写第二组失败测试（红）：补 `road_intersection_topology`、`road_intersection_branch_order`，先钉住 ordered branches / type / connection semantics。
5. 运行到红：`test_city_road_intersection_topology.gd`、`test_city_road_intersection_branch_order.gd`，确认当前交叉口还主要依赖几何后处理。
6. 实现（绿）：把交叉口拓扑 contract 上游化到 `CityRoadGraph`，并保持 fixed seed 稳定。
7. 写第三组失败测试（红）：补 `road_layout_semantic_takeover`、`road_runtime_node_budget`，把 chunk road consumer 接管与 runtime guard 写硬。
8. 实现（绿）：升级 `CityRoadLayoutBuilder`、`CityRoadMaskBuilder`、`CityRoadMeshBuilder`、`CityChunkProfileBuilder`、`CityChunkRenderer`，让 layout / surface / bridge 读取 semantic contract，并明确禁止 node-tree 回退。
9. 运行到绿：`test_city_reference_road_graph.gd`、`test_city_road_section_templates.gd`、`test_city_shared_graph_road_takeover.gd`、`test_city_bridge_deck_collision.gd`、新增的 `v7` world tests 全绿。
10. E2E：fresh isolated 跑 `test_city_runtime_performance_profile.gd`、`test_city_first_visit_performance_profile.gd`、`test_city_chunk_setup_profile_breakdown.gd`，确认 warm / cold / chunk setup 阈值都未回退。

## Risks

- 如果 lane / intersection semantics 设计成 consumer 私有字段，而不是 shared contract，会再次把语义分裂到多个子系统里。
- 如果交叉口仍以 endpoint cluster 几何猜测为主，后续 signage / vehicle / lane graph 会继续复制脆弱逻辑。
- 如果为了“更像 reference repo”而引入 `Path3D` lane tree 或 per-road scene nodes，运行期红线会被直接打穿。
- 如果只加数据字段而没有正式 consumer 接管，`v7` 会变成“有 contract 但没人用”的空心升级。

## Progress Notes

- 2026-03-14 `M3` closeout：新增 `tests/world/test_city_road_layout_semantic_takeover.gd`，用故意冲突的 legacy 字段与 `section_semantics` 做反作弊断言，确认 `CityRoadLayoutBuilder` 现已以 `lane_schema / edge_profile` 作为 chunk segment 的宽度、lane count 与 median 来源；`CityRoadMaskBuilder` 与 `CityRoadMeshBuilder` 现已正式消费 `marking_profile_id / surface_half_width_m / median_width_m`，其中 mask stripe、bridge stripe 与 bridge collision width 都会跟随 semantic contract；`CityChunkProfileBuilder` 现已输出 `road_semantic_consumer_stats`，让 profile 自身也成为正式 consumer。fresh world 回归已通过：`test_city_road_layout_semantic_takeover.gd`、`test_city_shared_graph_road_takeover.gd`、`test_city_bridge_deck_collision.gd`、`test_city_road_semantic_contract.gd`、`test_city_road_section_templates.gd`、`test_city_road_mask_profile_breakdown.gd`、`test_city_road_surface_lod.gd`、`test_city_chunk_profile_prepare_breakdown.gd`、`test_city_ground_road_overlay_material.gd`、`test_city_surface_page_contract.gd`、`test_city_surface_page_runtime_sharing.gd`、`test_city_pedestrian_lane_graph.gd`、`test_city_pedestrian_lane_graph_continuity.gd`、`test_city_pedestrian_query_local_lane_sampling.gd`。fresh isolated profiling 结果为：`test_city_chunk_setup_profile_breakdown.gd` `total_usec = 5568`、`road_overlay_usec = 971`、`ground_usec = 1189`；`test_city_runtime_performance_profile.gd` 两轮分别为 `9499 / 4930 / 9039` 与 `10195 / 4911 / 9761`；`test_city_first_visit_performance_profile.gd` 两轮分别为 `16192 / 5521 / 15317` 与 `16633 / 5174 / 15597`（格式：`wall_frame_avg_usec / streaming_mount_setup_avg_usec / update_streaming_avg_usec`）。结论：`M3` 已完成，但 `M4` 仍必须继续处理 runtime guard，因为 cold-path `update_streaming` 仍高于 `14500` 目标，而且 warm / cold 运行期都高于 `M2` closeout 基线。

# ECN-0027: Flat-Ground Runtime Simplification

## 基本信息

- **ECN 编号**：ECN-0027
- **关联 PRD**：PRD-0001、PRD-0002、PRD-0003
- **关联 Req ID**：REQ-0001-004、REQ-0001-006、REQ-0002-003、REQ-0002-004、REQ-0003-004、REQ-0003-005
- **发现阶段**：v36 profiling / main-world manual play
- **日期**：2026-03-21

## 变更原因

`v36` 原本聚焦近场 `crowd / traffic / renderer_sync` 热路径的三化治理，但主世界继续暴露出一条更基础的架构问题：

1. 地形高度被多条链路重复消费：
   - chunk ground mesh / collision
   - road layout / bridge deck
   - building grounding
   - player / pedestrian / vehicle runtime grounding
2. 车辆运行时存在“平面车道语义”和“运行时二次贴地语义”两套高度来源；一旦 ground context / cached profile 不一致，就会出现车辆飞天，而 bridge deck 只是把这条双语义风险进一步放大。
3. `first-visit` 与 chunk mount 的 terrain async / page / LOD 链路已经成为稳定的性能负担，但当前城市玩法并不需要连续起伏地形来成立。

因此，本轮需要先把“城市运行在统一平面上”提升为架构级冻结口径，再继续推进近场性能治理。否则继续只抠 crowd / traffic，只会在错误底座上做局部优化。

## 变更内容

### 原设计

- chunk ground 使用连续地形采样与 terrain async/page/LOD 链路。
- 普通道路、建筑、玩家、行人、车辆默认都消费 terrain height。
- elevated/bridge 道路会在 terrain 之上再抬升。
- profiling 与测试默认要求出现 terrain async completion / terrain commit / terrain relief。

### 新设计

- 整个城市默认运行在绝对平面 `y = 0`。
- 普通地面、普通道路、建筑基座、玩家、行人都不再消费 runtime terrain height。
- 高架桥 / bridge deck 语义也一并冻结，所有道路统一回到绝对平面。
- chunk ground 改为固定平面 mesh / collision，不再依赖 terrain async/page/LOD 才能挂载。
- profiling / contract 测试改为接受并验证：
  - terrain async sample 允许为 `0`
  - terrain relief 固定为 `0`
  - chunk ground 顶点/碰撞规模退化为平面级别
  - `bridge_count / bridge clearance / bridge proxy` 允许并要求退化为 `0`

## 影响范围

- 受影响的 Req ID：
  - REQ-0001-004
  - REQ-0001-006
  - REQ-0002-003
  - REQ-0002-004
  - REQ-0003-004
  - REQ-0003-005
- 受影响的 v36 计划：
  - `docs/plan/v36-index.md`
  - `docs/plan/v36-nearfield-runtime-data-batching-parallelization.md`
  - `docs/plan/v36-flat-ground-runtime-simplification.md`
- 受影响的测试：
  - `tests/world/test_city_terrain_sampler.gd`
  - `tests/world/test_city_chunk_setup_profile_breakdown.gd`
  - `tests/world/test_city_pedestrian_runtime_grounding.gd`
  - `tests/world/test_city_vehicle_drive_surface_grounding.gd`
  - `tests/world/test_city_bridge_deck_collision.gd`
  - `tests/world/test_city_bridge_midfar_visibility.gd`
  - `tests/world/test_city_bridge_grade_constraints.gd`
  - `tests/world/test_city_road_network_continuity.gd`
  - `tests/world/test_city_road_section_templates.gd`
  - `tests/e2e/test_city_first_visit_performance_profile.gd`
  - `tests/e2e/test_city_runtime_performance_profile.gd`
- 受影响的代码文件：
  - `city_game/world/rendering/CityTerrainSampler.gd`
  - `city_game/world/rendering/CityChunkGroundSampler.gd`
  - `city_game/world/rendering/CityRoadLayoutBuilder.gd`
  - `city_game/world/rendering/CityRoadMeshBuilder.gd`
  - `city_game/world/rendering/CityChunkProfileBuilder.gd`
  - `city_game/world/rendering/CityChunkScene.gd`
  - `city_game/world/rendering/CityChunkRenderer.gd`
  - `city_game/world/pedestrians/streaming/CityPedestrianStreamer.gd`
  - `city_game/world/vehicles/streaming/CityVehicleStreamer.gd`
  - `city_game/scripts/CityPrototype.gd`

## 处置方式

- [ ] PRD 已同步更新（待 closeout 后统一回链）
- [x] v36 计划已同步更新
- [x] 追溯矩阵已同步更新
- [x] 相关测试已同步更新

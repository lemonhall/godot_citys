# V36 Flat-Ground Runtime Simplification

## Goal

把当前“地形高度参与太多链路，导致车辆飞天、chunk mount 过重、terrain async 成为 first-visit 负担”的状态，收束成一个更简单、更可控的底座：

- 整个城市默认运行在绝对平面 `y=0`
- 普通道路、建筑、玩家、行人全部共享这套平面高度语义
- 高架桥 / bridge deck 语义也暂时冻结
- terrain async / page / LOD 不再是 chunk mount 的必要路径

## Scope

做什么：

- 将 `CityTerrainSampler` 退化为固定平面高度
- 将 `CityRoadLayoutBuilder` 的普通道路与 building grounding 统一到平面
- 移除 world runtime 中 bridge deck clearance / thickness / collision / proxy 语义
- 将 `CityChunkScene` 的 ground 改为固定平面 mesh / collision
- 将 `CityChunkRenderer` 从 terrain wait-chain 中解耦
- 将 pedestrian / player / vehicle grounding 统一到新的高度语义

不做什么：

- 本轮不移除 road surface overlay、building collapse、crowd、traffic
- 本轮不靠“空街”或“关系统”来伪造性能收益
- 本轮不追求一次性完成全部 `v36` closeout；flat-ground 是后续三化的底座修复

## Acceptance

1. `CityTerrainSampler.sample_height(...)` 对任意世界坐标都返回同一平面高度。
2. 所有道路、building center、pedestrian runtime ground、player surface resolve、vehicle drive surface 都回到该平面高度。
3. `bridge_count / bridge_collision_shape_count / bridge_min_clearance_m / bridge_deck_thickness_m / BridgeProxy` 全部退化为 `0` 或不存在。
4. chunk mount 不再等待 terrain async 才能入场。
5. `test_city_first_visit_performance_profile.gd` 与 `test_city_runtime_performance_profile.gd` 允许 terrain async sample/count 为 `0`，并继续保留 frame-time 与 density 守线。

## Files

- Modify: `docs/plan/v36-index.md`
- Create: `docs/plan/v36-flat-ground-runtime-simplification.md`
- Create: `docs/ecn/ECN-0027-flat-ground-runtime-simplification.md`
- Modify: `city_game/world/rendering/CityTerrainSampler.gd`
- Modify: `city_game/world/rendering/CityChunkGroundSampler.gd`
- Modify: `city_game/world/rendering/CityRoadLayoutBuilder.gd`
- Modify: `city_game/world/rendering/CityRoadMeshBuilder.gd`
- Modify: `city_game/world/rendering/CityChunkProfileBuilder.gd`
- Modify: `city_game/world/rendering/CityChunkScene.gd`
- Modify: `city_game/world/rendering/CityChunkRenderer.gd`
- Modify: `city_game/world/pedestrians/streaming/CityPedestrianStreamer.gd`
- Modify: `city_game/world/vehicles/streaming/CityVehicleStreamer.gd`
- Modify: `city_game/scripts/CityPrototype.gd`
- Modify: `tests/world/test_city_terrain_sampler.gd`
- Modify: `tests/world/test_city_chunk_setup_profile_breakdown.gd`
- Modify: `tests/world/test_city_pedestrian_runtime_grounding.gd`
- Modify: `tests/world/test_city_vehicle_drive_surface_grounding.gd`
- Modify: `tests/e2e/test_city_first_visit_performance_profile.gd`
- Modify: `tests/e2e/test_city_runtime_performance_profile.gd`

## Steps

1. 文档冻结
   - 通过 `ECN-0027` 与 `v36-index` 写清 flat-ground pivot 的目标和 DoD。
2. TDD Red
   - 先把 flat-ground 相关 world / e2e contract 改成新口径，并确认旧实现下失败。
3. Sampler 统一
   - 将 terrain sampler、chunk ground sampler、building grounding 统一到固定平面。
4. Bridge 退场
   - 删除 world runtime 中的 bridge 抬升、support、proxy 与 collision 语义。
5. Chunk mount 简化
   - 将 chunk scene ground 改成固定平面 mesh/collision。
   - 将 renderer 从 terrain wait-chain 中解耦，保留 surface page。
6. Actor grounding 收口
   - pedestrian/player 直接回到平面。
   - vehicle 也统一回到平面。
7. 回归与 profiling
   - 串行跑受影响 world / e2e tests，重新记录 first-visit / runtime 指标。
8. 清理
   - 删除临时 probe 文件，回写 `v36-mN-verification-YYYY-MM-DD.md`。

## Risks

- 如果只把 `sample_height()` 改成平面，但不拆 renderer terrain wait-chain，性能改善会很有限。
- 如果只改了一半，残留 bridge proxy / collision / clearance 统计，就会形成“代码已平、contract 仍旧抬桥”的双口径。
- 如果 pedestrian / vehicle grounding 只改一半，会出现“行人还在算地形、车辆还在吃旧 context”的双语义问题。

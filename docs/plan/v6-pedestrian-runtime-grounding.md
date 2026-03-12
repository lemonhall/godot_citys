# V6 Pedestrian Runtime Grounding

## Goal

把 pedestrian 从“spawn 时看起来落地、跑起来却可能埋进地形”的状态，推进到“运行期始终沿用真实 chunk 地表口径贴地移动”的状态。

## PRD Trace

- REQ-0002-008

## Scope

做什么：

- 让 active pedestrian 的 `world_position.y` 复用真实 chunk 地表的采样口径，而不是只读基础噪声地形高度
- 让贴地覆盖 spawn、运行期 step、tier 升降级与 chunk 回访后的 runtime rebuild
- 在 roadbed、坡地和局部地形过渡上保持 crowd 与世界表面一致
- 在实现完成后重新跑 isolated crowd/runtime profiling，确认没有把新采样路径做成新的热点

不做什么：

- 不做 foot IK
- 不做室内、楼梯塔或多层步行桥支持
- 不在本计划里扩展 pedestrian combat / death 行为

## Acceptance

1. active pedestrian 的 `world_position.y` 必须来自与真实 chunk 地表一致的 runtime sampling contract，而不是 `CityTerrainSampler` 这类只含基础噪声的单一高度口径。
2. 自动化测试必须证明：至少一个坡地 lane 与一个受 roadbed 影响的 lane 上，pedestrian 在 spawn 后和运行期移动后，其 `world_position.y` 与期望 runtime ground surface 的误差持续 `<= 0.05m`。
3. 自动化测试必须证明：同一次运行中，位于不同地表高度的 pedestrian 不再共享单一固定 `y` 契约。
4. fresh isolated `tests/e2e/test_city_pedestrian_performance_profile.gd` 与 `tests/e2e/test_city_runtime_performance_profile.gd` 必须继续 `PASS`，且 `wall_frame_avg_usec <= 16667`。
5. 反作弊条款：不得通过冻结 `y` 更新、施加全局常数偏移或仅在测试里避开问题 lane 来宣称“运行期贴地一致性”成立。

## Files

- Modify: `city_game/world/pedestrians/streaming/CityPedestrianStreamer.gd`
- Modify: `city_game/world/pedestrians/simulation/CityPedestrianTierController.gd`
- Modify: `city_game/world/rendering/CityChunkRenderer.gd`
- Modify: `city_game/world/rendering/CityChunkGroundSampler.gd`
- Modify: `city_game/scripts/CityPrototype.gd`
- Modify: `tests/world/test_city_pedestrian_spawn_grounding.gd`
- Create: `tests/world/test_city_pedestrian_runtime_grounding.gd`
- Verify: `tests/e2e/test_city_pedestrian_performance_profile.gd`
- Verify: `tests/e2e/test_city_runtime_performance_profile.gd`

## Steps

1. 写失败测试（红）
   - `test_city_pedestrian_runtime_grounding.gd` 断言 runtime moving pedestrian 的 `world_position.y` 与真实 chunk ground sampler 一致。
   - `test_city_pedestrian_spawn_grounding.gd` 补充“spawn 后继续 step 仍贴地”的断言，防止只修 spawn。
2. 跑到红
   - 运行 grounding 测试，预期 FAIL，原因是当前运行期贴地仍依赖基础地形高度而不是 roadbed-aware chunk surface。
3. 实现（绿）
   - 为 pedestrian runtime 提供 chunk/profile-aware 的 ground sampling context，并在 spawn、step、tier 升降级后统一复用。
4. 跑到绿
   - grounding 测试全部 PASS，证明 pedestrian 在运行期不会继续被地形吞没或浮空。
5. 必要重构（仍绿）
   - 收敛 sampling 接口与缓存口径，避免把 per-ped per-tick profile rebuild 引入主线程热点。
6. E2E / Profiling
   - isolated 重新运行 `test_city_pedestrian_performance_profile.gd` 与 `test_city_runtime_performance_profile.gd`，确认没有新的红线回退。

## Risks

- 如果实现为“每个 pedestrian 每一帧都独立重建 chunk profile”，会直接破坏 crowd update 热点预算。
- 如果 chunk 边界附近的 sampling context 不一致，会出现跨 chunk 的 `y` 跳变与 tier 切换弹跳。
- 如果只修 spawn grounding 而不修运行期 step，玩家一旦观察 pedestrian 长距离移动，问题仍会原样复现。

## Verification

- 2026-03-13 本地 headless `PASS`：`tests/world/test_city_pedestrian_spawn_grounding.gd`
- 2026-03-13 本地 headless `PASS`：`tests/world/test_city_pedestrian_runtime_grounding.gd`
- runtime grounding fresh 输出：`roadbed surface_delta_m = 0.229713`、`ground_error_m = 4.35e-7`、`slope expected_height_delta_m = 0.140779`、`peak_ground_error_m = 1.14e-7`
- 2026-03-13 isolated profiling 继续守线：`tests/e2e/test_city_pedestrian_performance_profile.gd` warm `15518`、first-visit `14214`；`tests/e2e/test_city_runtime_performance_profile.gd` warm `15765`
- 实现侧通过共享 deterministic road-layout cache 复用 chunk road profile，避免 runtime grounding 与 renderer/terrain pipeline 对同一 chunk 重复重建道路段数据。

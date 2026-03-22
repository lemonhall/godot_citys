# V38 Lake Leisure And Fishing Foundation

## Goal

交付一条正式的 `v38` 实现计划：先把用户要求的 lake shared layer `1/2` 做成正式运行时能力，再在独立 lab 场景里复用这两层挖出同样的湖并完成低干扰验收，随后在同一个 lab 里把 fishing minigame 跑通，最后再把同一套 `1/2/3` 层整体移植回主世界 `chunk_147_181`。该版本必须同时打通 `terrain_region_feature` 的首个真实 lake consumer、固定水位水面、bathymetry/shoreline/fish habitat contract、玩家下水观察鱼群，以及 shoreline fishing venue 的最小闭环与 `ambient_simulation_freeze`，但主世界接入必须晚于 lab closeout。

## PRD Trace

- Direct consumer: REQ-0025-001
- Direct consumer: REQ-0025-002
- Direct consumer: REQ-0025-003
- Direct consumer: REQ-0025-004
- Direct consumer: REQ-0025-005
- Guard / Runtime: REQ-0025-006
- Guard / Performance: REQ-0025-007

## Dependencies

- 依赖 `v21` 已冻结 `ground_probe` 与 `terrain_region_feature` future sibling 方向。
- 依赖 `v26` 已冻结 `scene_minigame_venue` family 与 `ambient_simulation_freeze` 主链。
- 依赖 `v28/v29` 已冻结多 minigame runtime 聚合、HUD 扩展与 authored venue contract。
- 依赖 `v37` 已验证 `lab-first -> main-world port` 的工作流与“shared runtime 不分叉”纪律。
- 依赖现有 `CityTerrainPageProvider.gd`、`CityChunkRenderer.gd`、`CityChunkScene.gd` 的 terrain/rendering 入口。
- 依赖 `PlayerController.gd` 与 `CityPrototype.gd` 现有玩家控制、世界交互与 HUD 聚合链。

## Contract Freeze

- 正式 lake region 冻结为：
  - `region_id = region:v38:fishing_lake:chunk_147_181`
  - `feature_kind = terrain_region_feature`
  - `region_kind = lake_basin`
- 正式 shoreline fishing venue 冻结为：
  - `venue_id = venue:v38:lakeside_fishing:chunk_147_181`
  - `feature_kind = scene_minigame_venue`
  - `game_kind = lakeside_fishing`
- 独立 lab 场景冻结为：
  - `lab_scene_path = res://city_game/scenes/labs/LakeFishingLab.tscn`
- `v38` 的 shared runtime 一致性冻结为：
  - lab 与主世界必须共享 `CityTerrainRegionFeatureRuntime.gd`
  - lab 与主世界必须共享 `CityLakeRegionRuntime.gd`
  - lab 与主世界必须共享 `CityLakeFishSchoolRuntime.gd`
  - lab 与主世界必须共享 `CityFishingVenueRuntime.gd`
  - lab 与主世界只允许 carrier / wrapper / anchor 接线不同，不允许行为逻辑分叉
- 锚点冻结为：
  - `anchor_chunk_id = chunk_147_181`
  - `anchor_chunk_key = (147, 181)`
  - `world_position = (2844.59, 0.00, 11508.18)`
  - `chunk_local_position = (84.59, 0.00, 44.18)`
  - `surface_normal = (0.00, 1.00, 0.00)`
- lake waterline contract 冻结为：
  - `water_level_y_m = 0.0`
  - `mean_depth_m ~= 10.0`
  - `max_depth_m = 15.0`
  - `shore_shelf_depth_m = 0.0..3.0`
- lake basin contract 至少包含：
  - `region_id`
  - `feature_kind`
  - `region_kind`
  - `anchor_chunk_id`
  - `anchor_chunk_key`
  - `world_position`
  - `surface_normal`
  - `water_level_y_m`
  - `mean_depth_m`
  - `max_depth_m`
  - `shoreline_profile_path`
  - `bathymetry_profile_path`
  - `habitat_profile_path`
  - `linked_venue_ids`
- lake runtime 不得只是画水面；必须通过 region 驱动：
  - terrain downward carve
  - 固定水位 water surface
  - 湖底深度采样
  - fish habitat 查询
- fishing venue contract 至少包含：
  - `venue_id`
  - `feature_kind`
  - `game_kind`
  - `linked_region_id`
  - `pole_anchor_id`
  - `cast_origin_anchor_id`
  - `bite_zone_ids`
  - `pole_interaction_radius_m`
  - `release_buffer_m`
  - `full_map_pin`
- fishing runtime 最小状态冻结为：
  - `fishing_mode_active`
  - `pole_equipped`
  - `cast_state`
  - `target_school_id`
  - `bite_wait_remaining_sec`
  - `ambient_simulation_frozen`
  - `last_catch_result`
- HUD 最小 contract 冻结为：
  - `visible`
  - `fishing_mode_active`
  - `pole_equipped`
  - `cast_state`
  - `bite_wait_remaining_sec`
  - `target_school_id`
  - `last_catch_result`
- fishing 输入 contract 冻结为：
  - `E = 拿起/放回鱼竿`
  - `右键 = 待甩杆预览`
  - `左键 = 甩杆 / 收杆`
- `MatchStartRing` 不再拥有 fishing 入口所有权。
- fishing 不再依赖任何单独的固定 start trigger；鱼竿本身就是唯一入口。
- `ambient_simulation_freeze` 在 lake leisure 区域的 release buffer 冻结为 `32.0m`
- full map pin `icon_id` 冻结为 `fishing`
- 交付顺序冻结为：
  - 先做 shared layer 1/2：`terrain_region_feature + carve/water/fish`
  - 再做 `LakeFishingLab.tscn` 里的同湖复现与下水观察
  - 再做 lab fishing minigame
  - 最后做主世界 `chunk_147_181` 正式接入

## Scope

做什么：

- 新增 `terrain_region_feature` registry/runtime
- 新增 `lake` 相关 definition/runtime/fish school runtime
- 在 terrain page provider 上实现 lake basin 的 downward carve override
- 新增固定 `water_level_y_m` 的 water surface page provider
- author lake region manifest、shoreline profile、bathymetry profile、habitat profile
- 在湖中提供正式 fish school summary/runtime
- 新增独立 `LakeFishingLab.tscn` / `LakeFishingLab.gd`
- 在 lab 场景里先复用 shared layer 1/2 挖出同样的湖，并完成水中观察/鱼群验收
- 在 lab 湖岸 author 一套 fishing minigame venue manifest / scene / script
- 新增 `CityFishingVenueRuntime.gd`
- lab 验收通过后，再在 `CityPrototype.gd` 聚合 fishing runtime、lake leisure freeze 与最小 HUD
- 支持玩家进入湖水区域并进入正式 water/underwater observation 状态
- 补齐 shared lake / lab lake / lab fishing / main-world port / freeze / e2e 测试

不做什么：

- 不做通用河流/海洋系统
- 不做船、潜水装备、水下战斗
- 不做完整鱼类百科、稀有度、天气、时间系统
- 不做完整湖边建筑群和景观园区
- 不做复杂流体/波浪模拟
- 不做新的 world pause 语义

## Acceptance

1. 自动化测试必须证明：`terrain_region_feature` registry/runtime 能正式读取 `region:v38:fishing_lake:chunk_147_181`，并保持 `linked_venue_ids` 口径一致。
2. 自动化测试必须证明：lake region 的 terrain sample 确实被向下 carve，湖区内部高度低于岸边高度，而不是保留平地碰撞。
3. 自动化测试必须证明：water surface 高度稳定在 `water_level_y_m = 0.0`，且与湖盆深度采样使用同一套真源。
4. 自动化测试必须证明：bathymetry 能稳定区分浅岸、常态深水和 `15m` 最深 pocket，不是全湖一个固定深度。
5. 自动化测试必须证明：player 进入湖水区域后，会暴露正式 water/underwater state，而不是继续被当作普通陆地。
6. 自动化测试必须证明：lake runtime 可返回非空 fish school summary，且 school depth 不越出合法水体范围。
7. 自动化测试必须证明：独立 lab 场景能加载 player、地面、lake root、water surface 与 fish runtime。
8. 自动化测试必须证明：lab 场景里挖出的湖与 shared shoreline / bathymetry / habitat profile 保持同源，不是第二套独立 lake 数据。
9. 自动化测试必须证明：lab 场景里 player 可进入正式 water/underwater state，并观察非空 fish school summary。
10. 自动化测试必须证明：lab 场景中至少一条 headless flow 可完成“接近鱼竿 -> E 拿竿 -> 右键预甩 -> 左键甩杆 -> 等待上钩 -> 左键收杆 -> E 放回”的最小钓鱼闭环。
11. 自动化测试必须证明：lab 验收通过后，主世界 `chunk_147_181` 能接入同一套 lake + fishing runtime，而不是重写第二套逻辑。
12. 自动化测试必须证明：进入主世界 lake leisure 区域后 `ambient_simulation_freeze` 激活，但 player、radio、lake runtime、fish runtime 与 fishing runtime 继续更新。
13. 自动化测试必须证明：离开主世界 lake leisure 内圈但仍处于 `32m` release buffer 内时，不会立刻解冻。
14. 自动化测试必须证明：full map 能从主世界 fishing venue manifest pipeline 解析出 `icon_id = fishing`。
15. 受影响的 `ground_probe`、soccer、tennis、missile command 关键 tests 必须继续通过。
16. 如触及 terrain page、chunk renderer、HUD 或 runtime hot path，fresh closeout 必须串行跑 profiling 三件套。
17. 反作弊条款：不得只画水面不挖地；不得把 lake 挂成 landmark；不得让 fish 只存在于随机数表；不得 lab/main-world 各写一套逻辑；不得用 world pause 冒充 leisure freeze。

## Files

- Create: `docs/prd/PRD-0025-lake-leisure-and-fishing-foundation.md`
- Create: `docs/plan/v38-index.md`
- Create: `docs/plan/v38-lake-leisure-and-fishing-foundation.md`
- Create: `docs/plans/2026-03-22-v38-lake-leisure-and-fishing-design.md`
- Create: `city_game/world/features/CityTerrainRegionFeatureRegistry.gd`
- Create: `city_game/world/features/CityTerrainRegionFeatureRuntime.gd`
- Create: `city_game/world/features/lake/CityLakeRegionDefinition.gd`
- Create: `city_game/world/features/lake/CityLakeRegionRuntime.gd`
- Create: `city_game/world/features/lake/CityLakeFishSchoolRuntime.gd`
- Create: `city_game/world/rendering/CityWaterSurfacePageProvider.gd`
- Create: `city_game/world/minigames/CityFishingVenueRuntime.gd`
- Create: `city_game/scenes/labs/LakeFishingLab.tscn`
- Create: `city_game/scenes/labs/LakeFishingLab.gd`
- Create: `city_game/serviceability/terrain_regions/generated/terrain_region_registry.json`
- Create: `city_game/serviceability/terrain_regions/generated/region_v38_fishing_lake_chunk_147_181/terrain_region_manifest.json`
- Create: `city_game/serviceability/terrain_regions/generated/region_v38_fishing_lake_chunk_147_181/lake_shoreline_profile.json`
- Create: `city_game/serviceability/terrain_regions/generated/region_v38_fishing_lake_chunk_147_181/lake_bathymetry_profile.json`
- Create: `city_game/serviceability/terrain_regions/generated/region_v38_fishing_lake_chunk_147_181/fish_habitat_profile.json`
- Create: `city_game/serviceability/minigame_venues/generated/venue_v38_lakeside_fishing_chunk_147_181/minigame_venue_manifest.json`
- Create: `city_game/serviceability/minigame_venues/generated/venue_v38_lakeside_fishing_chunk_147_181/lake_fishing_minigame_venue.tscn`
- Create: `city_game/serviceability/minigame_venues/generated/venue_v38_lakeside_fishing_chunk_147_181/LakeFishingMinigameVenue.gd`
- Modify: `city_game/serviceability/minigame_venues/generated/minigame_venue_registry.json`
- Modify: `city_game/scripts/CityPrototype.gd`
- Modify: `city_game/scripts/PlayerController.gd`
- Modify: `city_game/world/rendering/CityTerrainPageProvider.gd`
- Modify: `city_game/world/rendering/CityChunkRenderer.gd`
- Modify: `city_game/world/rendering/CityChunkScene.gd`
- Modify: `city_game/world/pedestrians/simulation/CityPedestrianTierController.gd`
- Modify: `city_game/world/vehicles/simulation/CityVehicleTierController.gd`
- Modify: `city_game/ui/PrototypeHud.gd`
- Modify: `city_game/ui/CityMapScreen.gd`
- Create: `tests/world/test_city_terrain_region_feature_registry_runtime.gd`
- Create: `tests/world/test_city_lake_region_manifest_contract.gd`
- Create: `tests/world/test_city_lake_bathymetry_contract.gd`
- Create: `tests/world/test_city_lake_water_surface_contract.gd`
- Create: `tests/world/test_city_lake_fish_school_contract.gd`
- Create: `tests/world/test_city_lake_swim_observer_contract.gd`
- Create: `tests/world/test_city_lake_lab_scene_contract.gd`
- Create: `tests/world/test_city_lake_lab_observer_contract.gd`
- Create: `tests/world/test_city_fishing_minigame_venue_manifest_contract.gd`
- Create: `tests/world/test_city_fishing_venue_ambient_freeze_contract.gd`
- Create: `tests/world/test_city_fishing_venue_cast_loop_contract.gd`
- Create: `tests/world/test_city_fishing_venue_reset_on_exit_contract.gd`
- Create: `tests/world/test_city_fishing_full_map_pin_contract.gd`
- Create: `tests/e2e/test_city_lake_lab_fishing_flow.gd`
- Create: `tests/world/test_city_lake_main_world_port_contract.gd`
- Create: `tests/e2e/test_city_lake_fishing_flow.gd`

## Steps

1. Analysis
   - 固定 `region_id`、`venue_id`、registry path、manifest path 与 lake/shore anchor 语义。
   - 用现有 `ground_probe` 坐标冻结 `water_level_y_m` 与 lake region 中心锚点。
   - 冻结 shoreline irregular 轮廓、bathymetry 深度带和 `32m` freeze release buffer。
   - 固定 lab-first -> main-world port 的两阶段口径。
2. Design
   - 写 `PRD-0025`
   - 写 `v38-index.md`
   - 写 `v38-lake-leisure-and-fishing-foundation.md`
   - 写 design doc，明确为什么必须走 `terrain_region_feature + scene_minigame_venue + lab-first port` 纪律
3. TDD Red
   - 先写 `terrain_region_feature` registry/runtime contract test
   - 再写 lake manifest / bathymetry / water surface / fish school / swim observer tests
   - 再写 lab scene / lab observer / lab fishing flow tests
   - 再写 main-world fishing venue manifest / freeze / cast loop / reset / full-map pin tests
   - 最后写 main-world `test_city_lake_fishing_flow.gd`
4. Run Red
   - 逐条运行新测试，确认失败原因是 `v38` 尚未实现，而不是路径或 contract 拼写错误
5. TDD Green
   - 实现 `terrain_region_feature` registry/runtime
   - 实现 lake region carve / water surface / fish school runtime
   - author lake region manifest 与 profile sidecar
   - 搭建 `LakeFishingLab.tscn`，先在 lab 里复用 shared layer 1/2 挖出同样的湖
   - author lab fishing venue scene / manifest / script
   - 实现 `CityFishingVenueRuntime.gd`
   - 在 lab 里跑通基于鱼竿交互的 fishing minigame
   - 最后接入 `CityPrototype.gd` 的 main-world fishing runtime 聚合、leisure freeze 与最小 HUD / map pin
6. Refactor
   - 收口 lake sampling、fish school summary 与 fishing runtime 输入/状态接口
   - 保证 lab 与主世界复用同一套 runtime，只让 wrapper / anchor 不同
   - 冷路径保留完整 lake/fish payload，热路径只暴露紧凑 summary，避免每帧 deep-copy
7. E2E
   - 先跑 `test_city_lake_lab_fishing_flow.gd`
   - 再跑 `test_city_lake_fishing_flow.gd`
   - 补跑 `ground_probe`、soccer、tennis、missile command 关键 tests
   - 如触及 terrain/rendering/HUD/tick，串行跑 profiling 三件套
8. Review
   - 更新 `v38-index` traceability
   - 写差异列表与 verification evidence
   - 如实现中改变 DoD、深度、freeze 语义或双链分工，先写 ECN 再改代码
9. Ship
   - `v38: doc: freeze lake leisure and fishing scope`
   - 后续红绿 slices 分别 `test / feat / refactor`

## Risks

- 如果把 lake 做成 landmark 或超大 scene，很快就会遇到“视觉有湖、碰撞还是平地”的错位。
- 如果不做 terrain downward carve，只画水面，后续 fish、underwater observation、水草和彩蛋都会建立在假深度上。
- 如果 fish 按“一条鱼一个节点”实现，近景数量一上来就会直接撞性能红线。
- 如果 lab 和主世界各自写一套 lake / fishing 逻辑，第二阶段会从“移植”退化成“重写”。
- 如果 fishing runtime 直接去维护第二套湖深度/鱼群数据，湖区与玩法状态很快就会漂移。
- 如果 leisure freeze 误走了 world pause，会把 radio、lake runtime 或 fishing runtime 一起停掉。
- 如果 `CityPrototype.gd` 继续堆湖区、鱼群和 fishing 全部特判，很快会变成新的玩法总控巨石。

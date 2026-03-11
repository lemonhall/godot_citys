# V5 Terrain LOD

## Goal

为 terrain 建立 near / mid / far 分辨率层级或等价 clipmap-lite 机制，把高分辨率地形限制在近景，同时保持道路覆盖、可行走地表和轮廓连续。

## PRD Trace

- REQ-0001-004
- REQ-0001-006
- REQ-0001-011

## Scope

做什么：

- terrain 至少提供 near / mid / far 两档以上分辨率差异
- 近景保留可行走与碰撞精度，远景保留轮廓和道路覆盖连续
- 让 terrain LOD 与 terrain page / road surface page 协同工作

不做什么：

- 不在本计划里做完整 GPU clipmap
- 不在本计划里引入新的玩法内容

## Acceptance

1. 自动化测试必须证明 terrain 至少存在两档不同分辨率或等价 LOD 表现。
2. 自动化测试必须证明 LOD 切换前后，道路覆盖主轮廓、地表边界和玩家可行走面连续，不会重新出现“远处一套、近处换形”的体验。
3. warm traversal 的 fresh runtime profiling 必须满足 `wall_frame_avg_usec <= 16667`。
4. 反作弊条款：不得通过禁用远景地形、清空道路覆盖、锁死相机或缩小 active window 来伪造 LOD 收益。

## Files

- Modify: `city_game/world/rendering/CityTerrainPageProvider.gd`
- Modify: `city_game/world/rendering/CityTerrainMeshBuilder.gd`
- Modify: `city_game/world/rendering/CityChunkRenderer.gd`
- Modify: `city_game/world/rendering/CityChunkScene.gd`
- Create: `tests/world/test_city_terrain_lod_contract.gd`
- Create: `tests/world/test_city_terrain_road_overlay_continuity.gd`
- Modify: `tests/e2e/test_city_runtime_performance_profile.gd`

## Steps

1. 写失败测试（红）
   - `test_city_terrain_lod_contract.gd` 断言 terrain LOD 档位与分辨率差异存在。
   - `test_city_terrain_road_overlay_continuity.gd` 断言道路覆盖在 LOD 切换下保持主轮廓连续。
2. 跑到红
   - 运行上述测试，预期 FAIL，原因是 terrain 当前没有明确分辨率层级。
3. 实现（绿）
   - 为 terrain page / mesh builder 增加分辨率层级或 clipmap-lite ring。
   - 让道路覆盖与近景碰撞面继续跟随统一高度场。
4. 跑到绿
   - LOD contract 与 road overlay continuity 测试全部 PASS。
5. 必要重构（仍绿）
   - 统一 terrain LOD 与 chunk visual profile 的档位命名。
6. E2E 测试
   - runtime profile 验证 warm traversal 守住 `16.67ms/frame`，同时人工巡检不再出现明显的 terrain/road 轮廓跳变。

## Risks

- terrain LOD 如果只降几何不处理道路覆盖，远近景可能再次出现“地面连续、道路断开”的错位。
- 如果 mid/far 分辨率切太狠，轮廓虽然连续但坡度与高架引道会变假。

# V6 Pedestrian Redline Guard

## Goal

把 crowd 系统的 profiling、debug 观测与红线验收做成 `v6` 的强制护栏，确保“街上有人”不会以失去 `60 FPS = 16.67ms/frame` 为代价。

## PRD Trace

- REQ-0002-006
- REQ-0002-007

## Scope

做什么：

- 为 runtime profile 增加 crowd update / spawn / render commit 分项
- 扩展 overlay / HUD / minimap 调试层，暴露 crowd tier 计数和 page/cache 指标
- 建立有人流条件下的 warm / first-visit profiling 基线
- 把 `pedestrian_mode = lite` 写成默认验收口径

不做什么：

- 不在本计划里实现 `full` crowd 模式
- 不在本计划里做最终玩家可见的地图产品化 UI
- 不在本计划里引入新的玩法功能

## Acceptance

1. `pedestrian_mode = lite` 且固定 density 预设下，fresh warm traversal 与 first-visit traversal 的 `wall_frame_avg_usec` 必须都 `<= 16667`。
2. profiling 输出必须新增 `crowd_update_avg_usec`、`crowd_spawn_avg_usec`、`crowd_render_commit_avg_usec`、`ped_tier0_count`、`ped_tier1_count`、`ped_tier2_count`、`ped_tier3_count` 与至少一个 crowd page/cache 指标。
3. 自动化测试必须证明 crowd debug overlay 默认折叠，打开后能读取上述关键字段；minimap crowd debug layer 必须使用真实 pedestrian lane / density 数据。
4. 反作弊条款：不得在 profiling 时临时关闭 pedestrians、把 density 改成 `0`、仅显示空壳占位或绕开 first-visit 冷路径。

## Files

- Modify: `city_game/world/debug/CityDebugOverlay.gd`
- Modify: `city_game/ui/PrototypeHud.gd`
- Modify: `city_game/ui/CityMinimapView.gd`
- Modify: `city_game/world/map/CityMinimapProjector.gd`
- Modify: `tests/e2e/test_city_runtime_performance_profile.gd`
- Create: `tests/e2e/test_city_pedestrian_performance_profile.gd`
- Create: `tests/world/test_city_pedestrian_debug_overlay.gd`
- Create: `tests/world/test_city_minimap_pedestrian_debug_layer.gd`
- Create: `tests/world/test_city_pedestrian_profile_stats.gd`

## Steps

1. 写失败测试（红）
   - `test_city_pedestrian_profile_stats.gd` 断言新的 crowd profiling 字段存在。
   - `test_city_pedestrian_debug_overlay.gd` 断言 crowd overlay 默认折叠、可展开并输出 tier 计数。
   - `test_city_minimap_pedestrian_debug_layer.gd` 断言 minimap crowd layer 与 lane / density 数据同源。
2. 跑到红
   - 运行上述测试与 crowd profile 脚本，预期 FAIL，原因是 crowd 相关观测字段与基线尚不存在。
3. 实现（绿）
   - 扩展 runtime performance profile、debug overlay 与 minimap projector。
   - 建立 warm / first-visit 有人流基线，并将 `pedestrian_mode = lite` 写入测试入口。
4. 跑到绿
   - overlay / minimap / profile stats 测试全部 PASS。
   - `test_city_pedestrian_performance_profile.gd` fresh PASS，证明 warm / first-visit 均未打穿红线。
5. 必要重构（仍绿）
   - 收敛 crowd profile 字段命名，与现有 terrain / road surface profile 口径对齐。
   - 保持 overlay 默认隐藏、只在需要时展开，避免重新污染试玩画面。
6. E2E 测试
   - 分别在 warm 与 first-visit 条件下跑 fresh profiling；每完成一个里程碑后都重复执行，确保没有引入新的性能回退。

## Risks

- 如果 crowd profiling 只看总帧耗，不拆 `update / spawn / render commit`，很快会失去热点定位能力。
- 如果 minimap crowd layer 走的是另一套简化随机数据，后续 debug 和真实世界状态会重新断链。
- 如果没有 first-visit 基线，系统很容易在 warm 状态“看起来没事”，但玩家第一次到新区域时卡顿失控。

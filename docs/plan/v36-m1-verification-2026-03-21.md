# V36 M1 Verification - 2026-03-21

## 范围

本次验证不是 `v36` closeout，只覆盖第一批已经落地的结构性改动：

- vehicle chunk snapshot 从 per-frame render dict 改为 `CityVehicleState` ref 直通 renderer
- vehicle cached assignment reuse 不再整块重建 chunk snapshot，而是沿用缓存结构并按 stepped visible state 打 dirty
- 对应新增 / 收紧的 contract tests

## 本批代码切片

修改文件：

- `city_game/world/vehicles/simulation/CityVehicleTierController.gd`
- `city_game/world/vehicles/rendering/CityVehicleTrafficRenderer.gd`

新增测试：

- `tests/world/test_city_vehicle_chunk_snapshot_data_refs.gd`
- `tests/world/test_city_vehicle_renderer_state_ref_snapshot.gd`
- `tests/world/test_city_vehicle_cached_assignment_reuse_no_snapshot_rebuild.gd`

## TDD 证据

先红后绿：

1. `test_city_vehicle_chunk_snapshot_data_refs.gd`
   - 红：chunk snapshot 里的 `tier1_states` 仍是 render dict
   - 绿：chunk snapshot `tier1_states` 已变为 `CityVehicleState` ref
2. `test_city_vehicle_renderer_state_ref_snapshot.gd`
   - 红：`CityVehicleTrafficRenderer._sync_agents()` 将 state ref 强行当 `Dictionary`，Tier 2 直接报脚本错误
   - 绿：renderer 已兼容 state ref 与 dict 两种输入
3. `test_city_vehicle_cached_assignment_reuse_no_snapshot_rebuild.gd`
   - 红：cached assignment reuse 仍会跑 `traffic_snapshot_rebuild_usec > 0`
   - 绿：reuse 路径 `traffic_snapshot_rebuild_usec = 0`，同时 visible chunk 仍会被标记 `dirty = true`

## 验证命令

### 新增 / 相关 world 回归

```powershell
$project='E:\development\godot_citys'
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'

$tests=@(
  'res://tests/world/test_city_vehicle_chunk_snapshot_data_refs.gd',
  'res://tests/world/test_city_vehicle_renderer_state_ref_snapshot.gd',
  'res://tests/world/test_city_vehicle_cached_assignment_reuse_no_snapshot_rebuild.gd',
  'res://tests/world/test_city_vehicle_renderer_initial_snapshot.gd',
  'res://tests/world/test_city_vehicle_batch_rendering.gd',
  'res://tests/world/test_city_vehicle_identity_continuity.gd',
  'res://tests/world/test_city_vehicle_hijack_contract.gd'
)
foreach($test in $tests){
  & $godot --headless --rendering-driver dummy --path $project --script $test
  if($LASTEXITCODE -ne 0){ exit $LASTEXITCODE }
}
```

结果：`PASS`

### fresh headless vehicle profile

```powershell
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/e2e/test_city_vehicle_performance_profile.gd'
```

结果：`PASS`

关键结果：

- warm `traffic_update_avg_usec = 507`
- warm `traffic_snapshot_rebuild_usec = 0`
- first-visit `traffic_update_avg_usec = 2625`
- first-visit `traffic_snapshot_rebuild_usec = 0`

同 session 内、本批优化前的对照值：

- warm `traffic_update_avg_usec = 605`
- first-visit `traffic_update_avg_usec = 3175`

当前判断：

- 这说明 vehicle 侧的“缓存 assignment 复用还在整块重建 snapshot”确实是肥路径之一。
- 首轮 traffic 数据化已经让 headless vehicle profile 出现可对账改善。

### fresh headless combined runtime

```powershell
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/e2e/test_city_runtime_performance_profile.gd'
```

结果：`FAIL`

关键结果：

- `wall_frame_avg_usec = 12323`
- `update_streaming_avg_usec = 3221`
- `update_streaming_renderer_sync_avg_usec = 2930`
- `traffic_update_avg_usec = 511`
- `crowd_update_avg_usec = 719`
- `hud_refresh_avg_usec = 390`

当前判断：

- 当前批次改动没有把 combined runtime 一把打穿到 `<= 11000 usec`。
- 但 combined runtime 里的 traffic 子项已经明显收敛到较低区间，说明下一步更该继续处理：
  - crowd 侧的结构性成本
  - 真实渲染下的 `renderer_sync`
  - HUD / minimap 与高频 runtime 刷新之间的耦合

## 结论

- `v36` 第一刀已经落地，而且不是参数微调，而是明确的结构性减重：
  - traffic chunk snapshot 数据化
  - cached assignment reuse 去掉整块 snapshot rebuild
- 这批改动已经拿到了新的 contract tests 和 headless vehicle profile 改善证据。
- `v36` 仍未进入 closeout：
  - combined runtime 仍未守住 `11000 usec` warm 线
  - 更关键的真实渲染 `inspection/live gunshot` 证据还没 fresh rerun

## 下一步

1. 将相同思路继续推进到 crowd 热路径，优先检查是否仍存在全量 rebuild / payload copy。
2. 审计 HUD / minimap 与 runtime 刷新耦合，避免在高频 traversal 中放大 frame jitter。
3. 以 rendered diagnostics / performance rerun 作为下一批收口证据，不拿 headless 改善冒充实机改善。

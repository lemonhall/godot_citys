# V16 M3 Verification - 2026-03-16

## Scope

- REQ-0009-001 `building inspection -> KP+ -> async export request`
- REQ-0009-002 `independent building scene + manifest sidecar`
- REQ-0009-003 `next-session / remount override replacement`
- REQ-0009-004 `v15 inspection + profiling guard no regression`

## Fresh Verification Commands

在 `E:\development\godot_citys`，串行执行：

```powershell
$project='E:\development\godot_citys'
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'
$tests=@(
  'res://tests/world/test_city_building_serviceability_export.gd',
  'res://tests/world/test_city_building_override_registry_priority.gd',
  'res://tests/e2e/test_city_building_serviceability_flow.gd',
  'res://tests/world/test_city_player_laser_designator.gd',
  'res://tests/world/test_city_chunk_setup_profile_breakdown.gd',
  'res://tests/e2e/test_city_runtime_performance_profile.gd',
  'res://tests/e2e/test_city_first_visit_performance_profile.gd'
)
foreach($test in $tests){
  & $godot --headless --rendering-driver dummy --path $project --script $test
  if($LASTEXITCODE -ne 0){ exit $LASTEXITCODE }
}
```

## Results

1. `res://tests/world/test_city_building_serviceability_export.gd`
   - `PASS`
   - 证明 `configure_building_serviceability_paths()`、`request_export_from_last_building_inspection()`、`get_building_export_state()`、`get_building_override_entry()` 已正式存在。
   - 证明导出 job 会进入 `running`，随后完成为 `completed`。
   - 证明 scene 与 manifest 真实落盘，scene 可被 `PackedScene` 再次 `load + instantiate`。
   - 证明 registry entry 已按 `building_id` 持久化，并且 HUD Toast 会报告重构结果。
   - 证明重复导出同一 `building_id` 会被拒绝，不会静默覆盖已有功能场景。

2. `res://tests/world/test_city_building_override_registry_priority.gd`
   - `PASS`
   - 证明 preferred registry 的同 `building_id` entry 会压住 fallback，同一建筑不会被低优先级 registry 反向覆盖。

3. `res://tests/e2e/test_city_building_serviceability_flow.gd`
   - `PASS`
   - 证明 `laser -> KP+ -> async running -> completion Toast -> next world session override mount` 整链路成立。
   - 证明 override node 带有 `city_building_override=true` 与 `city_building_override_scene_path=<scene_path>` 元数据。
   - 证明没有 override entry 的其他建筑继续走 procedural 链。

4. `res://tests/world/test_city_player_laser_designator.gd`
   - `PASS`
   - 证明 `v15` inspection/HUD/clipboard/building_id contract 未回退。

5. `res://tests/world/test_city_chunk_setup_profile_breakdown.gd`
   - `PASS`
   - `CITY_CHUNK_SETUP_PROFILE total_usec=3596 buildings_usec=2184 ground_usec=1096`

6. `res://tests/e2e/test_city_runtime_performance_profile.gd`
   - `PASS`
   - `CITY_PROFILE_REPORT wall_frame_avg_usec=10405 wall_frame_max_usec=33733 update_streaming_avg_usec=8670 frame_step_avg_usec=8981`

7. `res://tests/e2e/test_city_first_visit_performance_profile.gd`
   - `PASS`
   - `CITY_FIRST_VISIT_REPORT wall_frame_avg_usec=15259 wall_frame_max_usec=57409 update_streaming_avg_usec=14436 frame_step_avg_usec=14736`

## Implementation Notes Verified

- 导出入口冻结为最近一次有效 building inspection 后的小键盘 `+`。
- 导出 job 使用 `Thread` 异步执行，主线程只轮询完成并提交 registry/Toast。
- 导出产物默认按可配置 scene root 落盘；测试通过 `configure_building_serviceability_paths()` 强制写入 `user://serviceability_tests/...`，避免污染仓库源码目录。
- 已存在功能建筑 override 的 `building_id` 会被明确拒绝导出，防止覆盖后续人工编辑内容。
- registry preferred/fallback 合并遵循 preferred 优先，fallback 只补缺。
- override 替换只发生在 next-session / chunk remount 的 near build 链，没有引入当前 session 热替换，也没有引入 per-frame 全量 registry 扫描。

## Closeout

- `v16` 的 M1/M2/M3 本轮均有 fresh rerun 证据。
- 当前未发现 `v15 inspection`、`streaming mount`、`profiling guard` 回退证据。

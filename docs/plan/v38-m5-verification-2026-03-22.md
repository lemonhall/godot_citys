# V38 M5 Verification 2026-03-22

## Scope

本次验证覆盖 `v38 lake leisure and fishing foundation` 的正式 closeout：

- `terrain_region_feature -> lake basin -> fish school` shared layer `1/2`
- `LakeFishingLab.tscn` 的同湖复现、下水观察与最小 fishing 闭环
- 主世界 `chunk_147_181` 正式 lake region + fishing venue 接入
- `ambient_simulation_freeze`、`release_buffer = 32m`、`full_map icon_id = fishing`
- 受影响旧链回归：
  - `scene_minigame_venue` registry/runtime
  - soccer / tennis / missile command
  - terrain LOD contract
- profiling 三件套：
  - `chunk setup`
  - `first-visit`
  - `warm runtime`

## Command

```powershell
$project='E:\development\godot_citys'
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'
$tests=@(
  'res://tests/world/test_city_terrain_region_feature_registry_runtime.gd',
  'res://tests/world/test_city_lake_region_manifest_contract.gd',
  'res://tests/world/test_city_lake_bathymetry_contract.gd',
  'res://tests/world/test_city_lake_water_surface_contract.gd',
  'res://tests/world/test_city_lake_fish_school_contract.gd',
  'res://tests/world/test_city_lake_swim_observer_contract.gd',
  'res://tests/world/test_city_lake_lab_scene_contract.gd',
  'res://tests/world/test_city_lake_lab_observer_contract.gd',
  'res://tests/world/test_city_fishing_minigame_venue_manifest_contract.gd',
  'res://tests/world/test_city_fishing_venue_cast_loop_contract.gd',
  'res://tests/world/test_city_fishing_venue_ambient_freeze_contract.gd',
  'res://tests/world/test_city_fishing_venue_reset_on_exit_contract.gd',
  'res://tests/world/test_city_fishing_full_map_pin_contract.gd',
  'res://tests/world/test_city_lake_main_world_port_contract.gd',
  'res://tests/e2e/test_city_lake_lab_fishing_flow.gd',
  'res://tests/e2e/test_city_lake_fishing_flow.gd',
  'res://tests/world/test_city_scene_minigame_venue_registry_runtime.gd',
  'res://tests/world/test_city_soccer_venue_ambient_freeze_contract.gd',
  'res://tests/world/test_city_tennis_runtime_aggregate_contract.gd',
  'res://tests/world/test_city_missile_command_full_map_pin_contract.gd',
  'res://tests/world/test_city_terrain_lod_contract.gd',
  'res://tests/world/test_city_terrain_lod_lazy_mount.gd',
  'res://tests/world/test_city_terrain_lod_noop.gd'
)
foreach($test in $tests){
  & $godot --headless --rendering-driver dummy --path $project --script $test
  if($LASTEXITCODE -ne 0){ exit $LASTEXITCODE }
}
```

```powershell
$project='E:\development\godot_citys'
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_chunk_setup_profile_breakdown.gd'
if($LASTEXITCODE -ne 0){ exit $LASTEXITCODE }
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/e2e/test_city_first_visit_performance_profile.gd'
if($LASTEXITCODE -ne 0){ exit $LASTEXITCODE }
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/e2e/test_city_runtime_performance_profile.gd'
if($LASTEXITCODE -ne 0){ exit $LASTEXITCODE }
```

## Result

| Area | Result | Notes |
|---|---|---|
| shared lake registry/runtime | PASS | `terrain_region_feature` registry、lake manifest、bathymetry、水面与 fish school contract 全部通过 |
| lab lake observer | PASS | `LakeFishingLab.tscn` 能复用同湖真源，下水观察与 fish school 可见性 contract 通过 |
| lab fishing minigame | PASS | `seat -> cast -> bite/miss -> reset` 在 lab headless flow 通过 |
| main-world fishing port | PASS | 主世界 `chunk_147_181` 复用 shared lake/fishing runtime；pin/freeze/full flow 通过 |
| old minigame regressions | PASS | `scene_minigame_venue` registry、soccer、tennis、missile command 关键链未回退 |
| terrain LOD regressions | PASS | `contract`、`lazy_mount`、`noop` 全部通过 |

## Profiling

| Profile | Result | Key numbers |
|---|---|---|
| `test_city_chunk_setup_profile_breakdown.gd` | PASS | `total_usec = 736` |
| `test_city_first_visit_performance_profile.gd` | PASS | `streaming_mount_setup_avg_usec = 1802`、`update_streaming_avg_usec = 11118`、`wall_frame_avg_usec = 15728` |
| `test_city_runtime_performance_profile.gd` | PASS | `streaming_mount_setup_avg_usec = 292`、`update_streaming_avg_usec = 2349`、`wall_frame_avg_usec = 8974` |

## Notes

- 本轮 closeout 中补了一个真实 failure：
  - `test_city_fishing_venue_reset_on_exit_contract.gd`
  - 根因是 fishing runtime 先把 player 重新吸回座位，再检查 `release_buffer`，导致越界 reset 永远看不到真实离场位置
  - 修复后改为先判定是否越界，再决定是否继续 seat-lock
- 为了把 `first-visit` 稳定压回红线，又做了两类热路径收口：
  - fishing runtime 的每帧 `update()` 改成返回紧凑 summary，不再在热路径 deep-copy 全量状态
  - lake polygon / bounds 预计算进 runtime contract，并在 `CityPrototype` 中对离湖 chunk 的 water query 做 broad-phase 跳过
- 本次验证没有改 DoD，也没有新增 ECN。

# V36 M3 Verification - 2026-03-21

## 范围

本次验证覆盖 `v36` flat-ground pivot 的第二次收口调整：

- 在既有“地形统一到平面”基础上，进一步按主世界手测反馈，暂时取消高架桥 / bridge deck 运行时语义
- 世界道路继续保留 `expressway_elevated` 这类道路类别用于宽度/密度/命名，但不再生成抬升 bridge geometry / collision / proxy
- 车辆 drive surface 也不再需要理解桥面高度，统一回到共享平面 `y=0`

## 本批代码切片

修改文件：

- `city_game/world/rendering/CityRoadLayoutBuilder.gd`
- `tests/world/test_city_vehicle_drive_surface_grounding.gd`
- `tests/world/test_city_bridge_deck_collision.gd`
- `tests/world/test_city_bridge_midfar_visibility.gd`
- `tests/world/test_city_bridge_grade_constraints.gd`
- `tests/world/test_city_road_network_continuity.gd`
- `tests/world/test_city_road_section_templates.gd`
- `docs/ecn/ECN-0027-flat-ground-runtime-simplification.md`
- `docs/plan/v36-index.md`
- `docs/plan/v36-flat-ground-runtime-simplification.md`

## TDD 证据

先红后绿：

1. `test_city_vehicle_drive_surface_grounding.gd`
   - 红：`expressway_expected_y` 仍高于 `0`
   - 绿：普通道路与 expressway 都回到 `y=0`
2. `test_city_bridge_deck_collision.gd`
   - 红：`bridge_count > 0`
   - 绿：`bridge_count / bridge_collision_shape_count / clearance / thickness` 全部归零
3. `test_city_bridge_midfar_visibility.gd`
   - 红：`BridgeProxy` 仍然存在
   - 绿：chunk scene 不再挂载 `BridgeProxy`

## 验证命令

### headless parse

```powershell
$project='E:\development\godot_citys'
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'
& $godot --headless --rendering-driver dummy --path $project --quit
```

结果：`PASS`

### 受影响 world 回归

```powershell
$tests=@(
  'res://tests/world/test_city_terrain_sampler.gd',
  'res://tests/world/test_city_chunk_setup_profile_breakdown.gd',
  'res://tests/world/test_city_pedestrian_runtime_grounding.gd',
  'res://tests/world/test_city_vehicle_drive_surface_grounding.gd',
  'res://tests/world/test_city_bridge_deck_collision.gd',
  'res://tests/world/test_city_bridge_midfar_visibility.gd',
  'res://tests/world/test_city_bridge_grade_constraints.gd',
  'res://tests/world/test_city_road_network_continuity.gd',
  'res://tests/world/test_city_road_section_templates.gd'
)
foreach($test in $tests){
  & $godot --headless --rendering-driver dummy --path $project --script $test
  if($LASTEXITCODE -ne 0){ exit $LASTEXITCODE }
}
```

结果：`PASS`

关键输出：

- `test_city_chunk_setup_profile_breakdown.gd`
  - `ground_mesh_usec = 47`
  - `ground_collision_face_count = 2`
  - `total_usec = 1158`
- `test_city_vehicle_drive_surface_grounding.gd`
  - `road_expected_y = 0.0`
  - `expressway_expected_y = 0.0`
  - `road_grounded_y = 0.0`
  - `expressway_grounded_y = 0.0`

### first-visit performance guard

```powershell
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/e2e/test_city_first_visit_performance_profile.gd'
```

结果：`FAIL`

关键结果：

- `wall_frame_avg_usec = 21629`
- `update_streaming_avg_usec = 15835`
- 失败点：`update_streaming_avg_usec > 14500`

当前判断：

- 这说明高架桥语义取消已经收进 flat-ground world contract，但 `v36` 的 first-visit 性能红线并未因此自动收口
- 这是 `v36` 既有性能问题的一部分，不能把这次 no-bridge 改动包装成性能 closeout

### warm runtime performance guard

```powershell
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/e2e/test_city_runtime_performance_profile.gd'
```

结果：`FAIL`

关键结果：

- `wall_frame_avg_usec = 11428`
- `ped_tier1_count = 169`
- 失败点：`wall_frame_avg_usec > 11000`

附带现象：

- Godot 退出时仍打印大量 leak warning：
  - `RID allocations leaked`
  - `Leaked instance dependency`
  - `ObjectDB instances leaked`

当前判断：

- `M3` 的功能目标已完成，但性能 closeout 与 teardown leak 问题仍未完成

## 结论

- 主世界“整城平面化 + 取消高架桥系统”的功能口径已经落地。
- 车辆、道路、chunk scene 的 bridge 运行时语义已退场，不再出现“需要继续理解桥面高度”的 contract。
- `v36` 仍未 closeout：
  - first-visit performance guard 仍红
  - warm runtime performance guard 仍红
  - headless teardown leak warning 仍待单列处理

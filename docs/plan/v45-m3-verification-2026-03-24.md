# V45 M3 Verification - 2026-03-24

## Scope

验证 `v45` 的世界方向与 compass 体系是否已经正式收口：

- 共享 `CityWorldOrientation` 是否冻结 `北=-Z / 东=+X / 北=0°顺时针增加`
- minimap 与 full map 是否显式暴露 north-up contract
- 主世界 HUD 是否挂上正式 compass strip，并按统一口径输出 bearing
- `M777HowitzerLab` 是否复用同一套 compass / orientation 语义

## Commands

### 1. 文档冻结追溯

```powershell
rg -n "north-up|Vector3\(0, 0, -1\)|东 = 90|CityCompassStrip|CityWorldOrientation|M777HowitzerLab" docs/prd/PRD-0030-world-orientation-and-compass-system.md docs/plan/v45-index.md docs/plan/v45-world-orientation-and-compass.md docs/plans/2026-03-24-v45-world-orientation-and-compass-design.md
```

结果：

- exit code `0`
- 四份文档均命中：
  - 共享 north/east 定义
  - bearing 口径
  - `CityWorldOrientation`
  - `CityCompassStrip`
  - `M777HowitzerLab`

### 2. 项目解析检查

```powershell
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'
& $godot --headless --rendering-driver dummy --path E:\development\godot_citys --quit
```

结果：

- exit code `0`
- Godot headless 成功启动并退出，无脚本解析错误或资源缺失报错

### 3. Focused Orientation / HUD / Artillery Regression Suite

```powershell
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'
$tests=@(
  'res://tests/world/test_city_world_orientation_contract.gd',
  'res://tests/world/test_city_navigation_compass_hud_contract.gd',
  'res://tests/world/test_city_m777_howitzer_lab_compass_contract.gd',
  'res://tests/world/test_city_minimap_navigation_hud.gd',
  'res://tests/world/test_city_map_destination_contract.gd',
  'res://tests/world/test_city_m777_howitzer_scene_contract.gd',
  'res://tests/world/test_city_m777_howitzer_lab_scene_contract.gd'
)
foreach($test in $tests){
  & $godot --headless --rendering-driver dummy --path E:\development\godot_citys --script $test
  if($LASTEXITCODE -ne 0){ exit $LASTEXITCODE }
}
```

结果：

- exit code `0`
- 七条 tests 全部输出 `PASS`

验证覆盖：

- `test_city_world_orientation_contract.gd`
  - 共享 helper 冻结 `北=-Z / 东=+X / 北=0°顺时针增加`
  - minimap 与 full map 的投影几何满足 north-up
  - minimap snapshot 与 full map render state 都显式暴露 orientation contract
  - compass 绝对刻度标签在 `347°` 这类非整 5/10/30 相位附近仍保持连续可见，不会随着玩家 yaw 变化闪烁消失
- `test_city_navigation_compass_hud_contract.gd`
  - `CityPrototype` 暴露共享 world orientation contract
  - `PrototypeHud` 挂载正式 `Compass` 控件
  - 玩家转向东侧后，HUD / minimap / full map 的 bearing 全部进入 `90° / E` 口径
- `test_city_m777_howitzer_lab_compass_contract.gd`
  - `M777HowitzerLab` 暴露 orientation / compass state
  - lab HUD 挂载正式 `Compass` 控件
  - lab 玩家转向东侧后，bearing 进入 `90° / E`
  - reset 后恢复默认北向零位
- 原有回归继续通过：
  - `test_city_minimap_navigation_hud.gd`
  - `test_city_map_destination_contract.gd`
  - `test_city_m777_howitzer_scene_contract.gd`
  - `test_city_m777_howitzer_lab_scene_contract.gd`

## Traceability Closeout

| Req ID | 验证方式 | 结果 |
|---|---|---|
| REQ-0030-001 | `test_city_world_orientation_contract.gd` | done |
| REQ-0030-002 | `test_city_world_orientation_contract.gd` | done |
| REQ-0030-003 | `test_city_navigation_compass_hud_contract.gd` | done |
| REQ-0030-004 | `test_city_world_orientation_contract.gd`; `test_city_navigation_compass_hud_contract.gd` | done |
| REQ-0030-005 | `test_city_m777_howitzer_lab_compass_contract.gd` | done |

## Closeout Notes

- `v45` 已把“地图北 = 地理北 = 世界北”从隐含数学约定提升为正式 contract。
- 主世界 HUD 现已具备可复用的军用风格 compass strip；`M777HowitzerLab` 与主世界共用同一套方位口径。
- 这轮仍未实现火炮自身方位角 HUD、射向/射距解算或真实炮兵火控；这些属于后续版本增量。

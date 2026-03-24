# V44 M3 Verification - 2026-03-24

## Scope

验证 `v44` 的正式火炮 scene foundation 是否已经收口：

- `CityM777Howitzer.tscn` 是否作为正式 wrapper scene 存在并包裹 `m777_3_parts.glb`
- `YawPivot` / `PitchPivot` / 手工锚点 / 最小 API 是否满足 contract
- `M777HowitzerLab.tscn` 是否复用正式 howitzer scene，并能通过稳定 API 调 yaw / pitch

## Commands

### 1. 文档冻结追溯

```powershell
rg -n "CityM777Howitzer|M777HowitzerLab|YawPivotAnchor|PitchPivotAnchor|m777_lower_base|m777_upper_carriage|m777_gun_assembly" docs/prd/PRD-0029-artillery-howitzer-scene-foundation.md docs/plan/v44-index.md docs/plan/v44-artillery-howitzer-scene-and-lab.md docs/plans/2026-03-24-v44-artillery-howitzer-scene-and-lab-design.md
```

结果：

- exit code `0`
- 四份文档均命中正式 scene 路径、lab 路径、两枚锚点与三段式节点名

### 2. 项目解析检查

```powershell
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'
& $godot --headless --rendering-driver dummy --path E:\development\godot_citys --quit
```

结果：

- exit code `0`
- Godot headless 成功启动并退出，无脚本解析错误或资源缺失报错

### 3. 正式 howitzer scene contract

```powershell
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'
& $godot --headless --rendering-driver dummy --path E:\development\godot_citys --script res://tests/world/test_city_m777_howitzer_scene_contract.gd
```

结果：

- exit code `0`
- 输出 `PASS`

验证覆盖：

- 正式 `CityM777Howitzer.tscn` 与 `CityM777Howitzer.gd` 存在
- 场景文本直接引用 `res://city_game/assets/environment/source/artillery/m777/m777_3_parts.glb`
- runtime 层级存在：
  - `ModelRoot/LowerBaseMount/m777_lower_base`
  - `ModelRoot/YawPivot/m777_upper_carriage`
  - `ModelRoot/YawPivot/PitchPivot/m777_gun_assembly`
- 两枚正式锚点存在：
  - `Anchors/YawPivotAnchor`
  - `Anchors/PitchPivotAnchor`
- root API 存在并能分别驱动 yaw / pitch

### 4. howitzer lab contract

```powershell
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'
& $godot --headless --rendering-driver dummy --path E:\development\godot_citys --script res://tests/world/test_city_m777_howitzer_lab_scene_contract.gd
```

结果：

- exit code `0`
- 输出 `PASS`

验证覆盖：

- 正式 `M777HowitzerLab.tscn` 存在
- lab 挂载的是 `res://city_game/combat/artillery/CityM777Howitzer.tscn`，不是直接挂 `glb`
- lab 包含正式 `PlayerController` 玩家节点与当前玩家相机
- lab 暴露：
  - `get_howitzer()`
  - `get_lab_state()`
  - `reset_lab_state()`
  - `adjust_yaw_degrees()`
  - `adjust_pitch_degrees()`
- lab 调角会进入 howitzer runtime state，重置后能回到中位

## Traceability Closeout

| Req ID | 验证方式 | 结果 |
|---|---|---|
| REQ-0029-001 | `test_city_m777_howitzer_scene_contract.gd` | done |
| REQ-0029-002 | `test_city_m777_howitzer_scene_contract.gd` | done |
| REQ-0029-003 | `test_city_m777_howitzer_scene_contract.gd` | done |
| REQ-0029-004 | `test_city_m777_howitzer_scene_contract.gd` | done |
| REQ-0029-005 | `test_city_m777_howitzer_lab_scene_contract.gd` | done |
| REQ-0029-006 | `test_city_m777_howitzer_lab_scene_contract.gd` | done |

## Closeout Notes

- `v44` 已完成正式火炮 wrapper scene 与独立 lab 的 foundation。
- 主世界 landmark / task / full map 接入、开火链、音效细化、后坐与交互仍保持为后续版本增量，不属于本轮范围。

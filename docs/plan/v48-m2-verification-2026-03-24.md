# V48 M2 Verification - 2026-03-24

## Scope

针对 howitzer 最新实机反馈做 fresh verification：

- `M777HowitzerLab` 的 enter radius 从 `5m` 提升到 `7m`
- `LanyardLine` 改为正式 artillery 专用 rope curve，不再复用 fishing line
- rope baseline 与操炮态 operator rope 都必须表现为连续曲线，且不能因父级缩放塌成贴地折线

## Commands

### 1. Docs Freeze Check

```powershell
rg -n "7.0m|7m|20.0m|CityArtilleryLanyardLine|连续曲线|贴地折线|REQ-0029-007|REQ-0029-008" docs/prd/PRD-0029-artillery-howitzer-scene-foundation.md docs/ecn/ECN-0032-artillery-interaction-radius-and-lanyard-curve.md docs/plan/v48-index.md docs/plan/v48-artillery-interaction-polish.md docs/plans/2026-03-24-v48-artillery-interaction-polish-design.md
```

结果：

- exit code `0`
- PRD / ECN / v48 index / v48 plan / design 全部命中新的 `7m + artillery rope curve` 口径

### 2. Focused Regression Suite

```powershell
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'
$tests=@(
  'res://tests/world/test_city_m777_howitzer_scene_contract.gd',
  'res://tests/world/test_city_m777_howitzer_lab_scene_contract.gd',
  'res://tests/world/test_city_m777_howitzer_lab_interaction_contract.gd',
  'res://tests/world/test_city_m777_howitzer_lab_compass_contract.gd',
  'res://tests/world/test_city_m777_howitzer_fire_contract.gd',
  'res://tests/world/test_city_m777_howitzer_lab_fire_interaction_contract.gd',
  'res://tests/world/test_player_controller.gd'
)
foreach($test in $tests){
  & $godot --headless --rendering-driver dummy --path E:\development\godot_citys --script $test
  if($LASTEXITCODE -ne 0){ exit $LASTEXITCODE }
}
```

结果：

- exit code `0`
- 七条 tests 全部输出 `PASS`

新增/强化覆盖：

- `test_city_m777_howitzer_scene_contract.gd`
  - `LanyardLine` 必须绑定 `CityArtilleryLanyardLine.gd`
  - howitzer scene 不得继续引用 `FishingLineVisual.gd`
- `test_city_m777_howitzer_lab_interaction_contract.gd`
  - `interaction_radius_m` 必须冻结为 `7.0m`
  - `7m` 外 prompt 隐藏，`7m` 内 prompt 出现
  - 操炮态 rope 必须暴露 `sample_count`
  - 操炮态 rope 最低点不得因为父级缩放而接近地面
- `test_city_m777_howitzer_fire_contract.gd`
  - idle baseline rope 也必须暴露 `sample_count`
  - baseline rope 最低点同样不得出现近地异常

### 3. 项目解析检查

```powershell
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'
& $godot --headless --rendering-driver dummy --path E:\development\godot_citys --quit
```

结果：

- exit code `0`
- Godot headless 成功启动并退出，无解析错误、脚本错误或资源缺失报错

## Traceability Closeout

| Req ID | 验证方式 | 结果 |
|---|---|---|
| REQ-0029-007 | `test_city_m777_howitzer_lab_interaction_contract.gd`; 本文档 | done |
| REQ-0029-008 | `test_city_m777_howitzer_scene_contract.gd`; `test_city_m777_howitzer_fire_contract.gd`; 本文档 | done |

## Closeout Notes

- enter radius 现在正式提升到 `7m`，但 `20m` retention 没动，所以操炮 ownership 语义没有重新分叉。
- `LanyardLine` 已从 fishing minigame 的三点折线实现切换到 artillery 专用脚本，并以多点采样曲线表达 rope。
- rope 的 sag 现在按 world-scale 语义生效，不再被 howitzer scene 的父级缩放放大成贴地怪线。
- 本轮没有触碰 `MuzzleFxAnchor` 的用户手调位置，也没有修改 projectile / 弹道 / 爆炸范围，`v47` 的 fire scope 继续保持。

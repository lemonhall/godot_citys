# V49 M2 Verification - 2026-03-24

## Scope

针对 howitzer fire 手感调优做 fresh verification：

- 默认 fire cooldown 从 `6.0s` 缩到 `2.0s`
- fire contract 其余部分不回退
- `CityM777Howitzer.tscn` 不再输出无效 lanyard script UID warning

## Commands

### 1. Docs Freeze Check

```powershell
rg -n "2.0s|2\.0|REQ-0029-008|cooldown" docs/prd/PRD-0029-artillery-howitzer-scene-foundation.md docs/ecn/ECN-0033-artillery-fire-cooldown-retune.md docs/plan/v49-index.md docs/plan/v49-artillery-fire-cooldown-retune.md docs/plans/2026-03-24-v49-artillery-fire-cooldown-retune-design.md
```

结果：

- exit code `0`
- PRD / ECN / v49 index / v49 plan / design 全部命中新 `2.0s` cooldown 口径

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

本轮直接证明：

- fresh howitzer runtime 的 `cooldown_duration_sec` 已变为 `2.0s`
- accepted fire 后 howitzer 进入新的 `2.0s` cooldown
- rejected fire 仍返回 `cooldown_active`
- 火光、烟尘、拉火绳、后坐与音频行为未回退
- lab fire ownership / HUD / player jump suppression 仍保持通过

### 3. 项目解析检查

```powershell
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'
& $godot --headless --rendering-driver dummy --path E:\development\godot_citys --quit
```

结果：

- exit code `0`
- headless 成功启动并退出
- 本轮输出未再出现 `CityArtilleryLanyardLine.gd` 的 invalid UID warning

## Traceability Closeout

| Req ID | 验证方式 | 结果 |
|---|---|---|
| REQ-0029-008 | `test_city_m777_howitzer_scene_contract.gd`; `test_city_m777_howitzer_fire_contract.gd`; 本文档 | done |

## Closeout Notes

- 这轮只改正式 howitzer 的默认 cooldown，lab interaction test 里人为注入的 `SHORT_TEST_COOLDOWN_SEC=0.25` 没动。
- fire presentation 与 rope / anchor / HUD contract 都保持原状，没有借 cooldown retune 顺手扩 scope。

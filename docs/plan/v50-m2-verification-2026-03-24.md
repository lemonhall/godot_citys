# V50 M2 Verification - 2026-03-24

## Scope

针对 `v50` 的 howitzer 射击诸元 HUD 与 firing solution payload 做 fresh verification：

- `PrototypeHud` 新增正式 artillery solution HUD consumer
- howitzer 在操炮态内直接显示炮口世界 bearing 与当前 pitch
- accepted fire 留下正式 firing solution payload
- 既有 howitzer scene / fire / lab / compass 合同不回退

## Commands

### 1. Docs Freeze Check

```powershell
rg -n "REQ-0029-009|REQ-0029-010|artillery solution|firing solution|world bearing|PrototypeHud|get_firing_solution_snapshot|get_last_fired_solution" docs/prd/PRD-0029-artillery-howitzer-scene-foundation.md docs/ecn/ECN-0034-artillery-firing-solution-hud-and-payload.md docs/plan/v50-index.md docs/plan/v50-artillery-firing-solution-hud.md docs/plans/2026-03-24-v50-artillery-firing-solution-hud-design.md
```

结果：

- exit code `0`
- PRD / ECN / v50 index / v50 plan / design 全部命中新引入的 artillery solution HUD 与 firing solution payload contract

### 2. Focused + Regression Suite

```powershell
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'
$tests=@(
  'res://tests/world/test_city_navigation_compass_hud_contract.gd',
  'res://tests/world/test_city_m777_howitzer_scene_contract.gd',
  'res://tests/world/test_city_m777_howitzer_fire_contract.gd',
  'res://tests/world/test_city_m777_howitzer_lab_compass_contract.gd',
  'res://tests/world/test_city_m777_howitzer_lab_interaction_contract.gd',
  'res://tests/world/test_city_m777_howitzer_lab_fire_interaction_contract.gd',
  'res://tests/world/test_city_artillery_solution_hud_contract.gd',
  'res://tests/world/test_city_m777_howitzer_firing_solution_contract.gd',
  'res://tests/world/test_city_m777_howitzer_lab_artillery_solution_contract.gd'
)
foreach($test in $tests){
  & $godot --headless --rendering-driver dummy --path E:\development\godot_citys --script $test
  if($LASTEXITCODE -ne 0){ exit $LASTEXITCODE }
}
```

结果：

- exit code `0`
- 九条 tests 全部输出 `PASS`

本轮直接证明：

- `PrototypeHud` 已挂上正式 `ArtillerySolutionHud` consumer，并暴露 `set_artillery_solution_state()` / `get_artillery_solution_state()`
- artillery solution HUD 默认隐藏，只有 howitzer 操炮态激活后可见
- HUD `yaw` 显示的是炮口当前世界 bearing，不是 howitzer 相对 yaw
- HUD `pitch` 继续复用 howitzer 校准后的 `0-71°` 仰角语义
- `CityM777Howitzer` 已暴露 `get_firing_solution_snapshot()` / `get_last_fired_solution()`
- accepted fire 会返回并落存正式 `firing_solution` payload
- payload 至少包含 world origin、chunk metadata、world bearing、pitch、shell type 与 muzzle velocity
- 既有 compass / howitzer scene / fire / lab interaction / lab fire ownership 合同未回退

### 3. 项目解析检查

```powershell
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'
& $godot --headless --rendering-driver dummy --path E:\development\godot_citys --quit
```

结果：

- exit code `0`
- headless 成功启动并退出，无解析错误、脚本错误或资源缺失报错

## Traceability Closeout

| Req ID | 验证方式 | 结果 |
|---|---|---|
| REQ-0029-009 | `test_city_artillery_solution_hud_contract.gd`; `test_city_m777_howitzer_lab_artillery_solution_contract.gd`; 本文档 | done |
| REQ-0029-010 | `test_city_m777_howitzer_firing_solution_contract.gd`; `test_city_m777_howitzer_lab_artillery_solution_contract.gd`; 本文档 | done |

## Closeout Notes

- world bearing 的真源现在是“当前动态炮口方向”，不是静态 authoring anchor，也不是 howitzer 相对 yaw 值。
- artillery solution HUD 仍然是 shared HUD consumer；`M777HowitzerLab` 只负责推状态，不持有私有 UI。
- accepted fire 现在保留 formal payload，但本轮仍然没有引入 projectile、弹道积分、落点或爆炸链。

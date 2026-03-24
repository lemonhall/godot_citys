# V51 M3 Verification - 2026-03-24

## Scope

针对 `v51` 的主世界 howitzer summon、shared operation controller 与 artillery shell ballistic 做 fresh verification：

- `KP_8` 主世界召唤 howitzer
- lab / main-world 共享 howitzer operation controller
- 主世界 accepted fire 生成 formal artillery shell
- shell impact 回填正式 explosion result，并接入主世界爆炸消费链

## Commands

### 1. Docs Freeze Check

```powershell
rg -n "REQ-0029-011|REQ-0029-012|REQ-0029-013|KP_8|CityM777HowitzerOperationController|CityArtilleryShell|ballistic|firing_solution" docs/prd/PRD-0029-artillery-howitzer-scene-foundation.md docs/ecn/ECN-0035-world-howitzer-summon-and-ballistics.md docs/plan/v51-index.md docs/plan/v51-world-howitzer-summon-and-ballistics.md docs/plans/2026-03-24-v51-world-howitzer-summon-and-ballistics-design.md
```

结果：

- exit code `0`
- PRD / ECN / v51 index / v51 plan / design 全部命中新引入的 world summon、shared controller 与 shell ballistic contract

### 2. Focused + E2E Suite

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
  'res://tests/world/test_city_m777_howitzer_lab_artillery_solution_contract.gd',
  'res://tests/world/test_city_world_howitzer_spawn_contract.gd',
  'res://tests/world/test_city_world_howitzer_interaction_contract.gd',
  'res://tests/world/test_city_world_howitzer_ballistics_contract.gd',
  'res://tests/e2e/test_city_world_howitzer_flow.gd'
)
foreach($test in $tests){
  & $godot --headless --rendering-driver dummy --path E:\development\godot_citys --script $test
  if($LASTEXITCODE -ne 0){ exit $LASTEXITCODE }
}
```

结果：

- exit code `0`
- 13 条 tests 全部输出 `PASS`

本轮直接证明：

- `CityPrototype` 已暴露 `get_active_world_howitzer()`、`get_world_howitzer_operation_state()`、`get_active_artillery_shell_count()` 与 `get_last_artillery_shell_explosion_result()`
- `KP_8` 会在玩家前方地表召唤正式 howitzer，且重复召唤不会累积多门实例
- `CityM777HowitzerOperationController` 已被 `M777HowitzerLab` 与 `CityPrototype` 共用
- 主世界 howitzer 的 `E` / `J/L` / `I/K` / `Space` / retention / HUD 语义与 lab 共线
- accepted fire 会在主世界生成 formal `CityArtilleryShell`
- shell 使用 howitzer `firing_solution` payload 作为 launch 真源
- shell 会按 gravity + `ballistic_time_scale` 飞行并留下正式 explosion result
- explosion result 至少包含 `trigger_kind`、`world_position`、`radius_m`、`distance_travelled_m`、`flight_time_sec` 与 `firing_solution`
- shell impact 已接入主世界行人 / 车辆 / 建筑 / 敌对目标爆炸消费链

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
| REQ-0029-011 | `test_city_world_howitzer_spawn_contract.gd`; 本文档 | done |
| REQ-0029-012 | `test_city_world_howitzer_interaction_contract.gd`; `test_city_world_howitzer_flow.gd`; 既有 lab howitzer focused tests；本文档 | done |
| REQ-0029-013 | `test_city_world_howitzer_ballistics_contract.gd`; `test_city_world_howitzer_flow.gd`; 本文档 | done |

## Closeout Notes

- 主世界 howitzer 的输入 ownership 已不再是 `CityPrototype` 与 `M777HowitzerLab` 两套分叉逻辑，而是 shared controller 一条主链。
- shell ballistic 保留 howitzer payload 的 `muzzle_velocity_mps` 口径，同时通过 formal `ballistic_time_scale` 缩短高抛 shot 的等待时间。
- 当前 howitzer 仍是 debug summon 能力；任务化接入、预测落点和完整火控求解属于后续版本。

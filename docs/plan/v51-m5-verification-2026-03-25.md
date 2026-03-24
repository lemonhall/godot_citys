# V51 M5 Verification - 2026-03-25

## Scope

针对 `v51` 在 `2026-03-25` 收到的 live follow-up warning 做 fresh verification：

- `CityArtilleryShell._sync_flight_visual()` 不只处理“零方向”分支，还要直接保护 Godot `look_at()` 的真实前置条件
- 当最终 `look_target` 与 `origin` 近似相等时，shell visual sync 必须显式短路，不再继续调用 `look_at()`
- 主世界 howitzer 的 ballistic / e2e 主链在补完 guard 后仍保持 green

## Commands

### 1. Focused + Main-World Ballistic Suite

```powershell
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'
$tests=@(
  'res://tests/world/test_city_artillery_shell_visual_orientation_contract.gd',
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
- 3 条 tests 全部输出 `PASS`

本轮直接证明：

- `test_city_artillery_shell_visual_orientation_contract.gd` 已显式卡住 `look_target_same_as_origin` guard，而不再只覆盖“零向量不改朝向”这一条更弱的 contract
- `CityArtilleryShell.get_debug_state()` 已暴露 `visual_sync_guard_count` 与 `last_visual_sync_guard_reason`
- shell 在 main-world ballistic 与 e2e 路径中仍能正常飞行、命中并产出正式 explosion result

### 2. 项目解析检查

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
| REQ-0029-013 | `test_city_artillery_shell_visual_orientation_contract.gd`; `test_city_world_howitzer_ballistics_contract.gd`; `test_city_world_howitzer_flow.gd`; 本文档 | done |

## Closeout Notes

- 这次修复不是继续猜“方向是不是零”，而是把 guard 直接对齐到 Godot C++ `look_at_from_position()` 的真实失败前置条件：`origin.is_equal_approx(target)`。
- 除了 `look_target_same_as_origin`，shell 现在还会显式记录 `no_valid_direction`、`non_finite_direction`、`non_finite_origin`、`non_finite_look_target`，后续再出 live warning 时，定位口径会比只有聊天截图稳定得多。

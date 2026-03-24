# V51 M4 Verification - 2026-03-24

## Scope

针对 `v51` closeout 之后用户实机反馈的两个 live 回归做 fresh stabilization verification：

- `CityArtilleryShell` 在无有效运动向量时不再把视觉朝向硬切到 fallback forward，也不再触发批量 `look_at()` 同点 warning
- 主世界 `KP_8` 召唤的 M777 保留 authored root vertical offset，不再整体悬空
- 修复 summon 高度后，主世界 howitzer 的 interaction / ballistic / e2e 主链仍保持 green

## Commands

### 1. Focused + E2E Stabilization Suite

```powershell
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'
$tests=@(
  'res://tests/world/test_city_artillery_shell_visual_orientation_contract.gd',
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
- 5 条 tests 全部输出 `PASS`

本轮直接证明：

- shell visual sync 在 `frame_delta == 0` 且 `_velocity == 0` 时，会保留最近一次有效朝向，而不是把视觉 root 硬切回世界前方
- 主世界 howitzer summon 会保留 `CityM777Howitzer.tscn` 的 authored root vertical offset，而不是把 root 吸附到原始地表采样点
- summon 修高度之后，主世界 howitzer 的 `E` 操炮、accepted fire、live shell、explosion result 与 end-to-end 流程没有被回归打断

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
| REQ-0029-011 | `test_city_world_howitzer_spawn_contract.gd`; 本文档 | done |
| REQ-0029-012 | `test_city_world_howitzer_interaction_contract.gd`; `test_city_world_howitzer_flow.gd`; 本文档 | done |
| REQ-0029-013 | `test_city_artillery_shell_visual_orientation_contract.gd`; `test_city_world_howitzer_ballistics_contract.gd`; `test_city_world_howitzer_flow.gd`; 本文档 | done |

## Closeout Notes

- 主世界 summon 高度修复采用的是 authored root vertical offset 回放，而不是额外引入新的地表贴合求解器；符合当前版本“先修 live regression，不扩 scope”的边界。
- shell warning 修复落在 `CityArtilleryShell` 自身的 visual direction contract 上，而不是在外层吞日志或改 ballistic 主链；这次修的是根因，不是症状。

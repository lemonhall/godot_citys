# V47 M3 Verification - 2026-03-24

## Scope

针对用户实机反馈的 `v47` 开火演出回归点做 fresh verification：

- 操炮态按住 `Space` 击发直到松开时，不得再串到玩家跳跃
- fire presentation 必须跟随 `MuzzleFxAnchor` / `LanyardAnchor` 的完整 transform，而不是只吃位置
- 默认拉火绳 authoring 必须具备更可靠的可见性，不再只有一个被缩放放大的占位圆柱

## Commands

### 1. Focused Regression Suite

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

- `test_city_m777_howitzer_fire_contract.gd`
  - `MuzzleFlash`
  - `MuzzleSmoke`
  - `Lanyard`
  - `LanyardLine`
  - `FireAudio`
  - 以上四个 fire presentation node 都必须继承 fire anchor 的完整 local transform 语义，而不是只同步 position
  - `LanyardLine` 必须提供线式 rope baseline，保证火绳在 gameplay camera 距离下可见
- `test_city_m777_howitzer_lab_interaction_contract.gd`
  - 进入操炮态后，`LanyardLine` 终点必须跟到玩家侧 operator anchor，而不是继续留在炮尾附近
  - 玩家在 `20m` retention 半径内移动时，rope endpoint 仍需持续跟随
- `test_city_m777_howitzer_lab_fire_interaction_contract.gd`
  - 操炮态内按住 `Space` 直到松开完成 howitzer fire 之后，玩家 `vertical_speed` 仍不得出现 jump leak
  - 同一按键既要完成 formal fire，又不能让 lab 胶囊在长按 fire press 期间恢复 jump ownership
- `test_player_controller.gd`
  - 玩家基础移动/跳跃 contract 仍保持通过，说明 jump suppression 只在 howitzer fire ownership 场景下生效，没有打坏全局移动

### 2. 项目解析检查

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
| REQ-0029-008 | `test_city_m777_howitzer_scene_contract.gd`; `test_city_m777_howitzer_fire_contract.gd`; 本文档 | done |
| REQ-0029-007 | `test_city_m777_howitzer_lab_scene_contract.gd`; `test_city_m777_howitzer_lab_fire_interaction_contract.gd`; 本文档 | done |

## Closeout Notes

- `PlayerController` 新增的是“本次 fire press 直到松开都 suppress jump”，而不是禁掉操炮态移动；用户仍可在 `20m` 保活半径内自由走位。
- fire presentation runtime 现在以 formal anchor transform 为真源，后续如果继续在编辑器里微调 `MuzzleFxAnchor` / `LanyardAnchor`，运行时会沿同一 contract 生效。
- `Lanyard` 现在退回成小把手，真正可见的火绳由 `LanyardLine` 提供，避免 `ModelRoot x10` 缩放把占位圆柱放大成奇怪的竖棒。
- 操炮态下 `LanyardLine` 现在会连到玩家侧 operator anchor；退出操炮态后再回落到 gun-local baseline，不会再只剩炮边一小截假绳子。
- 本轮仍然没有引入 projectile、弹道、落点或爆炸链，`v47` 的 scope 保持不变。

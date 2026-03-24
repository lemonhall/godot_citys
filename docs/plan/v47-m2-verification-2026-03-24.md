# V47 M2 Verification - 2026-03-24

## Scope

验证 `v47` 是否已经把 M777 的正式开火演出收口到正式 howitzer runtime：

- 正式 howitzer scene 是否 author 了 fire anchors / fire presentation nodes / fire audio
- `request_fire()` 是否实现默认 `6s` 冷却、火光、烟尘、拉火绳、后坐与音频
- lab 是否只在操炮态内允许 `Space` 击发
- HUD 是否明确显示 `Space` 提示、`装填中 X.Xs...` 与 `可击发`
- `v46` 的 lab 交互与 `v45` 的 compass 口径是否保持不回退

## Commands

### 1. 文档冻结追溯

```powershell
rg -n "REQ-0029-008|Space|6.0s|装填中 X.Xs|可击发|MuzzleFxAnchor|LanyardAnchor|projectile / grenade / missile" docs/prd/PRD-0029-artillery-howitzer-scene-foundation.md docs/ecn/ECN-0031-artillery-fire-presentation.md docs/plan/v47-index.md docs/plan/v47-artillery-fire-presentation.md docs/plans/2026-03-24-v47-artillery-fire-presentation-design.md
```

结果：

- exit code `0`
- 五份文档均命中：
  - `REQ-0029-008`
  - `Space`
  - `6.0s`
  - `装填中 X.Xs...`
  - `可击发`
  - `MuzzleFxAnchor`
  - `LanyardAnchor`
  - `projectile / grenade / missile`

### 2. Focused Artillery Fire Regression Suite

```powershell
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'
$tests=@(
  'res://tests/world/test_city_m777_howitzer_scene_contract.gd',
  'res://tests/world/test_city_m777_howitzer_lab_scene_contract.gd',
  'res://tests/world/test_city_m777_howitzer_lab_interaction_contract.gd',
  'res://tests/world/test_city_m777_howitzer_lab_compass_contract.gd',
  'res://tests/world/test_city_m777_howitzer_fire_contract.gd',
  'res://tests/world/test_city_m777_howitzer_lab_fire_interaction_contract.gd'
)
foreach($test in $tests){
  & $godot --headless --rendering-driver dummy --path E:\development\godot_citys --script $test
  if($LASTEXITCODE -ne 0){ exit $LASTEXITCODE }
}
```

结果：

- exit code `0`
- 六条 tests 全部输出 `PASS`

验证覆盖：

- `test_city_m777_howitzer_scene_contract.gd`
  - 正式 howitzer scene author 了 `MuzzleFxAnchor`、`LanyardAnchor` 与 fire presentation runtime hierarchy
  - 正式 fire API `can_fire()` / `request_fire()` / `get_fire_state()` 存在
  - 默认 fire cooldown 冻结为 `6.0s`
  - debug state 暴露 formal weapon fire audio stream
- `test_city_m777_howitzer_fire_contract.gd`
  - accepted fire 进入 cooldown
  - 触发 muzzle flash / smoke / lanyard tension / recoil / audio
  - cooldown 中重复请求被拒绝
  - 不新增 projectile / grenade / missile 节点
  - 冷却结束后 fire state 回到 idle
- `test_city_m777_howitzer_lab_scene_contract.gd`
  - lab 暴露 `request_fire()`
  - `get_lab_state()` 暴露 fire_state 与 hud_status_text
- `test_city_m777_howitzer_lab_fire_interaction_contract.gd`
  - 未进入操炮态前 `Space` 不生效
  - 进入操炮态后 `Space` 触发正式 howitzer fire
  - HUD 显示 `Space` 提示、`装填中 ...` 与 `可击发`
  - `20m` 保活半径内仍可 fire；超出后自动失效
- `test_city_m777_howitzer_lab_interaction_contract.gd`
  - `v46` 的 `E` 进入/退出、`J/L/I/K` gating 与 `20m` 自动退出仍保持全绿
- `test_city_m777_howitzer_lab_compass_contract.gd`
  - `v45` 的 compass / bearing 共享语义未被 `v47` 破坏

### 3. 项目解析检查

```powershell
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'
& $godot --headless --rendering-driver dummy --path E:\development\godot_citys --quit
```

结果：

- exit code `0`
- Godot headless 成功启动并退出，无场景解析错误、脚本错误或资源缺失报错

## Traceability Closeout

| Req ID | 验证方式 | 结果 |
|---|---|---|
| REQ-0029-008 | `test_city_m777_howitzer_scene_contract.gd`; `test_city_m777_howitzer_fire_contract.gd` | done |
| REQ-0029-007 | `test_city_m777_howitzer_lab_scene_contract.gd`; `test_city_m777_howitzer_lab_fire_interaction_contract.gd` | done |

## Closeout Notes

- `v47` 已经把 fire presentation 下沉到了正式 howitzer runtime，而不是留在 lab 私货里。
- 本轮明确只完成“开火演出”，没有引入 projectile、弹道、落点或爆炸链。
- 后续如果要推进真实炮击，需要单独设计：
  - 火炮相对回转角与世界 bearing 的换算
  - 目标点输入方式
  - 弹道 / 落点 / 爆炸 / 伤害判定

# V46 M2 Verification - 2026-03-24

## Scope

验证 `v46` 是否已经把 `M777HowitzerLab` 的操炮输入收口为近距 `E` 交互：

- 只有进入 howitzer `5m` 交互半径才出现 `按 E 操作炮`
- 进入操炮态后 HUD 是否持续显示 `J/L`、`I/K` 与 `E` 的控制提示
- 离开 `5m` 但未超过约 `20m` 时是否仍保持操炮态
- `E` 是否正确进入/退出操炮态
- `J/L/I/K` 是否只在操炮态激活时才生效
- lab 是否复用主世界 `PrototypeHud` 的 interaction prompt contract

## Commands

### 1. 文档冻结追溯

```powershell
rg -n "按 E 操作炮|20.0m|5.0m|J/L|I/K|REQ-0029-007|PrototypeHud" docs/prd/PRD-0029-artillery-howitzer-scene-foundation.md docs/ecn/ECN-0030-artillery-lab-operation-interaction.md docs/plan/v46-index.md docs/plan/v46-artillery-lab-operation-interaction.md docs/plans/2026-03-24-v46-artillery-lab-operation-interaction-design.md
```

结果：

- exit code `0`
- 五份文档均命中：
  - `REQ-0029-007`
  - `按 E 操作炮`
  - `20.0m`
  - `5.0m`
  - `J/L` / `I/K`
  - `PrototypeHud`

### 2. 项目解析检查

```powershell
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'
& $godot --headless --rendering-driver dummy --path E:\development\godot_citys --quit
```

结果：

- exit code `0`
- Godot headless 成功启动并退出，无场景解析错误、脚本错误或资源缺失报错

### 3. Focused Artillery Interaction Regression Suite

```powershell
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'
$tests=@(
  'res://tests/world/test_city_m777_howitzer_lab_interaction_contract.gd',
  'res://tests/world/test_city_m777_howitzer_lab_compass_contract.gd',
  'res://tests/world/test_city_m777_howitzer_lab_scene_contract.gd',
  'res://tests/world/test_city_m777_howitzer_scene_contract.gd'
)
foreach($test in $tests){
  & $godot --headless --rendering-driver dummy --path E:\development\godot_citys --script $test
  if($LASTEXITCODE -ne 0){ exit $LASTEXITCODE }
}
```

结果：

- exit code `0`
- 四条 tests 全部输出 `PASS`

验证覆盖：

- `test_city_m777_howitzer_lab_interaction_contract.gd`
  - 出生在交互半径外时，HUD prompt 隐藏
  - 进入 `5m` 内后，HUD 出现 `按 E 操作炮`
  - 未进入操炮态前，`J/L` 不会改变 yaw
  - 按 `E` 后进入操炮态，HUD 持续显示 `J/L`、`I/K` 与 `E` 的控制提示，`J/L` 开始生效
  - 手动按 `E` 后仍可立即退出操炮态
  - 离开 `5m` 进入半径但仍在 `20m` 内时，操炮态继续保活
  - 超过约 `20m` 后自动退出操炮态，`J/L` 再次失效
- `test_city_m777_howitzer_lab_compass_contract.gd`
  - `M777HowitzerLab` 继续暴露正式 compass / bearing state
  - HUD 切到 `PrototypeHud` 后，lab compass 仍与 `v45` 共享同一方向口径
- `test_city_m777_howitzer_lab_scene_contract.gd`
  - lab 仍然挂载正式 howitzer scene，原有 yaw / pitch / reset 合同不回退
- `test_city_m777_howitzer_scene_contract.gd`
  - howitzer 本体 scene wrapper、anchors 与 yaw / pitch runtime API 合同继续保持全绿

## Traceability Closeout

| Req ID | 验证方式 | 结果 |
|---|---|---|
| REQ-0029-007 | `test_city_m777_howitzer_lab_interaction_contract.gd` | done |

## Closeout Notes

- `v46` 已经把 howitzer `lab` 的操炮键位从全局热键收口成近距 `E` 上下文交互。
- 本轮没有引入主世界 artillery interaction，也没有处理 howitzer 的绝对 bearing / 火控解算。
- 下一轮如果要继续推进，应把“相对回转角 vs 世界 bearing vs 炮击远处目标”的交互语义单独做设计，不要混回输入所有权这条已完成链路。

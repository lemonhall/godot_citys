# V28 M4 Verification - 2026-03-19

## Status Note

- 本文记录 `v28` 在 `2026-03-19` 这一轮针对“玩家/AI 球拍可视化 + 挥拍视觉反馈”的 fresh verification。
- 本轮目标不是扩大赛制范围，而是把用户新增的视觉诉求正式收口进已存在的 tennis 主链：
  - 根目录临时模型 `Tennis racket.glb` 归置进正式 tennis 资产域
  - 玩家与 AI 对手都要 visibly equipped
  - `E` 触发 serve / return 时，至少要有可观测的挥拍假动作
- 为了避免把新 `glb` 资源绑死在编辑器 import 链上，本轮实现改为由 `TennisRacketVisualRig.gd` 直接通过 `GLTFDocument` 读取原始 `glb`，这样 headless 测试与运行时都能稳定载入。

## Scope

- asset placement
  - `city_game/assets/minigames/tennis/props/TennisRacket.glb`
- runtime visual integration
  - `PlayerController.gd`
  - `TennisOpponent.gd`
  - `CityTennisVenueRuntime.gd`
  - `TennisRacketVisualRig.gd`
- HUD / feedback polish
  - `PrototypeHud.gd`
  - `CityPrototype.gd`
- targeted regressions
  - tennis runtime aggregate / AI return / reset / scoring / e2e match flow
  - one shared player-controller smoke regression through soccer goal flow

## Asset Placement Verified

- source drop:
  - repository root `Tennis racket.glb`
- formal runtime asset:
  - `res://city_game/assets/minigames/tennis/props/TennisRacket.glb`
- integration decision:
  - 不把球拍碰撞或真实击球判定绑到球拍 mesh 上
  - 只把它作为 player/opponent 共享的 visual rig
  - 正式击球 legality 仍继续走 `CityTennisVenueRuntime` 的 shot planner / strike window contract

## Commands

```powershell
$project='E:\development\godot_citys'
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'

& $godot --headless --rendering-driver dummy --path $project --quit

$tests=@(
  'res://tests/test_city_skeleton_smoke.gd',
  'res://tests/world/test_city_tennis_runtime_aggregate_contract.gd',
  'res://tests/world/test_city_tennis_ai_return_contract.gd',
  'res://tests/world/test_city_tennis_reset_on_exit_contract.gd',
  'res://tests/world/test_city_tennis_scoring_contract.gd',
  'res://tests/e2e/test_city_tennis_singles_match_flow.gd',
  'res://tests/e2e/test_city_soccer_minigame_goal_flow.gd'
)
foreach($test in $tests){
  & $godot --headless --rendering-driver dummy --path $project --script $test
  if($LASTEXITCODE -ne 0){ exit $LASTEXITCODE }
}
```

## Fresh Results

- parse/import check
  - `--quit` -> `PASS`
- `res://tests/test_city_skeleton_smoke.gd`
  - `PASS`
- `res://tests/world/test_city_tennis_runtime_aggregate_contract.gd`
  - `PASS`
  - 验证点：
    - 玩家具备 `get_tennis_visual_state()`
    - 玩家 racket visual 在 tennis venue runtime 内可见
    - AI 对手具备 racket visual
    - tennis HUD 具备真实的 `Assist` / `Coach` 视图节点
    - HUD snapshot 暴露 `coach_text` / `coach_tone`
- `res://tests/world/test_city_tennis_ai_return_contract.gd`
  - `PASS`
  - 验证点：
    - 玩家 opening serve 会触发 `serve` 风格挥拍 visual
    - AI return 会触发对手挥拍 visual
    - 玩家回球会再次触发挥拍 visual
    - 玩家与 AI 挥拍都会触发 audible swing cue
- `res://tests/world/test_city_tennis_reset_on_exit_contract.gd`
  - `PASS`
- `res://tests/world/test_city_tennis_scoring_contract.gd`
  - `PASS`
- `res://tests/e2e/test_city_tennis_singles_match_flow.gd`
  - `PASS`
- `res://tests/e2e/test_city_soccer_minigame_goal_flow.gd`
  - `PASS`

## Verified Implementation Notes

- 玩家侧不需要真骨骼动画，仍可通过独立 `TennisRacketVisualRig` 在简化胶囊体上提供可读的 third-person 挥拍反馈。
- AI 对手继续保留现有 animated human 模型；球拍作为独立 visual rig 挂在 opponent actor 根上，不污染现有材质染色逻辑。
- `TennisRacketVisualRig` 现在同时承担：
  - 归一化球拍模型尺度
  - 挥拍 pose
  - 轻量程序化挥拍音效
- 球拍视觉与击球物理解耦：
  - `E` 触发时先给玩家 swing visual
  - 真正是否合法回球，仍由 `strike_window_state + shot planner` 决定
  - 这样即使玩家 early/late 挥空，也能看见“我确实挥拍了”
- tennis HUD 已修正为真正渲染 `Assist` / `Coach` 两行：
  - `Assist` 给出窗口/辅助态摘要
  - `Coach` 给出中文动作指令，例如发球提示、跟圈提示、READY 回球提示
- 新资源不依赖编辑器预先 import，这保证了 CI/headless 口径与本地运行口径一致。

## Remaining Work

- 本文只覆盖 `M4` 里的挥拍视觉与针对性回归，不代表 `v28` 已整体 closeout。
- 当前仍未跑 profiling 三件套，因此不能宣称 `v28` 已完成最终 closeout：
  - `res://tests/world/test_city_chunk_setup_profile_breakdown.gd`
  - `res://tests/e2e/test_city_first_visit_performance_profile.gd`
  - `res://tests/e2e/test_city_runtime_performance_profile.gd`
- 根目录原始投递文件 `Tennis racket.glb` 仍保留，当前正式 runtime 已不依赖它；后续若要清理仓库根目录，可在单独整理轮次处理。

## Closeout Call

- 球拍资产归置：green
- 玩家/AI 挂拍：green
- `E` 揮拍视觉：green
- tennis targeted regressions: green
- cross-feature smoke regression: green
- `v28` overall closeout: pending wider reruns / profiling evidence

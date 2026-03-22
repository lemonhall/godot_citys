# V39 M4 Verification 2026-03-23

## Scope

本次验证覆盖 `v39 arthropod crawler locomotion labs` 的完整 lab-first closeout：

- shared arthropod locomotion spine
- `SpiderCrawlerLab.tscn` scene / gait / terrain-follow
- `LobsterCrawlerLab.tscn` scene / metachronal gait / shared-runtime reuse
- future main-world portability contract freeze
- 两条 lab e2e：
  - spider
  - lobster

## Command

```powershell
$project='E:\development\godot_citys'
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'

& $godot --headless --rendering-driver dummy --path $project --quit
if($LASTEXITCODE -ne 0){ exit $LASTEXITCODE }

$tests=@(
  'res://tests/world/test_arthropod_crawler_shared_spine_contract.gd',
  'res://tests/world/test_spider_crawler_lab_scene_contract.gd',
  'res://tests/world/test_spider_crawler_gait_contract.gd',
  'res://tests/world/test_spider_crawler_terrain_follow_contract.gd',
  'res://tests/world/test_lobster_crawler_lab_scene_contract.gd',
  'res://tests/world/test_lobster_crawler_metachronal_gait_contract.gd',
  'res://tests/world/test_lobster_crawler_shared_runtime_contract.gd',
  'res://tests/world/test_arthropod_crawler_portability_contract.gd',
  'res://tests/e2e/test_spider_crawler_lab_flow.gd',
  'res://tests/e2e/test_lobster_crawler_lab_flow.gd'
)
foreach($test in $tests){
  & $godot --headless --rendering-driver dummy --path $project --script $test
  if($LASTEXITCODE -ne 0){ exit $LASTEXITCODE }
}
```

## Result

| Area | Result | Notes |
|---|---|---|
| shared locomotion spine | PASS | `profile / leg runtime / foothold resolver / body solver / crawler runtime` 能被 species-agnostic contract test 直接消费 |
| spider lab | PASS | spider 继续保持 8 腿 gait、stance 锁脚、坡面法线跟随与 reset contract |
| lobster lab | PASS | lobster 作为 shared runtime 第二个 consumer 落地；`metachronal_forward`、低 clearance、低 stride claw support contract 全部通过 |
| portability freeze | PASS | spider / lobster species wrapper 都暴露 `world_anchor / ground_resolver / activation_gate / spawn_policy / debug_passthrough`，lab root 本身不被当 future world wrapper |
| lab e2e | PASS | spider 与 lobster 两条独立 lab flow 都能 headless 走完整的 teleport -> step -> reset 闭环 |

## Notes

- `v39` 本轮仍然没有接入主世界；closeout 只冻结了 future port contract，不声明已有 main-world spawn/runtime。
- 蜘蛛继续使用 proxy/blockout rig；龙虾正式复用了 `res://city_game/assets/environment/source/creatures/lobster_02.glb`。
- 这轮把 `stride_scale` 正式收进 shared profile contract，用来表达 lobster cheliped 轻支撑、低推进的 profile 差异，但没有为此分叉第二套 locomotion runtime。
- 调试期临时文件 `tests/world/test_arthropod_crawler_shared_spine_smoke.gd` 已删除，避免把根因定位脚本误留成正式测试资产。

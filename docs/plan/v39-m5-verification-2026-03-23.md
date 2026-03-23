# V39 M5 Verification 2026-03-23

## Scope

本次验证覆盖 `v39` 在 spider realism 方向上的增量 closeout：

- spider proxy 从单一 box body 改成 `prosoma + abdomen`
- spider leg visual contract 收紧为明显 distal-biased ratio
- spider display foot 从 locked foothold 瞬移改成 swing arc
- 默认 `SpiderCrawlerLab.tscn` 切到 `hybrid_focus`
- 当前仓库正式 spider 场景入口收口为单一 `SpiderCrawlerLab.tscn`

## Command

```powershell
$project='E:\development\godot_citys'
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'

& $godot --headless --rendering-driver dummy --path $project --quit
if($LASTEXITCODE -ne 0){ exit $LASTEXITCODE }

$tests=@(
  'res://tests/world/test_spider_crawler_leg_visual_contract.gd',
  'res://tests/world/test_spider_crawler_lab_scene_contract.gd',
  'res://tests/world/test_spider_crawler_lab_demo_contract.gd',
  'res://tests/world/test_spider_crawler_gait_contract.gd',
  'res://tests/world/test_spider_crawler_terrain_follow_contract.gd',
  'res://tests/e2e/test_spider_crawler_lab_flow.gd'
)
foreach($test in $tests){
  & $godot --headless --rendering-driver dummy --path $project --script $test
  if($LASTEXITCODE -ne 0){ exit $LASTEXITCODE }
}
```

## Result

| Area | Result | Notes |
|---|---|---|
| body silhouette | PASS | `CitySpiderCrawler.tscn` 现在明确暴露 `ProsomaMesh` 与 `AbdomenMesh`，不再是单一 `BodyMesh` 黑盒 |
| leg proportion | PASS | `test_spider_crawler_leg_visual_contract.gd` 现在卡住 distal > proximal，并验证前腿长于内侧中腿 |
| swing arc | PASS | leg visual state 现在暴露 `display_foot_world_position`，至少一条非 stance 腿会出现可见抬脚轨迹 |
| single lab entry | PASS | `SpiderCrawlerLab.tscn` 作为唯一正式 spider lab 入口，原有 scene/demo/gait/terrain/e2e 主链继续通过 |

## Notes

- 这轮仍然是 `lab-first` closeout，不宣称已经接入主世界。
- realism 提升主要发生在 spider wrapper / visual sync 层，没有分叉第二套 arthropod shared runtime。
- 早期实验里曾存在多方案 lab；当前仓库已清理为单一正式入口，避免 spider scene 继续膨胀。

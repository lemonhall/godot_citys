# V39 M8 Verification 2026-03-23

## Scope

本次验证覆盖 spider 第三轮 reference 对齐，也就是继续把 `PhilS94/Unity-Procedural-IK-Wall-Walking-Spider` 从“外层 stepping 节奏”往“内部原理块”拆开，对齐到当前 Godot 实现：

- `IKStepper.stepCheck()` 对齐为 stillness-gated step desire
- `IKStepper.findTargetOnSurface()` 对齐为 prediction/default 双家族的 structured surface search
- `Spider.getLegsCentroid()` / `Spider.GetLegsPlaneNormal()` 对齐为显式的 leg-centroid / plane-normal body solver debug contract
- `Spider.Update()` 里的 body centroid / body normal smoothing 对齐为 spider body visual smoothing，并新增 chase 态 lateral jitter guard
- 继续保留上一轮已经完成的 timer-based tetrapod scheduler

## Command

```powershell
$project='E:\development\godot_citys'
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'

& $godot --headless --rendering-driver dummy --path $project --quit
if($LASTEXITCODE -ne 0){ exit $LASTEXITCODE }

$tests=@(
  'res://tests/world/test_spider_crawler_reference_step_desire_contract.gd',
  'res://tests/world/test_spider_crawler_reference_surface_search_contract.gd',
  'res://tests/world/test_spider_crawler_reference_body_solver_contract.gd',
  'res://tests/world/test_spider_crawler_reference_scheduler_contract.gd',
  'res://tests/world/test_spider_crawler_reference_step_contract.gd',
  'res://tests/world/test_spider_crawler_body_target_stability_contract.gd',
  'res://tests/world/test_spider_crawler_lab_body_lateral_jitter_contract.gd',
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
| stillness-gated step desire | PASS | `test_spider_crawler_reference_step_desire_contract.gd` 证明 spider 在长时间静止后会抑制新的 step desire，而不是继续原地抖腿补锚点 |
| structured surface search | PASS | `test_spider_crawler_reference_surface_search_contract.gd` 证明 stepping leg 现在暴露 prediction/default 多候选搜索序列，而不是单一 downward ray |
| body solver debug contract | PASS | `test_spider_crawler_reference_body_solver_contract.gd` 证明 body target 现在显式暴露 `default_centroid_world_position / leg_centroid_world_position / plane_normal / centroid offsets` |
| body visual smoothing / lateral jitter guard | PASS | `test_spider_crawler_lab_body_lateral_jitter_contract.gd` 证明 spider chase gait 下的 body visual 不再逐帧硬追瞬时 centroid，adjacent lateral jump 被压回 guard 内 |
| scheduler continuity | PASS | `test_spider_crawler_reference_scheduler_contract.gd` 继续通过，说明第三轮对齐未打坏第二轮的 timer-based tetrapod cadence |
| spider focused suite | PASS | 新增 3 个 reference-internals tests 与既有 spider focused scene/demo/gait/terrain/e2e suite 全部 fresh 通过 |

## Notes

- 这轮的价值不在于“又更顺眼了一点”，而在于 reference repo 的内部原理块已经可以在当前仓库里单独追溯、单独测试。
- 本次还补抓到了一个 post-closeout 级别的 reference 细节遗漏：第三轮最初只对齐了 `centroid/plane normal` 的几何解，没把 `Spider.Update()` 里的 `delta * speed` smoothing 一起带过来，结果在 chase demo 里形成了明显的 1-2 帧 torso ghosting；现在已通过独立 jitter contract 固化。
- 当前还没有完全等价于参考项目的地方：
  - 还没有完整复刻它的全部 cast geometry 与 wall/ceiling topology
  - 还没有把 IK solve error 正式接成 `stepCheck()` 输入
  - body solver 目前已对齐 centroid/plane-normal 语义与 body smoothing 口径，但还没把全部权重参数外露成独立可配置 contract

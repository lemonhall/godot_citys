# V36 M2 Verification - 2026-03-21

## 范围

本次验证覆盖 `v36` 第二个执行切片，目标不是继续改参数，而是直接削掉 `renderer_sync` 中一条明确的无效回写路径：

- pedestrian Tier 1 `MultiMesh` batch 改为“优先复用已有实体槽位”，不再因为同一批行人仅仅换了输入顺序就整批重写 transform
- vehicle Tier 1 `MultiMesh` batch 同步改为相同语义，避免 traffic chunk snapshot 重排被放大成整批写回

这批改动针对的是 `v35`/`v36` 已锁定的近场热路径形态问题：

- `TierController` 会在重建 snapshot 时按动态顺序组织 Tier 1 state 数组
- `CityPedestrianCrowdBatch` 与 `CityVehicleTrafficBatch` 之前只认数组索引，不认实体身份
- 结果是“只是重排、并非位置变化”的输入，也会触发整批 `MultiMesh.set_instance_transform(...)`

## 本批代码切片

修改文件：

- `city_game/world/pedestrians/rendering/CityPedestrianCrowdBatch.gd`
- `city_game/world/vehicles/rendering/CityVehicleTrafficBatch.gd`

新增测试：

- `tests/world/test_city_pedestrian_tier1_reorder_stable_commit.gd`
- `tests/world/test_city_vehicle_tier1_reorder_stable_commit.gd`

## TDD 证据

先红后绿：

1. `test_city_pedestrian_tier1_reorder_stable_commit.gd`
   - 红：`first=2 second=2 third=1`
   - 含义：同一批行人仅仅重排，仍会重写 2 个 Tier 1 槽位
   - 绿：`first=2 second=0 third=1`
   - 含义：纯重排不再写回；只有真正移动的那个实体会触发 1 次写回
2. `test_city_vehicle_tier1_reorder_stable_commit.gd`
   - 红：`first=2 second=2 third=1`
   - 绿：`first=2 second=0 third=1`

修复方式：

- batch 内部新增 `cached_instance_state_ids`
- 每一帧先按“旧槽位里仍存活的实体 -> 新加入实体”构造 `next_slot_state_ids`
- 只有 transform/color 真变化时才写回 `MultiMesh`

这让 `Tier 1` 槽位从“数组顺序驱动”变成“实体身份优先复用”，属于结构性减重，不是参数调小。

## 验证命令

### 新增 / 相邻 world 回归

```powershell
$project='E:\development\godot_citys'
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'

$tests=@(
  'res://tests/world/test_city_pedestrian_tier1_reorder_stable_commit.gd',
  'res://tests/world/test_city_vehicle_tier1_reorder_stable_commit.gd',
  'res://tests/world/test_city_pedestrian_tier1_dirty_commit.gd',
  'res://tests/world/test_city_vehicle_renderer_initial_snapshot.gd',
  'res://tests/world/test_city_vehicle_batch_rendering.gd',
  'res://tests/world/test_city_vehicle_renderer_state_ref_snapshot.gd',
  'res://tests/world/test_city_pedestrian_chunk_snapshot_cache.gd',
  'res://tests/world/test_city_pedestrian_tier2_visual_instances.gd'
)
foreach($test in $tests){
  & $godot --headless --rendering-driver dummy --path $project --script $test
  if($LASTEXITCODE -ne 0){ exit $LASTEXITCODE }
}
```

结果：`PASS`

### fresh headless combined runtime

```powershell
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/e2e/test_city_runtime_performance_profile.gd'
```

结果：`FAIL`

失败原因：

- 不是 frame-time 继续超线
- 而是冻结 density guard 仍失败：`ped_tier1_count = 108 < 150`

关键结果：

- `wall_frame_avg_usec = 10204`，相对上一批的 `12323` 明显下降
- `update_streaming_renderer_sync_avg_usec = 2590`，相对上一批的 `2930` 下降
- `crowd_update_avg_usec = 611`，相对上一批的 `719` 下降
- `traffic_update_avg_usec = 372`，相对上一批的 `511` 下降
- `hud_refresh_avg_usec = 347`，相对上一批的 `390` 小幅下降

当前判断：

- 这说明“Tier 1 重排导致的无效回写”确实是 shared runtime 热路径的一部分
- 但 `test_city_runtime_performance_profile.gd` 现在仍被 population baseline 卡住，`v36` 还不能 closeout

### density baseline 交叉检查

```powershell
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_pedestrian_lite_density_uplift.gd'
```

结果：`FAIL`

关键结果：

- `tier1_count = 103 < 150`

当前判断：

- 这说明当前工作树里的 `lite` density freeze 本身就没有重新托回 warm `>= 150`
- 因而 `test_city_runtime_performance_profile.gd` 这次卡在 `ped_tier1_count`，不能直接归咎于本批 batch 槽位复用改动
- 后续要把 density baseline 作为独立问题显式处理，不能把它和本批 `renderer_sync` 降抖收益混为一谈

### fresh rendered inspection diagnostics

```powershell
& $godot --path $project --script 'res://tests/e2e/test_city_pedestrian_high_speed_inspection_diagnostics.gd'
```

结果：`PASS`

相对 `v35` artifact 的 before/after：

- `update_streaming_renderer_sync_avg_usec`: `4371 -> 4233`
- `update_streaming_renderer_sync_crowd_avg_usec`: `1888 -> 1861`
- `update_streaming_renderer_sync_traffic_avg_usec`: `1144 -> 1075`
- `hud_refresh_avg_usec`: `2896 -> 2342`
- `minimap_build_avg_usec`: `5637 -> 4380`
- `top_frame_usec`: `43162 -> 28941`

当前判断：

- inspection 实机链路已经不是“感觉稳一点”，而是 spike 和几条主项都出现了可对账下降
- 其中 `top_frame_usec` 的收敛尤其明显，说明无效批量写回确实会放大街道抖动

### fresh rendered live gunshot diagnostics

```powershell
& $godot --path $project --script 'res://tests/e2e/test_city_pedestrian_live_gunshot_diagnostics.gd'
```

结果：`PASS`

相对上一批 artifact 的 before/after：

- `update_streaming_renderer_sync_avg_usec`: `2048 -> 1837`
- `crowd_update_avg_usec`: `701 -> 563`
- `frame_step_avg_usec`: `9078 -> 8005`
- `traffic_update_avg_usec`: `505 -> 458`

当前判断：

- live gunshot 这条带 panic / combat 压力的链路也同步变轻了
- 说明这批 batch 槽位复用收益不只体现在 inspection 空跑上

### rendered performance guard 交叉检查

```powershell
& $godot --path $project --script 'res://tests/e2e/test_city_pedestrian_high_speed_inspection_performance.gd'
& $godot --path $project --script 'res://tests/e2e/test_city_pedestrian_live_gunshot_performance.gd'
```

结果：`FAIL`

`test_city_pedestrian_high_speed_inspection_performance.gd`

- `wall_frame_avg_usec = 20564 > 16667`
- `scenario_avg_tier1_count = 146 < 180`

`test_city_pedestrian_live_gunshot_performance.gd`

- `wall_frame_avg_usec = 15542`，frame-time 守住红线
- 但 `scenario_avg_tier1_count = 114 < 140`
- 并且当前 run 没有观察到 sampled witness 进入 violent state，说明这条链的 density / panic 语义也还没有回到冻结口径

当前判断：

- 这批改动已经让 diagnostics 数字变好，但距离 rendered performance guard closeout 还有明显差距
- 特别是 inspection 仍是“frame-time + density”双重未收口；live gunshot 更像“density / witness 语义”未收口
- 所以下一刀不能只继续抠 `MultiMesh` 写回，还得把 density / panic baseline 和 inspection 大头一起处理

## 结论

- `v36` 第二刀已经拿到 fresh rendered 证据，证明“Tier 1 重排不再整批重写”这条改动有真实收益。
- 这批收益不是来自 density 缩水、不是来自关系统、也不是只在 headless dummy 里好看。
- `v36` 仍未 closeout：
  - `test_city_runtime_performance_profile.gd` 现在卡在 `ped_tier1_count` 冻结人口线
  - rendered performance guard 仍未通过，inspection 还卡 `wall_frame_avg_usec` 与 density，live gunshot 还卡 density / witness 语义
  - inspection/live-gunshot 还有继续往下压的空间，尤其是 crowd / HUD-minimap 耦合仍然偏贵

## 下一步

1. 继续排 `ped_tier1_count` 为什么低于冻结线，先确认这是既有 baseline 问题还是本轮链路带出来的新回归。
   - 已确认：`test_city_pedestrian_lite_density_uplift.gd` 在当前工作树也会以 warm `103 < 150` 失败，这更像是既有 baseline 漂移。
2. 继续往 crowd snapshot / assignment rebuild 的结构性成本下刀，别只停留在 batch commit。
3. 再审一轮 `CityPrototype.gd` 的 HUD/minimap 刷新耦合，把 inspection 下的高价刷新继续压低。

## 同日补充切片：gameplay farfield 回填 + retained prepare 去浪费

本轮不是新开方向，而是继续把“前两化”的两个半拉子缺口补齐：

- gameplay 行人 render capping 在高速 traversal 下会把整条街裁空
  - 根因：chunk 初次挂载时会先提交空的 gameplay Tier 1 contract，随后 `farfield_render_dirty` 在高速 traversal 下又被 defer，导致这些 chunk 长时间保留空 batch
- retained-scene 复用链虽然已经存在，但 prepare 相位仍会为这些即将复用的 chunk 白做 near 组预构
  - 根因：`_process_prepare_budget()` 无条件执行 `_prebuild_near_mount_nodes(payload)`，即使 `_take_retained_chunk_scene(chunk_id)` 后续会直接复用缓存 chunk scene

### 本批代码切片

修改文件：

- `city_game/world/rendering/CityChunkRenderer.gd`
- `tests/world/test_city_pedestrian_gameplay_render_budget.gd`

新增测试：

- `tests/world/test_city_chunk_prepare_retained_scene_reuse.gd`

### TDD 证据

先红后绿：

1. `test_city_pedestrian_gameplay_render_budget.gd`
   - 红：`pedestrian_tier1_total = 172`，但 `pedestrian_multimesh_instance_total = 0`
   - 绿：`pedestrian_multimesh_instance_total = 3`
   - 含义：gameplay 仍保留强力 capping，但不再把 traversal 走廊整片裁成空白
2. `test_city_chunk_prepare_retained_scene_reuse.gd`
   - 红：retained chunk 的 waiting payload 里仍包含 `prepared_service_roots`
   - 绿：retained chunk prepare 不再预构 `prepared_service_roots / prepared_road_overlay / prepared_street_lamps`

### 验证命令

```powershell
$project='E:\development\godot_citys'
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'

$tests=@(
  'res://tests/world/test_city_chunk_prepare_retained_scene_reuse.gd',
  'res://tests/world/test_city_pedestrian_gameplay_render_budget.gd',
  'res://tests/world/test_city_pedestrian_chunk_dirty_skip.gd',
  'res://tests/world/test_city_pedestrian_batch_rendering.gd',
  'res://tests/world/test_city_runtime_crowded_diagnostic_snapshot.gd',
  'res://tests/e2e/test_city_runtime_performance_profile.gd'
)
foreach($test in $tests){
  & $godot --headless --rendering-driver dummy --path $project --script $test
  if($LASTEXITCODE -ne 0){ exit $LASTEXITCODE }
}
```

结果：`PASS`

### 同轮 before / after

以本轮修复前的 fresh headless 结果为 before：

- `test_city_runtime_crowded_diagnostic_snapshot.gd`
  - `wall_frame_avg_usec: 12442 -> 9666`
  - `update_streaming_avg_usec: 4445 -> 2854`
  - `update_streaming_renderer_sync_avg_usec: 4106 -> 2551`
  - `update_streaming_renderer_sync_queue_avg_usec: 1926 -> 437`
  - `update_streaming_renderer_sync_queue_prepare_avg_usec: 1564 -> 48`
  - `crowd_update_avg_usec: 772 -> 764`
  - `traffic_update_avg_usec: 500 -> 496`
- `test_city_runtime_performance_profile.gd`
  - `wall_frame_avg_usec: 13059 -> 9895`
  - `update_streaming_avg_usec: 5175 -> 3079`
  - `update_streaming_renderer_sync_avg_usec: 4806 -> 2654`
  - `crowd_update_avg_usec: 1098 -> 877`
  - `traffic_update_avg_usec: 541 -> 504`
  - `ped_tier1_count: 169 -> 169`

### 当前判断

- 这说明“retained-scene prepare 白做 near 组预构”确实是 shared runtime 的大头之一，而且比这一轮 crowd / traffic 本体 update 还更贵。
- gameplay farfield 回填修复并没有靠砍 density 换性能；`ped_tier1_count` 仍保持在 `169`，`test_city_runtime_performance_profile.gd` 也重新通过了冻结线。
- 本轮仅补了 headless fresh 证据；rendered inspection / live-gunshot 还没有随这一补充切片重跑，因此这里不能把 `v36` 包装成 closeout。

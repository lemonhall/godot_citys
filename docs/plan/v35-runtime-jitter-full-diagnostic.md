# V35 Runtime Jitter Full Diagnostic

## Goal

对“沿路高速 inspection 就抖”和“炸楼/枪火引发行人恐慌会掉到 20-30 FPS”做一次真正全量的性能诊断，不再把所有问题都笼统叫成“人多了所以卡”。

## Scope

做什么：

- 跑 fresh rendered profiling，验证用户症状不是手感错觉
- 将 `inspection` 疾跑和 `panic` 威胁链分开对账
- 记录 shared runtime、crowd、traffic、HUD/minimap 的主要指标
- 给下一轮 focused diagnostics 明确边界

不做什么：

- 本轮不直接承诺修完
- 本轮不靠关系统、降密度、缩小路线来“过线”
- 本轮不把炸楼残骸问题和 inspection 疾跑问题混成一个锅

## Fresh Evidence（2026-03-21, Windows / Vulkan / Forward+）

### A. `inspection` 高速穿行

命令：

```powershell
$project='E:\development\godot_citys'
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'

& $godot --path $project --script 'res://tests/e2e/test_city_pedestrian_high_speed_inspection_performance.gd'
```

结果：`FAIL`

关键指标：

- `wall_frame_avg_usec = 28257`
- `wall_frame_max_usec = 59845`
- `update_streaming_avg_usec = 12391`
- `update_streaming_renderer_sync_avg_usec = 10935`
- `frame_step_avg_usec = 19422`
- `crowd_update_avg_usec = 2241`
- `traffic_update_avg_usec = 1661`
- `hud_refresh_avg_usec = 4391`
- `minimap_build_avg_usec = 6857`
- `minimap_rebuild_count = 6`
- `minimap_request_count = 11`
- `crowd_assignment_decision = rebuild`
- `crowd_assignment_rebuild_reason = chunk_window_changed`
- `crowd_assignment_raw_player_velocity_mps = 1542.78`
- `crowd_assignment_player_velocity_mps = 180.0`

当前判断：

1. 这条链不是单纯的 “crowd 太重”。
2. `renderer_sync` 已经单项超过 `10ms`，是第一嫌疑。
3. `HUD/minimap` 不是噪声，`hud_refresh_avg 4.39ms` + `minimap_build_avg 6.86ms` 已经足以放大抖动。
4. 当前 `inspection` 场景中，`crowd assignment` 持续因为 `chunk_window_changed` 重建，说明高速跨 chunk 窗口时 crowd 层也在不断重算。

### B. `live gunshot` 恐慌链

命令：

```powershell
$project='E:\development\godot_citys'
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'

& $godot --path $project --script 'res://tests/e2e/test_city_pedestrian_live_gunshot_performance.gd'
```

结果：`FAIL`

关键指标：

- `wall_frame_avg_usec = 21981`
- `wall_frame_max_usec = 69657`
- `update_streaming_avg_usec = 5356`
- `update_streaming_renderer_sync_avg_usec = 4521`
- `frame_step_avg_usec = 12082`
- `crowd_update_avg_usec = 1994`
- `traffic_update_avg_usec = 1329`
- `hud_refresh_avg_usec = 620`
- `minimap_rebuild_count = 0`
- `scenario_max_violent_count = 13`
- `scenario_reactive_became_violent = true`
- `crowd_assignment_decision = reuse`
- `crowd_assignment_rebuild_reason = reuse_farfield`

当前判断：

1. 这条链和 `inspection` 疾跑不是同一根因。
2. `minimap/HUD` 在这里几乎不是主矛盾。
3. `panic` 场景里，shared runtime 仍然有压力，但更显著的是 `frame_step` 和 combat/threat/crowd 叠加后的总帧成本。
4. `crowd assignment` 并没有像 inspection 那样反复 rebuild，所以“全部怪 crowd assignment”也站不住。

## 已定位的一个明确代码嫌疑

在 [CityPrototype.gd](E:/development/godot_citys/city_game/scripts/CityPrototype.gd) 的 `_refresh_hud_status()` 里，非 headless 分支会直接：

- `hud.set_minimap_snapshot(build_minimap_snapshot())`

这说明真实渲染路径下，HUD 刷新会直接带着 minimap snapshot 跑；而 `inspection` 高速穿行时，minimap cache key 不断变化，导致 `minimap_rebuild_count = 6 / request_count = 11`。这条链已经足够可疑，值得在 M2 里单独做 focused diagnostics。

## 当前结论

`v35` 的第一轮 fresh 数据支持以下结论：

- “按 `C` 沿路高速穿行就抖”是真问题，而且比红线高很多。
- “行人恐慌链掉到 20-30 FPS”也是真问题。
- 两条问题并不完全同根：
  - `inspection` 更像 `renderer_sync + HUD/minimap + crowd window churn`
  - `panic` 更像 `frame_step + shared runtime + threat/combat/crowd`

## 下一步

M2 必须补两条 diagnostics artifact：

1. `inspection_high_speed_diagnostics`
   - 打开 `set_performance_diagnostics_enabled(true)`
   - 重点看：
     - `update_streaming_renderer_sync_queue_*`
     - `crowd_assignment_*`
     - `minimap/hud` 频次与 rebuild

2. `panic_threat_chain_diagnostics`
   - 同样打开 diagnostics
   - 重点看：
     - `renderer_sync queue`
     - `crowd/threat` 细项
     - combat/projectile 对 `frame_step` 的影响

在这两条没拿到 artifact 之前，不适合直接拍脑袋优化。

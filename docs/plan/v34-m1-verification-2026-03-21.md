# V34 M1 Verification - 2026-03-21

## Scope

本轮验证覆盖：

- `BuildingCollapseLab` 三段炸楼 profiling
- `CityPrototype` 主世界近景建筑三段炸楼 profiling
- debris runtime telemetry：
  - sleeping
  - shadow caster
  - mesh / collision
  - 线速度
- 首轮最小优化：
  - 关闭 debris per-chunk dynamic shadow
  - `collapse_settle_delay_sec` 后强制 debris 进入 sleeping

## 验证命令

### Headless / Contract

```powershell
$project='E:\development\godot_citys'
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'

& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/e2e/test_building_collapse_lab_performance_profile.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/e2e/test_city_building_collapse_performance_profile.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_building_collapse_lab_flow.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_main_world_building_collapse.gd'
```

结果：全部 `PASS`

### Rendered / Fresh Artifact

```powershell
$project='E:\development\godot_citys'
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'

& $godot --path $project --script 'res://tests/e2e/test_building_collapse_lab_performance_profile.gd'
& $godot --path $project --script 'res://tests/e2e/test_city_building_collapse_performance_profile.gd'
```

显示后端：`Windows / Vulkan / Forward+ / RTX 2070 Max-Q`

artifact：

- `reports/v34/building_collapse/performance/building_collapse_lab_profile_windows.json`
- `reports/v34/building_collapse/performance/city_building_collapse_profile_windows.json`

## Before / After 摘要

### A. 实验场 `BuildingCollapseLab`

#### pre-fix（同日 console capture）

| segment | wall avg usec | draw calls | objects | chunks | sleeping | shadow casters |
|---|---:|---:|---:|---:|---:|---:|
| pre_collapse | 16188 | 131 | 217 | 0 | 0 | 0 |
| collapse_burst | 16638 | 226 | 312 | 65 | 0 | 65 |
| post_collapse_settle | 16662 | 263 | 349 | 65 | 1 | 65 |

#### after-fix（artifact）

| segment | wall avg usec | draw calls | objects | chunks | sleeping | shadow casters |
|---|---:|---:|---:|---:|---:|---:|
| pre_collapse | 16222 | 131 | 217 | 0 | 0 | 0 |
| collapse_burst | 16630 | 159 | 245 | 65 | 65 | 0 |
| post_collapse_settle | 16673 | 159 | 245 | 65 | 65 | 0 |

实验场结论：

- `draw calls` 从 `226/263` 压到 `159/159`
- `render objects` 从 `312/349` 压到 `245/245`
- `sleeping ratio` 从约 `0` 提升到 `1.0`
- 但 wall-frame 仍几乎贴着 `16.67ms` 红线，没有形成足够余量

### B. 主世界 `CityPrototype`

#### pre-fix（同日 console capture）

| segment | wall avg usec | draw calls | objects | chunks | sleeping | shadow casters | update_streaming |
|---|---:|---:|---:|---:|---:|---:|---:|
| pre_collapse | 17915 | 973 | 1072 | 0 | 0 | 0 | 4093 |
| collapse_burst | 19080 | 1110 | 1207 | 45 | 0 | 45 | 4222 |
| post_collapse_settle | 17792 | 1108 | 1205 | 45 | 0 | 45 | 3889 |

#### after-fix（artifact）

| segment | wall avg usec | draw calls | objects | chunks | sleeping | shadow casters | update_streaming |
|---|---:|---:|---:|---:|---:|---:|---:|
| pre_collapse | 17464 | 973 | 1072 | 0 | 0 | 0 | 4027 |
| collapse_burst | 18597 | 1013 | 1110 | 45 | 45 | 0 | 4149 |
| post_collapse_settle | 18810 | 1013 | 1110 | 45 | 45 | 0 | 4213 |

主世界结论：

- debris 激活后的额外 `draw calls` 从约 `+137` 降到约 `+40`
- debris 激活后的额外 `objects` 从约 `+135` 降到约 `+38`
- `sleeping ratio` 从 `0` 提升到 `1.0`
- `update_streaming_avg_usec`、`crowd_update_avg_usec`、`traffic_update_avg_usec` 都只有小幅波动，`active_rendered_chunk_count = 25`、`multimesh_instance_total = 448` 不变
- 因此这轮已经能明确说：**主世界炸楼的新增压力主要来自 debris 自身，而不是 shared streaming/crowd/traffic**

## 根因判断

本轮 fresh profiling 支持以下判断：

1. 旧实现里，debris 在 burst / settle 两段都保持：
   - `1 mesh = 1 shadow caster`
   - `1 mesh = 1 dynamic rigid body`
   - sleeping 基本为 `0`
2. shared runtime 并没有随着炸楼显著抬升：
   - `update_streaming` 只小幅变化
   - `crowd` / `traffic` 小幅变化
   - chunk 数与 multimesh 总量稳定
3. 因此第一真根因不是世界 streaming，而是 rubble field 本身在 render/physics 上的持续存在成本

这是基于 artifact 的推断，不是凭感觉。

## 当前状态

### 已完成

- M1 实验场三段 profiling
- M2 主世界三段 profiling
- debris telemetry 链
- 首轮最小 root-cause fix

### 未完成

- `v34` 还没有达到 closeout
- 主世界 `Windows/Vulkan` 仍明显高于 `16.67ms` 红线
- 当前 profiling 还没有覆盖“玩家主动走近 rubble”的 focused traversal case；用户此前报告的 `6 FPS` 更可能出现在这个子场景

## 下一轮建议

优先级从高到低：

1. 新增 `post_collapse_rubble_approach` focused profiling
   - 直接复现“靠近碎块时”的 worst-case
2. 研究 settled debris proxy
   - 在视觉 settle 后，把大量独立 debris render instance 压成更低 draw/object 成本的代理表示
3. 继续保持 shared runtime telemetry
   - 防止后续优化误伤 `crowd/traffic/streaming`

# V23 M5 Verification 2026-03-17

## Scope

本文件记录 `v23` 在 `2026-03-17` 的 fresh `v22` 式性能回归与 targeted diagnostics。目标有两个：

- 把仓库级 profiling 三件套按冻结顺序重跑，确认 `M5` 整体口径是否可 closeout。
- 把 music road 的性能问题彻底从“体感抱怨”收敛到可复现的自动驾驶 profile、A/B 诊断和 root cause 证据。

覆盖范围：

- profiling 三件套：`chunk setup -> first_visit -> warm runtime`
- music road targeted diagnostics：
  - rendered `first_visit/warm` synthetic drive profile
  - `mute-note-playback` A/B
  - `hide-key-visuals` A/B
  - runtime state getter micro-benchmark

## Frozen Command Order

```powershell
$project='E:\development\godot_citys'
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'

& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_chunk_setup_profile_breakdown.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/e2e/test_city_first_visit_performance_profile.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/e2e/test_city_runtime_performance_profile.gd'

& $godot --path $project --script 'res://tests/e2e/test_city_music_road_drive_performance_profile.gd' -- --profile-mode=first_visit --diagnostics=false --mute-note-playback=false --hide-key-visuals=false
& $godot --path $project --script 'res://tests/e2e/test_city_music_road_drive_performance_profile.gd' -- --profile-mode=warm --diagnostics=false --mute-note-playback=false --hide-key-visuals=false

& $godot --path $project --script 'res://tests/e2e/test_city_music_road_drive_performance_profile.gd' -- --profile-mode=first_visit --diagnostics=false --mute-note-playback=true --hide-key-visuals=false
& $godot --path $project --script 'res://tests/e2e/test_city_music_road_drive_performance_profile.gd' -- --profile-mode=first_visit --diagnostics=false --mute-note-playback=false --hide-key-visuals=true
```

说明：

- profiling 三件套继续沿用 `v22` 冻结顺序，避免 warm/cold 口径串味。
- music road 使用 `synthetic_drive_vehicle_teleport` 全段自动驾驶，不再依赖手动开车主观观察。
- `mute-note-playback` 只关闭 `AudioStreamPlayer.play()`，不关闭 note trigger 链。
- `hide-key-visuals` 只隐藏 key multimesh，可继续保留 runtime / note trigger / note player。

## Results

### 1. 仓库级 profiling 三件套

| 测试 | 关键指标 | 阈值 | fresh 值 | 结论 |
|---|---|---:|---:|---|
| `test_city_chunk_setup_profile_breakdown.gd` | `total_usec` | `<= 8500` | `4401` | PASS |
| `test_city_chunk_setup_profile_breakdown.gd` | `ground_usec` | `<= 1800` | `1932` | FAIL |
| `test_city_chunk_setup_profile_breakdown.gd` | `road_overlay_usec` | `<= 1400` | `4` | PASS |
| `test_city_first_visit_performance_profile.gd` | `update_streaming_avg_usec` | `<= 14500` | `16696` | FAIL |
| `test_city_first_visit_performance_profile.gd` | `wall_frame_avg_usec` | `<= 16667` | `18795` | FAIL |
| `test_city_first_visit_performance_profile.gd` | `streaming_mount_setup_avg_usec` | `<= 5500` | `5085` | PASS |
| `test_city_runtime_performance_profile.gd` | `update_streaming_avg_usec` | `<= 10000` | `7915` | PASS |
| `test_city_runtime_performance_profile.gd` | `wall_frame_avg_usec` | `<= 11000` | `11243` | FAIL |
| `test_city_runtime_performance_profile.gd` | `streaming_mount_setup_avg_usec` | `<= 5500` | `2859` | PASS |

结论：

- `M5` 整体仍然 **blocked**。
- 原因不是 music road 没修好，而是仓库级三件套仍有旧红线未过。

### 2. Music Road targeted diagnostics

| 检查项 | `wall_frame_avg_usec` | `fps_avg` | 结论 |
|---|---:|---:|---|
| rendered `first_visit`，修复前，audible | `31499` | `33.54` | 明确不过线 |
| rendered `warm`，修复前，audible | `31414` | `33.43` | 明确不过线 |
| rendered `first_visit`，`mute-note-playback=true` | `30902` | `34.00` | 仅小幅改善，音频不是主根因 |
| rendered `first_visit`，阶段性修复后，`hide-key-visuals=true` | `25929` | `39.77` | 与 `keys_on` 基本同级，键面渲染不是主根因 |
| rendered `first_visit`，最终，audible | `11526` | `91.88` | 过线 |
| rendered `warm`，最终，audible | `11009` | `95.97` | 过线 |

最终最差段（rendered audible final）：

| profile | 最差段 | `wall_frame_avg_usec` | `fps_avg` |
|---|---:|---:|---:|
| `first_visit` | `segment 8` | `14190` | `72.14` |
| `warm` | `segment 8` | `14140` | `72.77` |

说明：

- 最差段仍在谱面高密区，但已经回到 `16.67ms` 预算内。
- road-local 这条链当前已不再是 60 FPS 红线来源。

## Artifacts

- 全局三件套：
  - 终端输出为 fresh evidence，本轮未新增独立 JSON artifact。
- music road targeted reports：
  - `reports/v23/music_road/performance/music_road_drive_profile_first_visit_diag_off_mute_off_keys_on_windows.json`
  - `reports/v23/music_road/performance/music_road_drive_profile_warm_diag_off_mute_off_keys_on_windows.json`
  - `reports/v23/music_road/performance/music_road_drive_profile_first_visit_diag_off_mute_on_keys_on_windows.json`
  - `reports/v23/music_road/performance/music_road_drive_profile_first_visit_diag_off_mute_off_keys_off_windows.json`

## Root Cause Findings

### 1. 音频 overlap 不是主根因

- rendered `first_visit`：
  - `mute off = 31499 usec / 33.54 FPS`
  - `mute on = 30902 usec / 34.00 FPS`
- rendered `warm`：
  - `mute off = 31414 usec / 33.43 FPS`
  - `mute on = 31416 usec / 33.44 FPS`

结论：

- 关闭真实播放只能带来很小、且不稳定的改善。
- note player overlap 不是当前 music road 掉帧的主嫌疑。

### 2. Key multimesh / shader 也不是主根因

- 在去掉第一条 hot path 之后，`keys_on` 与 `keys_off` 的 rendered `first_visit` 基本同级：
  - `keys on = 25928 usec / 39.85 FPS`
  - `keys off = 25929 usec / 39.77 FPS`

结论：

- 用户肉眼看到“问题发生在琴键区域”是对现象的定位，不是对根因的定位。
- 键面可视化本身不是导致十几帧的主根因。

### 3. 第一条真正的 hot path：每帧 deep-copy 全量 `triggered_note_events`

修复前，landmark 对外的 `get_music_road_runtime_state()` 每帧都会经过 `CityMusicRoadRunState.get_state()`，而该方法会深拷贝整条运行过程中已累计触发的 `triggered_note_events`。

用离线 micro-benchmark 量到的 getter 成本：

| 状态 | `triggered_note_count` | `get_music_road_runtime_state()` 平均耗时 |
|---|---:|---:|
| 早段 | `64` | `807 usec` |
| 后段 | `949` | `3932 usec` |

修复后改为 compact snapshot：

| 状态 | `triggered_note_count` | 平均耗时 |
|---|---:|---:|
| 早段 | `64` | `674 usec` |
| 后段 | `949` | `640 usec` |

结论：

- 这是一个典型的“越往后开越卡”的状态 payload 膨胀 bug。
- 它直接解释了为什么坏段集中在歌曲后半段。

### 4. 第二条真正的 hot path：RunState 每帧复制 strip 数组并重建全量 phase cache

继续沿代码路径下钻后发现：

- `advance_local_vehicle_state()` 的热路径每帧都要走：
  - `definition.get_note_strips()` / `get_note_strips_descending()`
  - `_refresh_phase_cache()`
- 这些 getter 本身会复制完整 strip 数组；`_refresh_phase_cache()` 还会为所有 strip 重新构造 phase dictionary。

最终修复：

- 在 `CityMusicRoadDefinition.gd` 增加 hot-path shared view：
  - `get_note_strips_shared()`
  - `get_note_strips_descending_shared()`
  - `get_strip_shared()`
- `CityMusicRoadRunState.gd` 改成：
  - setup 时一次性缓存 shared strip views
  - crossing 检测直接走 cached arrays，不再每帧复制 strips
  - phase 改成 lazy cache，只对真正被查询到的 strip 计算
- `CityMusicRoadLandmark.gd` 对外 runtime state 改为 compact snapshot，不再携带 `triggered_note_events`

stepwise 结果：

| 阶段 | rendered `first_visit` |
|---|---:|
| 修复前 | `31499 usec / 33.54 FPS` |
| 去掉 payload 膨胀后 | `25928 usec / 39.85 FPS` |
| 再去掉 strip-copy + eager phase cache 后 | `11526 usec / 91.88 FPS` |

## Current Boundary

当前最稳定的结论是：

1. music road 的局部性能问题已经通过自动驾驶 profile + A/B diagnostics + root-cause 修复收敛完毕。
2. road-local profile 目前不但超过 `60 FPS`，而且在当前机器上已经达到 `90+ FPS`。
3. `M5` 整体仍 blocked，但阻塞项已经不再是 music road，而是仓库级 profiling 三件套的旧红线。

## Status

- `music road local performance`：fixed
- `v23 M5 overall`：blocked
- blocked 原因：
  - `chunk setup ground_usec = 1932 > 1800`
  - `first_visit update_streaming_avg_usec = 16696 > 14500`
  - `first_visit wall_frame_avg_usec = 18795 > 16667`
  - `warm runtime wall_frame_avg_usec = 11243 > 11000`

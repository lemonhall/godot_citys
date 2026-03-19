# V27 M5 Verification - 2026-03-19

## Status Note

- 本文记录 `v27` 在 `2026-03-19` 的 `M5` fresh profiling rerun。
- 本轮不是继续拉长足球 AI 调参，而是基于用户最新口径做一次 ordered profiling three-piece evidence capture。
- 用户在回滚到可玩版本后明确表示：
  - 当前足球比赛“已经可以玩儿了”
  - 球员动作“挺真实的”
  - `v27` 不再继续朝“专业足球游戏”打磨
  - 剩余更偏音效/氛围类工作移出 `v27`
- 因此本文的职责是如实记录这次 `M5` 性能证据与 closeout 口径，而不是把性能结果包装成全绿。

## Scope

- ordered profiling three-piece rerun:
  - `res://tests/world/test_city_chunk_setup_profile_breakdown.gd`
  - `res://tests/e2e/test_city_first_visit_performance_profile.gd`
  - `res://tests/e2e/test_city_runtime_performance_profile.gd`
- `v27` 版本关闭记录

## Commands

```powershell
$project='E:\development\godot_citys'
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'

& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_chunk_setup_profile_breakdown.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/e2e/test_city_first_visit_performance_profile.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/e2e/test_city_runtime_performance_profile.gd'
```

## Fresh Results

### 1. Chunk Setup

- Command:
  - `res://tests/world/test_city_chunk_setup_profile_breakdown.gd`
- Result:
  - `PASS`
- Key profile:
  - `total_usec = 2910`
  - `ground_mask_cache_hit = true`
  - `ground_runtime_page_hit = true`

### 2. First Visit

- Command:
  - `res://tests/e2e/test_city_first_visit_performance_profile.gd`
- Result:
  - `FAIL`
- Failing assertion:
  - `M4 first-visit profile must keep mount setup average at or below 5500 usec`
- Key profile:
  - `streaming_mount_setup_avg_usec = 5705`
  - `streaming_mount_setup_max_usec = 23572`
  - `wall_frame_avg_usec = 16375`
  - `wall_frame_max_usec = 71508`
- Interpretation:
  - 本次单次 first-visit run 轻微超出 mount setup 平均门槛，超线幅度约 `205 usec`
  - 因为用户本轮明确要求“性能跑一遍”，所以这里不做二次 rerun，不把单次 fail 涂抹成绿

### 3. Warm Runtime

- Command:
  - `res://tests/e2e/test_city_runtime_performance_profile.gd`
- Result:
  - `PASS`
- Key profile:
  - `streaming_mount_setup_avg_usec = 3456`
  - `streaming_prepare_profile_avg_usec = 5294`
  - `update_streaming_avg_usec = 6850`
  - `wall_frame_avg_usec = 10854`

## Closeout Call

- `M5` profiling evidence: captured
- `chunk setup`: green
- `first-visit`: red on this single recorded run
- `warm runtime`: green
- 版本结论：
  - 用户明确接受当前 `v27` 的可玩状态，并要求停止继续把它打磨成“专业足球游戏”
  - 因此 `v27` 以“功能收口完成 + M5 性能证据已记录”的口径关闭
  - 本次关闭并不宣称 profiling 三件套全绿；它只如实记录：`first-visit` 这次单次 run 仍有一个轻微超线点，但用户选择不再为 `v27` 继续投入实现时间

## Deferred Out Of Scope

- 足球专业化打磨
  - 更深的战术 AI
  - 更精细的比赛节奏平衡
  - 更完整的守门员动作细节
- 音频与表现补完
  - 音效
  - 更丰富的氛围反馈
  - 更专业化的足球 presentation polish

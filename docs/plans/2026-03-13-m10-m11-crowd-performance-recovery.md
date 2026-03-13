# M10/M11 Crowd Performance Recovery Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 在不退化 `M9` 产品需求、不降低默认人口密度目标的前提下，把 pedestrian crowd runtime 重构到能够同时满足 `REQ-0002-016` 和 `16.67ms/frame` 红线。

**Architecture:** 先做 `M10` crowd core 重构，把当前“每帧全量扫描 + 全量快照重建 + 全量 MultiMesh 提交”的 crowd runtime 改成 `page runtime + dirty scheduler + dirty snapshot + dirty render commit`。再做 `M11` 近景高保真托底，把真实模型、death visual、inspection、violent reaction 重新压到固定预算的 nearfield set 上，而不是和高密度 Tier 1 共用同一套全量帧循环。

**Tech Stack:** Godot 4.6、GDScript、MultiMesh、现有 chunk streaming/runtime profile 测试、必要时的 RenderingServer/纯数据后台准备。

---

### Task 1: 先把 crowd 热点拆到足够细，形成 M10 基线

**Files:**
- Modify: `city_game/world/pedestrians/simulation/CityPedestrianTierController.gd`
- Modify: `city_game/world/rendering/CityChunkRenderer.gd`
- Modify: `tests/e2e/test_city_pedestrian_performance_profile.gd`
- Modify: `tests/e2e/test_city_runtime_performance_profile.gd`
- Create: `tests/world/test_city_pedestrian_crowd_breakdown.gd`

**Step 1: 写失败测试**

新增 `tests/world/test_city_pedestrian_crowd_breakdown.gd`，要求 runtime profile 至少暴露以下 crowd 分项：

- `crowd_active_state_count`
- `crowd_step_usec`
- `crowd_reaction_usec`
- `crowd_rank_usec`
- `crowd_snapshot_rebuild_usec`
- `crowd_chunk_commit_usec`
- `crowd_tier1_transform_writes`

**Step 2: 跑测试到红**

Run:

```powershell
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_pedestrian_crowd_breakdown.gd'
```

Expected: FAIL，当前 profile 还没有暴露这些 crowd 内部分项。

**Step 3: 写最小实现**

在 `CityPedestrianTierController.gd` 和 `CityChunkRenderer.gd` 中补齐 crowd breakdown 计时与计数，把 profile 数据透传到两个 E2E profile 测试。

**Step 4: 跑测试到绿**

Run:

```powershell
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_pedestrian_crowd_breakdown.gd'
```

Expected: PASS，并能看到 crowd 各阶段的基线输出。

**Step 5: Commit**

```powershell
git add city_game/world/pedestrians/simulation/CityPedestrianTierController.gd city_game/world/rendering/CityChunkRenderer.gd tests/world/test_city_pedestrian_crowd_breakdown.gd tests/e2e/test_city_pedestrian_performance_profile.gd tests/e2e/test_city_runtime_performance_profile.gd
git commit -m "test: add crowd breakdown profiling guard"
```

### Task 2: 把 page 变成长期 runtime，而不是每帧临时 state 列表

**Files:**
- Create: `city_game/world/pedestrians/simulation/CityPedestrianPageRuntime.gd`
- Modify: `city_game/world/pedestrians/streaming/CityPedestrianStreamer.gd`
- Modify: `city_game/world/pedestrians/simulation/CityPedestrianTierController.gd`
- Modify: `tests/world/test_city_pedestrian_page_cache.gd`
- Create: `tests/world/test_city_pedestrian_page_runtime_contract.gd`

**Step 1: 写失败测试**

新增 `test_city_pedestrian_page_runtime_contract.gd`，断言每个 active chunk 的 crowd page：

- 具有稳定的 `page_id`
- 保留固定 `state_ids`
- 暴露 `dirty_generation` / `dirty_indices` / `tier1_slot_count`
- 不会在无结构变化时每帧重建整页对象

**Step 2: 跑测试到红**

Run:

```powershell
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_pedestrian_page_runtime_contract.gd'
```

Expected: FAIL，当前 streamer 只有 page/state 字典，没有稳定 runtime 容器。

**Step 3: 写最小实现**

创建 `CityPedestrianPageRuntime.gd`，把 `CityPedestrianStreamer.gd` 改为持有稳定 page runtime；TierController 通过 page runtime 访问 state refs、dirty bits、固定 Tier 1 slot 分配。

**Step 4: 跑测试到绿**

Run:

```powershell
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_pedestrian_page_runtime_contract.gd'
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_pedestrian_page_cache.gd'
```

Expected: PASS，page cache continuity 不回退。

**Step 5: Commit**

```powershell
git add city_game/world/pedestrians/simulation/CityPedestrianPageRuntime.gd city_game/world/pedestrians/streaming/CityPedestrianStreamer.gd city_game/world/pedestrians/simulation/CityPedestrianTierController.gd tests/world/test_city_pedestrian_page_runtime_contract.gd tests/world/test_city_pedestrian_page_cache.gd
git commit -m "refactor: add stable pedestrian page runtime"
```

### Task 3: 用增量调度替换 TierController 的全量帧循环

**Files:**
- Create: `city_game/world/pedestrians/simulation/CityPedestrianSimulationScheduler.gd`
- Modify: `city_game/world/pedestrians/simulation/CityPedestrianTierController.gd`
- Modify: `city_game/world/pedestrians/simulation/CityPedestrianReactionModel.gd`
- Modify: `city_game/world/pedestrians/simulation/CityPedestrianState.gd`
- Create: `tests/world/test_city_pedestrian_incremental_scheduler.gd`
- Modify: `tests/world/test_city_pedestrian_reactive_behavior.gd`
- Modify: `tests/world/test_city_pedestrian_streaming_budget.gd`

**Step 1: 写失败测试**

新增 `test_city_pedestrian_incremental_scheduler.gd`，断言：

- Tier 1 采用分片轮转，不再全量逐帧 step
- Tier 2 / Tier 3 仍维持高频更新
- event-free 帧里，reaction 不再对全部 active states 全量重算
- scheduler 输出 dirty pages / dirty states

**Step 2: 跑测试到红**

Run:

```powershell
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_pedestrian_incremental_scheduler.gd'
```

Expected: FAIL，当前逻辑仍对全部 active states 做 step + reaction。

**Step 3: 写最小实现**

创建 `CityPedestrianSimulationScheduler.gd`，把 TierController 中的全量 step / reaction / ranking 改成：

- Tier 3：逐帧
- Tier 2：高频固定集合
- Tier 1：page-sliced 轮转
- Reaction：按受影响 page/lane corridor 局部更新

**Step 4: 跑测试到绿**

Run:

```powershell
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_pedestrian_incremental_scheduler.gd'
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_pedestrian_reactive_behavior.gd'
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_pedestrian_streaming_budget.gd'
```

Expected: PASS，reactive behavior 和 streaming budget 继续成立。

**Step 5: Commit**

```powershell
git add city_game/world/pedestrians/simulation/CityPedestrianSimulationScheduler.gd city_game/world/pedestrians/simulation/CityPedestrianTierController.gd city_game/world/pedestrians/simulation/CityPedestrianReactionModel.gd city_game/world/pedestrians/simulation/CityPedestrianState.gd tests/world/test_city_pedestrian_incremental_scheduler.gd tests/world/test_city_pedestrian_reactive_behavior.gd tests/world/test_city_pedestrian_streaming_budget.gd
git commit -m "refactor: add incremental pedestrian scheduler"
```

### Task 4: 把 chunk snapshot 从每帧重建改成 dirty cache

**Files:**
- Create: `city_game/world/pedestrians/rendering/CityPedestrianChunkSnapshotCache.gd`
- Modify: `city_game/world/pedestrians/simulation/CityPedestrianTierController.gd`
- Modify: `city_game/world/rendering/CityChunkRenderer.gd`
- Create: `tests/world/test_city_pedestrian_chunk_snapshot_cache.gd`

**Step 1: 写失败测试**

新增 `test_city_pedestrian_chunk_snapshot_cache.gd`，断言：

- chunk snapshot 在无结构变化时复用同一容器
- 只有 dirty chunk 会进入 render commit
- tier counts 与 state refs 不会因局部变更触发全窗口重建

**Step 2: 跑测试到红**

Run:

```powershell
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_pedestrian_chunk_snapshot_cache.gd'
```

Expected: FAIL，当前 `_chunk_render_snapshots.clear()` 仍是全量重建。

**Step 3: 写最小实现**

创建 `CityPedestrianChunkSnapshotCache.gd`，把 TierController/ChunkRenderer 改成长期 snapshot cache + dirty chunk commit。

**Step 4: 跑测试到绿**

Run:

```powershell
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_pedestrian_chunk_snapshot_cache.gd'
```

Expected: PASS，并且 Task 1 的 crowd breakdown 中 `crowd_snapshot_rebuild_usec` 明显下降。

**Step 5: Commit**

```powershell
git add city_game/world/pedestrians/rendering/CityPedestrianChunkSnapshotCache.gd city_game/world/pedestrians/simulation/CityPedestrianTierController.gd city_game/world/rendering/CityChunkRenderer.gd tests/world/test_city_pedestrian_chunk_snapshot_cache.gd
git commit -m "refactor: cache pedestrian chunk snapshots"
```

### Task 5: 把 Tier 1 从整批 MultiMesh 重写改成 page-local dirty commit

**Files:**
- Create: `city_game/world/pedestrians/rendering/CityPedestrianTier1PageBuffer.gd`
- Modify: `city_game/world/pedestrians/rendering/CityPedestrianCrowdBatch.gd`
- Modify: `city_game/world/pedestrians/rendering/CityPedestrianCrowdRenderer.gd`
- Modify: `tests/world/test_city_pedestrian_batch_rendering.gd`
- Create: `tests/world/test_city_pedestrian_tier1_dirty_commit.gd`

**Step 1: 写失败测试**

新增 `test_city_pedestrian_tier1_dirty_commit.gd`，断言：

- Tier 1 buffer 具备固定 page slot 分配
- 单页局部变化不会触发所有实例重写
- profile 中 `crowd_tier1_transform_writes` 小于 `ped_tier1_count`

**Step 2: 跑测试到红**

Run:

```powershell
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_pedestrian_tier1_dirty_commit.gd'
```

Expected: FAIL，当前 `configure_from_states()` 仍全量写 transform。

**Step 3: 写最小实现**

创建 `CityPedestrianTier1PageBuffer.gd`，让 `CityPedestrianCrowdRenderer.gd` / `CityPedestrianCrowdBatch.gd` 改成 page-local slot mapping + dirty transform commit。

**Step 4: 跑测试到绿**

Run:

```powershell
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_pedestrian_tier1_dirty_commit.gd'
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_pedestrian_batch_rendering.gd'
```

Expected: PASS，Tier 1 继续保持 batched representation。

**Step 5: Commit**

```powershell
git add city_game/world/pedestrians/rendering/CityPedestrianTier1PageBuffer.gd city_game/world/pedestrians/rendering/CityPedestrianCrowdBatch.gd city_game/world/pedestrians/rendering/CityPedestrianCrowdRenderer.gd tests/world/test_city_pedestrian_tier1_dirty_commit.gd tests/world/test_city_pedestrian_batch_rendering.gd
git commit -m "refactor: add tier1 dirty multimesh commit"
```

### Task 6: 让 HUD / minimap 只消费 crowd metrics，不再绑死 crowd 主循环

**Files:**
- Modify: `city_game/scripts/CityPrototype.gd`
- Modify: `city_game/world/rendering/CityChunkRenderer.gd`
- Modify: `tests/world/test_city_prototype_ui.gd`
- Modify: `tests/world/test_city_minimap_pedestrian_debug_layer.gd`

**Step 1: 写失败测试**

扩展现有 UI/minimap 测试，断言：

- crowd metrics feed 可独立采样
- HUD/minimap 刷新不要求同步触发 crowd snapshot rebuild
- debug overlay 展开时也不强迫 mounted chunks 全量提交

**Step 2: 跑测试到红**

Run:

```powershell
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_prototype_ui.gd'
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_minimap_pedestrian_debug_layer.gd'
```

Expected: FAIL 或缺指标，当前实现仍耦合在 `update_streaming_for_position()`。

**Step 3: 写最小实现**

把 crowd metrics 采样从 crowd snapshot rebuild 中分离出来，让 `CityPrototype.gd` 消费缓存 metrics，而不是请求同帧完整 crowd snapshot。

**Step 4: 跑测试到绿**

Run:

```powershell
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_prototype_ui.gd'
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_minimap_pedestrian_debug_layer.gd'
```

Expected: PASS，UI regressions 不回退。

**Step 5: Commit**

```powershell
git add city_game/scripts/CityPrototype.gd city_game/world/rendering/CityChunkRenderer.gd tests/world/test_city_prototype_ui.gd tests/world/test_city_minimap_pedestrian_debug_layer.gd
git commit -m "refactor: decouple crowd metrics from hud and minimap"
```

### Task 7: 恢复 M9 密度合同，并用 M10 core 把 profile 压回红线

**Files:**
- Modify: `city_game/world/pedestrians/model/CityPedestrianConfig.gd`
- Modify: `city_game/world/pedestrians/model/CityPedestrianQuery.gd`
- Modify: `tests/world/test_city_pedestrian_density_order_of_magnitude.gd`
- Verify: `tests/e2e/test_city_pedestrian_performance_profile.gd`
- Verify: `tests/e2e/test_city_runtime_performance_profile.gd`

**Step 1: 写失败测试**

保持 `test_city_pedestrian_density_order_of_magnitude.gd` 的 warm `540` / first-visit `600` 不变，不允许调低阈值。

**Step 2: 跑测试到红**

Run:

```powershell
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_pedestrian_density_order_of_magnitude.gd'
```

Expected: 现状仍 FAIL，证明必须恢复高密度 contract。

**Step 3: 写最小实现**

在 M10 core 已落地后，再把 `CityPedestrianConfig.gd` / `CityPedestrianQuery.gd` 从临时止血参数恢复到高密度合同，并让 scheduler/page buffer 吸收新增成本。

**Step 4: 跑测试到绿**

Run:

```powershell
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_pedestrian_density_order_of_magnitude.gd'
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/e2e/test_city_pedestrian_performance_profile.gd'
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/e2e/test_city_runtime_performance_profile.gd'
```

Expected: density test PASS，两个 isolated profile 继续 `<= 16667`。

**Step 5: Commit**

```powershell
git add city_game/world/pedestrians/model/CityPedestrianConfig.gd city_game/world/pedestrians/model/CityPedestrianQuery.gd tests/world/test_city_pedestrian_density_order_of_magnitude.gd
git commit -m "feat: restore high-density pedestrian contract on new runtime"
```

### Task 8: M11 重新托住近景高保真，不让它回退 M8/M9

**Files:**
- Modify: `city_game/world/pedestrians/rendering/CityPedestrianVisualCatalog.gd`
- Modify: `city_game/world/pedestrians/rendering/CityPedestrianVisualInstance.gd`
- Modify: `city_game/world/pedestrians/rendering/CityPedestrianCrowdRenderer.gd`
- Modify: `city_game/world/pedestrians/simulation/CityPedestrianReactionModel.gd`
- Modify: `city_game/world/pedestrians/simulation/CityPedestrianState.gd`
- Modify: `tests/world/test_city_pedestrian_sustained_fire_reaction.gd`
- Modify: `tests/world/test_city_pedestrian_inspection_mode_non_threat.gd`
- Modify: `tests/world/test_city_pedestrian_death_visual_persistence.gd`
- Modify: `tests/e2e/test_city_pedestrian_character_visual_presence.gd`
- Modify: `tests/e2e/test_city_pedestrian_live_burst_fire_stability.gd`

**Step 1: 写失败测试**

保持 M8/M9 的近景行为测试全部为硬约束，不允许用关功能换性能。

**Step 2: 跑测试到红**

用当前 M10 runtime 跑一次近景行为回归，确认没有因 page runtime / dirty commit 把 death visual、inspection、burst-fire stability 打坏。

**Step 3: 写最小实现**

把 Tier 2 / Tier 3 promotion、death visual lifecycle、inspection/violent threat 路由重新挂到新 runtime 上，确保近景高保真只作用于固定 nearfield set。

**Step 4: 跑测试到绿**

Run:

```powershell
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_pedestrian_sustained_fire_reaction.gd'
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_pedestrian_inspection_mode_non_threat.gd'
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_pedestrian_death_visual_persistence.gd'
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/e2e/test_city_pedestrian_character_visual_presence.gd'
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/e2e/test_city_pedestrian_live_burst_fire_stability.gd'
```

Expected: PASS，M8/M9 hand-play closeout 不回退。

**Step 5: Commit**

```powershell
git add city_game/world/pedestrians/rendering/CityPedestrianVisualCatalog.gd city_game/world/pedestrians/rendering/CityPedestrianVisualInstance.gd city_game/world/pedestrians/rendering/CityPedestrianCrowdRenderer.gd city_game/world/pedestrians/simulation/CityPedestrianReactionModel.gd city_game/world/pedestrians/simulation/CityPedestrianState.gd tests/world/test_city_pedestrian_sustained_fire_reaction.gd tests/world/test_city_pedestrian_inspection_mode_non_threat.gd tests/world/test_city_pedestrian_death_visual_persistence.gd tests/e2e/test_city_pedestrian_character_visual_presence.gd tests/e2e/test_city_pedestrian_live_burst_fire_stability.gd
git commit -m "feat: stabilize nearfield pedestrian fidelity on new runtime"
```

Plan complete and saved to `docs/plans/2026-03-13-m10-m11-crowd-performance-recovery.md`. Two execution options:

**1. Subagent-Driven (this session)** - I dispatch fresh subagent per task, review between tasks, fast iteration

**2. Parallel Session (separate)** - Open new session with executing-plans, batch execution with checkpoints

Which approach?

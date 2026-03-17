# V22 Performance Redline Recovery

## Goal

把当前 shared runtime 的性能问题从“知道有红线失败”推进到“有正式基线、有中文指标词典、有排障边界、有验证闭环”。本版不新增玩法；本版的交付物首先是一份能支撑后续多个 compact 协同诊断的性能计划文档，然后才是按这份文档执行的 runtime 修复。

## PRD Trace

- Core guard: REQ-0001-006
- Core redline: REQ-0001-010
- Core terrain pipeline: REQ-0001-011
- Cross-system budget pressure: REQ-0002-007
- Crowd plateau guard: REQ-0002-016
- Traffic redline: REQ-0003-009

## Dependencies

- 依赖 `v5` 已冻结 `16.67ms/frame` 红线、warm / first-visit / chunk setup 三件套与 terrain page/async 主链。
- 依赖 `v12`、`v14`、`v21` 已把更多 runtime consumer 接到同一条 shared streaming/rendering/nav/task 链上，因此 `v22` 不允许只看单个 feature 的局部 profile。
- 依赖 `tests/world/test_city_chunk_setup_profile_breakdown.gd`、`tests/e2e/test_city_runtime_performance_profile.gd`、`tests/e2e/test_city_first_visit_performance_profile.gd` 作为正式验证口径。

## Contract Freeze

- `chunk setup` 报告只回答“单个 chunk mount/setup 的成本构成”，不是 warm/cold traversal 的总体验指标。
- `warm runtime` 报告只在 corridor 预热并进入稳定 idle 后采样，目标是观察热路径 shared runtime，而不是 startup 世界生成。
- `first-visit` 报告故意沿未访问 corridor 采样，目标是观察冷路径 shared runtime 与 cold spike；它不能和 warm profile 直接混为一谈。
- `v22` closeout 的 profiling 顺序冻结为：`chunk_setup -> first-visit -> warm runtime`。原因不是“挑好看顺序”，而是先拿真正冷路径，再拿 warm corridor，避免 warm traversal 把 cold case 的解释口径污染掉。
- `wall_frame_*` 表示围绕一次 `await process_frame` 的墙钟时间，最接近最终体感帧时长。
- `update_streaming_*` 表示 `CityPrototype` 侧 shared streaming 协调链的累计成本；它高，说明问题不止在某个单一 renderer 子阶段。
- `streaming_prepare_profile_*` 表示 prepare 阶段聚合成本；`streaming_mount_setup_*` 表示 chunk scene 实际 mount/setup 成本；`streaming_terrain_async_*` 与 `streaming_terrain_commit_*` 用于分开观察 terrain 后台准备与主线程提交。
- `crowd_*`、`traffic_*`、`ped_*`、`veh_*` 字段默认视为诊断字典，不是当前唯一阈值，但它们决定了 shared runtime 热点是否被错误地转移到了人流或车流运行时。
- 细粒度 renderer/queue 诊断默认关闭；只有显式打开 `set_performance_diagnostics_enabled(true)` 时，`update_streaming_renderer_sync_*` 与 queue 子相位字段才有意义。closeout redline 一律使用默认 guard mode，不用 diagnostics mode 的带探针数据宣称过线。
- 任何收口都必须同时维持当前 deterministic density / tier contract；不得通过回退 `ped_tier1_count`、关闭 traffic、改空场景路线来伪造达标。

## Scope

做什么：

- 固化 `2026-03-17` fresh profiling 基线
- 把三项性能护栏的测试命令、阈值、当前值与中文解释写成正式文档
- 明确 warm / first-visit 各自的失败点、共享失败点与差分嫌疑链
- 为后续 targeted diagnostics、runtime 修复与 verification artifact 提供唯一口径

不做什么：

- 不新增玩法、任务、地图或视觉交付
- 不在 `v22` 文档中擅自放宽任何现有 profiling 阈值
- 不把“有一项 PASS”包装成“性能问题已解决”
- 不以关闭系统、降密度、缩路径、改单测口径替代真实 runtime 收口

## Acceptance

1. `docs/plan/v22-index.md` 与本文件必须明确记录三项性能护栏的执行命令、阈值、当前值、失败点与差异分析。
2. 文档必须给出中文指标词典，覆盖 `chunk setup`、`warm runtime`、`first-visit` 三类输出中的核心字段家族与诊断用途。
3. 后续 `v22` 实现收口时，fresh `test_city_runtime_performance_profile.gd` 必须再次满足：
   - `wall_frame_avg_usec <= 11000`
   - `streaming_mount_setup_avg_usec <= 5500`
   - `update_streaming_avg_usec <= 10000`
   - `wall_frame_avg_usec <= 16667`
   - `ped_tier1_count >= 150`
4. 后续 `v22` 实现收口时，fresh `test_city_first_visit_performance_profile.gd` 必须再次满足：
   - `streaming_mount_setup_avg_usec <= 5500`
   - `update_streaming_avg_usec <= 14500`
   - `wall_frame_avg_usec <= 16667`
5. 后续 `v22` 实现收口时，fresh `test_city_chunk_setup_profile_breakdown.gd` 仍必须保持：
   - `total_usec <= 8500`
   - `road_overlay_usec <= 1400`
   - `ground_usec <= 1800`
6. 诊断证据必须能回答：warm 和 first-visit 的 shared runtime 退化，主要是 prepare、mount、terrain async complete、crowd runtime、traffic runtime，还是这些阶段的组合；不能只给笼统结论。
7. 反作弊条款：不得通过关闭 pedestrians/vehicles、把 density 调低、把 active chunk window 缩小、冻结 player movement、改空场景路线、只改测试阈值、或只留文档不跑 fresh profiling 来宣称完成。

## Files

- Create: `docs/plan/v22-index.md`
- Create: `docs/plan/v22-performance-redline-recovery.md`
- Future Modify: `docs/plan/v21-index.md`
- Future Modify: `docs/plan/v22-mN-verification-YYYY-MM-DD.md`
- Future Modify: `city_game/scripts/CityPrototype.gd`
- Future Modify: `city_game/world/rendering/CityChunkRenderer.gd`
- Future Modify: `city_game/world/rendering/CityChunkScene.gd`
- Future Modify: `city_game/world/pedestrians/simulation/CityPedestrianTierController.gd`
- Future Modify: `city_game/world/vehicles/simulation/CityVehicleTierController.gd`
- Future Modify: `tests/e2e/test_city_runtime_performance_profile.gd`
- Future Modify: `tests/e2e/test_city_first_visit_performance_profile.gd`
- Future Create/Modify: targeted diagnostics tests around `update_streaming` / terrain async / mount setup

## Fresh Baseline（2026-03-17）

### 串行执行命令

```powershell
$project='E:\development\godot_citys'
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'

& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_chunk_setup_profile_breakdown.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/e2e/test_city_runtime_performance_profile.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/e2e/test_city_first_visit_performance_profile.gd'
```

### 结果摘要

| 测试 | 关键指标 | 阈值 | 2026-03-17 fresh 值 | 结论 |
|---|---|---|---|---|
| `test_city_chunk_setup_profile_breakdown.gd` | `total_usec` | `<= 8500` | `3510` | PASS |
| `test_city_chunk_setup_profile_breakdown.gd` | `ground_usec` | `<= 1800` | `1024` | PASS |
| `test_city_chunk_setup_profile_breakdown.gd` | `road_overlay_usec` | `<= 1400` | `3` | PASS |
| `test_city_runtime_performance_profile.gd` | `wall_frame_avg_usec` | `<= 11000` | `12933` | FAIL |
| `test_city_runtime_performance_profile.gd` | `update_streaming_avg_usec` | `<= 10000` | `11455` | FAIL |
| `test_city_runtime_performance_profile.gd` | `streaming_mount_setup_avg_usec` | `<= 5500` | `3673` | PASS |
| `test_city_runtime_performance_profile.gd` | `ped_tier1_count` | `>= 150` | `155` | PASS |
| `test_city_runtime_performance_profile.gd` | `wall_frame_max_usec` | 诊断字段 | `78685` | 说明 warm 路线仍有明显尖峰 |
| `test_city_first_visit_performance_profile.gd` | `update_streaming_avg_usec` | `<= 14500` | `18171` | FAIL |
| `test_city_first_visit_performance_profile.gd` | `wall_frame_avg_usec` | `<= 16667` | `19213` | FAIL |
| `test_city_first_visit_performance_profile.gd` | `streaming_mount_setup_avg_usec` | `<= 5500` | `5300` | PASS |
| `test_city_first_visit_performance_profile.gd` | `streaming_terrain_async_complete_avg_usec` | 诊断字段 | `142308` | 冷路径存在显著 terrain async complete 尖峰 |
| `test_city_first_visit_performance_profile.gd` | `wall_frame_max_usec` | 诊断字段 | `159766` | 冷路径尖峰比 warm 更重 |

### 当前可直接得出的边界判断

1. `chunk setup` 当前是绿的，说明问题不在“单个 chunk scene mount 总体已经爆表”这一层。
2. warm 与 first-visit 共同失守 `update_streaming_avg_usec`，说明 shared streaming 协调链一定需要优先排查。
3. 两条 runtime 测试里 `streaming_mount_setup_avg_usec` 都还在阈值内，因此 mount/setup 可能有尖峰，但不是当前平均值失守的第一解释。
4. first-visit 独有的 `streaming_terrain_async_complete_avg_usec = 142308` 与更高的 `wall_frame_max_usec = 159766`，说明冷路径还要额外检查 terrain async complete / cold prepare 的突刺。
5. warm runtime 下 `ped_tier1_count = 155` 仍达线，意味着不能靠把 crowd baseline 打回去来“修复”性能。

## Recovery Verification Freeze（2026-03-17）

### closeout 命令顺序

```powershell
$project='E:\development\godot_citys'
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'

& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_chunk_setup_profile_breakdown.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/e2e/test_city_first_visit_performance_profile.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/e2e/test_city_runtime_performance_profile.gd'
```

### closeout 结果摘要

| 测试 | 关键指标 | 阈值 | `2026-03-17` closeout 值 | 结论 |
|---|---|---|---|---|
| `test_city_chunk_setup_profile_breakdown.gd` | `total_usec` | `<= 8500` | `3390` | PASS |
| `test_city_chunk_setup_profile_breakdown.gd` | `ground_usec` | `<= 1800` | `969` | PASS |
| `test_city_chunk_setup_profile_breakdown.gd` | `road_overlay_usec` | `<= 1400` | `2` | PASS |
| `test_city_first_visit_performance_profile.gd` | `update_streaming_avg_usec` | `<= 14500` | `14493` | PASS |
| `test_city_first_visit_performance_profile.gd` | `wall_frame_avg_usec` | `<= 16667` | `15322` | PASS |
| `test_city_first_visit_performance_profile.gd` | `streaming_mount_setup_avg_usec` | `<= 5500` | `4680` | PASS |
| `test_city_runtime_performance_profile.gd` | `update_streaming_avg_usec` | `<= 10000` | `8599` | PASS |
| `test_city_runtime_performance_profile.gd` | `wall_frame_avg_usec` | `<= 11000` | `10235` | PASS |
| `test_city_runtime_performance_profile.gd` | `streaming_mount_setup_avg_usec` | `<= 5500` | `3285` | PASS |
| `test_city_runtime_performance_profile.gd` | `ped_tier1_count` | `>= 150` | `155` | PASS |

### closeout 边界结论

1. `queue/prepare` 仍然是冷路径里最大的 shared 主成本，但 `v22` 已把它压回 first-visit 阈值以内。
2. `streaming_terrain_async_complete_avg_usec` 仍然是 cold-only 尖峰观察口，closeout 时数值从基线 `142308` 降到 `108813`，但它仍是后续继续优化的首选对象之一。
3. `crowd_update_avg_usec` 与 `traffic_update_avg_usec` 在 closeout first-visit 中分别落到 `2345`、`2324`，不再单独顶穿红线，但依旧是 shared runtime 的持续压力源。
4. `warm runtime` 在 `ped_tier1_count = 155` 不回退的前提下恢复到 `update_streaming_avg_usec = 8599`、`wall_frame_avg_usec = 10235`，说明本次收口没有靠削弱人流密度伪造过线。

## 指标词典

### A. 单位与后缀约定

| 约定 | 中文含义 | 读法 |
|---|---|---|
| `*_usec` | 微秒 | `1000 usec = 1 ms` |
| `*_avg_usec` | 该阶段在样本窗口内的平均耗时 | 看长期稳定压力 |
| `*_max_usec` | 该阶段在样本窗口内的最大耗时 | 看尖峰/卡顿风险 |
| `*_sample_count` | 样本数量 | 看统计是否有代表性 |
| `*_count` | 对象数量、候选数或命中次数 | 看规模、密度、缓存表现 |
| `*_hit_count / *_miss_count` | cache 命中/未命中次数 | 看复用是否生效 |
| `*_mode` | 当前模式字符串 | 看当前运行的是哪种 runtime 档位 |
| `*_signature / *_path` | 缓存签名或缓存路径 | 看本次是否真的命中预期缓存 |

### B. Chunk Setup 报告字段

| 字段 | 中文解释 | 诊断用途 |
|---|---|---|
| `total_usec` | 单个 chunk 从 mount 到 setup 完成的总耗时 | 判断 mount 热路径是否整体爆表 |
| `ground_usec` | 地表构建总耗时 | 判断 terrain/ground 是否吞掉 mount 时间 |
| `ground_mesh_usec` | 地表 mesh 构建耗时 | 对应 terrain 网格主线程提交成本 |
| `ground_collision_usec` | 地表 collision 构建耗时 | 判断碰撞壳是否过重 |
| `ground_collision_face_count` | 地表 collision 面数 | 看 collision 成本是否来自几何规模 |
| `ground_material_usec` | 地表材质组装耗时 | 看材质与 shader 拼装是否成为热点 |
| `ground_shader_material_usec` | shader 材质装配耗时 | 判断 shader/material setup 是否异常 |
| `ground_mask_textures_usec` | 路面 mask 纹理准备耗时 | 看 road mask 贴图生成/复用是否健康 |
| `ground_mask_cache_hit` | ground mask cache 是否命中 | 判断本次是否复用了缓存 |
| `ground_mask_cache_load_usec` | ground mask cache 读取耗时 | 看 cache 命中后加载成本 |
| `ground_mask_cache_write_usec` | ground mask cache 写入耗时 | 看是否发生了新缓存写盘 |
| `ground_runtime_page_hit` | runtime terrain page 是否命中 | 判断 terrain page 复用是否生效 |
| `ground_duplication_ratio` | 高度采样重复度比值 | 观察是否在重复采样同一高度点 |
| `ground_unique_vertex_count` | 唯一顶点采样数 | 和 duplication ratio 一起判断地表采样质量 |
| `ground_vertex_sample_count` | 总顶点采样数 | 对比 unique 数量看重复工作量 |
| `road_overlay_usec` | 道路叠加层构建耗时 | 看道路覆盖/overlay 是否成为 mount 热点 |
| `buildings_usec` | 建筑部分 setup 耗时 | 判断建筑实例构建成本 |
| `props_usec` | 道具/小物件 setup 耗时 | 看 props 是否失控 |
| `proxies_usec` | 代理体/proxy setup 耗时 | 看 near/mid/far 代理链是否过重 |
| `occluder_usec` | 遮挡体 setup 耗时 | 判断 occluder 构建成本 |
| `pedestrians_usec` | chunk 内行人渲染相关 setup 耗时 | 观察人流接入 mount 时的静态成本 |
| `vehicles_usec` | chunk 内车辆渲染相关 setup 耗时 | 观察车流接入 mount 时的静态成本 |
| `set_lod_usec` | 初始 LOD 设置耗时 | 看首帧 LOD 套用成本 |

### C. Runtime / First-Visit 通用帧与 UI 字段

| 字段 | 中文解释 | 诊断用途 |
|---|---|---|
| `wall_frame_avg_usec` | 采样窗口内单帧墙钟平均耗时 | 最接近最终体感帧时长 |
| `wall_frame_max_usec` | 采样窗口内最大帧时长 | 看是否存在卡顿尖峰 |
| `wall_frame_sample_count` | 墙钟帧样本数 | 当前两条测试默认都是 `48` |
| `frame_step_avg_usec` | 运行时 `frame step` 平均耗时 | 看游戏逻辑步进压力 |
| `frame_step_max_usec` | `frame step` 最大耗时 | 判断尖峰来自逻辑步进还是别处 |
| `frame_step_sample_count` | `frame step` 样本数 | 判断平均值是否稳定 |
| `hud_refresh_avg_usec` | HUD 刷新平均耗时 | 排除 HUD 是否是稳定热点 |
| `hud_refresh_max_usec` | HUD 刷新最大耗时 | 看偶发 UI 峰值 |
| `hud_refresh_sample_count` | HUD 刷新采样次数 | UI 是否真的频繁更新 |
| `minimap_request_count` | minimap 请求次数 | 看本轮是否触发了 minimap 路径 |
| `minimap_build_avg_usec` | minimap rebuild 平均耗时 | 判断 minimap build 成本 |
| `minimap_build_max_usec` | minimap rebuild 最大耗时 | 判断 minimap 是否造成尖峰 |
| `minimap_cache_hits` | minimap 缓存命中次数 | 判断 minimap 复用质量 |
| `minimap_cache_misses` | minimap 缓存未命中次数 | 看 rebuild 压力来源 |
| `minimap_rebuild_count` | minimap 重建次数 | 判断 profiling 路线中是否发生了 rebuild |

### D. Shared Streaming 协调字段

| 字段 | 中文解释 | 诊断用途 |
|---|---|---|
| `update_streaming_avg_usec` | `CityPrototype.update_streaming_for_position()` 平均耗时 | 当前 shared runtime 的第一嫌疑指标 |
| `update_streaming_max_usec` | 同一链路最大耗时 | 看 streaming 协调尖峰 |
| `update_streaming_last_usec` | 最后一次采样耗时 | 看尾部是否已恢复或仍重 |
| `update_streaming_sample_count` | `update_streaming` 采样次数 | 看统计样本是否足够 |
| `streaming_prepare_profile_avg_usec` | prepare 阶段平均耗时 | 看 mount 前数据准备是否变重 |
| `streaming_prepare_profile_max_usec` | prepare 阶段最大耗时 | 看冷路径 prepare 尖峰 |
| `streaming_prepare_profile_sample_count` | prepare 阶段采样数 | 判断 prepare 的活跃频率 |
| `streaming_mount_setup_avg_usec` | chunk mount/setup 平均耗时 | 看 scene 挂载与 setup 是否长期过重 |
| `streaming_mount_setup_max_usec` | chunk mount/setup 最大耗时 | 看个别 chunk 是否有 mount 尖峰 |
| `streaming_mount_setup_sample_count` | mount/setup 采样数 | 看实际挂载了多少次 |
| `streaming_terrain_async_dispatch_avg_usec` | terrain 后台任务派发平均耗时 | 看 terrain async 调度成本 |
| `streaming_terrain_async_dispatch_max_usec` | terrain 后台任务派发最大耗时 | 看调度尖峰 |
| `streaming_terrain_async_dispatch_sample_count` | terrain 后台任务派发次数 | 看冷路径是否真的触发了异步 |
| `streaming_terrain_async_complete_avg_usec` | terrain 后台任务完成回收平均耗时 | 冷路径尖峰的重要观察口 |
| `streaming_terrain_async_complete_max_usec` | terrain 后台任务完成回收最大耗时 | 看 terrain async complete 是否直击卡顿 |
| `streaming_terrain_async_complete_sample_count` | terrain 后台任务完成回收次数 | 看冷路径回收频率 |
| `streaming_terrain_commit_avg_usec` | terrain 主线程提交平均耗时 | 看 prepared terrain 真正挂到 scene tree/GPU 的成本 |
| `streaming_terrain_commit_max_usec` | terrain 主线程提交最大耗时 | 看 terrain 提交尖峰 |
| `streaming_terrain_commit_sample_count` | terrain 主线程提交次数 | 判断 commit 是否频繁 |

### D2. Diagnostics Mode 细粒度 streaming 字段

这些字段只在 `set_performance_diagnostics_enabled(true)` 后才有正式意义；默认 guard mode 下它们会保持 `0`，这是预期行为，不代表实现坏了。

| 字段族 / 字段 | 中文解释 | 诊断用途 |
|---|---|---|
| `update_streaming_chunk_streamer_*` | `CityPrototype.update_streaming_for_position()` 中 chunk streamer 子阶段的样本数/平均值/最大值/末次值 | 先判断问题在 chunk window 计算，还是在 renderer sync |
| `update_streaming_renderer_sync_*` | `update_streaming` 中 renderer sync 子阶段的样本数/平均值/最大值/末次值 | 把 shared streaming 主嫌疑压到 renderer 侧 |
| `update_streaming_renderer_sync_queue_*` | renderer sync 内 queue 总阶段的样本数/平均值/最大值/末次值 | 判断 `prepare/mount/retire/async collect-dispatch` 哪一类最重 |
| `update_streaming_renderer_sync_queue_retire_*` | queue 内 retire 子阶段 | 看退场回收是否污染冷路径 |
| `update_streaming_renderer_sync_queue_terrain_collect_*` | queue 内 terrain async 完成回收子阶段 | 看 terrain worker 回收是否成持续热点 |
| `update_streaming_renderer_sync_queue_terrain_dispatch_*` | queue 内 terrain async 派发子阶段 | 看 terrain job 发射是否异常 |
| `update_streaming_renderer_sync_queue_surface_collect_*` | queue 内 surface async 完成回收子阶段 | 看 surface worker 回收是否异常 |
| `update_streaming_renderer_sync_queue_surface_dispatch_*` | queue 内 surface async 派发子阶段 | 看 surface job 发射是否异常 |
| `update_streaming_renderer_sync_queue_mount_*` | queue 内 mount 子阶段 | 看 prepared payload 真正挂 scene 的成本 |
| `update_streaming_renderer_sync_queue_prepare_*` | queue 内 prepare 子阶段 | 看 `CityChunkProfileBuilder.build_profile()` 与 near-mount 预构建是否仍是主热点 |
| `update_streaming_renderer_sync_lod_*` | renderer sync 内 LOD 子阶段 | 排除 LOD 切换是否吞帧 |
| `update_streaming_renderer_sync_far_proxy_*` | renderer sync 内 far proxy 子阶段 | 排除场景 landmark far proxy 是否有额外成本 |
| `update_streaming_renderer_sync_crowd_*` | renderer sync 内 crowd 子阶段 | 看 crowd runtime 在 renderer sync 总成本里的权重 |
| `update_streaming_renderer_sync_traffic_*` | renderer sync 内 traffic 子阶段 | 看 traffic runtime 在 renderer sync 总成本里的权重 |

### D3. Chunk Prepare Breakdown 细粒度字段

| 字段 | 中文解释 | 诊断用途 |
|---|---|---|
| `building_candidate_usec` | 建筑候选总生成耗时 | 先判断 `buildings_usec` 的主热块是不是候选生成 |
| `building_streetfront_candidate_usec` | streetfront 候选生成耗时 | 看临街候选生成是否过重 |
| `building_infill_candidate_usec` | infill 候选生成耗时 | 看内填候选生成是否是第一热点 |
| `building_selection_usec` | 候选挑选/占位裁决耗时 | 看真正挑楼体而不是生成候选的成本 |
| `building_inspection_payload_usec` | inspection payload 装配耗时 | 看 building id / address / inspection metadata 是否额外拖慢 prepare |

### E. Pedestrian / Crowd 字段

| 字段 | 中文解释 | 诊断用途 |
|---|---|---|
| `pedestrian_mode` | 当前行人模式 | 确认 profiling 是否在默认 `lite` 模式下 |
| `ped_tier0_count` | 当前 Tier 0 行人数 | 观察远距最低成本存在感规模 |
| `ped_tier1_count` | 当前 Tier 1 行人数 | 当前平台冻结最重要的人流规模指标 |
| `ped_tier2_count` | 当前 Tier 2 行人数 | 看近景轻量实体数量 |
| `ped_tier3_count` | 当前 Tier 3 行人数 | 看近场高成本实体数量 |
| `ped_page_cache_hit_count` | 行人 page cache 命中次数 | 判断 query/page 复用是否健康 |
| `ped_page_cache_miss_count` | 行人 page cache 未命中次数 | 看 cold 路径加载压力 |
| `ped_duplicate_page_load_count` | 行人重复加载同一 page 的次数 | 排查重复加载 bug |
| `crowd_update_avg_usec` | crowd runtime 整体 update 平均耗时 | 看行人运行时总成本 |
| `crowd_update_max_usec` | crowd runtime 整体 update 最大耗时 | 看行人运行时尖峰 |
| `crowd_update_sample_count` | crowd update 样本数 | 判断统计稳定性 |
| `crowd_spawn_avg_usec` | crowd spawn 平均耗时 | 看新行人进入 active window 的成本 |
| `crowd_spawn_max_usec` | crowd spawn 最大耗时 | 看 spawn storm 尖峰 |
| `crowd_spawn_sample_count` | crowd spawn 样本数 | 看 spawn 发生频率 |
| `crowd_render_commit_avg_usec` | crowd 渲染提交平均耗时 | 看行人 visual commit 成本 |
| `crowd_render_commit_max_usec` | crowd 渲染提交最大耗时 | 看 visual commit 尖峰 |
| `crowd_render_commit_sample_count` | crowd 渲染提交样本数 | 判断 commit 频率 |
| `crowd_active_state_count` | 当前 active 行人状态数 | 判断 runtime 实际活跃实体规模 |
| `crowd_farfield_count` | farfield 行人数 | 看远距层数量 |
| `crowd_midfield_count` | midfield 行人数 | 看中距层数量 |
| `crowd_nearfield_count` | nearfield 行人数 | 看近场高保真数量 |
| `crowd_step_usec` | crowd 主步进耗时 | 看纯 simulation step 成本 |
| `crowd_farfield_step_usec` | farfield 步进耗时 | 看远距步进成本 |
| `crowd_midfield_step_usec` | midfield 步进耗时 | 看中距步进成本 |
| `crowd_nearfield_step_usec` | nearfield 步进耗时 | 看近场步进成本 |
| `crowd_reaction_usec` | crowd 反应逻辑耗时 | 看 threat / reaction 是否吃时 |
| `crowd_rank_usec` | crowd 距离/优先级排序耗时 | 看选优排序是否变重 |
| `crowd_snapshot_rebuild_usec` | crowd snapshot rebuild 耗时 | 看快照重建是否失控 |
| `crowd_assignment_rebuild_usec` | crowd assignment 重建耗时 | 看近/中/远场分配更新成本 |
| `crowd_assignment_candidate_count` | crowd assignment 候选数量 | 和重建耗时一起判断规模压力 |
| `crowd_threat_broadcast_usec` | threat 广播耗时 | 判断威胁传播是否过重 |
| `crowd_threat_candidate_count` | threat 候选数量 | 看威胁事件波及范围 |
| `crowd_chunk_commit_usec` | crowd chunk 级渲染提交耗时 | 看 chunk apply 侧成本 |
| `crowd_tier1_transform_writes` | crowd Tier 1 transform 写入次数 | 看 batched crowd 更新规模 |
| `crowd_assignment_decision` | 最近一次 assignment 判定结果（`reuse/rebuild`） | 直接看 crowd runtime 这一帧是在复用还是重建 |
| `crowd_assignment_rebuild_reason` | 最近一次 assignment 判定原因 | 分辨是 `chunk_window_changed`、`player_distance`、`player_speed_delta` 还是稳定复用窗口 |
| `crowd_assignment_player_velocity_mps` | 最近一次用于 assignment 的有效玩家速度 | 看速度钳制后的 crowd 输入 |
| `crowd_assignment_raw_player_velocity_mps` | 最近一次原始玩家速度 | 对账真实移动速度与 effective velocity 的差分 |
| `crowd_assignment_player_speed_delta_mps` | 最近一次玩家速度变化量 | 判断 assignment rebuild 是否由速度变化触发 |
| `crowd_assignment_player_speed_cap_mps` | 当前 crowd assignment 速度上限 | 判断速度钳制口径是否正确 |

### F. Vehicle / Traffic 字段

| 字段 | 中文解释 | 诊断用途 |
|---|---|---|
| `vehicle_mode` | 当前车辆模式 | 确认 profiling 是否在默认 `lite` 模式下 |
| `veh_tier0_count` | 当前 Tier 0 车辆数 | 观察最低成本车辆存在感规模 |
| `veh_tier1_count` | 当前 Tier 1 车辆数 | 看中远景 batched traffic 规模 |
| `veh_tier2_count` | 当前 Tier 2 车辆数 | 看近景轻量车辆数 |
| `veh_tier3_count` | 当前 Tier 3 车辆数 | 看近场高成本车辆数 |
| `veh_page_cache_hit_count` | 车辆 page cache 命中次数 | 判断 query/page 复用是否健康 |
| `veh_page_cache_miss_count` | 车辆 page cache 未命中次数 | 看 cold 路径加载压力 |
| `veh_duplicate_page_load_count` | 车辆重复加载同一 page 的次数 | 排查重复加载 bug |
| `traffic_update_avg_usec` | traffic runtime 整体 update 平均耗时 | 看车流运行时总成本 |
| `traffic_update_max_usec` | traffic runtime 整体 update 最大耗时 | 看车流运行时尖峰 |
| `traffic_update_sample_count` | traffic update 样本数 | 判断统计稳定性 |
| `traffic_spawn_avg_usec` | traffic spawn 平均耗时 | 看新车进入 active window 的成本 |
| `traffic_spawn_max_usec` | traffic spawn 最大耗时 | 看 spawn storm 尖峰 |
| `traffic_spawn_sample_count` | traffic spawn 样本数 | 看 spawn 发生频率 |
| `traffic_render_commit_avg_usec` | traffic 渲染提交平均耗时 | 看车辆 visual commit 成本 |
| `traffic_render_commit_max_usec` | traffic 渲染提交最大耗时 | 看 visual commit 尖峰 |
| `traffic_render_commit_sample_count` | traffic 渲染提交样本数 | 判断 commit 频率 |
| `traffic_active_state_count` | 当前 active 车辆状态数 | 判断 runtime 实际活跃实体规模 |
| `traffic_step_usec` | traffic 主步进耗时 | 看车流纯 simulation step 成本 |
| `traffic_rank_usec` | traffic 排序耗时 | 看距离/优先级排序是否变重 |
| `traffic_snapshot_rebuild_usec` | traffic snapshot rebuild 耗时 | 看车辆快照重建成本 |
| `traffic_tier1_count` | traffic runtime 统计的 Tier 1 车辆数 | 与 renderer 统计互相对账 |
| `traffic_tier2_count` | traffic runtime 统计的 Tier 2 车辆数 | 判断近景负载 |
| `traffic_tier3_count` | traffic runtime 统计的 Tier 3 车辆数 | 判断高成本负载 |
| `traffic_chunk_commit_usec` | traffic chunk 级渲染提交耗时 | 看车辆 apply 侧成本 |
| `traffic_tier1_transform_writes` | traffic Tier 1 transform 写入次数 | 看 batched traffic 更新规模 |

### G. World Generation 字段

| 字段 | 中文解释 | 诊断用途 |
|---|---|---|
| `world_generation_usec` | 世界生成总耗时 | 看启动成本是否回退 |
| `world_generation_profile.total_usec` | 生成 profile 总耗时 | 和总启动耗时对账 |
| `world_generation_profile.road_graph_usec` | road graph 生成/加载耗时 | 看道路图是不是 startup 热点 |
| `world_generation_profile.road_graph_build_usec` | road graph 真构建耗时 | 看是否真的重新构建 |
| `world_generation_profile.road_graph_cache_hit` | road graph cache 是否命中 | 判断缓存是否生效 |
| `world_generation_profile.road_graph_cache_load_usec` | road graph cache 读取耗时 | 看命中后的读取成本 |
| `world_generation_profile.road_graph_cache_write_usec` | road graph cache 写入耗时 | 看是否发生了重写缓存 |
| `world_generation_profile.road_graph_cache_path` | road graph 缓存路径 | 对账是否用了预期缓存 |
| `world_generation_profile.road_graph_cache_signature` | road graph 缓存签名 | 对账缓存版本 |
| `world_generation_profile.road_graph_cache_size_bytes` | road graph 缓存大小 | 看缓存规模 |
| `world_generation_profile.road_graph_cache_error` | road graph 缓存错误文本 | 排查缓存异常 |
| `world_generation_profile.road_edge_count` | 道路边数量 | 判断基础道路规模 |
| `world_generation_profile.block_count` | block 数量 | 看世界规模 |
| `world_generation_profile.block_layout_usec` | block layout 生成耗时 | 看 block 布局阶段成本 |
| `world_generation_profile.district_count` | district 数量 | 看世界划分规模 |
| `world_generation_profile.district_usec` | district 生成耗时 | 看 district 阶段成本 |
| `world_generation_profile.parcel_count` | parcel 数量 | 判断 parcel 规模 |
| `world_generation_profile.name_candidate_catalog_usec` | 地名候选目录构建耗时 | 看命名目录阶段成本 |
| `world_generation_profile.street_cluster_count` | street cluster 数量 | 看街区聚类规模 |
| `world_generation_profile.street_cluster_usec` | street cluster 构建耗时 | 判断街区聚类成本 |
| `world_generation_profile.place_index_usec` | place index 主流程耗时 | 看地点索引是否进入 profile |
| `world_generation_profile.place_index_build_usec` | place index 真构建耗时 | 看是否重新构建地点索引 |
| `world_generation_profile.place_index_cache_hit` | place index cache 是否命中 | 判断地点索引缓存是否生效 |
| `world_generation_profile.place_index_cache_load_usec` | place index cache 读取耗时 | 看命中读取成本 |
| `world_generation_profile.place_index_cache_write_usec` | place index cache 写入耗时 | 看是否发生了重写缓存 |
| `world_generation_profile.place_index_cache_path` | place index 缓存路径 | 对账缓存文件 |
| `world_generation_profile.place_index_cache_signature` | place index 缓存签名 | 对账缓存版本 |
| `world_generation_profile.place_index_cache_size_bytes` | place index 缓存大小 | 看缓存规模 |
| `world_generation_profile.place_query_usec` | place query 初始化耗时 | 看 query 侧初始化成本 |
| `world_generation_profile.pedestrian_world_usec` | 行人世界生成耗时 | 看 crowd startup 成本 |
| `world_generation_profile.vehicle_world_usec` | 车辆世界生成耗时 | 看 traffic startup 成本 |
| `world_generation_profile.task_catalog_usec` | task catalog 构建耗时 | 看任务系统 startup 成本 |
| `world_generation_profile.task_count` | task 数量 | 判断任务规模 |
| `world_generation_profile.task_slot_count` | task slot 数量 | 判断任务槽位规模 |

## Steps

1. Analysis
   - 串行跑三项性能护栏，锁定 `2026-03-17` fresh 基线。
   - 对齐测试阈值、当前数值、失败点与共同嫌疑链。
2. Design
   - 冻结 `v22` 的文档口径与诊断边界。
   - 冻结“先找边界，再修根因”的排障顺序。
3. Plan
   - 建立 `v22-index.md`。
   - 建立本计划文档，写入基线与指标词典。
4. TDD Red
   - 为 `update_streaming`、prepare/mount、terrain async complete、crowd/traffic shared path 补 targeted diagnostics 或 regression tests。
   - 跑到红，证明当前 shared runtime 确实仍失守。
5. TDD Green
   - 沿边界定位结果修复 shared runtime 退化。
   - 保持 `ped_tier1_count`、`veh_tier1_count` 与现有 consumer contract 不回退。
6. Refactor
   - 收口临时探针，只保留对长期 profiling 有价值的只读 debug state。
7. E2E
   - 串行重跑三件套。
   - 视改动面补跑受影响的 world/e2e 回归。
8. Review
   - 把 before/after 数值写入 `v22-mN-verification-YYYY-MM-DD.md`。
   - 更新 `v22-index.md` 状态与差异列表。
9. Ship
   - 先提交文档 slice。
   - 后续每个性能修复 compact 各自独立提交。

## Risks

- 当前失败跨越 terrain、streaming、crowd、traffic 多个 runtime family，如果只看单个热点，很容易在别处引入新的尖峰。
- `streaming_mount_setup_avg_usec` 当前是绿的，但 `wall_frame_max_usec` 仍有尖峰；如果只盯平均值，可能会漏掉 cold spike。
- first-visit 暴露 `terrain_async_complete` 尖峰，而 warm runtime 没有；如果两条线混着修，很可能修掉热路径却保留冷路径卡顿。
- 如果为了过线回退 crowd/traffic 密度或 active window，会直接违反现有 PRD 与冻结平台。

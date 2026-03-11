# FPS60 Redline Baseline

## Executive Summary

截至 2026-03-12，项目已经解决了启动期 `road_graph` 生成导致的 splash 卡死问题，但运行期仍明显越过 `60 FPS = 16.67ms/frame` 的目标红线。

当前最新 headless 基线显示：

- 启动期已降到约 `0.94s`
- 最近两次 fresh 复测的 `wall_frame_avg_usec` 落在 `31333` 到 `36832`
- 对应约 `31.33ms/frame` 到 `36.83ms/frame`
- 对应约 `31.9 FPS` 到 `27.1 FPS`

也就是说，项目已经从此前约 `72ms/frame` 压到了约 `31ms` 到 `37ms/frame`，但距离 `16.67ms/frame` 仍有明显差距。当前最大的运行期卡点，已经稳定收敛到 `chunk mount setup -> ground material -> road surface mask paint` 这一条链路。

## 红线定义

- 目标帧率：`60 FPS`
- 帧时红线：`16.67ms/frame`
- 项目定位：`low poly` 大世界
- 结论：如果持续高于 `16.67ms`，则优先级高于新功能扩展

## Profiling 方法概览

当前 profiling 采用四层证据链：

1. **端到端帧耗**  
   通过 `tests/e2e/test_city_runtime_performance_profile.gd` 采 `wall_frame_avg_usec`、`update_streaming_avg_usec`、`frame_step_avg_usec`。

2. **Streaming 分段计时**  
   追 `prepare`、`mount setup`、`retire`，确认卡顿是发生在数据准备、挂载还是退场。

3. **Chunk setup breakdown**  
   通过 `tests/world/test_city_chunk_setup_profile_breakdown.gd` 拆 `ground_mesh`、`ground_collision`、`ground_material`、`road_overlay`、`buildings` 等阶段。

4. **热点微剖面**  
   只对当前最大热点打更细的 breakdown。当前已验证 `road mask` 的核心成本在 CPU paint，不在 texture upload。

这个方法的目的不是“到处埋点”，而是先用粗指标锁边界，再用细指标切根因。

## Measurement Setup

运行命令：

```powershell
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/e2e/test_city_runtime_performance_profile.gd'
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_chunk_setup_profile_breakdown.gd'
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_road_mask_profile_breakdown.gd'
```

说明：

- `headless + dummy renderer` 不代表最终真实 GPU 帧率。
- 但它是当前最稳定、最可重复的 regression baseline。
- 后续任何“性能改善”都必须先在这套基线上体现出来。

## Current Baseline

### 启动期

- `world_generation_usec = 944221`
- `world_generation_profile.road_graph_cache_hit = true`
- `world_generation_profile.road_graph_cache_load_usec = 887324`

结论：

- 启动期主因已从“全量生成道路图”变成“读取缓存 + 初始化世界对象”
- splash 卡几十秒的问题已不再是当前第一优先级

### 运行期总览

最近两次 fresh runtime profile 的区间：

- `wall_frame_avg_usec = 31333 ~ 36832`
- `wall_frame_max_usec = 87087 ~ 109647`
- `update_streaming_avg_usec = 29675 ~ 34748`
- `update_streaming_max_usec = 85162 ~ 106393`
- `frame_step_avg_usec = 29686 ~ 34757`
- `hud_refresh_avg_usec = 1798 ~ 2077`
- `minimap_build_avg_usec = 4505 ~ 5361`

结论：

- 当前主因已经不再是 HUD/minimap
- 帧耗主体与 `update_streaming` 几乎等价，说明卡顿主要发生在 streaming 路径

### Streaming 分段

最近两次 fresh runtime profile 的区间：

- `streaming_mount_setup_avg_usec = 32057 ~ 37789`
- `streaming_mount_setup_max_usec = 74848 ~ 79725`
- `streaming_prepare_profile_avg_usec = 6308 ~ 7802`
- `streaming_prepare_profile_max_usec = 13296 ~ 15278`

结论：

- `prepare` 已经被压到次要级别
- 当前第一根针是 `mount setup`

## Chunk Hotspots

### Chunk setup breakdown

最近两次 fresh `test_city_chunk_setup_profile_breakdown.gd` 样本区间：

- `total_usec = 31820 ~ 69284`
- `ground_usec = 27059 ~ 61033`
- `ground_material_usec = 16778 ~ 36217`
- `ground_mask_textures_usec = 16081 ~ 34741`
- `ground_mesh_usec = 9525 ~ 23445`
- `ground_collision_usec = 464 ~ 823`
- `road_overlay_usec = 1852 ~ 3462`
- `buildings_usec = 1837 ~ 3554`

结论：

- `ground` 明显压倒其他阶段
- `ground material` 又明显压倒 `ground collision / buildings / props / proxies`
- `ground material` 内部的主要大头是 `road mask textures`

### Road mask breakdown

最近两次 fresh `test_city_road_mask_profile_breakdown.gd` 样本区间：

- `surface_segment_count = 5`
- `intersection_cluster_count = 2`
- `paint_usec = 17018 ~ 37821`
- `image_usec = 5 ~ 7`
- `texture_usec = 21 ~ 26`
- `total_usec = 17194 ~ 38039`

结论：

- 当前热点不在 GPU texture upload
- 热点几乎完全在 CPU 栅格化 `road mask`

## Current Bottleneck Ranking

按当前证据链排序：

1. `streaming_mount_setup`
2. `ground material`
3. `road surface mask CPU paint`
4. `ground mesh`
5. `streaming prepare`
6. `minimap build`
7. `HUD refresh`

## Interpretation

当前系统已经证明下面几件事：

- 启动期缓存方向是正确的
- minimap 去耦方向是正确的
- road graph 空间索引方向是正确的
- 运行期剩余大头已经非常集中，不再是“到处都慢”

因此，`v4` 不应该继续做零散微调，而应聚焦：

1. 道路表面 mask 持久化缓存
2. near/mid/far 的路面细节分层
3. CPU 侧异步准备 byte mask，主线程只做资源提交
4. 为更长期的 surface page / RVT-lite 做结构预留

## Evidence

关键输出摘要：

```text
CITY_PROFILE_REPORT {"frame_step_avg_usec":34757,"frame_step_max_usec":106406,"frame_step_sample_count":48,"hud_refresh_avg_usec":2077,"hud_refresh_max_usec":10630,"hud_refresh_sample_count":49,"minimap_build_avg_usec":5361,"minimap_build_max_usec":9876,"minimap_cache_hits":35,"minimap_cache_misses":14,"minimap_rebuild_count":14,"minimap_request_count":49,"streaming_mount_setup_avg_usec":37789,"streaming_mount_setup_max_usec":79725,"streaming_mount_setup_sample_count":32,"streaming_prepare_profile_avg_usec":7802,"streaming_prepare_profile_max_usec":15278,"streaming_prepare_profile_sample_count":33,"update_streaming_avg_usec":34748,"update_streaming_last_usec":1832,"update_streaming_max_usec":106393,"update_streaming_sample_count":48,"wall_frame_avg_usec":36832,"wall_frame_max_usec":109647,"wall_frame_sample_count":48,"world_generation_profile":{"road_graph_cache_hit":true,"road_graph_cache_load_usec":906000,"total_usec":965971},"world_generation_usec":966016}
CITY_CHUNK_SETUP_PROFILE {"buildings_usec":1837,"ground_collision_usec":464,"ground_mask_textures_usec":16081,"ground_material_usec":16778,"ground_mesh_usec":9525,"ground_shader_material_usec":659,"ground_usec":27059,"occluder_usec":69,"props_usec":796,"proxies_usec":157,"road_overlay_usec":1852,"set_lod_usec":20,"total_usec":31820}
CITY_ROAD_MASK_PROFILE {"image_usec":5,"intersection_cluster_count":2,"paint_usec":17018,"surface_segment_count":5,"texture_usec":21,"total_usec":17194}
```

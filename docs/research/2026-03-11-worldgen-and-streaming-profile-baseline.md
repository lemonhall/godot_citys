# 启动期与运行期 Profiling 基线记录

## Executive Summary

2026 年 3 月 11 日的最新 headless profiling 显示，当前项目最扎眼的两个性能问题已经有明确边界：

- 启动时 splash 长时间停留，主因是整张世界在进入游戏前同步生成，而其中几乎全部时间都耗在 `road_graph` 构建。
- 进入游戏后的低 FPS，不是单一渲染瓶颈，而是 chunk streaming 的同步 mount/prepare 成本叠加 HUD 与 minimap 的持续重建成本。

因此，下一步最先该做的不是继续微调材质或 LOD，而是把启动期 `road_graph` 结果做持久化缓存，并进一步压缩运行期 chunk 挂载尖峰。

## Measurement Setup

本次数据来自以下两条 headless 测试：

```powershell
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_streaming_profile_stats.gd'
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/e2e/test_city_runtime_performance_profile.gd'
```

其中第二条测试会让 player 朝目标点持续推进 48 帧，从而采集更接近真实巡检时的 streaming 与 HUD/minimap 成本。

## Fresh Baseline

本轮在提交前又复测了一次，结果和第一次采样一致地指向同一个结论：启动瓶颈稳定锁在 `road_graph`，运行期瓶颈稳定锁在 streaming mount/setup。两次样本的关键范围如下：

- `world_generation_usec`: `21.77s` 到 `25.00s`
- `world_generation_profile.road_graph_usec`: `21.72s` 到 `24.94s`
- `wall_frame_avg_usec`: `165962` 到 `166586`
- `update_streaming_avg_usec`: `163376` 到 `164124`
- `streaming_mount_setup_avg_usec`: `137839` 到 `142721`
- `streaming_prepare_profile_avg_usec`: `44635` 到 `45558`
- `hud_refresh_avg_usec`: `32480` 到 `35985`
- `minimap_build_avg_usec`: `35554` 到 `39483`

### 启动期

- `world_generation_usec`: `25000694` us，约 `25.00s`
- `world_generation_profile.total_usec`: `25000653` us，约 `25.00s`
- `world_generation_profile.road_graph_usec`: `24936646` us，约 `24.94s`
- `world_generation_profile.district_usec`: `63994` us，约 `0.064s`
- `world_generation_profile.block_layout_usec`: `12` us

启动总耗时中，`road_graph` 占比约为 `99.74%`，已经足以把“卡在 splash”这个问题边界锁死到路网生成，而不是材质加载、HUD 初始化或 chunk 首帧挂载。

### 运行期

- `wall_frame_avg_usec`: `165962`，约 `6.0 FPS`
- `wall_frame_max_usec`: `567676`
- `update_streaming_avg_usec`: `163376`
- `update_streaming_max_usec`: `564807`
- `streaming_mount_setup_avg_usec`: `142721`
- `streaming_mount_setup_max_usec`: `450690`
- `streaming_prepare_profile_avg_usec`: `44635`
- `streaming_prepare_profile_max_usec`: `100953`
- `hud_refresh_avg_usec`: `32480`
- `hud_refresh_max_usec`: `69841`
- `minimap_build_avg_usec`: `35554`
- `minimap_build_max_usec`: `69191`
- `minimap_rebuild_count`: `44 / 49` 次请求
- `minimap_cache_hits`: `5`
- `minimap_cache_misses`: `44`

## Conclusions

### 1. Splash 卡顿的根因已经明确

这不是“加载场景慢”，也不是“Godot 启动慢”。当前是 `CityWorldGenerator.generate_world()` 在进场前同步完成了整张 70km 世界的数据构建，而 `road_graph` 几乎吞掉了全部启动时间。

### 2. 运行期卡顿的主因是 streaming 挂载尖峰

`update_streaming_avg_usec` 与 `streaming_mount_setup_avg_usec` 数值非常接近，说明主线程每次推进 streaming 时，最重的一段仍然是 chunk mount/setup，而不是纯 `_process()` 管理成本。

### 3. HUD 与 minimap 已经不是第一根针，但仍然偏重

HUD 刷新和 minimap 构建平均都在 35ms 到 40ms 量级，单独看已经偏高；但它们仍然低于 streaming mount/setup，所以短期优先级应排在启动缓存和 streaming 尖峰治理之后。

### 4. “同一 seed 每次都重建同一路网” 是当前最不合理的成本来源

因为路网对于同一个配置组合而言是可重现的，完全没必要每次启动都重新生成。把它落盘成 Godot 原生序列化或二进制缓存，是当前收益最高、风险最低的第一刀。

## Immediate Action

下一步按这个顺序推进：

1. 为 `road_graph` 增加磁盘缓存，缓存键至少包含 `seed`、世界尺寸、分区尺寸与 schema version。
2. 在 `generation_profile` 中显式记录 `cache_hit`、`cache_path` 与 `cache_write_usec`，确保后续 profiling 可追溯。
3. 保留现有 runtime profiling 接口，缓存落地后重新测一次启动基线，验证 splash 时间是否显著下降。
4. 启动问题稳定后，再继续清理运行期 streaming mount 尖峰与 minimap 重建频率。

## Post-Fix Verification

在引入 `road_graph` 磁盘缓存后，默认 `70km x 70km` 配置已经完成一次实测复核。先用 `test_city_world_generator.gd` 预热默认缓存，再运行 `test_city_runtime_performance_profile.gd`，第二次启动得到如下结果：

- `road_graph_cache_hit`: `true`
- `road_graph_cache_path`: `user://cache/world/road_graph_v1_seed424242_w70000_d70000_ds1000.bin`
- `road_graph_cache_size_bytes`: `13852252`
- `road_graph_cache_load_usec`: `580782`
- `road_graph_build_usec`: `0`
- `world_generation_usec`: `622536`
- `world_generation_profile.total_usec`: `622489`

也就是说，默认世界第二次启动已经从原先的 `21.77s` 到 `25.00s`，下降到了约 `0.62s`。这一刀已经把“每次启动都在 splash 上卡几十秒”的主因切掉了；剩下的主要问题就不再是 world generation，而是运行期 streaming / HUD / minimap 的帧内尖峰。

## Evidence

本次关键原始输出如下：

```text
CITY_PROFILE_REPORT {"frame_step_avg_usec":163387,"frame_step_max_usec":564821,"frame_step_sample_count":48,"hud_refresh_avg_usec":32480,"hud_refresh_max_usec":69841,"hud_refresh_sample_count":49,"minimap_build_avg_usec":35554,"minimap_build_max_usec":69191,"minimap_cache_hits":5,"minimap_cache_misses":44,"minimap_rebuild_count":44,"minimap_request_count":49,"streaming_mount_setup_avg_usec":142721,"streaming_mount_setup_max_usec":450690,"streaming_mount_setup_sample_count":33,"streaming_prepare_profile_avg_usec":44635,"streaming_prepare_profile_max_usec":100953,"streaming_prepare_profile_sample_count":33,"update_streaming_avg_usec":163376,"update_streaming_last_usec":36181,"update_streaming_max_usec":564807,"update_streaming_sample_count":48,"wall_frame_avg_usec":165962,"wall_frame_max_usec":567676,"wall_frame_sample_count":48,"world_generation_profile":{"block_count":300304,"block_layout_usec":12,"district_count":4900,"district_usec":63994,"parcel_count":1201216,"road_edge_count":31860,"road_graph_usec":24936646,"total_usec":25000653},"world_generation_usec":25000694}
```

# AGENTS.md

本文件是仓库级补充约束；全局用户偏好与更高优先级指令继续生效。

## 项目定位

- 本项目是 `70km x 70km` 级 low poly 城市底盘，不是高模演示。
- 任何新增功能都必须优先服从世界稳定性、流式加载连续性和运行期性能。

## 性能红线

- 把 `60 FPS = 16.67ms/frame` 视为全局硬红线。
- 当前项目尚未达线；`v4` 的核心目标就是把运行期帧耗持续压回这条红线以内。
- 在红线达成之前，任何新功能如果让运行期基线继续恶化，默认视为阻塞问题，而不是“以后再优化”。
- low poly 世界如果长期低于 60 FPS，是产品级失败，不允许用“功能先上”掩盖。

## 性能护栏

- 任何修改 `world generation / streaming / chunk rendering / terrain / road surface / HUD / minimap` 的工作，都必须给出前后 profiling 证据。
- 默认使用 `tests/e2e/test_city_runtime_performance_profile.gd` 作为运行期回归基线。
- 默认使用 `tests/world/test_city_chunk_setup_profile_breakdown.gd` 和 `tests/world/test_city_road_mask_profile_breakdown.gd` 追热点。
- 如果做不到 fresh profiling，就不能声称“性能已经改善”。
- 每完成一个里程碑 `M`，都必须重新跑一轮 fresh profiling，并与上一个里程碑留档的基线对比。
- 只有在 profiling 结果已经落盘、且确认没有引入新的性能回退之后，该里程碑才允许标记为完成并继续下一个 `M`。
- profiling 命令必须隔离执行，不得与其它 Godot 测试/实例并行运行；否则 wall-frame 与 streaming 数据会被进程争抢污染，结论无效。
- 在当前阶段，禁止再引入“每个 chunk mount 时主线程全量重建静态道路表面数据”这一类设计。

## Profiling 方法论

- 先看端到端：`wall_frame_avg_usec`、`update_streaming_avg_usec`、`streaming_mount_setup_avg_usec`。
- 再切阶段：`prepare`、`mount setup`、`HUD/minimap`、`world generation`。
- 再打微剖面：只对当前最大热点加 breakdown，不要同时到处埋点。
- 优先修根因：缓存、分层、异步数据准备、复用；不要只在症状上打补丁。

## 版本纪律

- 涉及性能目标、验收口径或渲染管线设计变化时，必须同步更新 `docs/prd`、`docs/ecn`、`docs/plan/vN-*`。
- `v4` 期间，默认优先处理性能专项，不新增与性能无关的大功能面。

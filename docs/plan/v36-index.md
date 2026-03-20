# V36 Index

## 愿景

PRD 入口：

- [PRD-0001 Large City Foundation](../prd/PRD-0001-large-city-foundation.md)
- [PRD-0002 Pedestrian Crowd Foundation](../prd/PRD-0002-pedestrian-crowd-foundation.md)
- [PRD-0003 Vehicle Traffic Foundation](../prd/PRD-0003-vehicle-traffic-foundation.md)

依赖入口：

- [v22-index.md](./v22-index.md)
- [v35-index.md](./v35-index.md)

`v36` 的目标不是继续做“诊断版 + 小参数修修补补”，而是正式把 `v35` 已经锁定的近场街道抖动问题推进到一轮架构级治理：把 `inspection` 与真实街道近场下最贵的 `crowd/traffic + renderer_sync` 热路径，拆成 `数据化`、`批处理化`、`并行化` 三个明确阶段，并要求每一个阶段都能回答：

- 它具体在吃掉哪一段 frame-time；
- 它是否真的压低了真实渲染下的 `wall_frame_avg_usec` / `renderer_sync` / `crowd_update` / `traffic_update`；
- 它有没有靠“把街上人砍空”、“把中距离都换成离谱 proxy”或“把系统关掉”来伪造改善。

## 决策冻结

- `v36` 是架构收口版，不再把主要精力放在“再诊断一次”。
- `v35` 的结论视为当前已知边界：
  - `inspection` 链主要嫌疑在 `renderer_sync + HUD/minimap + crowd window churn`
  - `live gunshot / panic` 链主要嫌疑在 `frame_step + threat/crowd/traffic` 叠加
- `v36` 不接受以下“伪优化”作为 closeout：
  - 把 `lite` crowd/traffic 密度进一步砍成空街
  - 让中距离长期停留在肉眼明显离谱的灰色 proxy
  - 关闭 `inspection`、`panic`、`HUD`、`minimap`、`crowd`、`traffic` 任一玩法链来跑“性能测试”
  - 只跑 headless dummy 就宣称真实渲染已稳
- 已经落地的保守节流与半径收缩可以保留为基线，但不能被包装成 `v36` 主成果；`v36` 主成果必须来自热路径形态变化。

## 里程碑

| 里程碑 | 范围 | DoD | 验证命令/测试 | 状态 |
|---|---|---|---|---|
| M1 近场 runtime 边界冻结 | 把 `crowd/traffic/renderer_sync/HUD/minimap` 的热路径责任边界写成正式 contract 与 plan | `v36` 计划与测试口径冻结，明确哪些成本允许在线程外计算、哪些必须留主线程 commit | 文档自检 + `v35` 既有 diagnostics/performance artifact 对账 | todo |
| M2 crowd 数据化 + dirty batch commit | 先治理行人近场热路径 | `crowd_update` 与 `renderer_sync_crowd` 有 before/after 对账，且不打坏 density / combat / visual contract | pedestrian world tests + rendered inspection/live-gunshot rerun | todo |
| M3 traffic 数据化 + dirty batch commit | 再治理车辆近场热路径 | `traffic_update` 与 `renderer_sync_traffic` 有 before/after 对账，且不打坏 drive / hijack / collision / traffic contract | vehicle world tests + rendered inspection/live-gunshot rerun | todo |
| M4 纯数据相位并行化 | 把可并行的候选收集/排序/采样/威胁评估搬离主线程 | 至少一条热路径的纯数据相位被 thread-pool 化，且不触碰非线程安全 SceneTree 操作 | focused world tests + rendered diagnostics/performance rerun | todo |
| M5 closeout rerun | fresh rendered 收口与验证文档 | `inspection` 与 `live gunshot` 两条链都能以 fresh rendered 证据证明改善，并保住基础 crowd/traffic/runtime 红线 | `tests/e2e/*performance*.gd` + `docs/plan/v36-mN-verification-YYYY-MM-DD.md` | todo |

## 计划索引

- [v36-nearfield-runtime-data-batching-parallelization.md](./v36-nearfield-runtime-data-batching-parallelization.md)

## 追溯矩阵

| Req ID | v36 Plan | 单元/集成测试 | E2E / 验证命令 | 证据 | 状态 |
|---|---|---|---|---|---|
| REQ-0001-006 | `v36-nearfield-runtime-data-batching-parallelization.md` | `tests/world/test_city_streaming_profile_stats.gd`、`tests/world/test_city_runtime_streaming_diagnostic_contract.gd` | `tests/e2e/test_city_runtime_performance_profile.gd`、`tests/e2e/test_city_first_visit_performance_profile.gd` | `docs/plan/v36-mN-verification-YYYY-MM-DD.md` | todo |
| REQ-0001-008 / REQ-0001-009 | `v36-nearfield-runtime-data-batching-parallelization.md` | `tests/world/test_city_minimap_snapshot_cache.gd`、`tests/world/test_city_minimap_motion_cache.gd`、`tests/world/test_city_minimap_idle_contract.gd` | `tests/e2e/test_city_fast_inspection_mode.gd`、`tests/e2e/test_city_pedestrian_high_speed_inspection_diagnostics.gd`、`tests/e2e/test_city_pedestrian_high_speed_inspection_performance.gd` | `reports/v35/runtime_jitter/diagnostics/*.json` + fresh `v36` artifact | todo |
| REQ-0002-003 / REQ-0002-004 / REQ-0002-006 / REQ-0002-007 | `v36-nearfield-runtime-data-batching-parallelization.md` | `tests/world/test_city_pedestrian_profile_stats.gd`、`tests/world/test_city_pedestrian_chunk_snapshot_cache.gd`、`tests/world/test_city_pedestrian_tier1_dirty_commit.gd`、`tests/world/test_city_pedestrian_traversal_assignment_scheduler.gd`、`tests/world/test_city_pedestrian_nearfield_traversal_assignment_scheduler.gd` | `tests/e2e/test_city_pedestrian_performance_profile.gd`、`tests/e2e/test_city_pedestrian_high_speed_inspection_performance.gd` | `docs/plan/v36-mN-verification-YYYY-MM-DD.md` | todo |
| REQ-0002-010 / REQ-0002-012 / REQ-0002-016 | `v36-nearfield-runtime-data-batching-parallelization.md` | `tests/world/test_city_pedestrian_layered_threat_runtime.gd`、`tests/world/test_city_pedestrian_witness_flee_response.gd`、`tests/world/test_city_pedestrian_lite_density_uplift.gd`、`tests/world/test_city_pedestrian_lod_contract.gd` | `tests/e2e/test_city_pedestrian_live_gunshot_diagnostics.gd`、`tests/e2e/test_city_pedestrian_live_gunshot_performance.gd` | `docs/plan/v36-mN-verification-YYYY-MM-DD.md` | todo |
| REQ-0003-004 / REQ-0003-005 / REQ-0003-008 / REQ-0003-009 | `v36-nearfield-runtime-data-batching-parallelization.md` | `tests/world/test_city_vehicle_profile_stats.gd`、`tests/world/test_city_vehicle_batch_rendering.gd`、`tests/world/test_city_vehicle_renderer_initial_snapshot.gd`、`tests/world/test_city_vehicle_streaming_budget.gd` | `tests/e2e/test_city_vehicle_performance_profile.gd`、`tests/e2e/test_city_runtime_performance_profile.gd` | `docs/plan/v36-mN-verification-YYYY-MM-DD.md` | todo |

## Closeout 证据口径

- `v36` 不接受“主观感觉稳了一些”作为 closeout。
- `v36` 的第一类证据是 fresh rendered diagnostics / performance artifact，至少覆盖：
  - `inspection_high_speed`
  - `live_gunshot`
- `v36` 的第二类证据是 before/after 对账，至少包含：
  - `wall_frame_avg_usec`
  - `update_streaming_renderer_sync_avg_usec`
  - `update_streaming_renderer_sync_crowd_avg_usec`
  - `update_streaming_renderer_sync_traffic_avg_usec`
  - `crowd_update_avg_usec`
  - `traffic_update_avg_usec`
  - `hud_refresh_avg_usec`
  - `minimap_build_avg_usec`
- `v36` 的第三类证据是“没有用缩水换成绩”的 gameplay / density / visual contract 回归。

## ECN 索引

- 当前无。

## 差异列表

- `v35` 已经证明：真实渲染下的近场街道抖动并非错觉，而且主要热点集中在 `crowd/traffic` 更新与 `renderer_sync`，而不是远处静态建筑。
- `v35` 也证明：单纯砍人口密度不是正解，既可能打坏 density guard，也不能保证把 `wall_frame_avg_usec` 拉回红线以内。
- `v36` 仍有两个开放风险需要正面应对：
  - inspection 中距离 visual / tier 语义不能因性能治理而退化成肉眼明显离谱的 proxy 体验
  - 并行化只能作用于纯数据相位，任何 SceneTree / render commit 误上线程都会制造新的不稳定

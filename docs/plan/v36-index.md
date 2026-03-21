# V36 Index

## 愿景

PRD 入口：

- [PRD-0001 Large City Foundation](../prd/PRD-0001-large-city-foundation.md)
- [PRD-0002 Pedestrian Crowd Foundation](../prd/PRD-0002-pedestrian-crowd-foundation.md)
- [PRD-0003 Vehicle Traffic Foundation](../prd/PRD-0003-vehicle-traffic-foundation.md)

依赖入口：

- [v22-index.md](./v22-index.md)
- [v35-index.md](./v35-index.md)
- [ECN-0027-flat-ground-runtime-simplification.md](../ecn/ECN-0027-flat-ground-runtime-simplification.md)

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
- `2026-03-21` 起，`v36` 新增 flat-ground pivot：
  - 整个城市默认运行在绝对平面 `y=0`
  - 普通道路 / 建筑 / 玩家 / 行人不再消费 runtime terrain height
  - 高架桥 / bridge deck 语义也暂时冻结，所有道路统一回到平面
  - terrain async / terrain page / terrain LOD 不再是主链必要条件

## 里程碑

| 里程碑 | 范围 | DoD | 验证命令/测试 | 状态 |
|---|---|---|---|---|
| M1 近场 runtime 边界冻结 | 把 `crowd/traffic/renderer_sync/HUD/minimap` 的热路径责任边界写成正式 contract 与 plan | `v36` 计划与测试口径冻结，明确哪些成本允许在线程外计算、哪些必须留主线程 commit | 文档自检 + `v35` 既有 diagnostics/performance artifact 对账 | done |
| M2 crowd / traffic 数据化首轮落地 | 先从更好切的 traffic chunk snapshot / cached assignment reuse 开刀，再继续推进 crowd | 至少一条近场人车热路径的结构性重建被拆掉，并拿到 before/after 证据；不得打坏 density / combat / visual contract | `tests/world/test_city_vehicle_*` + `tests/e2e/test_city_vehicle_performance_profile.gd` + fresh `v36-m1-verification-2026-03-21.md` | doing |
| M3 flat-ground runtime simplification | 取消 terrain runtime 主链，并把高架桥语义一起冻结为平路 | 普通地面/道路/建筑/玩家/行人全部回到绝对平面；车辆不飞天；terrain async 可为 0；`bridge_count/proxy/collision` 退化为 0 | flat-ground world tests + `tests/e2e/test_city_first_visit_performance_profile.gd` + `tests/e2e/test_city_runtime_performance_profile.gd` | doing |
| M4 traffic 数据化 + dirty batch commit | 在 flat-ground 基线上继续治理车辆近场热路径 | `traffic_update` 与 `renderer_sync_traffic` 有 before/after 对账，且不打坏 drive / hijack / collision / traffic contract | vehicle world tests + rendered inspection/live-gunshot rerun | todo |
| M5 纯数据相位并行化 | 把可并行的候选收集/排序/采样/威胁评估搬离主线程 | 至少一条热路径的纯数据相位被 thread-pool 化，且不触碰非线程安全 SceneTree 操作 | focused world tests + rendered diagnostics/performance rerun | todo |
| M6 closeout rerun | fresh rendered 收口与验证文档 | `inspection` 与 `live gunshot` 两条链都能以 fresh rendered 证据证明改善，并保住基础 crowd/traffic/runtime 红线 | `tests/e2e/*performance*.gd` + `docs/plan/v36-mN-verification-YYYY-MM-DD.md` | todo |

## 计划索引

- [v36-nearfield-runtime-data-batching-parallelization.md](./v36-nearfield-runtime-data-batching-parallelization.md)
- [v36-flat-ground-runtime-simplification.md](./v36-flat-ground-runtime-simplification.md)
- [v36-m1-verification-2026-03-21.md](./v36-m1-verification-2026-03-21.md)
- [v36-m2-verification-2026-03-21.md](./v36-m2-verification-2026-03-21.md)
- [v36-m3-verification-2026-03-21.md](./v36-m3-verification-2026-03-21.md)

## 追溯矩阵

| Req ID | v36 Plan | 单元/集成测试 | E2E / 验证命令 | 证据 | 状态 |
|---|---|---|---|---|---|
| REQ-0001-006 | `v36-nearfield-runtime-data-batching-parallelization.md` | `tests/world/test_city_streaming_profile_stats.gd`、`tests/world/test_city_runtime_streaming_diagnostic_contract.gd` | `tests/e2e/test_city_runtime_performance_profile.gd`、`tests/e2e/test_city_first_visit_performance_profile.gd` | `docs/plan/v36-mN-verification-YYYY-MM-DD.md` | todo |
| REQ-0001-004 / REQ-0001-006 / REQ-0002-003 / REQ-0003-004 | `v36-flat-ground-runtime-simplification.md` | `tests/world/test_city_terrain_sampler.gd`、`tests/world/test_city_chunk_setup_profile_breakdown.gd`、`tests/world/test_city_pedestrian_runtime_grounding.gd`、`tests/world/test_city_vehicle_drive_surface_grounding.gd` | `tests/e2e/test_city_first_visit_performance_profile.gd`、`tests/e2e/test_city_runtime_performance_profile.gd` | `docs/plan/v36-mN-verification-YYYY-MM-DD.md` | todo |
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

- [ECN-0027-flat-ground-runtime-simplification.md](../ecn/ECN-0027-flat-ground-runtime-simplification.md)

## 差异列表

- `v35` 已经证明：真实渲染下的近场街道抖动并非错觉，而且主要热点集中在 `crowd/traffic` 更新与 `renderer_sync`，而不是远处静态建筑。
- `v35` 也证明：单纯砍人口密度不是正解，既可能打坏 density guard，也不能保证把 `wall_frame_avg_usec` 拉回红线以内。
- `2026-03-21` 的 `v36` 首个执行切片已经把 vehicle chunk snapshot 从 per-frame render dict 推进到 state ref，并移除了 cached assignment reuse 下的整块 snapshot rebuild；相关测试与 headless vehicle profile 见 `v36-m1-verification-2026-03-21.md`。
- `2026-03-21` 的第二个执行切片已经把 pedestrian / vehicle Tier 1 `MultiMesh` batch 改成“实体槽位复用优先”，消除了 reorder-only transform writes；fresh rendered `inspection` / `live gunshot` 证据见 `v36-m2-verification-2026-03-21.md`。
- 首个切片之后，fresh headless `test_city_runtime_performance_profile.gd` 曾报 warm `wall_frame_avg_usec = 12323`；这证明 traffic 首刀还不足以把 shared runtime 打穿。
- 经过第二个切片后，fresh headless warm runtime 的 `wall_frame_avg_usec` 已降到 `10204`，但 `test_city_runtime_performance_profile.gd` 目前会卡在 `ped_tier1_count = 108 < 150` 的冻结 density guard；进一步交叉检查 `test_city_pedestrian_lite_density_uplift.gd` 也报 warm `tier1_count = 103 < 150`，说明这是当前工作树里需要单列处理的 baseline 问题，不能把这次 frame-time 改善包装成 closeout。
- 第二个切片之后，fresh rendered diagnostics 已经出现改善，但 rendered performance guards 仍未通过：inspection 仍卡 `wall_frame_avg_usec` 与 density，live gunshot 仍卡 density / witness 语义，因此 `v36` 还处在“诊断改善、closeout 未达成”的中间态。
- `2026-03-21` 晚间的 main-world 手测进一步暴露出“车辆飞天”和地形主链复杂度过高的问题，因此 `v36` 已按 [ECN-0027](../ecn/ECN-0027-flat-ground-runtime-simplification.md) 切入 flat-ground runtime simplification：先把普通地面统一为绝对平面，随后又按用户口径把高架桥语义也一并冻结为平路，再继续三化。
- 同日补充切片又补掉了两个半拉子缺口：`gameplay` 行人 farfield render 不再因高速 traversal 把整条街裁空；retained chunk scene 复用链也不再在 prepare 相位白做 near 组预构。对应 fresh headless 结果见 `v36-m2-verification-2026-03-21.md`：
  - `test_city_runtime_crowded_diagnostic_snapshot.gd`: `wall_frame_avg_usec = 9666`、`update_streaming_renderer_sync_queue_prepare_avg_usec = 48`
  - `test_city_runtime_performance_profile.gd`: `wall_frame_avg_usec = 9895`、`update_streaming_renderer_sync_avg_usec = 2654`、`ped_tier1_count = 169`
  - 这说明前两化在 headless warm runtime 上已经把 shared frame-time 拉回红线内，但 rendered closeout 仍需 fresh rerun，不能跳过。
- `v36` 仍有两个开放风险需要正面应对：
  - inspection 中距离 visual / tier 语义不能因性能治理而退化成肉眼明显离谱的 proxy 体验
  - 并行化只能作用于纯数据相位，任何 SceneTree / render commit 误上线程都会制造新的不稳定

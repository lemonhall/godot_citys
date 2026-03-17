# V22 Index

## 愿景

PRD 入口：

- [PRD-0001 Large City Foundation](../prd/PRD-0001-large-city-foundation.md)
- [PRD-0002 Pedestrian Crowd Foundation](../prd/PRD-0002-pedestrian-crowd-foundation.md)
- [PRD-0003 Vehicle Traffic Foundation](../prd/PRD-0003-vehicle-traffic-foundation.md)

依赖入口：

- [v5-terrain-redline-closeout.md](./v5-terrain-redline-closeout.md)
- [v12-index.md](./v12-index.md)
- [v14-index.md](./v14-index.md)
- [v21-index.md](./v21-index.md)

`v22` 的目标不是新增玩法，而是把 `2026-03-17` fresh profiling 暴露出的 shared runtime 红线失守正式收口。`v22` 已把 `update_streaming -> prepare/build_profile -> cold terrain async complete -> crowd/traffic runtime` 这条 shared 主链拆出细粒度诊断字段，并在 `2026-03-17` fresh closeout 中恢复了 `chunk setup`、`first-visit` 与 `warm runtime` 三项护栏；同时把新增字段名、中文释义、采样口径和 profiling 顺序冻结进正式文档，便于后续继续做性能优化时直接复用。

## 决策冻结

- `v22` 首轮只做 shared runtime 性能诊断、收口与文档化，不新增玩法、UI 或视觉范围。
- 当前基线冻结为 `2026-03-17` 串行 fresh profiling：后续任何“变好/变坏”的判断都必须与这组数据对账。
- profiling 三件套必须继续串行执行，不得并行，不得与其他 Godot profiling 进程混跑。
- `v22` closeout 的 profiling 顺序冻结为：`chunk_setup -> first_visit -> warm runtime`。
- 顺序冻结理由：`first-visit` 的语义是“真正未预热的冷路径”；把 warm traversal 放在它前面虽然仍是独立 Godot 进程，但会让 cold case 解释口径变脏，因此 closeout 默认先测冷路径、再测 warm。
- 当前已收敛出的主嫌疑链冻结为：`update_streaming` shared path，其中 queue/prepare 的 `build_profile`、cold `terrain_async_complete`、crowd runtime、traffic runtime 都有正式诊断字段可对账。
- 不允许通过关闭 `pedestrians / vehicles / tasks`、缩小 active chunk window、冻结移动、降低 density、改空场景 profiling 路线、或只调测试阈值来宣称过线。
- 文档必须保留原始字段名，并提供中文解释，便于你我后续协同阅读 profile 输出与 diff。

## 里程碑

| 里程碑 | 范围 | DoD | 验证命令/测试 | 状态 |
|---|---|---|---|---|
| M1 基线固化与指标词典 | `v22` 文档、fresh profiling 摘要、中文指标解释 | `docs/plan/v22-index.md` 与 `docs/plan/v22-performance-redline-recovery.md` 明确记录三项性能护栏命令、阈值、当前值、失败点与指标字典 | `tests/world/test_city_chunk_setup_profile_breakdown.gd`、`tests/e2e/test_city_runtime_performance_profile.gd`、`tests/e2e/test_city_first_visit_performance_profile.gd` | done |
| M2 边界定位与诊断探针 | `update_streaming`、prepare/mount、terrain async complete、crowd/traffic breakdown 的边界缩小 | 自动化证据能指出 warm 与 first-visit 分别是“最后一次正确”和“第一次错误”之间的主嫌疑阶段，而不是泛泛说“有性能问题” | `tests/world/test_city_runtime_streaming_diagnostic_contract.gd`、`tests/world/test_city_chunk_profile_prepare_breakdown.gd` | done |
| M3 warm runtime 收口 | warm traversal shared runtime | `wall_frame_avg_usec <= 11000`、`update_streaming_avg_usec <= 10000`、`streaming_mount_setup_avg_usec <= 5500`，且 `ped_tier1_count >= 150` 不回退 | `tests/e2e/test_city_runtime_performance_profile.gd` | done |
| M4 first-visit 收口 | cold corridor / first-visit shared runtime | `wall_frame_avg_usec <= 16667`、`update_streaming_avg_usec <= 14500`、`streaming_mount_setup_avg_usec <= 5500`，并解释 `terrain_async_complete` 与尖峰变化 | `tests/e2e/test_city_first_visit_performance_profile.gd` | done |
| M5 closeout verification | 三件套 + 受影响主链回归 + verification artifact | profiling 三件套串行 PASS；新增/修改的 targeted tests PASS；fresh 证据写入 `docs/plan/v22-mN-verification-YYYY-MM-DD.md` | `tests/world/test_city_chunk_setup_profile_breakdown.gd`、`tests/e2e/test_city_runtime_performance_profile.gd`、`tests/e2e/test_city_first_visit_performance_profile.gd` + 受影响模块测试 | done |

## 计划索引

- [v22-performance-redline-recovery.md](./v22-performance-redline-recovery.md)
- [v22-m5-verification-2026-03-17.md](./v22-m5-verification-2026-03-17.md)

## 追溯矩阵

| Req ID | v22 Plan | 单元/集成测试 | E2E / 验证命令 | 证据 | 状态 |
|---|---|---|---|---|---|
| REQ-0001-006 | `v22-performance-redline-recovery.md` | `tests/world/test_city_chunk_setup_profile_breakdown.gd` | `--script res://tests/e2e/test_city_first_visit_performance_profile.gd`、`--script res://tests/e2e/test_city_runtime_performance_profile.gd` | `docs/plan/v22-performance-redline-recovery.md`、`docs/plan/v22-m5-verification-2026-03-17.md` | done |
| REQ-0001-010 | `v22-performance-redline-recovery.md` | `tests/e2e/test_city_runtime_performance_profile.gd` | `--script res://tests/e2e/test_city_runtime_performance_profile.gd` | `docs/plan/v22-performance-redline-recovery.md`、`docs/plan/v22-m5-verification-2026-03-17.md` | done |
| REQ-0001-011 | `v22-performance-redline-recovery.md` | `tests/world/test_city_chunk_setup_profile_breakdown.gd` | `--script res://tests/e2e/test_city_first_visit_performance_profile.gd` | `docs/plan/v22-performance-redline-recovery.md`、`docs/plan/v22-m5-verification-2026-03-17.md` | done |
| REQ-0002-007 / REQ-0002-016 | `v22-performance-redline-recovery.md` | `tests/world/test_city_runtime_streaming_diagnostic_contract.gd`、`tests/e2e/test_city_runtime_performance_profile.gd` | `--script res://tests/e2e/test_city_runtime_performance_profile.gd` | `docs/plan/v22-performance-redline-recovery.md`、`docs/plan/v22-m5-verification-2026-03-17.md` | done |
| REQ-0003-009 | `v22-performance-redline-recovery.md` | `tests/world/test_city_runtime_streaming_diagnostic_contract.gd`、`tests/e2e/test_city_first_visit_performance_profile.gd` | `--script res://tests/e2e/test_city_first_visit_performance_profile.gd`、`--script res://tests/e2e/test_city_runtime_performance_profile.gd` | `docs/plan/v22-performance-redline-recovery.md`、`docs/plan/v22-m5-verification-2026-03-17.md` | done |

## Closeout 证据口径

- `v22` closeout 必须以 fresh profiling + fresh targeted diagnostics 为准，统一落在 `docs/plan/v22-mN-verification-YYYY-MM-DD.md`。
- 只更新聊天记录、只记录一句“性能不好”、或只靠旧的 `v21` profiling 产物，不能作为 `v22` 证据。
- 任何“性能改善”声明都必须附带与 `2026-03-17` 基线对账后的数值变化。
- profiling 三件套在 `v22` closeout 中默认按 `chunk_setup -> first_visit -> warm runtime` 顺序执行；如果未来要改顺序，必须先更新本文件与 verification artifact 的顺序冻结说明。

## ECN 索引

- 当前无。

## 差异列表

- `2026-03-17` fresh `chunk setup` 已 PASS：`total_usec = 3510`、`ground_usec = 1024`、`road_overlay_usec = 3`，当前不是主矛盾。
- `2026-03-17` fresh warm runtime 已 FAIL：`wall_frame_avg_usec = 12933 > 11000`，`update_streaming_avg_usec = 11455 > 10000`，`streaming_mount_setup_avg_usec = 3673 <= 5500`。
- `2026-03-17` fresh first-visit 已 FAIL：`update_streaming_avg_usec = 18171 > 14500`，`wall_frame_avg_usec = 19213 > 16667`，`streaming_mount_setup_avg_usec = 5300 <= 5500`。
- 当前两条 runtime 护栏都把怀疑边界压到了 shared `update_streaming` 主链；first-visit 还额外暴露 `streaming_terrain_async_complete_avg_usec = 142308` 与 `wall_frame_max_usec = 159766` 的冷路径尖峰。
- `2026-03-17` M5 closeout 已在冻结顺序 `chunk_setup -> first_visit -> warm runtime` 下 fresh PASS：
  - `chunk setup`: `total_usec = 3390`、`ground_usec = 969`、`road_overlay_usec = 2`
  - `first-visit`: `update_streaming_avg_usec = 14493`、`wall_frame_avg_usec = 15322`、`streaming_mount_setup_avg_usec = 4680`
  - `warm runtime`: `update_streaming_avg_usec = 8599`、`wall_frame_avg_usec = 10235`、`streaming_mount_setup_avg_usec = 3285`、`ped_tier1_count = 155`
- `v22` 额外把 `update_streaming_chunk_streamer_*`、`update_streaming_renderer_sync_*`、queue phase、crowd assignment 与 `building_*_usec` 细粒度诊断字段正式写回文档，后续优化不必再临时加探针。
- 观察到 `tests/world/test_city_streetfront_building_layout.gd` 仍在当前仓库红线内，这条属于 `v13` 形态链的既有风险，不属于本次 `v22` closeout 判定条件；如要处理，应单独开后续 compact。

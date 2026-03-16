# V16 Index

## 愿景

PRD 入口：[PRD-0009 Building Serviceability Reconstruction](../prd/PRD-0009-building-serviceability-reconstruction.md)

设计入口：[2026-03-16-v16-building-serviceability-design.md](../plans/2026-03-16-v16-building-serviceability-design.md)

依赖入口：

- [PRD-0008 Laser Designator World Inspection](../prd/PRD-0008-laser-designator-world-inspection.md)
- [v15-index.md](./v15-index.md)

`v16` 的目标是把 `v15` 冻结下来的 `building_id` 正式接进服务化闭环：玩家先用激光点中建筑，再在有效窗口内按小键盘 `+`，系统异步导出独立建筑场景与生成参数 sidecar，并在下次进城或 chunk 重新 mount 时，用同一个 `building_id` 把原 procedural building 替换为功能建筑场景，同时继续守住 inspection、streaming 与 profiling 红线。

## 决策冻结

- 导出触发键冻结为小键盘 `+`，并且只在最近一次有效 inspection 为 `building` 时生效。
- 导出路径默认优先写入 `res://city_game/serviceability/buildings/generated/`；失败时自动回退到 `user://serviceability/buildings/generated/`。
- override registry 冻结为 `building_id -> scene_path / manifest_path`；同一 `building_id` 只允许一个当前生效入口。
- 已存在功能建筑 override 的 `building_id` 不允许被新的 KP+ 导出静默覆盖，必须显式拒绝。
- registry 合并优先级冻结为 preferred path 优先；fallback path 只能补缺，不能覆盖同 `building_id` 的 preferred entry。
- 功能建筑替换冻结在 `CityChunkScene` 的 near mount/build 链，不允许引入 per-frame 全量 registry 扫描。
- `v16` 不承诺当前 session 立即热替换；正式生效时机是下一次进城或 chunk remount。
- `v16` 不承诺 mid/far HLOD 现在就显示功能建筑专属外观。

## 里程碑

| 里程碑 | 范围 | DoD | 验证命令/测试 | 状态 |
|---|---|---|---|---|
| M1 异步导出与场景产物 | inspection window、KP+ 触发、scene+sidecar 导出、Toast | 有效 building inspection 可触发异步导出；scene/sidecar/registry 实际落盘；Toast 报告开始与完成；重复导出不会覆盖已有功能场景 | `tests/world/test_city_building_serviceability_export.gd` | done |
| M2 回城替换挂点 | registry 持久化、next-session override instantiate、稳定锚点 | 第二次 world session 会按同一 `building_id` 挂 override scene；无 override 的建筑仍走 procedural | `tests/e2e/test_city_building_serviceability_flow.gd` | done |
| M3 回归与性能复验 | `v15` inspection 回归、profiling 三件套、registry priority | 激光 inspection/HUD 不回退；preferred registry 优先级稳定；性能三件套串行通过 | `tests/world/test_city_player_laser_designator.gd`、`tests/world/test_city_building_override_registry_priority.gd`、`tests/world/test_city_chunk_setup_profile_breakdown.gd`、`tests/e2e/test_city_runtime_performance_profile.gd`、`tests/e2e/test_city_first_visit_performance_profile.gd` | done |

## 计划索引

- [v16-building-serviceability.md](./v16-building-serviceability.md)

## 追溯矩阵

| Req ID | v16 Plan | 单元/集成测试 | E2E / 验证命令 | 证据 | 状态 |
|---|---|---|---|---|---|
| REQ-0009-001 | `v16-building-serviceability.md` | `tests/world/test_city_building_serviceability_export.gd` | `--script res://tests/e2e/test_city_building_serviceability_flow.gd` | [v16-m3-verification-2026-03-16.md](./v16-m3-verification-2026-03-16.md) | done |
| REQ-0009-002 | `v16-building-serviceability.md` | `tests/world/test_city_building_serviceability_export.gd` | `--script res://tests/e2e/test_city_building_serviceability_flow.gd` | [v16-m3-verification-2026-03-16.md](./v16-m3-verification-2026-03-16.md) | done |
| REQ-0009-003 | `v16-building-serviceability.md` | `tests/world/test_city_building_serviceability_export.gd` | `--script res://tests/e2e/test_city_building_serviceability_flow.gd` | [v16-m3-verification-2026-03-16.md](./v16-m3-verification-2026-03-16.md) | done |
| REQ-0009-004 | `v16-building-serviceability.md` | `tests/world/test_city_player_laser_designator.gd`、`tests/world/test_city_building_serviceability_export.gd`、`tests/world/test_city_building_override_registry_priority.gd` | `--script res://tests/world/test_city_chunk_setup_profile_breakdown.gd`、`--script res://tests/e2e/test_city_runtime_performance_profile.gd`、`--script res://tests/e2e/test_city_first_visit_performance_profile.gd` | [v16-m3-verification-2026-03-16.md](./v16-m3-verification-2026-03-16.md) | done |

## Closeout 证据口径

- `v16` closeout 必须以 fresh tests + fresh profiling 为准，统一落在 `docs/plan/v16-mN-verification-YYYY-MM-DD.md`。
- 只生成文件、不验证 load/instantiate，不算 `v16` 证据。
- profiling 三件套必须严格串行执行。

## ECN 索引

- 当前无。

## 差异列表

- `v16` 首版不做当前 session 立即热替换，只承诺 next-session / remount 生效。
- `v16` 首版不做功能建筑专属 mid/far HLOD。

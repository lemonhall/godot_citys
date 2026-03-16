# V18 Index

## 愿景

PRD 入口：[PRD-0011 Custom Building Full-Map Icons](../prd/PRD-0011-custom-building-full-map-icons.md)

设计入口：[2026-03-16-v18-custom-building-full-map-icons-design.md](../plans/2026-03-16-v18-custom-building-full-map-icons-design.md)

依赖入口：

- [PRD-0009 Building Serviceability Reconstruction](../prd/PRD-0009-building-serviceability-reconstruction.md)
- [v16-index.md](./v16-index.md)
- [v12-index.md](./v12-index.md)
- [v14-index.md](./v14-index.md)

`v18` 的目标是把“自定义建筑能在 full map 上拥有正式 icon/emoji”冻结成正式主链：icon 定义与自定义建筑 manifest 放在一起，运行时在启动后懒加载 override registry 指向的 manifest，渐进式缓存 full-map pin contract，并让 full map 用 `icon_id -> glyph` 的方式显示这批建筑；minimap、导航、fast travel 与 autodrive 均不纳入本版范围。

## 决策冻结

- `v18` 首版只做 full map，不做 minimap。
- icon 定义冻结在 `building_manifest.json` 的 `full_map_pin` payload 中。
- `full_map_pin` 最小字段冻结为：`visible / icon_id / title / subtitle / priority`。
- full-map pin 的世界坐标冻结为：优先读取 manifest 现有 `source_building_contract.inspection_payload.world_position`，其次退回 `source_building_contract.center`；禁止为取坐标去加载 `.tscn`。
- lazy loader 只允许基于 override registry entry 的 `manifest_path` 分批读取 manifest；禁止递归扫描目录和同步加载全部场景。
- 运行时缓存冻结为 session-memory cache；首版不做磁盘 pin cache。
- 自定义建筑 pin 的 `visibility_scope` 冻结为 `full_map`。
- `icon_id -> emoji/text glyph` 映射冻结在 UI 层，而不是 runtime contract。

## 里程碑

| 里程碑 | 范围 | DoD | 验证命令/测试 | 状态 |
|---|---|---|---|---|
| M1 manifest contract + lazy loader | `full_map_pin` contract、增量 manifest loader、内存 cache | runtime 能按批次读取 manifest；只为声明 `full_map_pin` 的建筑生成 pin；不会为取 pin 去加载 scene | `tests/world/test_city_service_building_map_pin_runtime.gd` | done |
| M2 full map icon integration | shared pin integration、full map glyph render、咖啡馆 pin | 打开 full map 后能看到咖啡馆 pin；render state 暴露 `icon_id + icon_glyph`；minimap 不出现这批 pin | `tests/world/test_city_service_building_full_map_pin_contract.gd`、`tests/e2e/test_city_service_building_full_map_icon_flow.gd` | done |
| M3 regressions + profiling | map/minimap/task pin 回归、startup-delay no-IO contract、性能三件套 | 现有 map/minimap/task pin contract 不回退；full map 关闭时 early traversal window 不读 manifest；profiling 三件套继续过线 | `tests/world/test_city_map_pin_overlay.gd`、`tests/world/test_city_minimap_idle_contract.gd`、`tests/world/test_city_task_map_tab_contract.gd`、`tests/world/test_city_service_building_map_pin_startup_delay_contract.gd`、`tests/world/test_city_chunk_setup_profile_breakdown.gd`、`tests/e2e/test_city_runtime_performance_profile.gd`、`tests/e2e/test_city_first_visit_performance_profile.gd` | blocked |

## 计划索引

- [v18-custom-building-full-map-icons.md](./v18-custom-building-full-map-icons.md)

## 追溯矩阵

| Req ID | v18 Plan | 单元/集成测试 | E2E / 验证命令 | 证据 | 状态 |
|---|---|---|---|---|---|
| REQ-0011-001 | `v18-custom-building-full-map-icons.md` | `tests/world/test_city_service_building_map_pin_runtime.gd` | `--script res://tests/world/test_city_service_building_full_map_pin_contract.gd` | [v18-m3-verification-2026-03-16.md](./v18-m3-verification-2026-03-16.md) | done |
| REQ-0011-002 | `v18-custom-building-full-map-icons.md` | `tests/world/test_city_service_building_map_pin_runtime.gd`、`tests/world/test_city_service_building_map_pin_startup_delay_contract.gd` | `--script res://tests/e2e/test_city_service_building_full_map_icon_flow.gd` | [v18-m3-verification-2026-03-16.md](./v18-m3-verification-2026-03-16.md) | done |
| REQ-0011-003 | `v18-custom-building-full-map-icons.md` | `tests/world/test_city_service_building_full_map_pin_contract.gd` | `--script res://tests/e2e/test_city_service_building_full_map_icon_flow.gd` | [v18-m3-verification-2026-03-16.md](./v18-m3-verification-2026-03-16.md) | done |
| REQ-0011-004 | `v18-custom-building-full-map-icons.md` | `tests/world/test_city_map_pin_overlay.gd`、`tests/world/test_city_minimap_idle_contract.gd`、`tests/world/test_city_task_map_tab_contract.gd` | `--script res://tests/world/test_city_chunk_setup_profile_breakdown.gd`、`--script res://tests/e2e/test_city_runtime_performance_profile.gd`、`--script res://tests/e2e/test_city_first_visit_performance_profile.gd` | [v18-m3-verification-2026-03-16.md](./v18-m3-verification-2026-03-16.md) | blocked |

## Closeout 证据口径

- `v18` closeout 必须以 fresh tests + fresh profiling 为准，统一落在 `docs/plan/v18-mN-verification-YYYY-MM-DD.md`。
- 只有 manifest 里有字段、但 world/runtime/full map 没吃进去，不算完成。
- 只有 full map 上画了点、但不是从 manifest lazy loader 主链出来的，不算完成。
- minimap 被默认 pin 污染，也不算完成。

## ECN 索引

- 当前无。

## 差异列表

- `v18` 首版不做 minimap。
- `v18` 首版不做 pin 点击导航、fast travel、autodrive。
- `v18` 首版不做自动 scene -> manifest icon 推断。
- 当前 fresh profiling 中，`test_city_first_visit_performance_profile.gd` 仍未过线；`REQ-0011-004` 尚未收口。
- `tests/world/test_city_service_building_map_pin_startup_delay_contract.gd` 已证明：full map 关闭时，first-visit early window 内 `manifest_read_count = 0`，`v18` loader 未进入该 profiling 窗口。

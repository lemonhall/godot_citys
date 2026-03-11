# V3 Index

## 愿景

PRD 入口：[PRD-0001 Large City Foundation](../prd/PRD-0001-large-city-foundation.md)

v3 的目标不是再给 v2 路网“补一点随机扰动”，而是把整座城市的道路骨架升级为参考项目式的连续生长道路图，并把这份道路图同时变成 3D 城市渲染、小地图、宏观导航与后续路名/POI 系统的共同上游。v3 完成后，城市的自然感与可辨认性都必须明显提升，且 HUD 中要出现一张与真实世界同源的 2D 小地图。

## 里程碑

| 里程碑 | 范围 | DoD | 验证命令/测试 | 状态 |
|---|---|---|---|---|
| M1 连续道路图 | 参考式 segment growth、局部约束、交叉吸附/切分、world-space road graph 替换 | 固定 seed 下 road graph 非空、存在非正交主干路与局部吸附形成的交叉口；chunk 道路查询直接消费共享 road graph | `test_city_reference_road_graph.gd`、`test_city_road_network_continuity.gd`、`test_city_shared_graph_road_takeover.gd` | done |
| M2 3D 路网接管 | chunk 渲染只消费共享道路图，建筑沿道路/街区布局 | 近景不再出现大量 per-chunk 孤路；道路跨 chunk 连续；建筑/道路关系仍满足缓冲区避让 | `test_city_shared_graph_road_takeover.gd`、`test_city_building_collision.gd`、`test_city_bridge_grade_constraints.gd`、`test_city_road_section_templates.gd` | done |
| M3 2D 小地图 | world road graph → 2D 投影 → HUD minimap | 小地图默认折叠，可展开；显示道路骨架、玩家位置/朝向；世界坐标到小地图坐标投影稳定可测 | `test_city_minimap_projection.gd`、`test_city_prototype_ui.gd` | done |
| M4 路径高亮与导航可视化 | 宏观 route 显示到小地图 | 至少一条 `plan_macro_route()` 结果可在小地图中高亮显示，且起终点与玩家/目标位置对应 | `test_city_minimap_route_overlay.gd`、`test_city_navigation_flow.gd` | done |

## 计划索引

- [v3-reference-road-graph.md](./v3-reference-road-graph.md)
- [v3-minimap-navigation.md](./v3-minimap-navigation.md)

## 追溯矩阵

| Req ID | v3 Plan | 单元/集成测试 | E2E / 验证命令 | 证据 | 状态 |
|---|---|---|---|---|---|
| REQ-0001-002 | `v3-reference-road-graph.md` | `tests/world/test_city_reference_road_graph.gd`、`tests/world/test_city_road_network_continuity.gd`、`tests/world/test_city_shared_graph_road_takeover.gd` | `--script res://tests/world/test_city_shared_graph_road_takeover.gd` | 2026-03-11 本地 headless `PASS`，已验证共享 `road_graph` 暴露 growth stats、真实交叉口，且 chunk 路面直接消费共享骨架 | done |
| REQ-0001-004 | `v3-reference-road-graph.md` | `tests/world/test_city_shared_graph_road_takeover.gd`、`tests/world/test_city_building_collision.gd`、`tests/world/test_city_road_section_templates.gd` | `--script res://tests/world/test_city_building_collision.gd` | 2026-03-11 本地 headless `PASS`，chunk 3D 路网已去除 per-chunk local cell fallback，建筑/道路净距与道路模板约束保持通过 | done |
| REQ-0001-005 | `v3-minimap-navigation.md` | `tests/world/test_city_minimap_route_overlay.gd`、`tests/e2e/test_city_navigation_flow.gd` | `--script res://tests/world/test_city_minimap_route_overlay.gd` | 2026-03-11 本地 headless `PASS`，宏观 route 已可投影为 minimap polyline | done |
| REQ-0001-006 | `v3-minimap-navigation.md` | `tests/world/test_city_prototype_ui.gd` | `--script res://tests/world/test_city_prototype_ui.gd` | 2026-03-11 本地 headless `PASS`，HUD 默认折叠且 minimap 已接入 | done |
| REQ-0001-009 | `v3-minimap-navigation.md` | `tests/world/test_city_minimap_projection.gd`、`tests/world/test_city_prototype_ui.gd` | `--script res://tests/world/test_city_minimap_projection.gd` | 2026-03-11 本地 headless `PASS`，已提供同源 2D 道路投影、玩家标记与 HUD minimap | done |

## ECN 索引

- [ECN-0006-reference-roadgraph-and-minimap.md](../ecn/ECN-0006-reference-roadgraph-and-minimap.md)：将参考项目式连续道路图与 2D 小地图/导航层纳入 v3。

## 差异列表

- v3 目标已闭环：参考式连续道路图、共享 3D 路网接管、同源 minimap 与 route overlay 均已落地并有自动化验证。
- 当前没有阻塞 v3 交付的残留差异；后续若继续推进，应进入 v4 范围，例如道路命名/指示牌、POI 与更强的 parcel 级街区求解。

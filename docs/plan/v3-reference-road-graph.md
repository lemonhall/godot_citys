# V3 Reference Road Graph

## Goal

把当前 `district edge + local cell` 的混合道路生成替换为参考项目式的连续道路图生成器，让 3D 城市共享一张更自然、更连续、更适合后续小地图与导航的 world road graph。

## PRD Trace

- REQ-0001-002
- REQ-0001-004

## Scope

做什么：

- 引入 segment growth 队列、主干路/支路模板、局部约束（相交、吸附、近距离接入、必要切分）
- 生成稳定可查询的 world-space continuous road graph
- 让 chunk 渲染只消费共享道路图，不再依赖本地 cell 补路制造自然感

不做什么：

- 不做 lane-level 交通系统
- 不做最终立交工程学求解
- 不做最终道路命名 UI

## Acceptance

- 固定 seed 下，road graph 稳定生成且拓扑一致。
- 自动化测试能证明 road graph 中存在非正交连续主干路、吸附接入、以及真实交叉切分结果。
- chunk 共享边界上的道路连接连续，不出现大量 per-chunk 孤路。
- 反作弊条款：不得保留当前 local cell 补路逻辑作为主要“自然感来源”。

## Files

- `city_game/world/generation/CityWorldGenerator.gd`
- `city_game/world/model/CityRoadGraph.gd`
- `city_game/world/rendering/CityRoadLayoutBuilder.gd`
- `tests/world/test_city_reference_road_graph.gd`
- `tests/world/test_city_road_network_continuity.gd`

## Steps

1. 写失败测试（红）
2. 运行到红：`test_city_reference_road_graph.gd`
3. 实现连续道路图生成器（绿）
4. 运行到绿：`test_city_reference_road_graph.gd` + `test_city_road_network_continuity.gd`
5. 必要重构：收敛共享 segment / intersection / query 接口
6. E2E：跑 `test_city_large_world_e2e.gd` 与 `test_city_travel_streaming_flow.gd`

## Risks

- 连续道路图生成如果没有 hard limit，容易把世界生成时间拉爆。
- 旧的建筑/地形/桥梁逻辑大量依赖当前道路段字典结构，替换时要先守住接口兼容层。
- 若只抄“看起来像”的扰动而不抄局部约束，最终效果仍会回到 v2 的补丁式自然感。

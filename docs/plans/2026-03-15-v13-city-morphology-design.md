# V13 City Morphology Design

## 问题定义

当前主线的问题不是“路不够弯”，而是**世界级生成口径错位**。`CityWorldGenerator.gd` 仍把 `district edge + collector` 当正式道路主骨架，再把 `CityReferenceRoadGraphBuilder.gd` 当 overlay 叠上去；这直接把 `70km x 70km` 世界铺成了近乎全域均匀的棋盘网。与此同时，`CityChunkProfileBuilder.gd` 的建筑候选主要来自 chunk 内规则格点扫描，离道路近只是一个评分项，不是正式的街道 frontage 约束，因此建筑密度和朝向也会继续均匀化。

这解释了为什么当前 2D 图像会退化成“密密麻麻的一张网”：不是 UI 渲染错了，而是上游 `road_graph` 和下游 building placement 都还在消费错误的世界级分布假设。

## 设计裁决

`v13` 采取三项硬改动：

1. **道路主骨架接管**：`district graph` 只保留为分块/索引元数据，不再直接灌进 `road_graph` 作为可见道路来源。新的 `road_graph` 由多中心密度场驱动的连续路段生长器直接生成，要求显式形成“主城区 + 卫星城 + 连接干道”。
2. **建筑沿街生成**：chunk building 不再先扫满候选格点再按 clearance 打分，而是先从 chunk 内正式道路段采样 streetfront candidate，再做碰撞/退距筛选；必要时再少量补 infill。
3. **PNG 世界级验收**：新增 deterministic overview exporter，直接从当前 `road_graph + chunk building layout` 生成 PNG 和 metadata。之后的人工验收不再先看运行时感觉，而是先看这张 2D 总览图是否像一个自然城市。

## 生成策略

道路生成借 `refs/citygen-godot` 的思想，但不照搬 2D physics 实现：

- 用多中心 population field 代替当前单中心 radial bias。至少一个中心城区，两个以上卫星中心，外加中心到卫星的 corridor bias。
- 用 `priority queue + global goals + local constraints` 继续生长 segment，但 highway seeds 不只从原点发四根，而是按中心/走廊成组播种。
- 局部约束继续保留“相交切分、近端点吸附、近线段接入”，但依赖现有 spatial index / shared road graph 数据结构，而不是 `Physics2DServer`。

建筑布局不做 parcel 级重构；本轮只把视觉上最关键的“沿街关系”写硬。也就是说，`block_layout / place_index` 等地址系统先不推翻，避免 `v12` 的查询/导航资产一起回炉。

## 验收与反作弊

`v13` 的 DoD 不再接受“world tests 全绿但全图仍像棋盘”的结果。正式验收包含三层：

- world tests：证明 `road_graph` 不再以内建 district lattice 为主骨架，且存在多中心形态统计。
- chunk tests：证明 building layout 的主体已经由 streetfront candidate 驱动。
- PNG tests：headless 输出 `PNG + metadata`，路径稳定、像素非空、统计可读。

反作弊条款：

- 不允许继续把全域 district grid 放进正式 `road_graph`，再靠缩放/裁切伪装成“只看到了主城”。
- 不允许导出静态参考图或与运行时世界数据脱钩的示意图。
- 不允许只修中心 `5x5` chunk 的视觉效果，而让全图 morphology 仍然保持均匀格网。

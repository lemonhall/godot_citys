# Large City Architecture Design

## Context

`godot_citys` 当前只有一个可运行的第三人称原型场景，适合验证基础移动与程序化街区，但还不具备承载几十平方公里城市的运行时结构。根据 `docs/research/2026-03-11-large-city-procgen-research.md`，后续扩城的关键不是继续把当前场景做大，而是先把世界表示、加载边界、渲染降级和导航边界定义清楚。

本设计文档的目标是锁定一个足够稳妥、又不会过早过重的 v2 方案，供后续塔山循环中的 PRD 与计划文档引用。

## Alternatives Considered

### Option A: 继续扩写单场景原型

做法是继续修改 `CityPrototype.tscn`，直接在场景里生成更多 block、更多建筑、更多装饰，并主要依赖简单 LOD 维持显示成本。优点是实现快、改动集中、短期能快速看到“大地图”效果。缺点也非常明确：所有内容都挤在同一棵场景树里，chunk 边界、数据层和 streaming 生命周期都不清晰，后面一旦叠加车辆、NPC、导航和存档，返工风险非常高。

这个方案只适合做一次性演示，不适合做长期城市底盘。

### Option B: 数据先行的 chunk streaming 底盘

先把世界拆成 `World -> District -> Chunk -> Parcel` 四层数据模型，只让玩家附近的小窗口进入高成本状态。运行时用 deterministic seed 生成城市骨架，用 chunk streamer 管理活跃区，用 chunk-local MultiMesh/HLOD/occluder 管理可见表现，用 chunk-local nav source 和宏观道路图管理寻路。

优点是与研究结论完全一致，扩展路径清晰，后续无论做步行、驾驶、任务、AI agent 还是存档都能挂在同一套世界模型上。缺点是前期用户可见功能增长较慢，大量工作在底层。

这是我推荐的路线。

### Option C: 直接 server-first、超低节点数架构

从一开始就把绝大多数实例、碰撞和可见性都下沉到 `RenderingServer` / `PhysicsServer` / `NavigationServer` 级别，场景树只保留极少量控制节点。理论上这是最能扛超大规模城市的方向，但对于当前项目阶段过重了：调试成本高，验证门槛高，也不利于先把游戏性原型跑起来。

这个方向更适合作为 v3 之后的性能升级路线，而不是 v2 起手。

## Recommended Design

v2 采用 **Option B：数据先行的 chunk streaming 底盘**。

设计约束如下：

1. 世界尺度先锁定为 `7km x 7km`，默认 `1 Godot unit = 1 meter`。
2. 运行时主 chunk 尺寸锁定为 `256m x 256m`。
3. 玩家周围高成本活跃窗口锁定为 `5x5` chunk；其外只保留低成本元数据或远景代理。
4. 不在 v2 引入双精度引擎、自定义 origin shifting、车辆交通、行人群体或任务系统。
5. 任何“几十平方公里已实现”的声明，必须以自动化测试和 debug 证据证明不是“单场景硬撑”或“只扩大地板”。

## Validation Focus

v2 的验证不以“城市是否好看”为主，而以四类证据为主：

1. 世界数据是否可确定性复现。
2. 活跃 chunk 数是否被硬限制。
3. 可见内容是否按 chunk 拆分并支持实例化/降级。
4. 玩家是否能跨 chunk 连续移动，且导航与 streaming 生命周期不断链。

后续 PRD 和 `docs/plan/v2-*.md` 将直接引用这些决策，不再重新讨论架构方向。

# V8 M2 Hand-Play Feedback And Replan

## Update

- `2026-03-14` 当前工作区的 `M2` 已不再被“远景方案不像车”“长期单向车流”“车辆分布很怪”这些产品问题阻塞。
- 最新手玩结论已经明确收敛为：当前远中景车辆表现、双向可见性和整体分布状态，用户都已经可以接受。
- 因此，`M2` 的真实状态不应再描述成“hand-play 体验整体失败”，而应改成“功能体验基本成立，但 closeout 仍被道路可视覆盖错位与性能红线证据卡住”。
- 本文件保留前半轮问题定位过程，但后续状态与 next round 必须以“只剩道路系统问题 + 性能问题”为准。

## 2026-03-14 Follow-Up Decisions

- 本轮后续修复范围已经进一步收口：
  - 必须补上车辆独立的性能护栏，不能只靠总 `wall_frame` 间接覆盖。
  - 必须把默认手玩视角下的双向车流可见性写成正式 contract，避免长期单向偏置。
  - 车辆 spacing guard 需要加强，尤其是同路同向的跟车距离；但当前密度被用户确认“基本合适”，本轮不再继续做动态 density 系统。
- `车在草坪上跑` 仍然记录为严重 blocker，但它被重新归类为 `road system / road overlay consumer` 问题，不再和车辆 query / density / proxy patch 混成一个修复项。
- 因此，当前 `M2` 的最近实现优先级调整为：
  1. `vehicle performance guard`
  2. `bidirectional coverage + spacing guard`
  3. `road coverage alignment` 诊断与道路侧修复

## Current Remaining Issues

### 1. 道路可视渲染与车辆 lane 消费仍然脱节

- 当前用户已经明确判断：这不是车辆 query 的问题，而是道路系统 / road overlay consumer 的问题。
- 车辆其实在 shared road semantics 派生出的 drivable lane 上跑，但主画面仍会出现“那里明明语义上是路、渲染上却是草”的错位。
- 因此，`M2` 的剩余视觉 blocker 不再是“车辆不像车”，而是“道路系统没有把对应道路画出来或画对”。

### 2. 性能问题仍未正式收口到红线

- 当前手玩口径已经不再是最早那种“只要有车就稳定 30-40 FPS”的严重失败，但也还不能诚实描述成 `<= 16.67ms` 已正式守住。
- 最新自动化证据更接近“车辆独立 budget 已有护栏，但 combined warm / first-visit redline 仍会偶发或轻微超线”。
- 因此，`M2` 现在的性能状态应描述为：`明显改善，但仍未 closeout`。

## Historical Blockers

以下 1-3 是本轮前半段的历史 blocker，用来解释为什么当时需要重写 `M2` 口径；它们不再是当前工作区的主要剩余问题。当前真正挂着的，只剩上面的 `道路覆盖错位` 与 `性能红线证据`。

### 1. Tier 1 远景视觉方案不成立

用户手玩反馈已经明确否定当前 `Tier 1` 的两次视觉尝试：

- 第一轮：远景白盒子车辆
  - 结果：显眼、诡异、像 placeholder，不像交通流。
- 第二轮：远景黑色地面阴影
  - 结果：在并不远的中距离上就退化成“影子替代车辆”，同样不合理。

这说明：

- `Tier 1` 不能再使用“只保轮廓、不保车辆实体”的 cheap proxy 方案作为默认产品形态。
- 后续 `Tier 1` 必须改为“仍像车”的低成本表示，而不是白盒或地面影子。

### 2. 车辆可视比例与角色比例失衡

最新手玩截图已经再次证明：

- 车辆相对 pedestrian 明显偏小
- 即使 `glb` 的 meter baseline 看上去“现实”，也没有和当前项目的角色 / 相机 / 世界呈现比例对齐

这说明当前问题不只是 manifest 的物理长度，而是：

- `vehicle asset normalization`
- `pedestrian presentation scale`
- `camera / third-person inspection framing`

这三者之间还没有经过同一口径校准。

### 3. 车辆分布仍然不自然

用户已经连续指出三类产品问题：

- 经常只能看到一个方向的车
- 会出现两辆车挤在一起、像连环跟车
- 同车型扎堆，视觉多样性很差

本轮虽然已经做过：

- world-space 近距去重
- 车型选择扰动
- density 上下调

但 live 结果仍然不稳定，说明当前问题不是单个参数，而是以下几层一起失真：

- `lane selection`
- `direction coverage`
- `same-road / sibling-lane` 的车流配比
- `chunk-local thinning` 对双向交通的偏置

### 4. 道路可视渲染与车辆 lane 消费脱节

这是当前最严重的产品 blocker。

用户手玩确认：

- 小地图上看得到路
- 车辆也沿着“系统认为有路”的区域在跑
- 但主画面上却是草坪，像车在草地上行驶

这意味着当前很可能存在以下边界裂缝之一：

1. shared `road_graph / lane graph` 是对的，但 `CityRoadMeshBuilder / road overlay consumer` 漏画了对应道路。
2. lane graph 与 road overlay 使用的道路宽度 / 偏移 / section template 并不一致。
3. minimap / debug view 消费的是语义道路，主画面消费的是另一套更稀疏或被裁剪的渲染结果。

无论是哪一种，结论都一样：

- 当前 `M2` 还不能说“车辆系统已经正确落在道路系统上”。

### 5. Live performance 仍然显著回退

用户手玩口径：

- 只要有车，FPS 基本落在 `30-40`
- 主观体感已经明显劣化

本轮 fresh headless 结果也没有完全洗白这个问题：

- 有过一轮 warm profile 到 `wall_frame_avg_usec = 10302`
- 但后续在 density / visual / query 调整后，又回到 `11066`、`12740` 这类不稳定结果
- first-visit 路径仍然多次高于目标，且 mount/update 仍会抖

所以当前真实状态不是“性能已经稳了”，而是：

- world tests 基本在绿
- live perception 与 isolated profiling 还没有建立足够可信的收口证据

## Root-Cause Boundaries

### Boundary A: 车辆 runtime 本身 vs 道路可视 consumer

当前最需要先判清楚的不是“继续怎么调车”，而是：

- 车到底走错了
- 还是路没画出来

后续必须先加 diagnostics，明确以下三份数据是否同源且同位置：

- `vehicle lane graph`
- minimap / debug road snapshot
- main scene road overlay mesh

如果这三者不对齐，再继续调 density、model scale、tier proxy 都是在修症状。

### Boundary B: 视觉表现 vs runtime budget

本轮已经证明：

- 白盒不行
- 阴影也不行

说明 `Tier 1` 不是一个“随便找个更便宜的几何体”就能交差的问题。
下一轮必须把 `Tier 1` 明确定义成产品资产：

- 它可以很轻
- 但必须仍然是车
- 并且需要和 `Tier 2 / Tier 3` 保持连续的 silhouette / scale / heading 认知

### Boundary C: density 参数 vs distribution policy

当前用户看到的“不自然”，更多来自分布策略而不是总量本身。

后续必须把“有多少车”和“车怎么分布”拆开：

- 总量：`spawn_slots_per_chunk`、tier budgets
- 分布：双向覆盖、road-class 配比、same-road 去重、车型多样性

否则每次只调一个 density 数，结果都会在“太空 / 太挤 / 太怪 / 太慢”之间摆动。

## Decision

### 1. `M2` 不再因 Tier 1 视觉方案、双向覆盖或分布状态被阻塞

- 当前用户已经明确接受现有远景方案、双向车流和整体分布。
- 因此，`M2` 不能继续按“远景策略待定 / 还得继续重做分布”来描述当前状态。

### 2. `M2` 剩余 closeout 焦点收缩为道路覆盖与性能红线

- 下一轮主要不是继续修车辆“像不像车”，而是把 `lane graph / minimap / road overlay` 的 coverage 对齐问题交回道路系统收口。
- 同时继续补 performance evidence，把 `vehicle-specific budget` 与 combined runtime redline 之间的证据链补齐。

### 3. M2 closeout 口径需要重写

当前 `v8-ambient-traffic-layered-runtime.md` 的 DoD 需要按最新手玩结论重写为：

- 当前远中景车辆形态、双向可见性和整体分布已达到可接受状态
- 车辆不会在主画面草坪上行驶
- combined runtime 的性能证据能正式证明 `16.67ms` 红线成立，而不是“体感还行但没有硬证据”

## Next Round

### Round 1: 道路覆盖对齐诊断

目标：

- 用正式 debug contract 证明 `lane graph / minimap / road overlay` 哪一层发生了偏移或漏画

产出：

- 新的 world/debug tests
- 一份对齐诊断结果写回 `docs/plan`

### Round 2: 性能证据与红线收口

目标：

- 把车辆独立 budget、combined warm runtime、combined first-visit 的证据链补齐
- 判清楚当前性能问题到底是 traffic runtime 本身、streaming mount、还是更上游的 combined cost

约束：

- 不能靠 profiling 专用降配、临时关车、临时减人来宣称达标
- 不能把道路系统问题继续伪装成车辆系统问题

### Round 3: 进入 M3 前的最小收口判断

目标：

- 如果道路覆盖错位已被道路系统修掉，combined redline 也拿到正式证据，那么 `M2` 就可以从“blocked / replan required”改成“closeout ready”。
- 之后再进入 `M3 Pedestrian Coupling 与红线共存`，而不是继续在 `M2` 上做无止境的视觉微调。

## Bottom Line

`2026-03-14` 当前工作区里，`M2` 的真实状态是：

- `vehicle_query / lane graph / runtime guard` 这些 contract 已经有基础
- 当前 hand-play 对远景方案、双向车流和车辆分布已经基本满意
- 道路可视渲染与车辆 lane 消费仍然没有真正对齐，这个问题应由道路系统继续收口
- 性能表现已经明显改善，但还没有拿到足够硬的 combined redline closeout 证据
- 因此，`M2` 现在更准确的状态是：`功能体验基本成立，剩余 blocker 只剩道路覆盖错位与性能红线`

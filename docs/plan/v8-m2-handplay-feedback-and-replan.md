# V8 M2 Hand-Play Feedback And Replan

## Update

- `2026-03-14` 当前工作区的 `M2` 不能继续按“边修边补白盒 / 阴影 / density”方式推进，也不能标记为完成。
- 本轮已经得到一组足够明确的手玩结论：车辆系统的主要风险不再只是“有没有车”，而是“当前车辆到底是不是作为城市道路系统的真实 downstream consumer 在工作”。
- 当前结论不是“车辆 runtime 完全没做出来”，而是“world contract 已经有了，但 hand-play 体验、道路可视对齐和 live performance 仍然不成立”。
- 因此本轮决定先落状态说明文档，停止继续堆战术 patch，并把 `M2` 视为 `blocked / replan required`。

## Hand-Play Blockers

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

### 1. 停止继续把 `M2` 往当前 shadow-proxy 方向硬推

当前 `Tier 1 shadow` 方案虽然能让某些 headless 数据变绿，但已经被手玩明确否决。

因此：

- 不再把“地面影子代理车”视为 `M2` 的默认 closeout 方案
- 当前工作区中的相关实验只保留为诊断历史，不代表产品方向

### 2. 先补诊断，再重做 M2

下一轮要先补的不是更多 patch，而是 3 组诊断合同：

1. `lane graph -> road overlay` coverage 对齐诊断
2. `minimap road -> main scene road` coverage 对齐诊断
3. `direction coverage / same-road spacing / model variety` 的 runtime distribution 诊断

### 3. M2 closeout 口径需要重写

当前 `v8-ambient-traffic-layered-runtime.md` 的 DoD 更偏“runtime contract 成立”，但缺少 hand-play 产品门槛。
下一轮 `M2` 必须把以下内容写成正式 acceptance：

- 中距离 `Tier 1` 看起来仍然是车，而不是影子或白盒
- 车辆不会在主画面草坪上行驶
- 双向交通在默认手玩视角下可见，不出现长期单向偏置
- 同模扎堆和贴屁股连环车不作为常态
- live hand-play FPS 不能出现“只要有车就稳定掉到 30-40” 的产品级回退

## Next Round

### Round 1: 道路覆盖对齐诊断

目标：

- 用正式 debug contract 证明 `lane graph / minimap / road overlay` 哪一层发生了偏移或漏画

产出：

- 新的 world/debug tests
- 一份对齐诊断结果写回 `docs/plan`

### Round 2: Tier 1 可视策略重做

目标：

- 用“仍像车”的轻量表示替代当前 shadow proxy

约束：

- 不能回退到 per-vehicle 重节点海
- 不能再用白盒或纯阴影交差

### Round 3: 分布策略与 live redline

目标：

- 重新定义双向交通覆盖、车型扰动、同路段 spacing 约束
- 再做 fresh warm / first-visit / hand-play closeout

## Bottom Line

`2026-03-14` 当前工作区里，`M2` 的真实状态是：

- `vehicle_query / lane graph / runtime guard` 这些 contract 已经有基础
- 但 hand-play 体验仍然明显失败
- 道路可视渲染与车辆 lane 消费很可能还没有真正对齐
- 所以本轮只能先落“状态与重做边界文档”，不能把 `M2` 描述成接近完成

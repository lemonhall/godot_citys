# 2026-03-23 Spider Leg Proportion And Gait Realism Deep Dive

## Executive Summary

这次 spider lab “会走但不像活物”，根因不是单一参数，而是三个问题叠在一起：腿段比例过于接近等长、腿根与落脚点几乎共线、以及 swing 阶段只有相位切换没有真实脚步轨迹。[1][2][3] 对照文献与开源实现后，当前仓库最该修的不是再加一层噪声，而是把两段腿代理改成更接近真实蜘蛛的 distal-biased ratio，并把脚步从“锁点瞬移”改成“抬脚摆动再落下”的可视 swing arc。[1][5]

## Key Findings

- **两段腿代理不能做成近等长**：蜘蛛真实腿并不是“中点折一下”的两根等长杆。一个直接相关的力学论文把腿简化成 `femur 15.5 mm + tibia 15.2 mm + metatarsus 12.0 mm`，若映射成两段代理，更接近 `0.57 : 1.0` 而不是 `0.88 : 1.0`。[1]
- **只靠 phase relation 不够解释蜘蛛步态**：新的分析指出，单纯用 phase relation 看不见力学交换、支撑负载与 body dynamics，因此“8 条腿按时钟切换”很容易看起来像机器人。[2]
- **蜘蛛会随地形/基底改变 coordination**：实验显示蜘蛛在不同 substrate 上会改变 gait pattern 与 kinematics，说明一个只会平地二相切换的 scheduler 很难在视觉上像“活物”。[3]
- **程序化实现通常都做 swing trajectory 和 step trigger**：开源 procedural spider controller 普遍会为每条腿单独设置 step threshold、predicted foothold 和步态曲线，而不是只更新 locked foothold。[5][6]
- **对本仓库最有效的改法是三件套**：`socket fan + distal-biased leg ratio + swing arc`。这三件叠加比单纯调 `phase_offset` 更能改善“像不像蜘蛛”。[1][2][5]

## Detailed Analysis

### 1. 腿段比例到底该怎么看

真实蜘蛛腿有多节，不适合直接硬套成一个中点膝盖。对游戏里的 proxy 来说，更合理的做法是把 body-near 的可视段当作 proximal/femur side，把 distal 侧当作 tibia/metatarsus/tarsus 的合并段。[1][4] 这样做出来的“膝”应该明显偏向身体一侧，而不是 span 的正中间。

对当前仓库原始实现来说，最大的视觉问题正好相反：`CitySpiderCrawler.gd` 之前是以 socket 与 foot 的中点为核心，再外加 lateral offset 来算 knee，所以最终可见上段、下段长度非常接近。这会直接让八条腿看起来像“八个机械折杆”，而不是蜘蛛那种近端较短、远端更长的细长腿。

因此，这轮修正的核心比例口径是：

- 两段代理默认向 `upper : lower ~= 0.5~0.7 : 1.0` 靠拢，不再接受接近 `1 : 1`
- 前腿比内侧中腿更长，避免八条腿全部同模同长
- 腿根 socket 与默认 foothold 分离，形成真正外展的支撑面，而不是脚几乎落在身体正下方

### 2. 为什么“会走”了还是不像活物

论文已经把这个问题讲得很清楚：phase relation 只是 coordination 的表层描述，不能单独解释机械输出、支撑切换与 body motion。[2] 如果工程实现里每条腿只是根据全局相位切换 `stance/lift/swing/plant`，而且脚点本身没有可见的 swing 轨迹，那视觉上就只剩“同步切模式”。

当前仓库在这点上的旧问题有四个：

- `default_foothold` 与 `socket` 原先几乎同源，腿看起来更像垂直撑杆
- 膝关节按中点附近计算，造成两段长度近似等长
- 八条腿前中后差异太小，silhouette 不够像蜘蛛
- foot 主要表现为 locked foothold 更新，缺少真正的 display swing arc

这也是为什么用户看到的是“它在动，但不是个正常蜘蛛”。问题不在“有没有 gait”，而在“运动信号是不是长在蜘蛛的身体结构上”。

### 3. 论文和开源项目给出的工程启发

JEB 的 octopedal locomotion 论文把蜘蛛看成两组 quadrupeds，并用更接近真实节段的模型分析其 joint kinematics；这说明 even in simplified animation，腿的几何分段位置本身就会改变视觉正确性。[1] 另一篇分析进一步指出 phase-only 模型不足，需要把力学与 body dynamics 一起考虑。[2]

开源实现也很一致：PhilS94 的 Unity 程序化蜘蛛并不是“脚点瞬移”，而是做 per-leg step planning、预测 foothold、Bezier/arc 式 swing；`minecraft-spider` 这类项目则把 segment count、segment length、step interval 作为可调显式参数暴露出来。[5][6] 这类工程实践和论文结论是同向的。

对 `godot_citys` 来说，最直接的落地含义就是：

- 共享 arthropod runtime 继续保留
- 但 spider wrapper 不能只当“换个 profile id”，而要拥有 spider-specific 的 visual/morphology preset
- gait realism 必须在 species wrapper 层显式建模：
  - socket layout
  - foothold layout
  - per-leg phase offset
  - knee projection ratio
  - display foot swing arc

### 4. 对本仓库这次落地实现的具体指导

这轮实现已经按上面的诊断做了第一版收口，主要变化在：

- `city_game/world/creatures/arthropods/CitySpiderCrawler.gd`
- `city_game/world/creatures/arthropods/CityArthropodLegRuntime.gd`
- `city_game/world/creatures/arthropods/CitySpiderCrawler.tscn`
- `city_game/scenes/labs/SpiderCrawlerLab.tscn`
- `city_game/scenes/labs/SpiderCrawlerMorphologyLab.tscn`
- `city_game/scenes/labs/SpiderCrawlerGaitLab.tscn`
- `city_game/scenes/labs/SpiderCrawlerHybridLab.tscn`

工程决策如下：

- 用 `variant_id` 把 spider 切成 `morphology_focus / gait_focus / hybrid_focus`
- 把 body 从单一 box 改成 `ProsomaMesh + AbdomenMesh`
- 把 socket 与 foothold 解耦，形成真正外张的 spider stance
- 把 knee 从 midpoint 逻辑改成 body-biased `knee_projection_ratio`
- 给 leg runtime 增加 `previous_foothold + swing_progress`
- 在 visual sync 里生成 `display_foot_world_position`，让 swing 真正可见

这套改法还不是“终局版蜘蛛”，但已经把问题从“像机械折杆”推进到了“可对比的 spider variants”。

## Areas of Consensus

- 蜘蛛 locomotion 不能只看 phase table，还要看几何与力学。[1][2]
- Simplified spider rigs 依然需要腿段比例、socket layout 与 swing trajectory。[1][5]
- 地形和 substrate 会改变 gait 表现，因此 scheduler 不能假定单一平地模板在所有场景里都自然。[3]

## Areas of Debate

- **两段代理到底怎么折算多节真实腿**：不同论文、不同物种会把 patella 是否单独保留说法不一，但都不支持“严格中点折叠”的视觉代理。[1][4]
- **蜘蛛 gait 更像 tetrapod 还是 staggered wave**：速度、物种、地形都会改变 coordination，因此工程上更适合做 variant/preset，而不是硬冻一个节拍表。[2][3]
- **是否要在这一阶段引入完整 IK / force solver**：文献支持更高阶模型，但对当前 `lab-first` 目标，先把 morphology + swing arc 收住更划算。[2][5]

## Sources

[1] Wilson RS. et al. “Biomechanics of octopedal locomotion: kinematic and kinetic analysis of the spider *Grammostola mollicoma*.” *Journal of Experimental Biology* 214(20), 2011. Peer-reviewed biomechanics paper, directly relevant to leg segmentation and gait mechanics. https://journals.biologists.com/jeb/article/214/20/3433/10466/Biomechanics-of-octopedal-locomotion-kinematic-and

[2] “A phase relation-based approach does not explain mechanical features of spider locomotion.” *Peer-reviewed article hosted on PMC*, 2025. High relevance because it explicitly argues against relying on phase relation alone to explain spider locomotion. https://pmc.ncbi.nlm.nih.gov/articles/PMC12211592/

[3] Silva-Pereyra J. et al. “Substrate-specific locomotion in spiders?” *Journal/abstract indexed by PubMed*, 2019. Relevant evidence that substrate changes coordination and gait expression. https://pubmed.ncbi.nlm.nih.gov/31579616/

[4] Liu T. et al. “Origami-inspired, self-sensing, and self-actuating artificial spider legs.” *Peer-reviewed article hosted on PMC*, 2021. Useful for anatomy/joint-function discussion and why spider leg simplification should respect real segment function. https://pmc.ncbi.nlm.nih.gov/articles/PMC7927609/

[5] PhilS94. “Unity-Procedural-IK-Wall-Walking-Spider.” GitHub repository. Practical open-source reference for per-leg procedural stepping, wall-aware foothold prediction, and visible swing trajectories. https://github.com/PhilS94/Unity-Procedural-IK-Wall-Walking-Spider

[6] TheCymaera. “minecraft-spider.” GitHub repository. Useful lightweight reference showing segment count/length and timing exposed as explicit procedural parameters instead of hidden hardcode. https://github.com/TheCymaera/minecraft-spider

## Gaps and Further Research

- 还没有把真实 spider leg 的 7 节代理到 3 节以上可视 rig；当前仍是面向 lab 的 2-link proxy
- 还没有做 force-aware 支撑多边形约束，只是先从 phase-clock 推进到更好的 visual gait
- 还没有做 wall-walking / ceiling inversion；当前冻结仍是地面、坡面、低障碍 crawling
- 如果后续继续做，下一步最值钱的是：
  - per-leg workspace exhaustion trigger
  - body sway / abdomen lag
  - 3-link visible spider leg proxy
  - main-world wrapper 接入前的 focused perf guard

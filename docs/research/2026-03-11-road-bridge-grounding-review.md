# 道路、高架与贴地移动诊断报告

## Executive Summary

当前 `godot_citys` 的道路与高架问题，根因不是单一美术或参数错误，而是底层表示仍停留在“道路中心线 + ribbon 挤带 + 地形点采样”的占位阶段。你截图里那种像被侵蚀过的不规则灰色路面，正是这一表示方式在弯道、接缝和局部坡度上必然出现的结果。

结合本地实现与外部资料，当前版本存在四个结构性缺口：`Player` 缺少贴地与桥面承托机制；道路不是基于车道模板和交叉口求解生成；高架桥只有视觉抬升和桥墩占位，没有桥面厚度与碰撞；项目已将世界尺度设为 `70km x 70km`，但若允许玩家连续巡检到距原点 `35km`，已明显超出 Godot 官方对第三人称单精度场景的常规舒适范围 [1][2][3][4][5][6][7]。

## Key Findings

- **`Player` 目前并不会主动贴附道路或桥面**：`PlayerController.gd` 只有基础 `move_and_slide()`，没有 `floor_snap_length`、`apply_floor_snap()` 或路面/桥面投影逻辑；高速巡检时更容易暴露“固定在某个 y 值附近移动”的观感问题 [1]。
- **当前“路面”并不是标准车道制道路，而是一条按中心线左右偏移出来的多边形带**：在弯折和汇交处没有交叉口求解，因此会自然长出你截图里那种不规则边界 [2][3]。
- **高架桥目前只是视觉占位**：桥仅通过 `_apply_bridge_profile()` 抬高中心线，`BridgeSupports` 也只是盒状桥墩实例；桥面没有厚度、没有可行走碰撞，也没有基于净空约束或跨越目标进行设计 [2][4][5]。
- **v2 文档中的“桥梁占位”与当前实现基本一致，但与用户对“可行走高架桥”的期待并不一致**：这说明当前更像是 v2 占位版已到位，而不是“真实道路/桥梁体验”已完成。
- **`70km x 70km` 连续城市需要额外处理精度问题**：当前世界边界是 `±35000m`；Godot 官方对第三人称单精度 3D 的建议范围明显更小，因此若继续沿用当前全局坐标策略，后续会遇到物理、碰撞和摄像机精度风险 [7]。

## Detailed Analysis

### 1. 本地实现证据

`Player` 贴地能力目前明显不足。[`city_game/scripts/PlayerController.gd`](../../city_game/scripts/PlayerController.gd) 中，移动核心只有 `_physics_process()` 里的 `move_and_slide()`；文件里不存在 `floor_snap` 相关逻辑。更关键的是，测试辅助函数 `advance_toward_world_position()` 直接把 `global_position.y` 强制写到目标值，这在自动化巡检里能“看起来能走”，但不会让真实手动控制自然贴附地面或桥面 [1]。

道路与桥梁承托也没有进入物理层。[`city_game/world/rendering/CityChunkScene.gd`](../../city_game/world/rendering/CityChunkScene.gd) 只为 `GroundBody` 建了一个 `ConcavePolygonShape3D` 地形碰撞；道路 overlay 是后来加到 `NearGroup` 下的视觉节点，没有单独的 `StaticBody3D` 或桥面碰撞体 [2]。

路面几何本身也不是“道路建模”。[`city_game/world/rendering/CityRoadMeshBuilder.gd`](../../city_game/world/rendering/CityRoadMeshBuilder.gd) 的 `_append_ribbon()` 做法，是对每个中心线点采样切线，再左右偏移半个宽度后直接拼接四边形。它没有车道横断面、没有交叉口 miter/bevel/cap 规则、没有路缘/路肩，也没有桥面厚度 [3]。

最后，道路骨架仍然带有较强的“每个 cell 内部随机组织”痕迹。[`city_game/world/rendering/CityRoadLayoutBuilder.gd`](../../city_game/world/rendering/CityRoadLayoutBuilder.gd) 里，本地道路来自 `hub + portals + spoke + arc`；宽度常量只有 `8.0m` 与 `6.5m`；桥梁抬升是按道路类别随机打标，再固定抬 `6.0m` 或 `4.5m`。这套逻辑非常适合“先有一版连续骨架”，但不适合直接承担真实城市道路体验 [4]。

### 2. 你截图里的路面为什么会长成那个样子

这张图里的路面不是“某处 mesh 坏了”，而是当前三步串起来后的必然结果：

1. 先在局部 cell 内随机生成一条 spoke 或 arc 中心线；  
2. 再把中心线每个点的 `y` 直接采样到地形高度；  
3. 最后把这条三维折线用 ribbon 方式挤成路面。

当中心线存在局部急转、弯中弯、边界 portal 接入或地形起伏时，左右偏移边界就会产生视觉上的“收缩、斜削、狗啃边、步道化”。你看到的不是材质或阴影伪影，而是几何定义本身就没有表达真实道路。

### 3. 与论文和工程资料的差距

经典程序化城市研究普遍把道路视为“城市骨架”，而不是独立 chunk 内随机摆放的视觉元素。Parish 与 Muller 明确采用“主干道路网 -> 街区 -> 地块 -> 建筑”的自上而下流程 [5]。Chen 等人的 tensor field 方法，则强调以全局场控制道路方向，使区域风格连续而不是每个格子自己长自己的 [6]。

更贴近工程实现的 StreetGen 与 Galin 等人的工作，核心也不是“挤一条 ribbon”，而是把道路看作有横断面、有交叉口、有街道对象约束的统一系统，并显式处理地形、桥梁、隧道等条件 [3][4]。这正是当前实现缺少的东西。

现实世界的城市道路也不是任意宽度的灰带。NACTO 的城市道路指南指出，城市环境里常见车道宽度约为 `10-11 ft`；更高等级道路通常会采用更宽的设计值 [8]。TxDOT 的设计手册则给出“新建和重建工程垂直净空应提供 `16.0 ft`”这类明确的下限，约等于 `4.88m`，这还只是下限，不是“看起来像高架”的典型高度 [9]。当前代码里 `4.5m` 的 collector bridge，甚至在某些位置因地形起伏和 profile 形状显得更低，难怪会让人感觉“高架只有一人高”。

### 4. v2 文档与当前实现的真实差异

[`docs/plan/v2-index.md`](../plan/v2-index.md) 对 M3 的描述里写的是“桥梁占位”“ribbon 路面”“chunk 地表承托”。按字面看，当前实现并没有完全偏离这份文档，因为代码里确实只有占位性质的桥梁与 ribbon 路面 [10]。

但如果把你的验收标准定义为：

- 道路必须读起来像真实城市路网；
- `Player` 必须自然贴地并能上桥；
- 高架桥必须具备厚度、净空和桥面碰撞；
- 路面需要符合 `8/4/2/1` 车道模板，而不是随机宽灰带；

那么当前实现显然还没有达到这个层级。更直接地说：**v2 的占位版目标大体实现了，但“真实道路与高架体验”并没有实现。**

### 5. 对下一阶段整改的约束

后续整改不能只做参数微调。仅仅把 `LOCAL_ROAD_WIDTH_M` 改大、把桥抬高、或给 `Player` 多加一点重力，都不能解决你截图里的根问题。要真正修正，需要同时重构：

- 道路数据层：从 cell 随机带子，升级为连续道路图与交叉口节点。
- 路面几何层：从 ribbon，升级为按车道模板挤出带厚度的 roadbed/deck。
- 地形与承托层：道路定义路基，地形为道路让形，而不是反过来。
- 角色移动层：让 `Player` 对地面和桥面都有稳定 floor contact。

## Areas of Consensus

- 道路网络应该先作为全局连续骨架生成，再派生街区、地块和建筑 [3][4][5][6]。
- 高架桥不应只是抬高的中心线，还需要桥面、支撑、净空和跨越逻辑 [3][4][9]。
- 在 Godot 中，大世界角色移动若要稳定贴地，必须明确处理 floor snap / ground contact，而不是只依赖裸 `move_and_slide()` [1]。
- `70km x 70km` 这一级别若允许玩家远离原点连续漫游，必须提前处理精度策略 [7]。

## Areas of Debate

- **道路骨架生成方法**：规则网、tensor field、example-based 或混合式都可成立；当前项目更适合“宏观规则 + 局部有机”的混合路线 [5][6]。
- **70km 方案选型**：可以走 origin shifting，也可以走双精度引擎；Godot 官方同时承认两条路线都存在工程取舍 [7]。
- **桥梁层级深度**：v2 可以先做到“可行走、净空合理、交叉成立”的轻量桥体系，不必一步做到完整立交工程细节。

## Sources

[1] Godot Engine Documentation. “CharacterBody3D.” 官方类文档，包含 `floor_snap_length` 与 `apply_floor_snap()` 的地面贴附语义。  
https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html

[2] 本地代码证据：`city_game/world/rendering/CityChunkScene.gd`、`city_game/scripts/PlayerController.gd`。用于确认当前只有地形碰撞、没有道路/桥面碰撞，且玩家缺少 floor snap。

[3] Chicaud, N., et al. “StreetGen: In Base City Scale Procedural Generation of Streets, Street Networks, and Urban Geometry.” 该方向强调道路、交叉口与街道对象的一体化建模。  
https://arxiv.org/abs/1012.0306

[4] Galin, E., Peytavie, A., Guérin, E., Benes, B. “Procedural Generation of Roads.” 论文方向覆盖道路、地形适配以及桥梁/隧道这类约束处理。  
https://hal.inria.fr/inria-00504914/document

[5] Parish, Yoav I. H., and Pascal Müller. “Procedural Modeling of Cities.” SIGGRAPH 2001. 道路网 -> 地块 -> 建筑的经典城市管线。  
https://www.researchgate.net/publication/220720591_Procedural_Modeling_of_Cities

[6] Chen, Guoning, et al. “Interactive Procedural Street Modeling.” SIGGRAPH 2008. 使用 tensor field 控制道路网络的连续风格与方向。  
https://www.sci.utah.edu/~chengu/street_sig08/street_project.htm

[7] Godot Engine Documentation. “Large world coordinates.” 官方文档，给出单精度建议范围以及双精度 large world coordinates 的适用条件。  
https://docs.godotengine.org/en/stable/tutorials/physics/large_world_coordinates.html

[8] NACTO. “Lane Width.” 官方城市街道设计指南页面，说明城市环境常见车道宽度范围。  
https://nacto.org/publication/urban-street-design-guide/street-design-elements/lane-width/

[9] TxDOT. “Roadway Design Manual.” 官方设计手册，给出新建/重建工程的垂直净空下限等设计要求。  
https://www.txdot.gov/manuals/des/rdw/chapter-4-basic-design-criteria/4-7-vertical-alignment.html

[10] 本地文档证据：`docs/plan/v2-index.md`。用于对照当前 v2 里“桥梁占位 / ribbon 路面 / chunk 地表承托”的验收口径。

## Gaps and Further Research

- 这份报告聚焦你当前最在意的“道路为什么怪、高架为什么假、玩家为什么不贴地”，还没有展开车辆 lane graph、交通信号控制和真实立交匝道设计。
- 中国城市道路与高架的本地化规范、桥梁净空和城市快速路横断面，后续若要更贴近西安语境，建议补一轮国内规范调研。
- 如果你后续真的要在 `70km x 70km` 内做高速驾驶巡检，精度策略需要从“风险提示”升级为单独设计项。

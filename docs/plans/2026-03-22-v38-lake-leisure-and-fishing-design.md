# 2026-03-22 V38 Lake Leisure And Fishing Design

## 方案选择

围绕“在 `chunk_147_181` 做一个以后能钓鱼、能下水看鱼的湖”，表面上有三条路。

方案 A 是最偷懒的做法：继续沿 `scene_landmark` 或一个超大自定义 scene，在地表上放一块不规则水面，再在湖边补个钓鱼点。它的好处是实现直观，看起来像是“很快就有湖”。但它本质上违背了 `PRD-0012` 已经冻结的边界，因为 lake 不只是一个离散摆件，而是会改 terrain、改碰撞、改深度语义的区域特征。只要不向下 carve terrain，后面鱼群、下水观察、水草和彩蛋就都会建立在假深度上，迟早返工。

方案 B 是另一种极端：只做 `terrain_region_feature`，把湖盆、水体、鱼群、钓鱼规则、HUD、坐下点、收线逻辑全部塞进同一条 lake runtime。这样看似“所有东西都和湖绑定”，但风险同样大。lake runtime 的职责应该是地形 carve、水位、bathymetry、habitat 和水中观察；如果把坐下、抛竿、bite window、HUD 和 catch resolve 也塞进去，很快就会复制一遍 `scene_minigame_venue` 已经打通过的那套规则/重置/提示链。

推荐方案是 C：**lake 走 `terrain_region_feature`，fishing 走 `scene_minigame_venue`，二者通过 `linked_region_id` 对接，而且开发流程采用 `v37` 那种 lab-first -> main-world port 纪律**。lake region 负责“这片地方是什么”，fishing venue 负责“玩家在这里可以玩什么”。这是唯一既符合 `PRD-0012`、又复用 `v26/v28/v29` 成熟 minigame 主链，同时还能把未来鱼群、水草、彩蛋和 shoreline 扩展留出空间的路线。

## 为什么 lake 必须先 carve terrain，而不是先做水面

这次最关键的技术边界，就是用户补充的那句“湖理论上需要 override 那部分地面，要向下挖下去”。这句话实际上把方案空间直接收窄了。因为只要我们接受“湖不是平地上的贴图”，那 lake 的真源就只能是 **shoreline polygon + bathymetry profile**，而不是某个 scene 里的 mesh 造型。换句话说，湖底高度、岸线位置、平均深度、最深 pocket、玩家何时算入水、鱼群可以在哪个深度带活动，这些都必须来自同一份 region 数据。

因此 `v38` 的 lake region 应该成为第一条真正把 `terrain_region_feature` 跑通的版本。`CityTerrainPageProvider.gd` 继续保留页面式 terrain 生成，只是在命中 lake region 的页面上增加一个 downward carve pass：先按 shoreline polygon 判断是否落在湖盆内部，再根据 bathymetry profile 求出该点应该被压低到什么深度。与此同时，水面不跟地形一起走，它应该由固定 `water_level_y_m` 的独立 provider 生成。这样湖底和水位不会互相污染；后续如果要调浅岸、深坑或彩蛋洞，也只需要改 depth profile，而不用重做水面或 fishing 判定。

## 推荐架构：`terrain_region_feature + fish school runtime + scene_minigame_venue`

完整架构建议拆成三层。第一层是 `terrain_region_feature`。它有自己的 registry、manifest 和 sidecar profile 文件，负责 `region_id = region:v38:fishing_lake:chunk_147_181` 这一片湖区的数据真源。最小 contract 里至少要有水位、常态深度、最大深度、shoreline profile、bathymetry profile、habitat profile 和 `linked_venue_ids`。这层不关心玩家怎么钓鱼，只关心湖在哪里、挖多深、什么地方是浅岸、什么地方是深水。

第二层是 lake runtime。这里再细分成两个消费者。一个是地形/渲染侧：`CityTerrainPageProvider.gd` 负责湖盆 carve，新的 `CityWaterSurfacePageProvider.gd` 负责固定水位的水面 page。另一个是生态/交互侧：`CityLakeRegionRuntime.gd` 和 `CityLakeFishSchoolRuntime.gd` 负责水中状态、fish school summary、depth sampling 和 future underwater anchor 查询。鱼群不要做成一条鱼一个逻辑节点；应该优先冻结成 school/habitat 驱动的批量表现，这样未来“很多鱼在里面游”才不会直接把 runtime 弄炸。

第三层是 fishing venue。它继续沿 `scene_minigame_venue` 走：manifest、near mount、venue scene、专属 runtime、HUD 和 reset。scene-first 原则在这里很重要。座位、鱼竿朝向、出线起点、浮漂可视区域、岸边小平台和 future dock props 都应该交给 `.tscn` author；脚本只管规则、状态机、bite 窗口和 catch resolve。这样未来调坐姿、钓位和镜头时，不需要回到代码里继续硬写 transform。

## 为什么这次必须先 lab，再主世界

这次用户补的流程要求，其实非常合理。lake 不是单一玩法，而是把三件本来就容易互相干扰的东西绑在一起：terrain carve、水位/水中观察、以及 shoreline fishing 规则。如果我们直接在主世界 `chunk_147_181` 上开干，那么 streaming、chunk page、地图 pin、ambient freeze、玩家移动、湖边座位和 fish school 可视都会同时参与调试，任何一个 bug 都会很难判断是在 shared lake layers、在 fishing runtime，还是在主世界 wrapper。`v37` 直升机炮艇已经证明，这类问题最稳的做法是先把 shared runtime 在一个低干扰 carrier 上跑顺，再把同一条 runtime 移植回主世界。

所以 `v38` 应该复制这条纪律，但又不能照抄表面形式。直升机的 lab 主要是为了隔离任务链和战斗链；lake 的 lab 则是为了隔离 **区域地形 + 水体 + 观察 + 玩法** 这四件事的叠加复杂度。推荐流程冻结为四步：先把 layer 1/2，也就是 `terrain_region_feature + carve/water/fish` 做成 shared runtime；然后在 `LakeFishingLab.tscn` 里用同一份 shoreline / bathymetry / habitat 真源挖出“同样的湖”；在 lab 里确认下水观察与 fish schools 成立之后，再把 fishing venue runtime 接进来跑通 minigame；最后，只有在 lab 的 lake 与 fishing 都稳定之后，才允许把同一套 1/2/3 层接回主世界 `chunk_147_181`。这样主世界阶段是真正的 port，不是第二轮重写。

## 湖区、鱼群与钓鱼规则怎么解耦

lake 和 fishing 的关系，最容易做错的地方，就是让一边偷管另一边的事情。`v38` 应该明确把两者的接口冻结下来。

lake region 对外提供的是世界事实：水位是多少、当前位置水深多少、这里属于哪个 habitat zone、最近有哪些 fish schools、某个 cast point 是否落在合法水域里。它应该像导航系统提供 `resolved_target` 一样，提供稳定、可缓存、可测试的 `lake sampling` 和 `fish school summary`。它不应该直接决定“现在有没有咬钩”“玩家这次钓没钓上来”，因为那已经是游戏规则，不是区域事实。

fishing venue runtime 则只消费这些事实。它要做的是：玩家坐下后进入 `idle -> seated -> cast_out -> waiting_bite -> bite_window -> reeling -> catch_resolved -> resetting` 这条闭环；`cast` 是否有效取决于 cast point 有没有落到 lake 的合法水域；bite 候选来自当前有效 habitat zone 的 fish school summary；catch 结果和 HUD 更新属于 venue runtime 自己的规则状态。这样 future 如果要在同一座湖边再加第二个钓位，甚至加一个“只看鱼不钓鱼”的观景 spot，也不需要复制湖数据，只要继续复用同一份 lake region contract 即可。

## `ambient_simulation_freeze` 该挂在谁身上

用户已经明确说，这片地方空旷，进来后行人和车辆都可以完全冻结。这里不能粗暴理解成“那就全局 pause 吧”。`v26` 已经证明，这样做会误伤 radio 和正在运行的场馆规则；lake 这版还会额外误伤水中观察和 fish school runtime。

更稳的做法，是把 freeze 所有权挂在 **lake leisure zone** 上，但仍复用现有 `ambient_simulation_freeze` 语义。也就是说，只要玩家进入 lake 内圈，或者已经激活 shoreline fishing venue，就允许 freeze 保持激活；只有离开外圈并再退出 `32m` release buffer，才真正解冻。freeze 期间只停 `pedestrians + ambient vehicles`，player、radio、lake runtime、water surface 和 fish schools 继续更新。这样用户无论是在岸边坐下钓鱼，还是直接跳进湖里看鱼，都能获得同一套轻世界负载、重湖区内容的体验，而不会出现“坐下才 freeze，下水反而解冻”的奇怪错位。

## 测试与版本切分

`v38` 最适合切成五段。第一段是 family/document freeze：`terrain_region_feature` 从 future note 变成正式 consumer，并把 `scene_minigame_venue` 的 fishing sibling 关系以及 lab-first -> main-world port 纪律写硬。第二段是 shared layer 1/2：把 terrain carve、水位、shoreline/bathymetry、fish school 与 underwater observation 做成可复用 runtime，但先不宣称主世界功能完成。第三段是 lab lake：在独立 `LakeFishingLab.tscn` 里用同一份 profile 真源挖出正式湖区，并完成下水观察和 fish 可视验收。第四段才是 lab fishing：让坐下、抛竿、bite、收线、HUD、reset 和 ambient freeze 在 lab 里跑通。第五段才是 main-world port：把同一套 1/2/3 层接回 `chunk_147_181`，并补齐 map pin、世界接线、回归与 profiling。

测试也要按这个顺序写。第一层是 shared region contract：registry、manifest、shoreline、bathymetry、water surface。第二层是 lab lake contract：lab 场景能加载、player 可入水、fish school 可见。第三层是 lab fishing contract：seat/cast/bite/reset。第四层才是 main-world port contract：同一套 runtime 在主世界 target chunk 也成立，且 map pin / leisure freeze / e2e 链路不分叉。最后，如果改到了 terrain page、chunk renderer、HUD 或 hot-path payload，就必须继续接受 profiling 三件套约束。lake 这种功能最怕的是“看起来很安静，实际上每帧在深拷贝全湖鱼群和区域采样结果”，所以这条红线要从文档阶段就写硬。

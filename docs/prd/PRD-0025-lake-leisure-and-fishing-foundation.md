# PRD-0025 Lake Leisure And Fishing Foundation

## Vision

把 `godot_citys` 从“已经有若干离散场馆和 minigame”的状态，推进到“世界里第一次出现正式的可下水湖区 + 休闲钓鱼玩法”。`v38` 的目标不是在地表上摆一张蓝色平面，也不是在湖边放一把椅子就说能钓鱼，而是在用户给定的 `chunk_147_181` ground probe 周围，正式落成一块 **需要向下 carve 地形的浅湖区域**：湖岸是不规则形状，水位稳定在 probe 给定高程附近，常态深度约 `10m`，最深处约 `15m`；玩家未来可以走到岸边坐下钓鱼，也可以直接跳进湖里，看见湖中的鱼群和后续扩展出来的水草、彩蛋与水下装饰。

`v38` 的成功标准不是“地图上多了一个湖的概念”，而是同时满足七件事。第一，仓库必须正式把 lake 从 `PRD-0012` 预留的 future note 变成第一条真实 `terrain_region_feature` consumer，而不是偷走 `scene_landmark` 或“挂一个超大 scene” 的老路。第二，lake runtime 必须真的 override 那一片 terrain，把地面往下挖成湖盆；不能只有视觉上的水面，没有向下 carve 的地形、碰撞和深度。第三，湖区必须显式暴露水位、不规则 shoreline、bathymetry、可游泳/可观察区域和鱼群 habitat contract，而不是把深度写死在脚本常量里。第四，本轮开发流程必须像 `v37` 直升机炮艇那样，先把 shared `1/2` 层能力做成正式运行时，再在独立 lab 场景里用同一套能力挖出同样的湖并完成低干扰验收，最后才允许把整条链移植回主世界。第五，钓鱼规则不应和湖盆 carve/runtime 混在一起，而应继续沿现有 `scene_minigame_venue` 主链，在 lab 里先挂一套正式 `fishing venue`，把坐下、抛竿、咬钩、收线、重置和 HUD 关进自己的 runtime；lab 验收无误后，再把同一套 runtime 正式接回主世界。第六，进入这片湖区后，系统必须允许像足球场那样把 `pedestrians + ambient vehicles` 冻结掉，但不得演变成 full world pause，更不能把收音机、玩家、湖区和鱼群 runtime 一起停掉。第七，`v38` 不得为了做湖和钓鱼而打坏 `v21` 的 ground probe / world feature discipline、`v26/v28/v29` 的 minigame 聚合链，或现有 streaming/performance guard。

## Background

- `PRD-0012` 与 `v21` 已明确冻结：山和湖不应该走 `scene_landmark`，而应该进入 future sibling family `terrain_region_feature`，共享 `ground_probe` 输入，但不共享离散场景 mount 实现。
- `PRD-0016`、`PRD-0017`、`PRD-0018` 与 `PRD-0019` 已冻结 `scene_minigame_venue`、runtime 聚合、HUD、reset 和 `ambient_simulation_freeze` 这条成熟主链。
- `PRD-0024` 与 `v37` 已验证一条更稳的开发流程：shared runtime 先在低干扰 lab 场景里跑顺，再把同一条 runtime 移植回主世界正式链路；lab 和 main-world 只允许 wrapper/接线不同，不允许行为分叉。
- 用户本轮给定的正式锚点为：
  - `chunk_id = chunk_147_181`
  - `chunk_key = (147, 181)`
  - `world_position = (2844.59, -0.00, 11508.18)`
  - `chunk_local_position = (84.59, -0.00, 44.18)`
  - `surface_normal = (0.00, 1.00, 0.00)`
- 用户已经明确冻结了首版湖区的现实约束：
  - 湖并不深，常态深度约 `10m`
  - 最深处约 `15m`
  - 湖面不需要很大，但希望是不规则形状
  - 玩家未来要能跳下去，在水里看见鱼群游动
  - 湖里未来会继续扩展水草、隐藏彩蛋和其他水下内容
  - 进入湖区后，行人和 ambient 车辆可以完全冻结
  - 用户主要想做的是一套休闲钓鱼机制，并希望继续走 minigame 包装
- 这意味着 `v38` 不能只做“湖边钓鱼点”，也不能只做“有水没玩法”的风景区域；正确路线必须是 **shared lake layers 1/2 + lab-first 验收 + fishing venue runtime + main-world port**。

## Scope

本 PRD 只覆盖 `v38 lake leisure and fishing foundation`。

包含：

- 新增正式 `terrain_region_feature` family 的首个真实 lake consumer
- 在用户给定锚点 author 一座不规则浅湖，并对对应 terrain 做向下 carve override
- 固定 `water_level_y_m`、bathymetry profile、shoreline polygon 与湖区 collision/深度语义
- 支持玩家进入湖区并进入正式 `lake water / underwater observation` 状态
- 新增鱼群 habitat/runtime，使湖中存在正式可见 fish schools
- 新增一个独立 `F6` 可运行的 lake/fishing lab 场景，先复用前两层共享能力挖出同样的湖
- 在 lab 场景中先落成一套正式 `scene_minigame_venue` consumer，用于休闲钓鱼
- lab 验收完成后，再把 lake region + fishing venue 正式接回主世界 `chunk_147_181`
- 进入湖区或激活钓鱼玩法时的 `ambient_simulation_freeze`
- 至少一个 full-map pin 入口，用于把该处作为 fishing 目的地显示
- 补齐 lake region / fish school / fishing venue / freeze / e2e 测试

不包含：

- 不做全城通用河流/海洋系统
- 不做船、皮划艇、潜水装备或水下战斗
- 不做复杂鱼类生态链、捕食关系、季节系统或天气系统
- 不做完整钓鱼装备树、背包、收集图鉴或任务系统
- 不做湖边建筑群、码头群、完整景观园林一整套装饰
- 不做全城 navmesh/道路系统级重构

## Non-Goals

- 不追求把 lake 假装成 `scene_landmark` 或挂一个超大 `PackedScene` 来冒充地形改造
- 不追求只画一层水面而不下挖 terrain
- 不追求把 fish 做成“一条鱼一个节点”的高成本运行时
- 不追求把 fishing 规则塞进 lake carve/runtime 里，形成第二个巨石总控
- 不追求跳过 lab，直接把完整 lake + fishing 首版硬塞进主世界再边跑边修
- 不追求通过 `SceneTree.paused`、`Engine.time_scale = 0` 或 world pause 冒充湖区冻结

## Requirements

### REQ-0025-001 系统必须支持正式的 lake `terrain_region_feature` authored 入口

**动机**：lake 是区域地形特征，不是离散摆件；如果它没有正式 region 入口，后续 terrain carve、水位、鱼群 habitat 和钓鱼区都会没有统一真源。

**范围**：

- 新增正式 `terrain_region_feature` registry / manifest / runtime 主链
- 首个正式 lake region 冻结为：
  - `region_id = region:v38:fishing_lake:chunk_147_181`
  - `feature_kind = terrain_region_feature`
  - `region_kind = lake_basin`
- manifest 最小字段至少包含：
  - `region_id`
  - `display_name`
  - `feature_kind`
  - `region_kind`
  - `anchor_chunk_id`
  - `anchor_chunk_key`
  - `world_position`
  - `surface_normal`
  - `water_level_y_m`
  - `mean_depth_m`
  - `max_depth_m`
  - `shoreline_profile_path`
  - `bathymetry_profile_path`
  - `habitat_profile_path`
  - `linked_venue_ids`
- `linked_venue_ids` 在 `v38` 至少包含 `venue:v38:lakeside_fishing:chunk_147_181`
- lake region 必须复用 `ground_probe` 提供的 chunk/world/local 三套坐标语义

**非目标**：

- 不要求 `v38` 首版同时支持多个 lake region 共用一套编辑器 UI

**验收口径**：

- 自动化测试至少断言：registry / manifest / profile path 三者口径一致。
- 自动化测试至少断言：`chunk_147_181` 附近 session 中能读取到正式 `terrain_region_feature` lake entry。
- 自动化测试至少断言：lake region 使用的是 `terrain_region_feature`，而不是 `scene_landmark` 或 `scene_minigame_venue`。
- 反作弊条款：不得只在脚本里硬编码一组湖参数，却没有正式 registry / manifest。

### REQ-0025-002 lake runtime 必须真的向下 override terrain，形成正式湖盆与水位

**动机**：如果只在地表上盖一张水面，视觉上像湖，但碰撞、深度、湖底和未来的 fish / weeds / easter egg 全是假的。

**范围**：

- `CityTerrainPageProvider` 或等价 terrain 页面生成链，必须支持 region 驱动的 downward carve override
- lake region 必须以 `shoreline polygon + bathymetry profile` 为真源，把命中区域的 terrain 向下挖成湖盆
- `water_level_y_m` 在 `v38` 冻结为锚点高程附近的稳定水位；默认口径为 `0.0`
- 深度约束冻结为：
  - 常态深度目标约 `10m`
  - 最深处约 `15m`
  - 允许存在 `0m-3m` 的浅岸过渡带，便于玩家下水
- 湖岸必须是不规则形状；不得是简单圆形或矩形坑
- 水面与湖盆必须共享同一套深度参考，不允许“视觉水面”和“碰撞深度”各写一套数据
- runtime 必须为未来水草、沉底彩蛋和其他水下物件保留稳定 depth sampling 能力

**非目标**：

- 不要求 `v38` 首版引入复杂流体或波浪模拟

**验收口径**：

- 自动化测试至少断言：lake region 覆盖区域内的 terrain sample 低于 surrounding shore sample，证明存在真实 downward carve。
- 自动化测试至少断言：water surface 高度与 manifest 的 `water_level_y_m` 一致。
- 自动化测试至少断言：bathymetry profile 能稳定采样出浅岸、常态深度和最深 pocket，不是全湖一个固定深度。
- 自动化测试至少断言：shoreline profile 不是规则圆/矩形近似，而是至少三段以上不等曲率/不等边长的 authored 轮廓。
- 反作弊条款：不得只画水面材质、不挖 terrain、仍保留平地碰撞却宣称“湖已完成”。

### REQ-0025-003 玩家必须能进入湖区并在水下观察正式 fish schools

**动机**：用户明确要求未来能跳进湖里，看见鱼在里面游；这要求 fish 不是只给 fishing UI 的隐藏数值，而是世界中的可见 runtime。

**范围**：

- lake region 必须暴露正式 `water volume / underwater observation` 状态
- 玩家进入湖水区域时，系统必须进入正式的 lake water state，而不是只穿过一层无语义材质
- lake region 必须提供正式 fish habitat profile，并驱动鱼群 runtime
- fish school 最小 contract 冻结为：
  - `school_id`
  - `habitat_zone_id`
  - `species_id`
  - `centroid_world_position`
  - `depth_range_m`
  - `visual_count`
  - `active`
- fish schools 必须与 lake depth/habitat 同源，不得再维护第二套“假鱼群坐标”
- fish 的实现默认应走 batched school / multimesh / summary 驱动路线，而不是“一条鱼一个逻辑节点”

**非目标**：

- 不要求 `v38` 首版做鱼类百科、重量系统或复杂 AI 捕食

**验收口径**：

- 自动化测试至少断言：玩家进入湖水区域后会暴露正式水中状态，而不是仍被当作普通陆地。
- 自动化测试至少断言：lake runtime 可以返回非空 fish school summary。
- 自动化测试至少断言：鱼群 depth 处于 lake bathymetry 允许的水体范围，而不是漂在岸上或埋进湖底以下。
- 自动化测试至少断言：玩家在水下观察时，鱼群不会因为进入 underwater state 而整体消失。
- 反作弊条款：不得把 fish 只做成钓鱼随机数表，没有世界可见 runtime。

### REQ-0025-004 必须先交付一个独立的 lake/fishing lab 场景，并复用 shared lake layers 1/2

**动机**：terrain carve、水位、水中观察、鱼群可视和 shoreline 玩法一起在主世界里调试太重；这轮需要像 `v37` 一样先在低干扰环境里把 shared runtime 跑顺，再做主世界 port。

**范围**：

- 新增一个独立 lab 场景，建议路径冻结为：
  - `res://city_game/scenes/labs/LakeFishingLab.tscn`
- lab 场景必须显式 author：
  - 一块可承载同样 shoreline/bathymetry profile 的地面载体
  - player spawn
  - lake leisure trigger zone
  - 至少一处 shoreline fishing seat/cast zone
- lab 场景必须复用 shared `1/2` 层，而不是写一套 lab-only 假湖逻辑：
  - `terrain_region_feature` registry/runtime
  - lake carve / water surface runtime
  - fish school / underwater observation runtime
- lab 湖盆必须使用与主世界正式目标同一份 shoreline / bathymetry / habitat 真源；允许 carrier 和 wrapper 不同，不允许重新发明第二份湖数据
- 在 lab 验收通过之前，不得声称主世界 lake/fishing 已 closeout

**非目标**：

- 不要求 lab 场景复刻主世界全部 chunk streaming 与 full-map 细节

**验收口径**：

- 自动化测试至少断言：`F6` 运行后 lab 场景可加载 player、地面、lake root、water surface 与 fish runtime。
- 自动化测试至少断言：lab 场景里挖出的湖与 shared shoreline / bathymetry profile 保持同源，不是第二套独立 lake 参数。
- 自动化测试至少断言：玩家可在 lab 场景进入正式 water/underwater observation 状态，并看见 fish school。
- 反作弊条款：不得把 lab 做成脚本里临时 `Node3D.new()` 拼出来的一次性壳；不得为 lab 单独写一套和主世界不同的 lake 逻辑。

### REQ-0025-005 钓鱼规则必须继续沿 `scene_minigame_venue` 主链包装，并先在 lab 跑通再移植回主世界

**动机**：用户明确希望 fishing 继续走 minigame 包装，这样规则、HUD、重置和 future 扩展更好维护。

**范围**：

- 正式新增 shoreline fishing venue：
  - `venue_id = venue:v38:lakeside_fishing:chunk_147_181`
  - `feature_kind = scene_minigame_venue`
  - `game_kind = lakeside_fishing`
- 开发顺序冻结为：
  - 先在 `LakeFishingLab.tscn` 中接入同一套 fishing venue runtime
  - lab 流程稳定后，再把同一套 runtime/manifest 语义接回主世界 `chunk_147_181`
- venue manifest 至少包含：
  - `venue_id`
  - `display_name`
  - `feature_kind`
  - `game_kind`
  - `anchor_chunk_id`
  - `anchor_chunk_key`
  - `world_position`
  - `scene_root_offset`
  - `scene_path`
  - `manifest_path`
  - `linked_region_id`
  - `full_map_pin`
- venue scene 必须 author 至少一处正式 shoreline `seat / cast origin / bite zone / release bounds`
- fishing runtime 最小闭环冻结为：
  - `idle`
  - `seated`
  - `cast_out`
  - `waiting_bite`
  - `bite_window`
  - `reeling`
  - `catch_resolved`
  - `resetting`
- HUD 至少需要暴露：
  - `visible`
  - `fishing_mode_active`
  - `cast_state`
  - `target_school_id`
  - `bite_window_active`
  - `last_catch_result`
- full-map pin `icon_id` 在 `v38` 冻结为 `fishing`

**非目标**：

- 不要求 `v38` 首版支持多把鱼竿、多种鱼饵或完整装备系统

**验收口径**：

- 自动化测试至少断言：fishing venue 可以从 `scene_minigame_venue` registry / manifest pipeline 正式读取并 near mount。
- 自动化测试至少断言：lab 场景可完成“进点位 -> 坐下 -> 抛竿 -> 等待 bite -> 成功/失败收线 -> reset”。
- 自动化测试至少断言：venue scene 暴露正式可坐下的 shoreline anchor 和 cast contract。
- 自动化测试至少断言：主世界 port 后，同一条 flow 能在 `chunk_147_181` 正式跑通。
- 自动化测试至少断言：fishing venue 的 `linked_region_id` 指向正式 lake region，而不是孤立场馆。
- 自动化测试至少断言：full map 上可解析 `icon_id = fishing` 的 pin。
- 反作弊条款：不得把 fishing 做成离开世界的独立 UI 页面；不得只有菜单随机结果，没有 lake world runtime 参与；不得 lab 一套、主世界再写第二套逻辑冒充“移植完成”。

### REQ-0025-006 进入湖区后必须支持 `ambient_simulation_freeze`，但不得误伤 lake/fishing runtime

**动机**：用户已经明确表示这片区域空旷，进入后可以把行人和 ambient 车辆完全冻结，以换取更稳的湖区和 fishing 体验。

**范围**：

- `ambient_simulation_freeze` 继续只冻结：
  - `pedestrians`
  - `ambient vehicles`
- 必须保留：
  - `player`
  - `lake region runtime`
  - `water surface runtime`
  - `fish school runtime`
  - `fishing venue runtime`
  - `HUD`
  - `radio`
- freeze 触发语义冻结为：
  - 进入 lake leisure 内圈或激活 fishing venue 时即可保持激活
  - 只有离开 lake leisure 外圈后再退出额外 `32.0m` release buffer 才允许解冻
- lake leisure freeze 不得复用 `world_simulation_pause`

**非目标**：

- 不要求 `v38` 首版支持多个不同 lake / minigame 同时争夺 freeze owner 的复杂优先级系统

**验收口径**：

- 自动化测试至少断言：进入 lake leisure 区域后，`is_ambient_simulation_frozen()` 为 `true`。
- 自动化测试至少断言：freeze 期间 fish school 与 fishing runtime 仍继续运行。
- 自动化测试至少断言：离开内圈但仍处于 `32.0m` release buffer 内时，不会立刻解冻。
- 自动化测试至少断言：radio 在 lake leisure freeze 期间仍可继续播放。
- 反作弊条款：不得用 `SceneTree.paused`、`Engine.time_scale = 0` 或 `_apply_world_simulation_pause(true)` 冒充 lake freeze。

### REQ-0025-007 `v38` 不得破坏现有 world feature / minigame / performance 主链

**动机**：lake 是新的区域特征和新的 leisure 玩法，不是破坏既有 contract 的通行证。

**范围**：

- `ground_probe`、`scene_landmark`、`scene_minigame_venue` 既有主链继续成立
- `CityPrototype` 必须在不打坏 soccer / tennis / missile command 的前提下聚合 fishing runtime
- 若改动触及 terrain page、chunk render、HUD、runtime tick，则 profiling 三件套继续作为正式 guard
- lake/fish runtime 不得在每帧扫描全城或 deep-copy 全量 fish payload

**非目标**：

- 不要求 `v38` 顺手重构所有 world feature family 的抽象层

**验收口径**：

- 受影响的 `ground_probe`、soccer、tennis、missile command 关键 tests 必须继续通过。
- 若触及 rendering / streaming / HUD / hot-path payload，必须 fresh rerun profiling 三件套。
- 反作弊条款：不得通过关闭旧 minigame、关掉 ground probe 或简化 lake runtime 来换 `v38` 表面通过。

## Success Metrics

- 独立 lab 场景里能先跑出一座真正由 terrain carve 出来的浅湖，而不是平地上的假水面。
- lab 场景里玩家能进入湖中并观察正式 fish schools。
- lab 场景里 fishing minigame 能跑通最小休闲钓鱼闭环。
- 主世界 `chunk_147_181` 最终能复用同一套 runtime 正式落湖与钓鱼，不发生 lab/main-world 行为分叉。
- 进入湖区后 ambient freeze 可以稳定工作，但 radio 和 lake/fishing runtime 不受误伤。

## Open Follow-Ups

- `v39+` 可扩展多个 shoreline fishing spots、简易栈桥、码头或小木屋。
- `v39+` 可扩展水草、沉箱、宝箱、隐藏彩蛋和更多水下装饰。
- `v39+` 可扩展 fish species / rarity / bait / weather / time-of-day 等更完整的 fishing progression。
- `v39+` 可考虑把 lake region 的地图表达从 point pin 升级成 area highlight / shoreline UI，但这不属于 `v38` foundation。

# PRD-0013 Music Road Landmark And Song Trigger

## Vision

把“钢琴道路”正式做成 `godot_citys` 世界里的一个可发现、可驾驶、可重复体验的 authored landmark。玩家在 full map 上能看到一个明确的音乐符号起点，开车抵达后，会看见一段带钢琴键视觉提示的特殊高速公路；当玩家沿着起点到终点的正式方向，以目标车速匀速驶过这段道路时，路面上预先配置好的触发条会依次触发音符，最终完整演奏出当前唯一支持的曲目《诀别书》。

`v23` 的成功标准不是“地图上多了一个图标”，也不是“场景里放了一段奇怪公路”，而是同时满足六件事。第一，这条音乐公路必须沿 `v21` 已冻结的 `scene_landmark` 主链接入世界，而不是偷偷改写 `road_graph` 或伪装成 building override。第二，音乐公路必须有正式的 authored data contract，当前只支持 `song_id = jue_bie_shu`，但从第一版起就要按未来多曲库扩展来设计。第三，玩家在驾驶视角下必须能清楚读出这是一条“钢琴道路”，而且键位的 shader 预点亮、命中发光与衰减熄灭已经属于 `v23` 正式范围。第四，真正的曲目触发必须由车辆真实穿越条带产生，所以倒着开时要能逆序出音，减速时也要真的把音符间隔拉开，而不是按一个脱离空间位置的计时器假唱。第五，这个玩法不得破坏现有 landmark、地图、驾驶和性能护栏主链。第六，`v23` 必须提供一个中间试听产物，让不识谱的用户也能靠听觉检查“塞进高速路里的《诀别书》音符序列”是否正确。[已由 ECN-0022 变更]

## Background

- `PRD-0012` 与 `v21` 已冻结 `scene_landmark registry -> manifest -> near chunk mount -> optional full_map_pin` 主链，证明“独立于 building_id 的 authored 世界内容”可以正式接入大世界。
- `PRD-0004` 与 `v9` 已冻结玩家 hijack 与 driving 主链，当前玩家驾驶状态可稳定暴露 `driving / world_position / heading / speed_mps`。
- `PRD-0011` 与 `v18` 已冻结基于 manifest 的 full-map pin contract，证明“地图图标通过 `icon_id` 解析 glyph”的路线已经存在。
- 当前仓库并没有“音乐道路”或“道路触发旋律”主链，也没有能直接把一段曲子与一串道路触发条绑定的 formal data contract。
- 用户明确要求：
  - 当前版本只支持一首曲子：《诀别书》
  - 优先方案是做一条独立 authored 公路，再把它挂进游戏世界
  - 地图上显示一个音乐符号作为起点 marker
  - 路面有类似钢琴键的视觉提示，但这些键只是示意，真正触发哪一个音符由配置决定
  - 倒着开要能听到逆序效果，故意减速要能听到旋律真的变慢
  - 键位 shader 预点亮在 `v23` 内直接交付，而不是未来再补
  - 谱源搜索和试听检查由实现侧负责，不能把“找谱子”甩给用户
  - `refs/godot-road-generator` 里的 highway 资产如果经视觉级验证可用，就必须复制进项目自有 `assets` 目录并安置好，不能直接拿 `refs/` 路径交付
- `refs/godot-road-generator` 证明“独立道路场景 + 自定义 road material / road mesh”这类 authoring 路线是可行的，但该参考仓库没有现成的“钢琴道路”资产或曲目系统，因此只能借鉴组织方式与材质/道路 authoring 思路，不能当成现成功能直接接入。

## Scope

本 PRD 只覆盖 `v23 music road landmark + song trigger`。

包含：

- 新增一个独立 authored 的 `scene_landmark` consumer：音乐公路
- 音乐公路在 full map 上显示正式起点 pin
- 音乐公路 scene 包含可读的钢琴键视觉提示
- 音乐公路 scene 包含可驱动 shader 的键位视觉相位
- 新增正式 `music_road_definition` contract，当前只承载 `song_id = jue_bie_shu`
- 玩家驾驶车辆通过时，按真实 traversal 顺序与时间间隔触发音符
- 新增中间检查步骤：把最终采用的《诀别书》音符序列渲染成试听产物供人工验耳
- 若复用 `refs/godot-road-generator` 的 highway mesh / material 候选，通过视觉级验证后必须复制到 `city_game/assets/environment/source/music_road/road_generator_frozen/`
- 补齐 world / e2e / performance 级验证计划

不包含：

- 不在 `v23` 内把世界既有 procedural 道路直接升级为可播放曲目的通用系统
- 不在 `v23` 内支持多首曲子切换或曲库 UI
- 不在 `v23` 内支持玩家步行触发旋律
- 不在 `v23` 内把音乐公路接入 place search、route query、fast travel 或 autodrive
- 不在 `v23` 内实现节奏游戏评分、连击、排行榜或任务结算

## Non-Goals

- 不追求把音乐公路挂进 `road_graph / vehicle lane graph`，也不追求让 AI 车辆自动演奏
- 不追求做真正可下压、可弹起、逐键碰撞反馈的机械钢琴键
- 不追求把整首《诀别书》做成“一开局自动整段播放”的单条音频，而是必须保留“空间位置 -> 音符触发”的交互语义
- 不追求把 `refs/godot-road-generator` 直接 vendoring 到正式产品源码
- 不追求本版就支持任意已有道路一键覆盖成音乐道路
- 不追求把用户变成找谱和校谱的人

## Requirements

### REQ-0013-001 音乐公路必须作为正式 scene_landmark consumer 接入世界，并在 full map 上暴露起点 pin

**动机**：这条路首先是一个“世界中的地点”，玩家需要先找到它，才能开上去体验音乐触发。

**范围**：

- 新增正式 `scene_landmark` consumer：音乐公路
- consumer 必须沿 `v21` 已冻结的 `registry -> manifest -> scene` 主链接入
- 音乐公路 manifest 必须 opt-in 一个 full-map pin
- `full_map_pin.icon_id` 在 `v23` 冻结为 `music_road`
- `music_road` 的 UI glyph 在 `v23` 冻结为 `🎵`
- 该 pin 默认只进入 `full_map` scope，不进入 minimap
- 音乐公路必须有正式起点语义，marker 表示的是正式 entry side，而不是整段道路的几何中心

**非目标**：

- 不要求 `v23` 支持点击 pin 后自动算路
- 不要求 `v23` 把音乐公路变成 place search 的正式 consumer

**验收口径**：

- 自动化测试至少断言：音乐公路 registry entry、manifest path 与 scene path 三者口径一致。
- 自动化测试至少断言：目标 chunk near mount 时，音乐公路 scene 会被正式实例化并带有稳定 `landmark_id` 元数据。
- 自动化测试至少断言：打开 full map 后，render state 中能看到 `icon_id = music_road` 且 `icon_glyph = 🎵` 的 marker。
- 自动化测试至少断言：同一 session 下 minimap overlay 不会出现 `music_road` pin。
- 自动化测试至少断言：地图 marker 的世界位置来自 manifest 中冻结的起点世界坐标，而不是从 scene 包围盒或随机 visual node 推导。
- 反作弊条款：不得把音乐公路伪装成 building override；不得绕过 manifest 在 UI 层直接写死一个“音乐图标”；不得通过把 pin 泄漏到 minimap 来冒充“地图上可见”。

### REQ-0013-002 系统必须冻结正式的 music_road_definition authored contract，当前只支持 `song_id = jue_bie_shu`

**动机**：用户已经明确说未来可能扩成曲库，因此第一版就不能把《诀别书》的所有条带和音符硬编码到脚本里。

**范围**：

- 新增正式 `music_road_definition` 数据文件，作为音乐公路的 authored sidecar
- definition 最小字段冻结为：
  - `experience_kind`
  - `song_id`
  - `display_name`
  - `target_speed_mps`
  - `speed_tolerance_mps`
  - `entry_direction`
  - `entry_gate`
  - `approach_glow_distance_m`
  - `hit_flash_duration_sec`
  - `release_decay_duration_sec`
  - `note_strips`
- `experience_kind` 在 `v23` 冻结为 `music_road`
- `song_id` 在 `v23` 冻结为 `jue_bie_shu`
- `note_strips` 中每条 strip 最小字段冻结为：
  - `strip_id`
  - `order_index`
  - `local_center`
  - `trigger_width_m`
  - `trigger_length_m`
  - `note_id`
  - `sample_id`
  - `visual_key_kind`
- 所有 strip 的位置语义都必须以“landmark-local space”表达；世界落点由 manifest 负责
- `order_index` 必须严格单调递增，构成正式演奏顺序

**非目标**：

- 不要求 `v23` 提供可视化编辑器
- 不要求 `v23` 首版支持多 song pack 热切换

**验收口径**：

- 自动化测试至少断言：音乐公路 definition 能被解析成正式 structured payload，而不是运行时临时拼 `Dictionary`。
- 自动化测试至少断言：`song_id = jue_bie_shu`、`experience_kind = music_road`、`target_speed_mps`、`speed_tolerance_mps` 非空且数值有效。
- 自动化测试至少断言：`note_strips` 非空，`order_index` 连续且无重复，`strip_id` 全部唯一。
- 自动化测试至少断言：每条 strip 都具备完整的 local-space trigger 几何与 `note_id / sample_id`。
- 自动化测试至少断言：definition 显式暴露 `approach_glow_distance_m`、`hit_flash_duration_sec` 与 `release_decay_duration_sec`，供 shader 视觉相位消费，而不是把这些值硬编码在 scene script。
- 自动化测试至少断言：manifest 与 definition 的引用关系稳定，不依赖 scene script 内写死歌曲常量。
- 反作弊条款：不得把《诀别书》条带顺序、音符或目标速度硬编码在 GDScript 常量里而绕过 definition 文件；不得只存“音符数量”而不存每条 strip 的正式 authored 位置。

### REQ-0013-003 音乐公路的视觉必须在驾驶视角下清楚传达“钢琴道路”语义，并直接交付 shader 预点亮链路，但不要求物理琴键

**动机**：用户要的首先是“开上去就知道这是音乐公路”，不是在 HUD 文案里猜。

**范围**：

- 音乐公路采用独立 authored straight corridor 方案，不直接篡改 procedural road mesh
- 路面必须具有清晰的钢琴键视觉 cue
- `visual_key_kind` 在 `v23` 至少支持 `white` 与 `black`
- 这些键可以是贴图、decal、覆盖 mesh 或组合材质，但语义只是视觉提示
- 每条 key strip 必须有正式视觉相位：`idle / approach / active / decay`
- `approach` 相位必须支持“车尚未压到键，但键已经开始发光”
- `active` 相位必须支持“命中后亮度抬升”
- `decay` 相位必须支持“命中后逐步熄灭”
- 路面仍必须保持可驾驶，不要求每个 key 都做独立物理碰撞件
- 允许 scene 中加入 entry cue，例如起点牌、起点门或起始音乐符号，但不是硬性 requirement

**非目标**：

- 不要求真实机械式按键反馈
- 不要求首版就支持多车道并行演奏

**验收口径**：

- 自动化测试至少断言：音乐公路 scene mounted 后存在正式的钢琴键视觉节点族，且同时包含 `white` 与 `black` 两类 cue。
- 自动化测试至少断言：音乐公路可读视觉包围盒满足正式“直线高速路段”尺度，不允许只有几块贴图碎片拼成一个近似不可识别的小装饰。
- 自动化测试至少断言：visual bottom 与 authored 地面高度基本对齐，不允许 scene 正确挂载但关键视觉 cue 埋到地下。
- 自动化测试至少断言：玩家驾驶相机的常用观察距离下，琴键 cue 不会因为过小、过窄或全被路面色彩吞掉而失去可辨识性。
- 自动化测试至少断言：同一条 strip 在 `approach -> active -> decay` 过程中会输出正式视觉相位与可归一化的强度值，shader 可直接消费，不需要第二套隐藏逻辑。
- 反作弊条款：不得仅在地图 icon 或 HUD 文案上写“音乐公路”却不给任何路面视觉 cue；不得把键位效果实现成只在 editor 可见、运行时不可见的 debug helper；不得把“预点亮”偷换成命中后才亮。

### REQ-0013-004 音乐公路的音符触发必须是 traversal-driven 的真实机制；正向目标速度窗口决定 canonical success，但逆向和变速也必须产生真实可听结果

**动机**：这件事的产品核心不是“路上有声音”，而是“车速和空间位置共同决定曲子能否被完整演奏出来”。

**范围**：

- 正式 runtime 只在玩家处于 `driving = true` 时成立
- runtime 必须基于车辆连续位置计算对 strip 的 crossing，不能只靠固定时间轴
- run 必须从 definition 冻结的 `entry_gate` 以 `entry_direction` 正向进入后才有 canonical success 资格
- 正向 armed run 期间，玩家车辆穿过 strip 时，runtime 按 `order_index` 依次触发 `note_id / sample_id`
- 若玩家从反方向穿过道路，runtime 必须按实际 crossing 顺序逆序触发音符，形成 reverse audition
- 每条 strip 在同一 run 中最多触发一次
- 音符事件之间的时间间隔必须来自车辆真实 crossing 时间；减速会拉长音符间隔，加速会缩短音符间隔
- 当且仅当整段正向 canonical run 在 `target_speed_mps ± speed_tolerance_mps` 的正式窗口内完成时，runtime 才标记本次为 `song_success = true`
- 超出速度窗口时，允许继续听到原始音符触发，但不得宣称“完整演奏成功”
- 玩家离开道路、停车过久、逆向进入或退出后重新进入时，run 必须 reset

**非目标**：

- 不要求 `v23` 提供节拍条、评分 UI 或 combo 系统
- 不要求逆向通过也能被计为 canonical success

**验收口径**：

- 自动化测试至少断言：synthetic driving run 以目标速度窗口通过时，strip 触发顺序与 `note_strips.order_index` 完全一致，且最终 `song_success = true`。
- 自动化测试至少断言：synthetic reverse driving run 会按相反 crossing 顺序触发同一批 note，形成可复核的 reverse sequence。
- 自动化测试至少断言：慢速与快速 run 产出的 note event 时间间隔不同，且与 crossing 时间差一致；不得被量化回固定节拍。
- 自动化测试至少断言：过慢或过快通过时，`song_success = false`，不能把一条仅按时间播放的固定音频片段冒充“成功演奏”。
- 自动化测试至少断言：玩家未处于 driving 状态时，穿过道路不应触发正式 run。
- 自动化测试至少断言：逆向进入不会错误 arm 成一个正式成功 run。
- 自动化测试至少断言：同一条 strip 在同一 run 中不会因为帧抖动、车辆晃动或重复采样而 double-fire。
- 反作弊条款：不得在 run 开始时直接播放整段预录音频来假装位置驱动；不得完全忽略车辆世界位置、只按 elapsed time 输出曲子；不得把成功条件降格为“任意把所有 strip 碰一遍”；不得把逆向和慢速行为统一量化成同一套固定 note timing。

### REQ-0013-005 v23 不得破坏现有 landmark / driving / map / performance 主链

**动机**：音乐公路是一个新 landmark consumer，不是重写大世界道路、地图和驾驶底盘的借口。

**范围**：

- 不得修改 `road_graph / vehicle lane graph / place_index` 的正式语义来迁就音乐公路
- 音乐公路 runtime 只允许在 landmark 已 mounted 时工作
- 不得在 `_process()` 中全城扫描所有 music road definition
- full-map pin 继续沿现有 `icon_id -> glyph` UI contract 走，不得新开第二套地图图标链
- 高速路视觉资产优先复用 `refs/godot-road-generator` 中可稳定抽取的 straight-highway mesh / material 体系；但 `refs/` 里的 highway 资产只允许作为候选输入，任何经视觉级验证后被正式采用的资源都必须复制到 `city_game/assets/environment/source/music_road/road_generator_frozen/`
- profiling 三件套继续作为 guard

**非目标**：

- 不要求 `v23` 解决既有 first-visit profiling 历史 debt
- 不要求 `v23` 接入 autopdrive 跑曲流程

**验收口径**：

- 受影响的 scene landmark / full-map pin / driving tests 必须继续通过。
- 新增音乐公路 manifest / definition / runtime / e2e tests 必须通过。
- 串行运行 `test_city_chunk_setup_profile_breakdown.gd`、`test_city_runtime_performance_profile.gd`、`test_city_first_visit_performance_profile.gd` 仍需给出 fresh 结果。
- 自动化测试至少断言：音乐公路 pin 不会污染 minimap，landmark loader 不会退化成 per-frame registry scan。
- 自动化测试至少断言：若正式音乐公路 scene 采用了 `refs/godot-road-generator` lineage 的 highway 资产，则这些被采用的文件都位于 `city_game/assets/environment/source/music_road/road_generator_frozen/`，且 scene / material 引用全部指向项目自有复制件。
- 自动化测试至少断言：最终产品运行时不依赖 `res://refs/...` 路径直接加载 highway 资产。
- 反作弊条款：不得为了 profiling 过线而临时关闭音乐公路 loader、禁用音符触发或跳过 full-map pin；不得把音乐公路偷塞进 `road_graph` 现有测试夹具里并宣称“没有新增成本”；不得把正式游戏运行时直接绑到 `refs/` 参考目录；不得视觉上用了 `refs` 候选资产却不复制进项目自有 `assets` 目录。

### REQ-0013-006 v23 必须提供一个中间试听产物，让用户可以靠听觉检查《诀别书》音符序列是否正确

**动机**：用户明确表示自己不识谱，只能靠听觉检查。如果没有中间试听产物，就无法高效确认“最终编码进高速路里的音符序列”是不是对的。

**范围**：

- `v23` 当前正式谱源冻结为用户提供并归档的本地 MIDI：`reports/v23/music_road/source_private/jue_bie_shu_aigei_source.mid`。[已由 ECN-0023 变更]
- 必须新增一个本地 Python 工具，把最终采用的 normalized note sequence 渲染为 `wav`；如环境允许，可额外导出 `mp3`
- 中间试听产物建议落地到 `reports/v23/music_road/`
- 中间试听产物不是玩家功能，不要求进入游戏 UI

**非目标**：

- 不要求 `v23` 内做 DAW 级别高保真混音
- 不要求用户自己去找谱、抄谱或肉眼核对音高

**验收口径**：

- 自动化检查至少断言：仓库内存在正式的谱源冻结说明，记录当前采用的是哪一份本地 MIDI、归档路径是什么，以及为什么不再需要裁切。[已由 ECN-0023 变更]
- 自动化检查至少断言：本地 Python 工具能从 normalized note sequence 确定性输出 `jue_bie_shu_preview.wav`。
- 自动化检查至少断言：同一输入重复渲染时，试听产物的事件数、总时长与导出元数据稳定一致。
- 自动化检查至少断言：drive runtime 所消费的 note sequence 与试听工具所消费的 normalized note sequence 是同一份正式数据，而不是两套各自维护的副本。
- 反作弊条款：不得跳过试听产物；不得只给用户一张曲谱截图就宣称“可验收”；不得让 runtime 用一份数据、试听工具又偷偷用另一份人工修饰版本。

## Open Questions

- 最终挂载 chunk 和精确 `world_position.y` 需要在实现前通过 fresh `ground_probe` 锁定；当前 PRD 只冻结路线，不提前伪造高程。
- 音符输出最终采用简易 synth、单音 sample bank 还是别的 audio 资源组织方式，当前不作为 PRD 硬约束；但 `note_id / sample_id` authored contract 必须先存在。
- `music_road` 是否未来进入 place search。当前答案：不是 `v23` 范围。
- 《诀别书》当前正式采用哪一份 normalized source。当前答案：冻结为用户提供并归档的 `reports/v23/music_road/source_private/jue_bie_shu_aigei_source.mid`，不做 `110` 秒裁切。[已由 ECN-0023 变更]

## Future Direction

- 后续可在不破坏 `v23` contract 的前提下扩展为 song library：多个 `song_id`、多条音乐公路、甚至同一条公路切换曲目。
- 未来若要做“把既有 procedural 高速公路局部改造成音乐路段”，应作为 `scene_landmark overlay` 或 sibling family 单独立项，而不是回写本版独立 authored road 的范围。
- 如果未来需要把音乐公路接入任务系统，更合理的方向是让任务 runtime 消费 music road 的状态，而不是把音乐公路 runtime 硬塞进 task trigger 主链。

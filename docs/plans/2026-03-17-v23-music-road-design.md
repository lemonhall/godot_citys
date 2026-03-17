# 2026-03-17 V23 Music Road Design

## 问题收口

当前仓库已经有两条足够强的基础链。第一条是 `v21` 的 `scene_landmark registry -> manifest -> near chunk mount -> optional full_map_pin`，它证明一个独立 authored 世界内容完全可以不依赖 `building_id` 而正式进入大世界。第二条是 `v9` 之后的 driving state 暴露，玩家在驾驶时能稳定给出 `driving / world_position / heading / speed_mps`。把这两条链拼起来，理论上已经足够承载“地图找到一个特殊地点 -> 开车过去 -> 驶过一连串按顺序触发的路面 strip -> 形成旋律”这种玩法。

真正的问题不在“能不能发出声音”，而在“应该把哪一层当成正式资产”。如果把《诀别书》的旋律和条带顺序写进脚本常量，首版也许很快，但第二首歌一来就会返工。如果直接把一条 procedural 生成道路升级成音乐道路，则会立刻碰到 `road_graph / lane graph / route_result / profiling` 这一整套冻结主链，范围失控风险极高。用户已经明确给了一个更稳的方向：先做一条独立 authored 的直线道路 scene，在独立场景里把玩法跑通，再通过 landmark 机制挂进世界。所以 `v23` 最该守住的不是“强行复用现有道路”，而是“不要为了复用而破坏已有世界底盘”。

## 方案比较

有三条候选路线。第一条是“改 existing road_graph，把某一段世界道路变成音乐道路语义”。它的好处是道路天然融入城市，但代价太高：要碰 existing road selection、chunk render、driving readability，甚至未来还可能把导航、autodrive 和 AI 车辆语义一起卷进来。第二条是“在现有道路上额外叠一层 music overlay landmark”。这比改 road_graph 温和，但依旧需要先找一段足够直、足够长、足够可控、且不容易被现有 traffic/pedestrian 干扰的路段；最麻烦的是 overlay 和原路面几何、视觉、碰撞之间容易互相打架。

第三条是“独立 authored straight corridor，作为 `scene_landmark` consumer 挂进世界”。这是我推荐的路线。它的好处有四个。第一，完全不污染世界道路生成主链。第二，视觉可以为钢琴键 cue 单独设计，不受 existing road material 限制。第三，触发逻辑可以把 landmark-local strip positions 当成唯一真源，测试容易写。第四，`refs/godot-road-generator` 正好证明独立道路 scene 与 custom material authoring 是成熟路线，尤其 museum demo 和 custom material 思路都适合拿来借鉴“怎样快速 author 一段独立高速道路”，即便它没有现成钢琴道路资产。

## 推荐架构

推荐架构是“一个 landmark + 一个 definition + 一个 mounted-only runtime”。landmark 这一层解决“它在哪里、如何挂进世界、地图怎么找到它”。因此音乐公路继续走 `scene_landmark`：一个正式 `landmark_manifest.json`，一个独立 `music_road_landmark.tscn`，以及 `landmark_override_registry.json` 里的正式 entry。地图侧继续沿 `full_map_pin.icon_id -> CityMapScreen glyph` 主链，只新增 `music_road -> 🎵`，不新开第二套 UI 图标逻辑。

definition 这一层解决“这条路具体演奏什么、速度窗口是多少、条带在哪里”。因此我建议新增 `music_road_definition.json` sidecar。这个文件不负责世界坐标，只负责 landmark-local authored 数据：`song_id = jue_bie_shu`、`target_speed_mps`、`speed_tolerance_mps`、`entry_gate`、`entry_direction`、`note_strips[]`。每条 strip 记录 `order_index / local_center / trigger geometry / note_id / sample_id / visual_key_kind`。这样未来要加第二首歌，变的是 definition，而不是 landmark mount contract。

runtime 这一层解决“玩家这次到底有没有按正确方式跑完这条路”。这里不要依赖“起点一进就播整段音频”的 timer-only 假实现，也不要把希望寄托于高车速下的纯 `Area3D` 碰撞。更稳的办法是：在 landmark mounted 且玩家处于 `driving = true` 时，runtime 只读取玩家车辆世界位置，把它投影到 landmark-local strip 空间，判断 crossing、速度窗口和 run state。这样既 deterministic，又容易给测试暴露 debug state。

## 视觉与参考资产

`refs/godot-road-generator` 的价值主要在 authoring 参考，而不是现成素材。它的 README 和 museum demo 说明了一件事：独立道路 scene、custom material、可替换 surface material 这条路线很成熟，适合拿来快速做一条“玩法性很强但不属于主世界道路系统”的特殊公路。它还明确支持 custom material 与自定义 mesh，这对音乐公路尤其重要，因为我们只需要一条“可驾驶、可读、可贴 cue”的 straight corridor，不需要把整套插件 runtime 接进正式项目。

但同样要写清楚：这个参考仓库里没有“钢琴道路”现成纹理，没有《诀别书》曲目定义，也没有“车速对齐 -> 旋律成功”的玩法 contract。所以 `v23` 不应该把它当现成功能搬进来，而应该只吸收两个原则。第一，独立道路 scene 是合理的 authoring 单元。第二，路面视觉应该优先通过材质、覆盖 mesh 或 decal 解决，而不是做一排复杂机械结构。结合用户的要求，这意味着路面上的“钢琴键”只是视觉 cue。真正触发哪一个音符、条带顺序怎样、速度窗口是多少，都必须回到 `music_road_definition` 这一层去配置，而不是在视觉层偷偷埋逻辑。

## 验证与边界

`v23` 的测试策略必须围绕三个层面展开。第一层是 static contract：manifest、registry、definition、map glyph。这一层确保“音乐公路作为一个世界地点”存在且可追溯。第二层是 runtime contract：正向进入、目标速度窗口、strip 顺序、不重复触发、异常速度不误判成功。这一层验证“位置与速度共同决定旋律”的核心语义。第三层是 e2e：玩家开地图找到 `🎵` 起点，抵达 landmark 后跑出一次成功演奏流程。没有这层，前两层都对也不代表真实用户体验成立。

边界也要提前冻结。`v23` 不做 place search、不做自动寻路、不做 autodrive 演奏、不做任务化评分、不做多曲库 UI。当前唯一曲目就是《诀别书》。如果后续要扩到 song library，应该新增更多 definition 文件；如果后续要把普通世界道路局部改造成音乐道路，也应该另开 sibling 方案，而不是回写本版“独立 landmark straight corridor”的范围。把这些边界现在写硬，后面实现时就不至于一边想做彩蛋，一边不小心把导航、道路和音频系统全卷进来。

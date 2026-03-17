# 2026-03-17 V23 Music Road Design

## 问题收口

当前仓库已经有两条足够强的基础链。第一条是 `v21` 的 `scene_landmark registry -> manifest -> near chunk mount -> optional full_map_pin`，它证明一个独立 authored 世界内容完全可以不依赖 `building_id` 而正式进入大世界。第二条是 `v9` 之后的 driving state 暴露，玩家在驾驶时能稳定给出 `driving / world_position / heading / speed_mps`。把这两条链拼起来，理论上已经足够承载“地图找到一个特殊地点 -> 开车过去 -> 驶过一连串按顺序触发的路面 strip -> 形成旋律”这种玩法。用户新补的要求把这个玩法的真实性边界又抬高了一层：倒着开要逆序出音，减速要真的变慢，键位 shader 还要在车未压上去之前就开始发光。

真正的问题不在“能不能发出声音”，而在“应该把哪一层当成正式资产”。如果把《诀别书》的旋律和条带顺序写进脚本常量，首版也许很快，但第二首歌一来就会返工。如果直接把一条 procedural 生成道路升级成音乐道路，则会立刻碰到 `road_graph / lane graph / route_result / profiling` 这一整套冻结主链，范围失控风险极高。用户已经明确给了一个更稳的方向：先做一条独立 authored 的直线道路 scene，在独立场景里把玩法跑通，再通过 landmark 机制挂进世界。所以 `v23` 最该守住的不是“强行复用现有道路”，而是“不要为了复用而破坏已有世界底盘”。

## 方案比较

有三条候选路线。第一条是“改 existing road_graph，把某一段世界道路变成音乐道路语义”。它的好处是道路天然融入城市，但代价太高：要碰 existing road selection、chunk render、driving readability，甚至未来还可能把导航、autodrive 和 AI 车辆语义一起卷进来。第二条是“在现有道路上额外叠一层 music overlay landmark”。这比改 road_graph 温和，但依旧需要先找一段足够直、足够长、足够可控、且不容易被现有 traffic/pedestrian 干扰的路段；最麻烦的是 overlay 和原路面几何、视觉、碰撞之间容易互相打架。

第三条是“独立 authored straight corridor，作为 `scene_landmark` consumer 挂进世界”。这是我推荐的路线。它的好处有四个。第一，完全不污染世界道路生成主链。第二，视觉可以为钢琴键 cue 单独设计，不受 existing road material 限制。第三，触发逻辑可以把 landmark-local strip positions 当成唯一真源，测试容易写。第四，`refs/godot-road-generator` 正好证明独立道路 scene 与 custom material authoring 是成熟路线，尤其 museum demo 和 custom material 思路都适合拿来借鉴“怎样快速 author 一段独立高速道路”，即便它没有现成钢琴道路资产。

## 推荐架构

推荐架构是“一个 landmark + 一个 definition + 一个 mounted-only runtime + 一个试听 QA tool”。landmark 这一层解决“它在哪里、如何挂进世界、地图怎么找到它”。因此音乐公路继续走 `scene_landmark`：一个正式 `landmark_manifest.json`，一个独立 `music_road_landmark.tscn`，以及 `landmark_override_registry.json` 里的正式 entry。地图侧继续沿 `full_map_pin.icon_id -> CityMapScreen glyph` 主链，只新增 `music_road -> 🎵`，不新开第二套 UI 图标逻辑。

definition 这一层解决“这条路具体演奏什么、速度窗口是多少、条带在哪里、键位亮灯参数是什么”。因此我建议新增 `music_road_definition.json` sidecar。这个文件不负责世界坐标，只负责 landmark-local authored 数据：`song_id = jue_bie_shu`、`target_speed_mps`、`speed_tolerance_mps`、`entry_gate`、`entry_direction`、`approach_glow_distance_m`、`hit_flash_duration_sec`、`release_decay_duration_sec`、`note_strips[]`。每条 strip 记录 `order_index / local_center / trigger geometry / note_id / sample_id / visual_key_kind`。这样未来要加第二首歌，变的是 definition，而不是 landmark mount contract；以后想把灯效做得更奇幻，也不用重写 runtime 判定层。

runtime 这一层解决“玩家这次到底有没有按正确方式跑完这条路，以及每个键现在该不该亮”。这里不要依赖“起点一进就播整段音频”的 timer-only 假实现，也不要把希望寄托于高车速下的纯 `Area3D` 碰撞。更稳的办法是：在 landmark mounted 且玩家处于 `driving = true` 时，runtime 只读取玩家车辆世界位置，把它投影到 landmark-local strip 空间，判断 crossing、速度窗口和 run state。这个 runtime 必须以“signed progress crossing”为核心，所以：

- 正向 crossing 触发 canonical 顺序音符
- 逆向 crossing 触发 reverse audition
- 音符时间差直接取 crossing 的真实时间差，减速自然变慢
- 同一套 strip state 再输出 `idle / approach / active / decay` 给 shader 消费

这样音频和视觉不会各跑一套逻辑，也更适合测试。

## 视觉与参考资产

`refs/godot-road-generator` 的价值现在不只是 authoring 参考，还包括可复用的高速路视觉资产候选。这个参考仓库的 `custom_containers` 下确实有 `.glb` 与配套 `.tscn`，例如 `highway_onramp.glb/.tscn`、`highway_offramp.glb/.tscn`，以及统一的 `road_texture.material`；museum demo 也证明这套材质/几何风格在直线高速路段上是成立的。对 `v23` 来说，这意味着可以优先沿“复用其 mesh / material 体系”的路线收敛音乐公路底座，而不是从零重新捏一条低价值的高速路壳子。

但同样要写清楚：这个参考仓库里没有“钢琴道路”现成纹理，没有《诀别书》曲目定义，也没有“车速对齐 -> 旋律成功”的玩法 contract。所以 `v23` 不应该把它当现成功能搬进来，而应该只吸收两个原则。第一，独立道路 scene 是合理的 authoring 单元。第二，路面视觉应该优先通过材质、覆盖 mesh、shader 或 decal 解决，而不是做一排复杂机械结构。结合用户的要求，这意味着路面上的“钢琴键”只是视觉 cue，但这个 cue 在 `v23` 内就要具备 approach glow / hit flash / decay fade 三段视觉相位。真正触发哪一个音符、条带顺序怎样、速度窗口是多少，都必须回到 `music_road_definition` 这一层去配置，而不是在视觉层偷偷埋逻辑。

资产落地策略也要说得更具体。“尽量能用则用”的真正含义不是“运行时先引用 `refs/`，以后再整理”，而是“把 `refs/` 当候选池做视觉级筛选”。一旦某个 highway mesh / material 被证明视觉上可用，并决定进入正式音乐公路方案，它就必须被复制并整理到 `city_game/assets/environment/source/music_road/road_generator_frozen/`。之后正式 landmark scene、材质引用和 import 链都只允许指向这份项目自有复制件，而不再回指 `res://refs/...`。如果筛出来的候选在视觉上不够好，那就放弃复用，回到 first-party fallback；不能因为“先跑得通”就把参考目录路径带进正式交付。

还有一个必须单独拉出来说的点：谱源不能再交给用户。用户已经明确说自己不识谱，只能听。因此 `v23` 需要一个独立的 authoring QA tool。它不进入游戏，但它要消费和 runtime 完全相同的 normalized note sequence，并渲染出一个 `wav` 试听产物。谱源策略应采用三角校验：用官方发布信息确认曲目身份和时长锚点，用可机读 MIDI 候选拿到可编辑 note data，再用人类可读简谱/五线谱预览做肉眼交叉。这样最后用户听到的 `wav`，才能真正成为“我塞进高速路里的就是这个版本”的验收锚点，而不是另起一套人工示意音频。

## 验证与边界

`v23` 的测试策略必须围绕四个层面展开。第一层是 static contract：manifest、registry、definition、map glyph。这一层确保“音乐公路作为一个世界地点”存在且可追溯。第二层是 authoring QA gate：谱源选择说明与 `wav` 试听产物。这一层确保“塞进高速路里的音符序列本身是可验耳的”。第三层是 runtime contract：正向进入、目标速度窗口、reverse traversal、真实 note timing、不重复触发、视觉相位输出。这一层验证“位置、方向和速度共同决定旋律”的核心语义。第四层才是 e2e：玩家开地图找到 `🎵` 起点，抵达 landmark 后跑出一次成功演奏流程。没有第二层和第三层，单靠 e2e 只会得到“好像能响”，但没法证明它响得对。

边界也要提前冻结。`v23` 不做 place search、不做自动寻路、不做 autodrive 演奏、不做任务化评分、不做多曲库 UI。当前唯一曲目就是《诀别书》。如果后续要扩到 song library，应该新增更多 definition 文件；如果后续要把普通世界道路局部改造成音乐道路，也应该另开 sibling 方案，而不是回写本版“独立 landmark straight corridor”的范围。把这些边界现在写硬，后面实现时就不至于一边想做彩蛋，一边不小心把导航、道路和音频系统全卷进来；也不至于一边想着赶进度，一边把“找谱、校谱、试听验收”又推回给用户。

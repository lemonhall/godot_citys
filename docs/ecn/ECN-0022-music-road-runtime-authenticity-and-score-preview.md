# ECN-0022 V23 Music Road Runtime Authenticity And Score Preview

## Why

`v23` 初稿把音乐公路定义成“正向 driving + 目标速度窗口 + 顺序触发《诀别书》音符”的 landmark 体验，但用户随后把三个更硬的现实要求补充清楚了：

- 倒着开入公路时，音符顺序也必须真的倒过来，而不是简单判定失败后什么都不发生。
- 故意减速时，旋律的时间间隔也必须真的拉长，而不是仍按固定节拍播放。
- 键位的 shader 预点亮不再只是 future-ready contract，而是直接纳入 `v23` 范围。

用户还补充了一个 authoring QA 现实约束：他不识谱，只能靠听觉验收。因此，`v23` 不能把“谱源是否正确”“最终塞进高速路里的音符序列是否正确”留给人工猜测，必须增加一个中间检查步骤：把选定曲谱确定性渲染成试听音频产物，供用户直接听。

同时，用户明确建议高速路视觉资产优先复用 `refs/godot-road-generator` 的 mesh / material 体系，只要该复用路线不会把正式产品运行时绑死到 `refs/` 参考目录。

## Change

- `v23` 音乐触发机制从“正向成功检测”升级为“方向感知 + 真实时间间隔”的 traversal runtime：
  - 正向通过仍是 canonical `song_success`
  - 逆向通过必须能够产生逆序 note audition
  - 音符间隔必须由车辆真实 crossing 时间决定
- `v23` 视觉范围从“钢琴键 cue 可读”升级为“钢琴键 cue + shader 预点亮/命中发光/衰减熄灭”。
- `v23` 计划新增 authoring QA gate：
  - 由实现侧自己解决谱源搜索
  - 采用“官方音频锚点 + 可机读 MIDI 候选 + 人类可读谱预览”三角校验
  - 新增本地 Python 渲染工具，把 normalized note sequence 输出为 `wav`，必要时附带 `mp3`
- 高速路视觉资产路线升级为：
  - 优先复用 `refs/godot-road-generator` 中可稳定抽取的 straight-highway mesh / material 体系
  - `refs/` 内的 highway 资产只允许作为候选输入；只要某个 mesh / material 经过视觉级验证后被正式采用，就必须复制并整理到 `city_game/assets/environment/source/music_road/road_generator_frozen/`
  - 正式音乐公路 scene / material / import 链只允许引用项目自有复制件，不能让 `godot_citys` 运行时直接依赖 `refs/`

## Still Out Of Scope

- `v23` 仍然不接入 place search / route query / fast travel / autodrive
- `v23` 仍然不做节奏评分、combo、排行榜
- `v23` 仍然不要求用户自己找《诀别书》曲谱
- `v23` 仍然不把 `refs/` 当成正式产品源码区；只允许抽取/固化所需资产

## Affected Docs

- `docs/prd/PRD-0013-music-road-landmark-and-song-trigger.md`
- `docs/plan/v23-index.md`
- `docs/plan/v23-music-road-landmark.md`
- `docs/plans/2026-03-17-v23-music-road-design.md`

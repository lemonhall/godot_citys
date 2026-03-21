# V37 Helicopter Gunship Encounter Design

## Context

`v37` 不是单纯“把一架直升机放到天上”，而是要把三条现有主链收成一条可验证的遭遇战链：`v33` 的 lab-first 工作流、`v32` 的玩家导弹武器链、以及 `v14` 的任务圈/route/world ring 主链。用户已经把首版边界说得很清楚：先在 `city_game/scenes/labs/` 做独立场景，把炮艇出现、盘旋、机炮压制、无限导弹、受击和击落链调顺；然后再把同一套 runtime 移植回主世界 `chunk_101_178` 的正式任务圈。与此同时，本轮不能把需求复杂化：没有玩家掉血、没有任务失败、没有弹药上限，任务唯一完成条件就是玩家把炮艇击落，而且**这件事必须可以无限次重复**。

这意味着 `v37` 的真正难点不在模型导入，而在“如何在不破坏 `v14` 主链的前提下，把 objective completion 从 `enter slot` 最小化扩展成 `event complete`，同时再加上 repeatable reset”。如果这一步做成 gunship-only 私有状态机，主世界的 map pin、tracked route、world ring 和 task brief 都会立即分叉；但如果粗暴重写整套 task runtime，又会超出本轮范围。所以 `v37` 的设计应该是：继续保留 `available -> active -> completed` 与 `start slot / route_target_override` 主链，只对“active objective 如何完成”和“完成后如何回到下一次可接状态”做最小事件扩展。

## Chosen Approach

本轮选择“**单架精英炮艇 + 单任务点位 + lab/runtime 复用 + task event completion 最小扩展**”路线，而不选择：

- 多架炮艇编队
- 完整 player damage / fail / reset 系统
- 临时写一套 lab-only combat controller
- 绕开 task runtime 直接在 `CityPrototype` 私存一份 encounter 状态

原因很直接：

1. 用户要的是一场可打、可调、可移植的首版遭遇战，不是空战系统大全。
2. 现有 `v14` runtime 已经把 `route/pin/world ring` 收到 task 主链里，不能为了一个炮艇任务再开旁路。
3. 当前玩家导弹 `CityMissile.tscn` 已具备正式飞行与爆炸 contract，最值钱的复用点就是它。

技术拆分建议分三层：

- `CityHelicopterGunship`：炮艇 scene 与生命值/飞行/攻击状态机
- `CityHelicopterGunshipEncounterRuntime`：负责 start ring、spawn、lab/world 共用 encounter orchestration
- `CityTaskRuntime` 最小事件扩展：仍用同一 task 状态机，但允许通过事件完成 active objective，并在 repeatable task 上恢复到 `available`

## Runtime Architecture

### 1. Lab Scene

建议新增：

- `res://city_game/scenes/labs/HelicopterGunshipLab.tscn`
- `res://city_game/scenes/labs/HelicopterGunshipLab.gd`

场景内静态摆放：

- `WorldEnvironment`
- `DirectionalLight3D`
- 平直地面
- `Player`
- `CombatRoot`
- `EncounterRoot`
- `StartRing`
- 空中 spawn/orbit anchor

lab 不应该再发明一套特殊玩法链，而是直接实例化正式 `CityHelicopterGunshipEncounterRuntime`。这样后续移植回主世界时，lab 只是把“task start slot”换成“本地 start ring”，其它部分保持同一实现。

### 2. Gunship Scene

炮艇本体建议拆成独立 scene，例如：

- `res://city_game/combat/helicopter/CityHelicopterGunship.tscn`
- `res://city_game/combat/helicopter/CityHelicopterGunship.gd`

视觉根资源直接包裹：

- `res://city_game/assets/environment/source/aircraft/helicopter_a.glb`

炮艇 runtime 维护正式 state：

- `max_health`
- `current_health`
- `combat_state`
- `spawn_anchor`
- `orbit_center`
- `orbit_radius_m`
- `orbit_altitude_m`
- `last_hit_world_position`
- `missile_barrage_count`
- `burst_fire_state`

推荐首版把 survivability contract 冻成“10 发玩家导弹 direct hit 不死”，并以 `max_health = 160` 作为当前导弹伤害口径下的建议实现值。飞行方面不追求真实空气动力学，而是采用可预测的“保持高度 + 围绕中心盘旋 + 在攻击窗口略微调整朝向”的游戏化 flight profile。

### 3. Attack Profile

首版攻击谱固定为两条：

- 机炮压制：短 burst tracer / ground impact / near-miss feedback
- 导弹攻击：复用 `CityMissile.tscn` 视觉与飞行资产族

这里的重点不是把敌方导弹完全做成玩家导弹镜像，而是复用同一 scene/model 资产链，并给 runtime 增加足够的 owner / exclusion / damage profile 配置能力。因为本轮玩家不掉血，敌方导弹的职责主要是制造空地对轰的视觉和节奏压力，而不是推动 player damage 系统。

### 4. Task Integration

主世界接入的关键是最小化扩展 task contract。建议保留：

- `available`
- `active`
- `completed`

并给 task definition/runtime 增加一个很薄的事件完成字段，例如：

- `completion_mode = "event"`
- `completion_event_id = "encounter:helicopter_gunship_v37"`

同时再补一个 repeatable 语义字段，例如：

- `repeatable = true`
- `completion_count`

start slot 仍然是正式 `task_available_start`；active 后 route/world ring 仍然指向同一世界 anchor，只是 objective completion 不再来自 `complete_objective_slot()`，而是来自炮艇被击落时 encounter runtime 发出的 formal event。对于这个 repeatable task，`completed` 不是长期终态，而是单次 run 的 closeout 语义；在 closeout 结束后，runtime 把该任务恢复到 `available`，重新暴露绿圈，并要求玩家下一次重新进圈触发。这样 `map/minimap/task brief/world ring` 继续只认 task runtime，不会长出 gunship-only 第二套导航/任务状态。

## Phase Split

### Phase 1: Lab

先完成独立实验场：

- 进入起始圈
- 炮艇空中生成
- 炮艇盘旋与攻击
- 玩家反击
- 炮艇受击
- 击落结束

这阶段只看 encounter 自身是否成立，不受主世界 task catalog / streaming 细节干扰。

### Phase 2: Main World Port

把同一 encounter runtime 接回：

- `chunk_101_178`
- `world_anchor = (-8981.45, 0.0, 10796.22)`
- `v14` task start ring / tracked route / world ring 主链

active task 进入空战阶段后，炮艇常驻到被击落为止；本轮没有失败态，也没有离区失败逻辑。

击落 closeout 结束后，主世界必须回到初始 encounter 口径：

- 空中无炮艇
- 任务恢复 `available`
- 绿圈重新出现
- 下一轮必须重新进入绿圈

## Testing Strategy

至少补五类验证：

1. lab scene contract：lab 场景、玩家、ring、encounter root、炮艇 scene 可正常挂载
2. survivability / attack contract：炮艇会盘旋、会攻击、10 发玩家导弹不死
3. task runtime event completion contract：开始任务靠 `start slot`，完成任务靠 `event`
4. repeatable reset contract：第一次击落后恢复初始可接状态，再进绿圈能开始第二轮
5. main-world e2e：进 `chunk_101_178` 起始圈后触发 encounter，击落炮艇后任务完成并可再次触发

## Risks

- 如果 task completion 直接另起一套 gunship-only 状态机，`v14` 的 map/minimap/world ring/brief 会立刻分叉。
- 如果敌方导弹复用策略做得太粗，可能会误伤自身或污染玩家导弹既有 contract。
- 如果 survivability 只冻结成裸 `max_health`，未来玩家导弹伤害改动后，10 发不死的真实需求会悄悄失效。
- 如果 repeatable reset 不写成 formal contract，很容易做成“一次打完就永远消失”或“站在圈里原地连刷”的脏状态。
- 如果 lab 和主世界各写一套 encounter logic，第二阶段会从“移植”退化成“重写”。

## Recommendation

`v37` 首版严格控制目标：

- 一架炮艇
- 一个遭遇战点位
- 一条 event-complete task 扩展
- 一条 repeatable reset 扩展
- 无失败、无玩家掉血、无限敌方导弹

先把这条链跑通，再谈 player damage、脱战、失败、坠机残骸和多阶段 boss。不要在 `v37` 首版同时追求完整空战系统。

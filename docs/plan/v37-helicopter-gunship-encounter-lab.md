# V37 Helicopter Gunship Encounter Lab

## Goal

先交付一个可独立 `F6` 运行的直升机炮艇遭遇战 lab 场景，在低干扰环境里完成“进入起始圈 -> 炮艇空中生成 -> 炮艇盘旋 -> 机炮压制 -> 无限导弹攻击 -> 玩家反击 -> 炮艇受击 -> 击落完成”的完整闭环；随后再把同一套 runtime 逻辑接回主世界 `chunk_101_178` 的正式任务圈，并以“击落炮艇”而不是“进入 objective 圈”作为任务完成条件。

## PRD Trace

- Direct consumer: REQ-0024-001
- Direct consumer: REQ-0024-002
- Direct consumer: REQ-0024-003
- Direct consumer: REQ-0024-004
- Direct consumer: REQ-0024-005
- Direct consumer: REQ-0024-006

## Dependencies

- 依赖 `v14` 已冻结 `task catalog / task runtime / world ring / start trigger` 主链
- 依赖 `v32` 已冻结玩家导弹正式武器链：
  - `res://city_game/combat/CityMissile.tscn`
  - `missile_launcher`
- 依赖 `v33` 已验证 lab-first -> main-world port 的工作流
- 炮艇视觉资源首版直接复用：
  - `res://city_game/assets/environment/source/aircraft/helicopter_a.glb`

## Contract Freeze

- 独立 lab 必须先做，再做主世界移植
- 正式主世界触发点冻结为：
  - `chunk_id = chunk_101_178`
  - `chunk_key = (101, 178)`
  - `world_anchor = Vector3(-8981.45, 0.0, 10796.22)`
  - `chunk_local_anchor = Vector3(34.55, 0.0, 100.22)`
- encounter 完成条件冻结为：
  - `击落炮艇`
- 首版任务状态仍冻结为：
  - `available`
  - `active`
  - `completed`
- 首版不引入：
  - `failed`
  - 玩家掉血
  - 离区失败
- 炮艇攻击谱冻结为：
  - 机炮压制
  - 无限导弹
- 敌方导弹视觉/scene 资产默认复用：
  - `res://city_game/combat/CityMissile.tscn`
- 炮艇 survivability contract 冻结为：
  - 至少承受 `10` 发玩家导弹直接命中后仍未被击落
- 推荐首版数值基线：
  - `max_health = 160`
- task completion 最小扩展冻结为：
  - `completion_mode = "event"`
  - `completion_event_id = "encounter:helicopter_gunship_v37"`
- repeatable task 最小扩展冻结为：
  - `repeatable = true`
  - `completion_count`
  - `reset_to_available_after_closeout = true`
- 主世界与 lab 的 closeout 一致性冻结为：
  - 炮艇先空爆并进入坠落
  - 只有 crash cleanup 完成后，绿圈才重新出现
- 炮艇任务 pin contract 冻结为：
  - `icon_id = helicopter`
  - full-map UI glyph = `🚁`

## Scope

做什么：

- 新增独立 lab 场景、lab 脚本和 focused tests
- 新增炮艇 scene/runtime
- 新增 encounter runtime，负责 start ring、spawn、orbit、attack、destroyed
- 扩展任务 runtime，使 active task 能通过 encounter event 完成
- 扩展任务 runtime，使本任务在完成 closeout 后自动恢复到初始可接状态
- 把同一 encounter runtime 接回主世界 `chunk_101_178`
- 让主世界 shared route / pin / world ring 继续沿 task 主链消费 encounter objective

不做什么：

- 不做玩家生命值或失败态
- 不做多架炮艇编队
- 不做锁定、制导、弹药数量或装填系统
- 不做剧情对话、奖励结算或通缉链
- 不做跨 session 持久化
- 不做一次性通关后永久消失的任务口径

## Acceptance

1. 自动化测试必须证明：独立 lab 场景能正常加载玩家、地面、combat root、起始圈和炮艇 encounter root。
2. 自动化测试必须证明：玩家进入起始圈后，炮艇会在空中正式生成并进入盘旋攻击状态。
3. 自动化测试必须证明：炮艇会调度机炮与导弹两条攻击链，而不是只切状态文案。
4. 自动化测试必须证明：炮艇至少承受 `10` 发玩家导弹直接命中后仍未被摧毁。
5. 自动化测试必须证明：追加伤害足够后，炮艇会进入 `destroyed` 状态并发出正式 encounter completion 事件。
6. 自动化测试必须证明：主世界 `chunk_101_178` 的起始圈会启动同一 encounter，且击落炮艇后任务进入 `completed`。
7. 自动化测试必须证明：本轮没有引入 `failed`，也没有因为炮艇攻击修改玩家生命值。
8. 自动化测试必须证明：击落 closeout 结束后，任务会恢复到 `available`，绿圈重新出现，再次进入绿圈能开启第二次 run。
9. 自动化测试必须证明：主世界 full map 上的该任务 pin 走共享 task pin 主链，且正式使用直升机图标。
10. 反作弊条款：不得只让模型出现在天上却没有正式攻击；不得通过 lab-only 私有逻辑假装主世界可复用；不得把“击落完成”偷换成“进入第二个圈完成”；不得靠重载整个场景来冒充可重复任务。

## Files

- Create: `docs/prd/PRD-0024-helicopter-gunship-encounter.md`
- Create: `docs/plans/2026-03-21-v37-helicopter-gunship-encounter-design.md`
- Create: `docs/plan/v37-index.md`
- Create: `docs/plan/v37-helicopter-gunship-encounter-lab.md`
- Create: `city_game/scenes/labs/HelicopterGunshipLab.tscn`
- Create: `city_game/scenes/labs/HelicopterGunshipLab.gd`
- Create: `city_game/combat/helicopter/CityHelicopterGunship.tscn`
- Create: `city_game/combat/helicopter/CityHelicopterGunship.gd`
- Create: `city_game/combat/helicopter/CityHelicopterGunshipEncounterRuntime.gd`
- Create: `city_game/combat/helicopter/CityHelicopterGunshipWorldEncounter.tscn`
- Modify: `city_game/combat/CityMissile.gd`
- Optional Modify: `city_game/combat/CityMissile.tscn`
- Modify: `city_game/world/tasks/generation/CityTaskCatalogBuilder.gd`
- Modify: `city_game/world/tasks/model/CityTaskDefinition.gd`
- Modify: `city_game/world/tasks/model/CityTaskRuntime.gd`
- Modify: `city_game/world/tasks/runtime/CityTaskTriggerRuntime.gd`
- Modify: `city_game/world/tasks/runtime/CityTaskWorldMarkerRuntime.gd`
- Modify: `city_game/scripts/CityPrototype.gd`
- Create: `tests/world/test_city_helicopter_gunship_lab_scene_contract.gd`
- Create: `tests/world/test_city_helicopter_gunship_attack_contract.gd`
- Create: `tests/world/test_city_helicopter_gunship_survivability_contract.gd`
- Create: `tests/world/test_city_task_helicopter_gunship_event_completion.gd`
- Create: `tests/world/test_city_task_helicopter_gunship_repeatable_reset.gd`
- Create: `tests/world/test_city_task_helicopter_gunship_pin_contract.gd`
- Create: `tests/e2e/test_city_task_helicopter_gunship_flow.gd`

## Steps

1. Analysis
   - 固定 lab-first -> main-world port 的两阶段口径。
   - 固定无失败、无玩家掉血、无限敌方导弹。
   - 固定 `chunk_101_178` 的正式任务圈坐标。
2. Design
   - 写 `PRD-0024`、design doc、`v37-index` 和本计划文档。
3. TDD Red: Lab Scene
   - 先写 lab scene contract test，锁定 `F6` 场景的玩家、地面、起始圈、encounter root 与炮艇 scene 依赖。
4. Run Red
   - 跑 lab focused test，确认当前缺少正式场景与 runtime。
5. TDD Green: Lab Scene
   - 落 `HelicopterGunshipLab.tscn`
   - 接入玩家、start ring 与 encounter root
   - 接入正式炮艇 scene
6. TDD Red: Gunship Runtime
   - 写炮艇 orbit / attack / survivability tests。
   - 重点锁定“10 发玩家导弹不死”的正式 contract。
7. TDD Green: Gunship Runtime
   - 实现炮艇生命值、受击、盘旋与攻击状态机。
   - 扩展导弹 scene/runtime 的 owner/profile 配置，支撑敌方导弹复用。
8. TDD Red: Task Event Completion
   - 写 `task runtime` 的 event-completion contract test。
   - 证明当前 `v14` 只支持进圈完成，尚不支持 encounter completion。
9. TDD Red: Repeatable Reset
   - 写 repeatable task reset contract test。
   - 证明当前 runtime 完成后不会自动回到初始可接状态。
10. TDD Green: Task Event Completion + Repeatable Reset
   - 以最小扩展方式给 task definition/runtime 增加 `completion_mode = event`。
   - 以最小扩展方式给该任务增加 `repeatable = true` 与 `completion_count`。
   - 保持 `available -> active -> completed` 主链不分叉，同时支持 closeout 后回到 `available`。
11. Port to Main World
   - 在 `CityTaskCatalogBuilder` 为 `chunk_101_178` 新增正式 start/objective definition。
   - 在 `CityPrototype` 中挂接 encounter runtime，把击落事件回流给 task runtime。
   - 让主世界 closeout 与 lab 保持一致：空爆坠落完成后再返绿圈。
   - 给 full map task pin 接上正式 `helicopter` 图标。
12. E2E / Focused Verification
   - 跑 lab focused tests。
   - 跑 main-world task encounter flow。
   - 跑 repeatable second-run verification。
   - 跑 full-map helicopter pin contract。
   - 补跑受影响的 task/runtime/missile focused 回归。
13. Review
   - 更新 `v37-index` 追溯矩阵与验证证据。

## Risks

- 如果 event completion 扩展过重，容易把 `v14` 的简洁任务状态机重写成另一套系统。
- 如果敌方导弹复用 `CityMissile.tscn` 时不处理 owner/exclusion，可能会污染既有导弹 contract 或误伤自己。
- 如果 survivability 只靠裸血量而不写“10 发 direct hit 不死”的测试，后续平衡改动会悄悄打破用户要求。
- 如果 repeatable reset 不要求 fresh re-entry edge，玩家可能会站在圈里原地连触发，战斗节奏会很脏。
- 如果 lab 和主世界 encounter 各自写一套逻辑，第二阶段会变成高风险重写。

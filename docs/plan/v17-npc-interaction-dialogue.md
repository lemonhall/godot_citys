# V17 NPC Interaction And Dialogue

> 2026-03-16 口径修正：本计划作用域是“任何被显式配置为可交互的 NPC”，不是“仅限功能建筑里的 NPC”；咖啡馆服务员只是第一个真实 consumer。

## Goal

交付一条正式、可复用的 NPC 近距交互主链：玩家靠近某个被显式配置为可交互的 NPC 到 `5m` 内时，HUD 持续显示“可以按下 `E` 键交互”；玩家按下 `E` 后进入正式对话 runtime；咖啡馆服务员作为首个 consumer 会说出“你想喝点什么？”。

## PRD Trace

- Direct consumer: REQ-0010-001
- Direct consumer: REQ-0010-002
- Direct consumer: REQ-0010-003
- Guard / Performance: REQ-0010-004

## Dependencies

- 依赖 `CityPrototype._unhandled_input()` 作为正式输入 ownership 总入口。
- 依赖 `PrototypeHud` 已有 HUD 根结构，可在其上扩展 interaction prompt 与 dialogue view。
- 依赖 `v16` 的咖啡馆服务员已存在稳定场景锚点与 idle actor 表现，作为首个 consumer 落点。

## Contract Freeze

- `E` 是正式 NPC 交互键，不是 debug-only 临时键。
- 通用 interactable NPC actor 的最小 contract 冻结为：`actor_id / display_name / interaction_kind / interaction_radius_m / dialogue_id / opening_line`。
- interaction prompt 的最小 HUD state 冻结为：`visible / actor_id / prompt_text / distance_m`。
- dialogue runtime 的最小 state 冻结为：`status / owner_actor_id / speaker_name / body_text / dialogue_id`。
- 近距候选只允许来自当前已挂载且显式声明为可交互的 NPC actor group，不允许每帧扫描全城 pedestrian 数据。
- `v17` 首版对话冻结为 opening line + close，不做商品交易、库存和多轮分支。

## Scope

做什么：

- 为任何被显式配置为可交互的 NPC 建立通用 actor contract
- 新增世界级 `NpcInteractionRuntime`，负责 `5m` 候选裁定与 `E` 提示 ownership
- 在 `PrototypeHud` 新增持续性的 interaction prompt
- 新增 `DialogueRuntime` 与 dialogue panel
- 把咖啡馆服务员接成首个对话 consumer
- 补 world/e2e tests、回归 tests 与 profiling 证据

不做什么：

- 不做商店结算、库存或任务奖励
- 不做多轮分支树或 dialogue authoring tool
- 不做所有 pedestrians 自动转为 interactable
- 不做语音、表情或复杂 NPC 行为树

## Acceptance

1. 自动化测试必须证明：玩家在 `5m` 外看不到 NPC 交互提示，进入 `5m` 内后才会看到 `E` 提示。
2. 自动化测试必须证明：多个近距 NPC 同时存在且都在 `5m` 内时，只允许最近 actor 拥有提示显示权。
3. 自动化测试必须证明：无 active interaction candidate 时按 `E` 不会误开 dialogue。
4. 自动化测试必须证明：有 active interaction candidate 时按 `E` 会进入 dialogue active 状态，并隐藏 interaction prompt。
5. 自动化测试必须证明：咖啡馆服务员按 `E` 后正文会出现“你想喝点什么？”。
6. 自动化测试必须证明：关闭对话后，会回到正确的 prompt 逻辑，而不是卡在 active 状态。
7. 自动化测试必须证明：车辆 `F` 键交互链不回退。
8. 串行 profiling 至少 `runtime` 与 `first_visit` 继续过线。
9. 反作弊条款：不得通过写死 HUD 文本、场景特判、只弹 Toast、或跳过实时候选裁定来宣称完成。

## Files

- Modify: `city_game/scripts/CityPrototype.gd`
- Modify: `city_game/ui/PrototypeHud.gd`
- Modify: `city_game/world/serviceability/CityIdleServicePedestrian.gd`
- Modify: `city_game/serviceability/buildings/generated/bld_v15-building-id-1_seed424242_chunk_137_136_003/咖啡馆.tscn`
- Create: `city_game/world/interactions/CityInteractableNpc.gd`
- Create: `city_game/world/interactions/CityNpcInteractionRuntime.gd`
- Create: `city_game/world/interactions/CityDialogueRuntime.gd`
- Create: `city_game/ui/CityDialoguePanel.gd`
- Create: `tests/world/test_city_npc_interaction_prompt_contract.gd`
- Create: `tests/world/test_city_dialogue_runtime_contract.gd`
- Create: `tests/e2e/test_city_cafe_barista_dialogue_flow.gd`
- Create: `docs/plan/v17-index.md`

## Steps

1. 写失败测试（红）
   - 先写 `test_city_npc_interaction_prompt_contract.gd`，覆盖 `5m` 提示 ownership。
   - 再写 `test_city_dialogue_runtime_contract.gd`，覆盖 `E` 键 ownership 与 dialogue `idle / active`。
   - 再写 `test_city_cafe_barista_dialogue_flow.gd`，覆盖咖啡馆服务员首个 consumer。
2. 运行到红
   - 预期失败点必须落在：当前没有正式 interactable NPC contract、没有 interaction prompt runtime、没有 dialogue runtime，而不是测试本身写错。
3. 实现（绿）
   - 新增 `CityInteractableNpc.gd` 和 `CityNpcInteractionRuntime.gd`。
   - 在 `PrototypeHud` 增加 interaction prompt 与 dialogue panel。
   - 新增 `CityDialogueRuntime.gd`，接 `E` ownership。
   - 把咖啡馆服务员接成首个 consumer。
4. 运行到绿
   - `test_city_npc_interaction_prompt_contract.gd`
   - `test_city_dialogue_runtime_contract.gd`
   - `test_city_cafe_scene_contract.gd`
   - `test_city_cafe_barista_dialogue_flow.gd`
5. 必要重构（仍绿）
   - 收口 actor contract、HUD state 和 dialogue state，避免 `CityPrototype` 再长成巨石。
6. E2E
   - 跑 `test_city_cafe_barista_dialogue_flow.gd`。
   - 补跑车辆交互回归与 profiling guard。

## Risks

- 如果交互候选走全城扫描，`v17` 会直接踩 performance 红线。
- 如果 prompt 继续复用 timed Toast，后续任务、商店、NPC 提示 ownership 一定会打架。
- 如果 dialogue runtime 只做咖啡馆场景特判，不做通用 contract，第二个 NPC 一上来就要推倒重写。

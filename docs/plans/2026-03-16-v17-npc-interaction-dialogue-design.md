# V17 NPC Interaction And Dialogue Design

**Goal:** 把“接近 NPC -> HUD 提示 -> 按 `E` -> 对话”收口成正式 runtime，而不是继续在每个功能场景里写零散脚本。

**Architecture:** 继续沿 `CityPrototype + PrototypeHud + serviceability scene` 主链推进。交互候选只来自当前已挂载的 service actors，按最近距离做单拥有者裁定；HUD 增加一条持续性的 interaction prompt；按 `E` 进入独立 dialogue runtime，再由 dialogue runtime 接管 `E` ownership。

**Tech Stack:** Godot 4.6、GDScript、现有 `PrototypeHud`、`CityPrototype._unhandled_input()`、功能建筑 service scene、现有 `suit.glb` 服务员。

---

## Context

- 现在仓库里已经有 `FocusMessage` Toast，但它是时间衰减消息，不适合作为“持续显示直到离开 3m”的交互提示。
- `CityPrototype` 已经维护输入 ownership：`M` 地图、`T` 快速旅行、`F` 车辆交互、`KP+` 建筑导出。NPC 交互要接进同一条 ownership 链，而不是绕开它。
- `v16` 的咖啡馆服务员已经存在于服务化场景里，具备 `actor_id / role` 元数据与稳定锚点，是最合适的第一个 consumer。

## Options

### 方案 A：继续复用 `FocusMessage` Toast，靠距离触发/关闭提示

优点：改动最少。

缺点：Toast 语义是“时间性通知”，不是“条件成立即持续显示”。它没有 owner 概念，也无法表达“最近候选唯一拥有者”。一旦后续再加任务、商店或多 NPC，HUD 状态会立刻打架。

### 方案 B：新增 `InteractionPrompt` HUD 状态 + `NpcInteractionRuntime` + `DialogueRuntime`

优点：语义清晰，ownership 明确；以后任何 service actor 都能接同一 contract。提示、交互、对话分层明确，不污染 `FocusMessage`。

缺点：要多建一个 runtime 和一条 HUD 状态。

### 方案 C：把 NPC 对话直接并进任务系统 world marker / trigger 链

优点：理论上可以复用 slot/index。

缺点：过重。任务 trigger 是目标点/路标模型，NPC 近距交互是 actor-centric 模型，把两者强行揉在一起会把任务系统带偏。

推荐：**方案 B**。这是最稳的正式路径。

## Data Flow

```text
mounted service actor nodes
  -> CityNpcInteractionRuntime scans active actors only
  -> nearest actor within 3m becomes prompt owner
  -> PrototypeHud shows "可以按下 E 键交互"
  -> KEY_E
  -> CityDialogueRuntime.begin_dialogue(actor_contract)
  -> dialogue panel shows speaker + text
  -> KEY_E / ESC closes
  -> interaction runtime regains prompt ownership
```

## Component Design

### 1. `CityServiceActor.gd`

- 通用 actor contract 承载脚本。
- 最小导出字段：
  - `actor_id`
  - `display_name`
  - `interaction_kind`
  - `interaction_radius_m`
  - `dialogue_id`
  - `opening_line`
- `_ready()` 时进入统一 group，例如 `city_service_actor`。
- 可与 `CityIdleServicePedestrian.gd` 组合使用，避免把 idle 动画逻辑和交互逻辑耦死。

### 2. `CityNpcInteractionRuntime.gd`

- 世界级 runtime，挂在 `CityPrototype` 下。
- 只扫描当前 scene tree 中已挂载的 `city_service_actor`，不碰全城生成数据。
- 每帧或事件驱动选出最近且在 `3m` 内的候选 actor。
- 输出稳定 state：
  - `visible`
  - `actor_id`
  - `display_name`
  - `prompt_text`
  - `distance_m`

### 3. `PrototypeHud` interaction prompt

- 新增与 `FocusMessage` 分离的 prompt 状态。
- 视觉上可复用同一家族样式，但生命周期不同：
  - `FocusMessage` = timed toast
  - `InteractionPrompt` = condition-owned prompt

### 4. `CityDialogueRuntime.gd`

- 最小对话状态：
  - `idle / active`
  - `speaker_name`
  - `body_text`
  - `dialogue_id`
  - `owner_actor_id`
- `begin_dialogue(contract)` 打开。
- `close_dialogue()` 关闭。
- `E` 在 active 时变成“继续/关闭”，不是再次尝试开新交互。

## Testing Strategy

### World Contract

- `tests/world/test_city_npc_interaction_prompt_contract.gd`
  - 距离内显示 `E` 提示，距离外隐藏
  - 多候选时只认最近 actor
- `tests/world/test_city_dialogue_runtime_contract.gd`
  - `E` ownership 与 `idle / active` 切换
  - 对话打开时 prompt 隐藏，关闭时恢复
- `tests/world/test_city_cafe_scene_contract.gd`
  - 咖啡馆服务员具备 `CityServiceActor` contract 与 opening line

### E2E

- `tests/e2e/test_city_cafe_barista_dialogue_flow.gd`
  - 进入咖啡馆
  - 靠近服务员
  - 看到提示
  - 按 `E`
  - 看到“你想喝点什么？”
  - 关闭对话

### Guard

- `tests/world/test_city_player_vehicle_drive_mode.gd`
- `tests/e2e/test_city_vehicle_hijack_drive_flow.gd`
- `tests/e2e/test_city_runtime_performance_profile.gd`
- `tests/e2e/test_city_first_visit_performance_profile.gd`

## Task Breakdown

### Task 1: 文档 + 红测

**Files:**

- Create: `docs/prd/PRD-0010-npc-interaction-dialogue.md`
- Create: `docs/plan/v17-index.md`
- Create: `docs/plan/v17-npc-interaction-dialogue.md`
- Create: `tests/world/test_city_npc_interaction_prompt_contract.gd`
- Create: `tests/world/test_city_dialogue_runtime_contract.gd`
- Create: `tests/e2e/test_city_cafe_barista_dialogue_flow.gd`

### Task 2: 通用 actor contract 与 prompt runtime

**Files:**

- Create: `city_game/world/serviceability/CityServiceActor.gd`
- Create: `city_game/world/serviceability/CityNpcInteractionRuntime.gd`
- Modify: `city_game/scripts/CityPrototype.gd`
- Modify: `city_game/ui/PrototypeHud.gd`

### Task 3: dialogue runtime 与 UI

**Files:**

- Create: `city_game/world/serviceability/CityDialogueRuntime.gd`
- Create: `city_game/ui/CityDialoguePanel.gd`
- Modify: `city_game/scripts/CityPrototype.gd`
- Modify: `city_game/ui/PrototypeHud.gd`

### Task 4: 咖啡馆服务员首个 consumer

**Files:**

- Modify: `city_game/world/serviceability/CityIdleServicePedestrian.gd`
- Modify: `city_game/serviceability/buildings/generated/bld_v15-building-id-1_seed424242_chunk_137_136_003/咖啡馆.tscn`
- Test: `tests/world/test_city_cafe_scene_contract.gd`
- Test: `tests/e2e/test_city_cafe_barista_dialogue_flow.gd`

### Task 5: 回归与 closeout

**Files:**

- Create: `docs/plan/v17-m3-verification-2026-03-16.md`

**Commands:**

- `& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_npc_interaction_prompt_contract.gd'`
- `& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_dialogue_runtime_contract.gd'`
- `& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_cafe_scene_contract.gd'`
- `& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/e2e/test_city_cafe_barista_dialogue_flow.gd'`
- `& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_player_vehicle_drive_mode.gd'`
- `& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/e2e/test_city_vehicle_hijack_drive_flow.gd'`
- `& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/e2e/test_city_runtime_performance_profile.gd'`
- `& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/e2e/test_city_first_visit_performance_profile.gd'`

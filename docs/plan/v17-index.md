# V17 Index

> 2026-03-16 口径修正：`v17` 不是“建筑物里的 NPC 交互版”，而是“任何被显式配置为可交互的 NPC 都可复用的通用交互/对话底座”；咖啡馆服务员只是首个 consumer。

## 愿景

PRD 入口：[PRD-0010 NPC Interaction And Dialogue](../prd/PRD-0010-npc-interaction-dialogue.md)

设计入口：[2026-03-16-v17-npc-interaction-dialogue-design.md](../plans/2026-03-16-v17-npc-interaction-dialogue-design.md)

依赖入口：

- [PRD-0009 Building Serviceability Reconstruction](../prd/PRD-0009-building-serviceability-reconstruction.md)
- [v16-index.md](./v16-index.md)

`v17` 的目标是把“接近任意被显式配置为可交互的 NPC -> HUD 提示 -> 按 `E` -> 对话”冻结成正式主链。第一批交付先以咖啡馆服务员为首个 consumer，但 runtime contract 必须从一开始就服务于未来更多 NPC，而不是只给单个场景写死。

## 决策冻结

- `v17` 的正式 NPC 交互键冻结为 `E`，不挤占车辆 `F` 键交互。
- 近距提示距离冻结为 `3m`。
- HUD 交互提示冻结为持续 state，不复用 `FocusMessage` 计时 Toast。
- 对话 runtime 首版冻结为单轮 opening line + close，不做商品结算和多轮分支。
- 交互候选只允许来自当前已挂载且显式声明为可交互的 NPC actor group，不允许每帧扫描全城 pedestrian 数据。

## 里程碑

| 里程碑 | 范围 | DoD | 验证命令/测试 | 状态 |
|---|---|---|---|---|
| M1 近距交互提示 | 通用 actor contract、3m 候选求解、HUD `E` 提示 | 最近 actor 在 `3m` 内稳定拥有提示；离开范围或对话打开后提示隐藏；不影响车辆 `F` 交互 | `tests/world/test_city_npc_interaction_prompt_contract.gd`、`tests/world/test_city_player_vehicle_drive_mode.gd` | todo |
| M2 通用对话 runtime + 咖啡馆首个 consumer | `E` 键对话 ownership、dialogue runtime、咖啡馆服务员 opening line | 靠近服务员可按 `E` 打开对话；正文出现“你想喝点什么？”；关闭后回到提示态 | `tests/world/test_city_dialogue_runtime_contract.gd`、`tests/world/test_city_cafe_scene_contract.gd`、`tests/e2e/test_city_cafe_barista_dialogue_flow.gd` | todo |
| M3 回归与性能复验 | 车辆交互不回退、runtime/first-visit profiling | `F` 键车辆交互继续成立；近距提示与对话链不踩性能红线 | `tests/e2e/test_city_vehicle_hijack_drive_flow.gd`、`tests/e2e/test_city_runtime_performance_profile.gd`、`tests/e2e/test_city_first_visit_performance_profile.gd` | todo |

## 计划索引

- [v17-npc-interaction-dialogue.md](./v17-npc-interaction-dialogue.md)

## 追溯矩阵

| Req ID | v17 Plan | 单元/集成测试 | E2E / 验证命令 | 证据 | 状态 |
|---|---|---|---|---|---|
| REQ-0010-001 | `v17-npc-interaction-dialogue.md` | `tests/world/test_city_npc_interaction_prompt_contract.gd` | `--script res://tests/e2e/test_city_cafe_barista_dialogue_flow.gd` | — | todo |
| REQ-0010-002 | `v17-npc-interaction-dialogue.md` | `tests/world/test_city_dialogue_runtime_contract.gd` | `--script res://tests/e2e/test_city_cafe_barista_dialogue_flow.gd` | — | todo |
| REQ-0010-003 | `v17-npc-interaction-dialogue.md` | `tests/world/test_city_cafe_scene_contract.gd` | `--script res://tests/e2e/test_city_cafe_barista_dialogue_flow.gd` | — | todo |
| REQ-0010-004 | `v17-npc-interaction-dialogue.md` | `tests/world/test_city_player_vehicle_drive_mode.gd`、`tests/world/test_city_npc_interaction_prompt_contract.gd` | `--script res://tests/e2e/test_city_vehicle_hijack_drive_flow.gd`、`--script res://tests/e2e/test_city_runtime_performance_profile.gd`、`--script res://tests/e2e/test_city_first_visit_performance_profile.gd` | — | todo |

## Closeout 证据口径

- `v17` closeout 必须以 fresh tests + fresh profiling 为准，统一落在 `docs/plan/v17-mN-verification-YYYY-MM-DD.md`。
- 只显示提示、不支持 `E` ownership 与对话 runtime，不算 `v17` 完成。
- 只有咖啡馆服务员能交互、未来被配置为可交互的 NPC 无法复用同一 contract，不算 `v17` 完成。

## ECN 索引

- 当前无。

## 差异列表

- 当前尚未实现 `E` 键 NPC 交互主链。
- 当前尚未存在正式 dialogue runtime。
- 当前咖啡馆服务员只有 idle 表现，没有交互与对话。

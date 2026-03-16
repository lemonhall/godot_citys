# V20 Index

## 愿景

依赖入口：

- [PRD-0010 NPC Interaction And Dialogue](../prd/PRD-0010-npc-interaction-dialogue.md)
- [v17-index.md](./v17-index.md)
- [v19-index.md](./v19-index.md)

`v20` 的目标是把枪店店员正式接成 `v17` 通用 NPC 交互/对话底座的第二个真实 consumer。玩家进入枪店后，接近店员到 `5m` 内会看到稳定的 `E` 提示，按下 `E` 后会进入正式对话态，店员使用 `man.glb` 并说出“都很致命，想要哪一把？”。

## 决策冻结

- 本轮只做枪店店员 actor、近距提示、对话 opening line 与场景 contract。
- 本轮复用 `v17` 的 `CityInteractableNpc / CityNpcInteractionRuntime / CityDialogueRuntime` 主链，不新造 gun-shop-only 交互状态。
- 本轮模型固定使用 `res://city_game/assets/pedestrians/civilians/man.glb`。
- 本轮不做武器购买、库存、金钱、任务或多轮对话。

## 里程碑

| 里程碑 | 范围 | DoD | 验证命令/测试 | 状态 |
|---|---|---|---|---|
| M1 场景 consumer 接入 | 枪店 `Staff/Gunsmith`、锚点占位、idle 动画、交互 contract | 枪店 scene 包含正式店员 actor；actor 使用 `man.glb`；actor contract 冻结 `actor_id / interaction_kind / radius / dialogue_id / opening_line`；actor 朝向顾客区且 idle 动画播放 | `tests/world/test_city_gun_shop_scene_contract.gd` | todo |
| M2 近距提示与对话整链路 | 枪店里 `5m -> E 提示 -> E 打开对话 -> E 关闭` | 靠近枪店店员后 HUD 出现 `E` 提示；店员拥有最近 candidate ownership；按 `E` 后正文出现“都很致命，想要哪一把？”；关闭后回到提示态 | `tests/e2e/test_city_gun_shop_clerk_dialogue_flow.gd` | todo |
| M3 回归 | 既有咖啡馆 consumer 与枪店 scene 不回退 | 咖啡馆 barista 仍可交互；枪店武器展示与场景 contract 不回退 | `tests/e2e/test_city_cafe_barista_dialogue_flow.gd`、`tests/world/test_city_gun_shop_weapon_display_contract.gd` | todo |

## 计划索引

- [v20-gun-shop-clerk-dialogue.md](./v20-gun-shop-clerk-dialogue.md)

## 追溯矩阵

| Req ID | v20 Plan | 单元/集成测试 | E2E / 验证命令 | 证据 | 状态 |
|---|---|---|---|---|---|
| REQ-0010-001 | `v20-gun-shop-clerk-dialogue.md` | `tests/world/test_city_gun_shop_scene_contract.gd` | `tests/e2e/test_city_gun_shop_clerk_dialogue_flow.gd` | — | todo |
| REQ-0010-002 | `v20-gun-shop-clerk-dialogue.md` | `tests/world/test_city_gun_shop_scene_contract.gd` | `tests/e2e/test_city_gun_shop_clerk_dialogue_flow.gd` | — | todo |
| REQ-0010-004 | `v20-gun-shop-clerk-dialogue.md` | `tests/world/test_city_gun_shop_weapon_display_contract.gd` | `tests/e2e/test_city_cafe_barista_dialogue_flow.gd` | — | todo |

## ECN 索引

- 当前无。

## 差异列表

- 本轮不做枪店购买逻辑。
- 本轮不做多轮枪械介绍或分支选项。

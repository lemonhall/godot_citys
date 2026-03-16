# V20 Gun Shop Clerk Dialogue

## Goal

把枪店店员正式接成 `v17` 通用 NPC 交互/对话底座的第二个真实 consumer，确保枪店不只是静态场景，而是具备最小可交互服务员闭环。

## PRD Trace

- Direct consumer: REQ-0010-001
- Direct consumer: REQ-0010-002
- Direct consumer: REQ-0010-004

## Scope

做什么：

- 在 `枪店_A.tscn` 添加正式 `Staff/Gunsmith` actor
- 复用 `CityIdleServicePedestrian.gd` 挂接 `man.glb`
- 配置枪店店员 contract：`actor_id / display_name / interaction_kind / interaction_radius_m / dialogue_id / opening_line`
- 补枪店 scene contract test 与 gun shop clerk dialogue e2e test

不做什么：

- 不做交易系统
- 不做武器购买结果
- 不做多轮分支或新 HUD 样式

## Acceptance

1. 自动化测试必须证明：枪店 scene 包含正式店员 actor，且该 actor 使用 `man.glb` 作为模型来源。
2. 自动化测试必须证明：枪店店员具备正式 interactable NPC contract，`interaction_radius_m` 冻结为 `5m`。
3. 自动化测试必须证明：枪店店员默认播放 idle 动画并面向顾客区域，而不是背对柜台前方。
4. 自动化测试必须证明：玩家进入 `5m` 范围后，HUD 显示 `E` 提示，且提示 ownership 属于枪店店员。
5. 自动化测试必须证明：按 `E` 后 dialogue runtime 进入 `active`，正文包含“都很致命，想要哪一把？”；再次按 `E` 会关闭并回到提示态。
6. 反作弊条款：不得只在 HUD 里硬编码这句台词；不得跳过正式 actor contract；不得写 gun-shop-only 对话旁路。

## Files

- Modify: `city_game/serviceability/buildings/generated/bld_v15-building-id-1_seed424242_chunk_134_130_014/枪店_A.tscn`
- Modify: `tests/world/test_city_gun_shop_scene_contract.gd`
- Create: `tests/e2e/test_city_gun_shop_clerk_dialogue_flow.gd`
- Create: `docs/plan/v20-index.md`
- Create: `docs/plan/v20-gun-shop-clerk-dialogue.md`

## Steps

1. 写失败测试（红）
   - 修改 `tests/world/test_city_gun_shop_scene_contract.gd`
   - 新建 `tests/e2e/test_city_gun_shop_clerk_dialogue_flow.gd`
2. 运行到红
   - 预期失败点必须落在：枪店 scene 尚无正式店员 actor，或整链路对话尚未接上。
3. 实现（绿）
   - 在枪店 scene 接入 `Staff/Gunsmith`
   - 绑定 `man.glb`、idle 动画与 opening line
4. 运行到绿
   - 跑枪店 scene contract test 与 gun shop clerk dialogue e2e test
5. 必要重构（仍绿）
   - 收口命名与 metadata，使枪店店员 consumer 与咖啡馆 barista 风格一致
6. Verify
   - 跑 `tests/e2e/test_city_cafe_barista_dialogue_flow.gd`
   - 跑 `tests/world/test_city_gun_shop_weapon_display_contract.gd`

## Risks

- `man.glb` 的动画名与咖啡馆服务员不同，若直接套旧参数会导致 idle 不播放。
- 枪店柜台与货架尺度较大，若店员缩放或朝向不对，提示会在错误位置出现。
- 若改成 gun-shop-only 逻辑，后续第三个 consumer 会再次分叉。

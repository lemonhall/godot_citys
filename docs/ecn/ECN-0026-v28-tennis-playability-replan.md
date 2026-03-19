# ECN-0026: V28 Tennis Playability Replan

## 基本信息

- **ECN 编号**：ECN-0026
- **关联 PRD**：PRD-0018
- **关联 Req ID**：REQ-0018-001、REQ-0018-002、REQ-0018-003A
- **发现阶段**：`v28-tennis-singles-minigame` 手玩回合
- **日期**：2026-03-19

## 变更原因

首轮 `v28` 实机场测已经证明文档里原先冻结的可玩性口径还不够硬，主要有四个具体问题：

1. start ring 被放在球场右前外侧，离玩家真正要进入的发球/接球区过远，导致“开赛入口存在，但落点不在可玩区”。
2. 场地虽然已经按 `7.5x` 放大，但当前平台抬高量仍不足，局部区域继续被地形吃掉。
3. 网球 ball 的碰撞直径会跟着 `target_diameter_m` 变，但 visual mesh 没有同步归一化，实机看到的球仍偏小，第三人称可读性不足。
4. 网球 runtime 的玩家合法击球半径大于 shared interactive prop prompt 半径，导致“strike window 已 ready，但共享 E 提示不亮”，玩家接不了 AI 回球。

这些都不是 polish，而是正式的 playability contract 变化，因此必须进入 ECN，而不是口头调整后继续施工。

## 变更内容

### 原设计

- court 平台相对首版实现额外抬高 `+1.0m`
- start ring 只要求存在，未冻结其相对 player-side serve 区的可达性约束
- tennis ball 只冻结了 `target_diameter_m`，未冻结 visual mesh 必须随 contract 同步缩放
- shared prompt 半径未与 tennis strike window 对齐

### 新设计

- `v28` court 平台总抬高量冻结为：**相对原始 authored 基线累计 `+2.0m`**
  - 对应 `scene_root_offset.y = 2.74`
- tennis ball resting center 必须随 court uplift 与 oversize ball 同步抬高
  - 对应 `scene_root_offset.y = 2.89`
- start ring 位置冻结为：**home/player side 的 serve setup zone 附近**
  - 它必须位于 home side
  - 它必须靠近 home serve anchors，不能再落到 far sideline / far apron
- receive blue ring 语义冻结为：**玩家可进入的接球操作圈**
  - 它负责把玩家引到可击球站位，而不是只画原始落点
  - 来球第一次落地/进入正式击球阶段后，这个圈应及时消失，把屏幕留给 `E` 提示与击球反馈
- tennis ball 首版 gameplay readability 冻结为：**oversized third-person readable ball**
  - `target_diameter_m` 不再维持近真实尺寸，而是提升到 `2x-3x` 可读区间
  - visual mesh 必须按 `target_diameter_m` 归一化，不能继续停留在场景初始尺寸
- shared `E` prompt 可触达半径必须与 tennis receive UX 对齐
  - `interaction_radius_m` 不得小于 player strike radius
  - 目标是让“合法接球窗口”与“共享交互入口”收敛成同一条用户链路

## 影响范围

- 受影响的 Req ID：
  - `REQ-0018-001`
  - `REQ-0018-002`
  - `REQ-0018-003A`
- 受影响的 v28 计划：
  - `docs/plan/v28-index.md`
  - `docs/plan/v28-tennis-singles-minigame.md`
- 受影响的测试：
  - `tests/world/test_city_tennis_minigame_venue_manifest_contract.gd`
  - `tests/world/test_city_tennis_ball_prop_manifest_contract.gd`
  - `tests/world/test_city_tennis_court_geometry_contract.gd`
  - `tests/world/test_city_tennis_ai_return_contract.gd`
  - `tests/e2e/test_city_tennis_singles_match_flow.gd`
- 受影响的代码文件：
  - `city_game/serviceability/minigame_venues/generated/venue_v28_tennis_court_chunk_158_140/minigame_venue_manifest.json`
  - `city_game/serviceability/minigame_venues/generated/venue_v28_tennis_court_chunk_158_140/TennisMinigameVenue.gd`
  - `city_game/serviceability/interactive_props/generated/prop_v28_tennis_ball_chunk_158_140/interactive_prop_manifest.json`
  - `city_game/serviceability/interactive_props/generated/prop_v28_tennis_ball_chunk_158_140/TennisBallProp.gd`

## 处置方式

- [x] PRD 已同步更新（标注 ECN-0026）
- [x] v28 计划已同步更新
- [x] 追溯矩阵已同步更新
- [ ] 相关测试已同步更新

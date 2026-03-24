# V48 Artillery Interaction Polish

## Goal

把 M777 howitzer 的 enter radius 和 rope visual 从“能用但别扭”收口到“正式可复用 contract”：玩家在约 `7m` 内就能稳定看到 `按 E 操作炮`，而火绳在 idle baseline 与操炮态下都表现为连续曲线，不再出现贴地折线。

## Dependencies

- howitzer lab：
  - `res://city_game/scenes/labs/M777HowitzerLab.tscn`
  - `res://city_game/scenes/labs/M777HowitzerLab.gd`
- 正式 howitzer runtime：
  - `res://city_game/combat/artillery/CityM777Howitzer.tscn`
  - `res://city_game/combat/artillery/CityM777Howitzer.gd`
  - `res://city_game/combat/artillery/CityArtilleryLanyardLine.gd`

## Contract Freeze

- enter radius：
  - `7.0m`
- retention radius：
  - `20.0m`
- rope visual：
  - formal artillery-only script
  - multi-sample curve
  - stable world-scale sag

## PRD Trace

- `REQ-0029-007`
- `REQ-0029-008`

## Scope

做什么：

- 把 howitzer enter radius 从 `5m` 提升到 `7m`
- 给 `LanyardLine` 换成正式 artillery 专用 rope curve script
- 暴露 rope debug state，让 focused tests 能直接验证 sample count 与最低点
- 补 fresh verification 文档

不做什么：

- 不改 `20m` retention 规则
- 不重做 fire anchors
- 不改 `Space`、cooldown 或炮口火光/烟尘合同
- 不做 projectile、弹道、落点与爆炸

## Acceptance

1. 自动化测试必须证明：`M777HowitzerLab` 的 `interaction_radius_m` 冻结为 `7.0m`。
2. 自动化测试必须证明：玩家在约 `7m` 外时，HUD 不出现 `按 E 操作炮`；进入 `7m` 内后才出现。
3. 自动化测试必须证明：正式 howitzer scene 的 `LanyardLine` 绑定到 `CityArtilleryLanyardLine.gd`，不再引用 `FishingLineVisual.gd`。
4. 自动化测试必须证明：操炮态 rope debug state 暴露 `sample_count`，且 `sample_count >= 8`，不允许退回三点折线。
5. 自动化测试必须证明：操炮态 rope debug state 暴露 `min_world_y`，并且 rope 最低点不会低于两端较低端点 `0.45m` 以上的容忍线，防止父级缩放把 rope 拉成贴地怪线。
6. 自动化测试必须证明：受影响 focused tests 与项目解析检查 fresh 通过。

## Files

- Update: `docs/prd/PRD-0029-artillery-howitzer-scene-foundation.md`
- Create: `docs/ecn/ECN-0032-artillery-interaction-radius-and-lanyard-curve.md`
- Create: `docs/plans/2026-03-24-v48-artillery-interaction-polish-design.md`
- Create: `docs/plan/v48-index.md`
- Create: `docs/plan/v48-artillery-interaction-polish.md`
- Update: `tests/world/test_city_m777_howitzer_scene_contract.gd`
- Update: `tests/world/test_city_m777_howitzer_lab_interaction_contract.gd`
- Update: `tests/world/test_city_m777_howitzer_fire_contract.gd`
- Update: `city_game/scenes/labs/M777HowitzerLab.gd`
- Update: `city_game/combat/artillery/CityM777Howitzer.tscn`
- Update: `city_game/combat/artillery/CityM777Howitzer.gd`
- Create: `city_game/combat/artillery/CityArtilleryLanyardLine.gd`
- Create: `docs/plan/v48-m2-verification-2026-03-24.md`

## Steps

1. Analysis / Doc Freeze
   - 冻结 `7.0m` enter radius、`20.0m` retention 与 artillery rope curve contract。
2. TDD Red
   - 先扩 focused tests：
     - `test_city_m777_howitzer_scene_contract.gd`
     - `test_city_m777_howitzer_lab_interaction_contract.gd`
   - 预期第一轮红灯原因：
     - lab 仍是 `5m`
     - `LanyardLine` 仍绑定 `FishingLineVisual.gd`
     - rope debug state 还没有 `sample_count` / `min_world_y`
3. TDD Green
   - 实现 `7m` radius；
   - 新增 artillery rope curve script；
   - 让 howitzer runtime 暴露新的 rope debug state。
4. Refactor
   - 收口 rope visual 的 debug state 和世界空间采样逻辑，避免 howitzer runtime 继续知道过多渲染细节。
5. Verification
   - 跑 focused tests 与解析检查；
   - 回填 `v48-m2-verification-2026-03-24.md`。

## Risks

- 如果继续复用 fishing rope visual，howitzer 后续任何 rope 调整都还会被 unrelated minigame 约束住。
- 如果 rope sag 仍在 local-space 里直接计算，父级缩放一变，视觉又会再次坏掉。
- 如果只改半径不补测试和文档，未来很容易再次回退到 `5m`。

# V46 Artillery Lab Operation Interaction

## Goal

把 `M777HowitzerLab` 的操炮输入从“进场即全局 `J/L/I/K`”改成“近距 `E` 进入操炮态后才拥有输入所有权”的正式交互链，并明确操炮态提示可见与 `5m` 进入 / `20m` 脱离的双半径合同。

## Dependencies

- 火炮 lab：
  - `res://city_game/scenes/labs/M777HowitzerLab.tscn`
  - `res://city_game/scenes/labs/M777HowitzerLab.gd`
- 火炮 runtime：
  - `res://city_game/combat/artillery/CityM777Howitzer.tscn`
  - `res://city_game/combat/artillery/CityM777Howitzer.gd`
- 共享 HUD prompt contract：
  - `res://city_game/ui/PrototypeHud.gd`

## Contract Freeze

- 交互半径：
  - `5.0m`
- 操炮保活半径：
  - `20.0m`
- 近距 prompt：
  - `按 E 操作炮`
- 操炮态提示：
  - `按 E 退出操炮  J/L 方位  I/K 高低  R 复位`
- 操炮态切换：
  - `E` 进入
  - `E` 退出
- 键位 gating：
  - 仅操炮态激活时允许 `J/L/I/K`

## PRD Trace

- `REQ-0029-007`

## Scope

做什么：

- 给 `M777HowitzerLab` 增加 howitzer 近距检测与操炮态状态机
- 让 `Hud` 复用 `PrototypeHud` 的 interaction prompt contract
- 让操炮态下的 HUD prompt 切换为持续可见的控制提示
- 让 `J/L/I/K` 只在操炮态激活时驱动 howitzer
- 补 focused contract test 与 verification 文档

不做什么：

- 不改 howitzer scene 本体的 yaw / pitch API 口径
- 不实现火炮绝对 bearing HUD
- 不实现主世界 artillery interaction
- 不实现开火、弹道、后坐或装填

## Acceptance

1. 自动化测试必须证明：玩家出生在交互半径外时，HUD prompt 默认隐藏。
2. 自动化测试必须证明：玩家进入 howitzer `5m` 交互半径后，HUD 出现 `按 E 操作炮`。
3. 自动化测试必须证明：未进入操炮态前，`J/L/I/K` 不会改变火炮 yaw / pitch。
4. 自动化测试必须证明：按下 `E` 后进入操炮态，HUD 会切换成持续可见的 `按 E 退出操炮  J/L 方位  I/K 高低  R 复位` 控制提示。
5. 自动化测试必须证明：进入操炮态后，`J/L` 能改变 yaw，`I/K` 能改变 pitch。
6. 自动化测试必须证明：玩家离开 `5m` 进入半径但仍处于约 `20m` 保活半径内时，操炮态不会被误释放。
7. 自动化测试必须证明：再次按下 `E` 后可手动退出操炮态；或者离炮超过约 `20m` 后会自动退出操炮态。
8. 自动化测试必须证明：退出操炮态后，`J/L/I/K` 立即重新失效。
9. 自动化测试必须证明：lab 的 prompt introspection 走的是 `PrototypeHud.get_interaction_prompt_state()`，而不是额外一套 lab-only HUD 协议。

## Files

- Update: `docs/prd/PRD-0029-artillery-howitzer-scene-foundation.md`
- Create: `docs/ecn/ECN-0030-artillery-lab-operation-interaction.md`
- Create: `docs/plans/2026-03-24-v46-artillery-lab-operation-interaction-design.md`
- Create: `docs/plan/v46-index.md`
- Create: `docs/plan/v46-artillery-lab-operation-interaction.md`
- Update: `city_game/scenes/labs/M777HowitzerLab.gd`
- Update: `city_game/scenes/labs/M777HowitzerLab.tscn`
- Create: `tests/world/test_city_m777_howitzer_lab_interaction_contract.gd`
- Create: `docs/plan/v46-m2-verification-2026-03-24.md`

## Steps

1. Analysis / Doc Freeze
   - 冻结 5m 进入半径、20m 保活半径、`E` prompt、操炮态提示与非目标边界。
2. TDD Red
   - 先写 `test_city_m777_howitzer_lab_interaction_contract.gd`。
   - 预期第一轮红灯原因：
     - lab 尚未暴露 `request_primary_interaction()`
     - lab 尚未暴露 `get_operation_state()`
     - `J/L/I/K` 仍是全局热键
     - `Hud` 还未暴露共享 prompt introspection
3. TDD Green
   - 给 lab 接上 `PrototypeHud` prompt contract；
   - 实现 howitzer 双半径判定、`E` 进入/退出、操炮态 prompt 与 `J/L/I/K` gating。
4. Refactor
   - 收口 lab 内的 prompt state、operation state 与 status/debug 输出，避免散落在多处。
5. Verification
   - focused tests 全绿；
   - 补 `v46-m2-verification-2026-03-24.md` closeout 证据。

## Risks

- 如果 prompt 仍然是 lab-only 文本节点，未来接主世界时会再次分叉。
- 如果 `J/L/I/K` 只靠 UI 提示“约束”，没有真正做输入 gating，后续主世界接入时还会回到全局热键污染。
- 如果把 yaw 语义和这轮输入所有权问题绑在一起，会把一个小而清晰的交互改动重新膨胀成未收口的大设计。

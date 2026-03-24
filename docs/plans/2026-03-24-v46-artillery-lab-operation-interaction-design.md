# 2026-03-24 V46 Artillery Lab Operation Interaction Design

## Context

`v44` 已经把 `M777` 的包装 scene、锚点与 yaw / pitch runtime API 收住了，但 `lab` 的输入仍然是“进场即全局 `J/L/I/K`”。这不符合主世界现有的交互模式，也会在未来接入主世界时直接制造热键污染。

## Decision

本轮只做一件事：把 `lab` 的操炮输入收口为上下文交互。

- 玩家接近火炮约 `5m` 时，复用主世界 HUD prompt contract，显示 `按 E 操作炮`；
- 按下 `E` 进入操炮态，再次按下 `E` 可手动退出；
- 进入操炮态后，HUD 持续显示 `按 E 退出操炮  J/L 方位  I/K 高低  R 复位`；
- 只有操炮态激活时，`J/L/I/K` 才驱动火炮；
- 操炮态采用双半径：`5m` 进入、约 `20m` 才自动脱离；
- howitzer 本体 API 不改口径，继续保留 `set_yaw_degrees()` / `set_pitch_degrees()`；
- 绝对 bearing、火炮零位、远距火控解算留给后续单独版本，不与这轮输入所有权问题混做一团。

## Rationale

这个切法有三个好处：

1. 不污染 `v44` 的 howitzer foundation contract。火炮 scene 仍然只负责机械层与角度 API，输入所有权放在 `lab` 层处理。
2. 复用主世界已有的 prompt 协议和 `PrototypeHud`，不再造第三套 lab-only 提示系统。
3. 把“输入上下文”和“射击语义”解耦。这样本轮只验证 `E` 进入/退出与 `J/L/I/K` gating，后续再专门脑暴“相对回转角 vs 世界 bearing vs 炮击流程”。

## Non-Goals

- 不锁定玩家移动或相机；
- 不实现主世界 howitzer 交互；
- 不实现绝对方位角显示、射向/射距解算、装药、火控或弹道。

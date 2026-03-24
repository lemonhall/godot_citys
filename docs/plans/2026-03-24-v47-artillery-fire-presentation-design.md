# V47 Artillery Fire Presentation Design

## Context

`v44-v46` 已经把 M777 的 scene wrapper、轴心校准、射界限制、lab 交互与 compass 全部收口，但 howitzer 仍然停留在“能调角但不能正式开火”的状态。用户已经把本轮目标冻结得很清楚：要逼真的 fire feedback，但不要硬核火控；开火键是 `Space`；玩家在操炮态内仍可自由移动，只要不离炮约 `20m` 以上就保持操作权；必须有拉火绳、炮口火光、烟尘和音效；暂时不做炮弹实体、弹道、落点或爆炸。

## Recommended Approach

继续沿正式 runtime 真源推进，而不是在 `M777HowitzerLab` 里拼一套私有特效。具体做法是把 fire presentation 直接 author 到 `CityM777Howitzer.tscn`：新增 `MuzzleFxAnchor` 与 `LanyardAnchor` 两枚锚点、`FirePresentationRoot` 下的火光/烟尘/拉火绳/音频节点，以及 `CityM777Howitzer.gd` 的 fire state machine。这样 lab 只负责“什么时候允许请求 fire”，而火炮本体负责“accepted fire 以后出现什么反馈”。后续即便接到主世界、任务系统或更复杂的火控 UI，也仍然复用这一条正式 howitzer contract，不会再把演出逻辑散落在 lab、本体、主世界三处。

## Fire Runtime Contract

正式 fire API 冻结为三件事：

- `can_fire()`
- `request_fire()`
- `get_fire_state()`

`request_fire()` 只有在 cooldown 为 `0` 时才 accepted；accepted 后立刻进入 `6.0s` 冷却，并激活五类反馈：火光、烟尘、拉火绳张紧、轻微后坐、weapon fire audio。冷却期间再次请求必须明确返回 rejected，而不是“重复播一次特效”。为了防止偷换概念，演出节点全部预先 author 在 scene 中，fire 期间只更新可见性、材质参数、缩放与位移，不动态生成 projectile/grenade/missile 节点。

## Lab Integration

`M777HowitzerLab` 不新增第二套 fire runtime，只做 howitzer fire 的输入门禁与 HUD 呈现。未进入操炮态时，`Space` 不生效；按下 `E` 进入操炮态后，HUD prompt 更新为 `J/L`、`I/K`、`Space` 与 `E` 的完整提示。冷却显示采用用户确认的 A 方案：冷却中显示 `装填中 X.Xs...`，冷却结束显示 `可击发`。由于用户明确要求“仍可自由移动”，本轮不锁玩家位置，只沿用 `v46` 的 `20m` 自动脱离规则。

## Testing Strategy

测试分成两层：

1. howitzer fire contract
   - scene 必须 author fire anchors / fire presentation nodes / fire audio；
   - `request_fire()` accepted 后进入 `6s` 冷却并激活所有演出 state；
   - cooldown 中再次请求被拒绝；
   - fire 期间不新增 projectile/grenade/missile 节点。
2. lab fire interaction
   - 未进入操炮态时，`Space` 不触发 fire；
   - 进入操炮态后，`Space` 触发 howitzer fire；
   - HUD 可见 `Space` 提示、`装填中 X.Xs...` 与 `可击发`；
   - 离炮超过 `20m` 后自动脱离，`Space` 再次失效。

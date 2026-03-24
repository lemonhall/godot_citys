# V49 Artillery Fire Cooldown Retune Design

## Context

howitzer 的 fire presentation 已经具备正式 contract，但默认 `6.0s` cooldown 明显更偏“写实占位”，而不是当前 lab 阶段真正需要的手感。用户给的目标很直接，就是把“打得不爽”的 6 秒改短。由于本轮不做弹道、不做装填动画、不做复杂乘员流程，所以这里没有必要发明额外的二段装填状态或更复杂的热管理模型。

## Recommended Approach

直接把正式 howitzer runtime 的默认 `fire_cooldown_sec` 从 `6.0` 调到 `2.0`，保持 `request_fire()`、`get_fire_state()`、HUD 文案和 rejected fire 语义全部不变。这是最小变更，也最符合当前阶段目标。测试只需要把 focused contract 的默认 cooldown 期望同步到 `2.0s`，不需要改 lab 那条已经用 `SHORT_TEST_COOLDOWN_SEC=0.25` 加速的 interaction test，因为它测试的是 fire ownership 和 HUD 切换，不是默认配置值。

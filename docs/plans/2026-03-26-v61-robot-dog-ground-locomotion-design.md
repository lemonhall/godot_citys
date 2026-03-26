# 2026-03-26 V61 Robot Dog Ground Locomotion Design

## 背景

`v60` 已经把机械狗最危险的底层合同冻结下来了：8 个关节只绕 local `Z` 轴、`P` 键爬下/起身成立、腿部 visual pivot 不再被 runtime 抹掉。下一步如果直接冲 `pounce / jump / attack`，复杂度会立刻跃迁到“空中态 + 落地态 + 攻击判定”这一层，风险不对等。

所以 `v61` 只收地面 locomotion，并且顺手把玩家输入冲突问题一起解决掉。当前冻结语义是：小键盘 `4` 正式负责机械狗召唤/回收；召唤成功后，镜头和控制权立刻切到机械狗第三人称；再次按下小键盘 `4`，控制权回到 `Player`，机械狗消失。

## 方案比较

### 方案 A：先做“召唤/回收 + 第三人称接管 + 地面 locomotion”

推荐方案。

分层会很清楚：

- `CityPrototype`：世界级召唤/回收 wrapper
- `RobotDogControlRuntime`：输入所有权、镜头接管、player freeze
- `CityRobotDog.gd`：locomotion state + gait/pose 驱动

优点：

- 先把“谁在响应输入”这件事冻结；
- 后续 `v62` 做扑击和跳跃时，不需要再回头重写控制语义；
- 机械狗和无人机/火炮一样，都有一个正式的小键盘召唤位。

### 方案 B：继续只在 lab 里做 locomotion

不推荐。

- 只能回避主世界的输入冲突，不能解决它；
- 后续接主世界时还要重做一遍控制权切换。

### 方案 C：直接把扑击/跳跃一起并进 `v61`

拒绝。

- 这会把地面 gait、空中态、攻击判定混成一个版本；
- 一旦动作发飘，很难分清是 locomotion 还是 airborne/attack 的锅。

## 决策冻结

- 小键盘 `4` 是机械狗正式召唤/回收热键。
- 召唤时，机械狗出生在 `Player` 前方约 `2m`，朝向与 `Player` 一致。
- 召唤成功后，镜头切到机械狗第三人称。
- 机械狗控制态下，`W/A/S/D/Shift/P` 只归机械狗消费。
- `Player` 在机械狗控制态下原地冻结。
- `v61` 只做地面态：`idle / walk / run / backward / turn / prone`。
- `pounce / jump / landing / attack` 全部进入 `v62`。

## 拟定实现结构

- `CityPrototype.gd`
  - 新增小键盘 `4` 热键消费
  - 新增机械狗召唤/回收 wrapper
  - 新增镜头/输入所有权接管
- `CityRobotDog.gd`
  - 从 `v60` pose runtime 扩展到 ground locomotion state machine
  - 保持 joint/pivot 合同不回退
- `RobotDogLab.gd`
  - 对齐正式控制态，避免 lab-only 私有热键分叉

必要时新增：

- `city_game/world/creatures/quadrupeds/CityRobotDogControlRuntime.gd`

## 测试冻结

最少四类：

1. `world summon toggle contract`
   - 锁小键盘 `4` 正式召唤/回收
2. `camera takeover contract`
   - 锁第三人称接管、player freeze、输入所有权切换
3. `ground locomotion contract`
   - 锁 `idle / walk / run / backward / turn / prone`
4. `lab parity contract`
   - 锁 `RobotDogLab` 不会分叉出另一套控制逻辑

## 风险

- 如果 `Player` freeze 做得不彻底，会出现玩家和机械狗一起响应该组热键的双写 bug。
- 如果 `walk/run` 只是根节点滑行，视觉上会立刻暴露，不满足地面 locomotion 的真实性要求。
- 如果 `RobotDogLab` 不跟正式控制态对齐，后面调试会再次回到“两套主链”的旧坑里。

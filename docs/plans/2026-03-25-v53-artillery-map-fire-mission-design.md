# 2026-03-25 V53 Artillery Map Fire Mission Design

## 背景

`v52` 已经让 howitzer 拥有 formal solver，但它仍然更像“系统能力”，还不是玩家能直接执行的玩法。用户这轮要的不是新一层孤立 UI，而是一条完整炮兵闭环：在 full map 右键选目标，选择 `炮击标记`，立刻看到 bearing / pitch；随后玩家按自己想到的办法记下参数，召唤 howitzer，手动拨炮，按 `Space` 击发；最后镜头切到目标区看爆炸。

关键不是“地图上多一个黄叉”，而是三条主链要共线：

1. 地图上的 marker / solution 必须吃 `v52` 的 shared ballistic solver；
2. 召唤 howitzer 时必须尽量保住地图阶段那份 solution 的有效性；
3. 击发后的观察镜头必须复用已有 shell + chunk prewarm，而不是做一个假爆炸旁路。

## 方案对比

### 方案 A：地图只做显示，howitzer 继续完全独立

优点：

- 地图改动最少。

缺点：

- 地图抄下来的 solution 很容易因为 summon 位置漂移而失效；
- 玩家会立刻感知到“地图算的是一套，炮打的是另一套”；
- 观察 closeout 也没有稳定真源。

### 方案 B：单个 active fire mission + planned battery snapshot + observer closeout

优点：

- map / summon / fire / observer 四段是同一条主链；
- 只维护一个 active mission，范围收敛，验证简单；
- free fire 仍然保留，不被任务系统绑定。

缺点：

- 需要给 `CityPrototype` 增加一条新的 artillery runtime 接线；
- 需要在 full map 内补右键上下文菜单。

### 方案 C：直接做多目标炮兵任务板

优点：

- 未来扩展空间大。

缺点：

- 明显超出用户当前范围；
- 很快会滑向任务系统 / battery roster / 多 marker 调度，返工风险高。

## 冻结结论

采用 **方案 B**。

## 设计冻结

### 1. 单个 active fire mission

- full map 右键只提供 `炮击标记` 一个正式动作；
- 只允许一个 active fire mission；
- marker 进入统一 pin 栈，视觉冻结为黄色 cross；
- map render state 同时暴露：
  - context menu
  - active fire mission
  - solution state

### 2. Shared solver，不再另起一套“地图火控”

- map 直接调用 `CityArtilleryBallistics.solve_firing_solution_to_target()`；
- 如果当前已有 active world howitzer，就用它的 platform origin；
- 如果当前还没有 howitzer，就冻结一个与 `KP_8` summon 共线的 planned battery snapshot；
- 这样“先地图记诸元，再召唤火炮”仍然成立。

### 3. Observation closeout

- accepted fire 后，runtime 立刻根据 actual firing solution 预测理论 impact；
- 用 `prewarm_actor_pages()` + `prewarm_chunk_pages()` 预热目标 chunk 环；
- 先保留 howitzer 炮口演出和短暂飞行等待，再切到 impact observer camera；
- shell 仍然按原本 runtime 飞行，observer 只是切镜，不是造假爆炸；
- closeout 完成后恢复玩家 camera ownership。

## 验证策略

- map contract：
  - right-click menu
  - single active marker
  - solver presentation / out-of-range reason
- world contract：
  - planned battery snapshot 能影响 `KP_8` summon
  - accepted fire 启动 observer closeout
  - free fire 也有 closeout
- e2e：
  - `打开 full map -> 右键炮击标记 -> 关闭地图 -> KP_8 -> 操炮 -> Space -> observer impact`

# 2026-03-26 V57 Drone Squadron Strike Orders Design

## 背景

`v56` 已经把机群的“召唤 / 回收 / 不挤在一块”做成了正式合同，但攻击语义还停留在单机时代：FPV ADS 下右键开镜，左键永远是长机自己去自爆，随后固定播放 `NO SIGNAL`。这和当前机群玩法不匹配，因为一旦有多架无人机，用户更自然的心智模型是：

- 长机负责观察、瞄准和下令
- 僚机负责消耗
- 只有真正只剩最后一架长机时，才轮到长机自己去送

同时，用户还要一条更像“命令链”的面域打击：中键不是让所有僚机同时砸向同一个点，而是让它们围绕准星区域，以 `1 -> 2 -> 3` 的批次、带时间间隔地阶梯式冲锋。

## 方案比较

### 方案 A：长机保留输入/相机 owner，squadron manager 负责把攻击命令派发给僚机

推荐方案。

- 长机 runtime 继续负责：
  - FPV/ADS
  - 准星取点
  - leader-only 自爆后备链
- squadron manager 新增：
  - 单架僚机 strike dispatch
  - area strike wave queue
  - 僚机 attrition 记账
- wingman node 从“纯跟随可视物”升级为“可跟随、可冲锋、可爆炸、可报销”的轻量战斗节点

优点：

- 不会把长机 runtime 重新膨胀成机群总控巨石
- 现有 leader-only kamikaze / `NO SIGNAL` 旧链可以原样保留为 fallback
- 中键 area strike 也自然归到 squadron manager，而不是塞进 leader runtime 的局部 if/else

### 方案 B：把所有僚机都升级成完整 `CityPlayerDroneRuntime`

拒绝。

- 每架都带 camera / input / player lock / signal loss 语义，owner 冲突风险太高
- area strike 波次调度会落成“若干 full runtime 的并发 orchestration”，复杂度过大

## 决策冻结

- `MOUSE_BUTTON_LEFT + FPV ADS`
  - `active wingman count >= 1`：
    - 只派 1 架可用僚机去自杀冲锋
    - 长机不进入 `strike_committed`
    - 长机不进入 `signal_loss`
  - `active wingman count == 0`：
    - 回退到当前 leader kamikaze + `NO SIGNAL`
- `MOUSE_BUTTON_MIDDLE + FPV ADS`
  - 下达 area strike 命令
  - 中心点为当前准星冻结点
  - 散布半径：`12m`
  - 波次规模：`1 -> 2 -> 3` 循环
  - 批次间隔：`0.6s`
- area strike 只消费当前可用僚机；长机永不自动并入批次

## 实现落点

### 输入层

`CityPlayerDroneRuntime.gd`

- 继续作为鼠标输入 owner
- 在 FPV ADS 的 `left/middle click` 分支里，先把攻击命令委托给 squadron runtime
- 只有 squadron runtime 明确表示“没有可用僚机可派”时，左键才回退到 leader 自爆旧链

### Squadron Orchestrator

`CityPlayerDroneSquadronRuntime.gd`

- 新增：
  - 单架僚机 dispatch API
  - area strike queue
  - wave timer
  - attrition bookkeeping
  - debug strike events
- manager 继续是真正的：
  - wingman lifecycle owner
  - desired/active squad accounting owner
  - area strike schedule owner

### Wingman Runtime

`CityPlayerDroneWingman.gd`

- 从纯跟随节点扩展为轻量状态机：
  - `formation`
  - `striking`
  - `exploding`
  - `spent`
- 复用长机 strike profile 的速度 / impact / explosion 半径口径
- 不拥有 camera / input / FPV / signal loss

## 数据与调试

为保证 `v57` 可测，squadron debug state 需要新增：

- `available_wingman_count`
- `striking_wingman_count`
- `pending_area_assignment_count`
- `wingman_states`
- `recent_strike_events`
  - 至少包含：
    - `order_kind`
    - `wingman_slot_index`
    - `dispatch_time_sec`
    - `wave_index`
    - `target_world_position`

这样测试可以直接卡住：

- 左键到底是不是派了僚机
- 中键到底是不是按 `1 -> 2 -> 3` 波次派发
- 多架是不是打到了不同落点

## 测试策略

### Focused Contract

- 新增 `test_city_player_drone_squadron_single_strike_dispatch_contract.gd`
  - 有僚机时左键不再让长机自爆
  - 只派 1 架僚机
  - 长机不播 `NO SIGNAL`
  - 只剩长机时回退 leader old chain
- 新增 `test_city_player_drone_squadron_area_strike_command_contract.gd`
  - 中键 area strike 会产生不同落点
  - dispatch 波次遵循 `1 -> 2 -> 3`
  - 批次间隔不少于 `0.6s`

### E2E

- 新增 `test_city_player_drone_squadron_strike_flow.gd`
  - 玩家放飞机群
  - 左键先派单架僚机
  - 再用中键下 area strike
  - 长机全程保留观察位

### 旧链回归

- `test_city_player_drone_suicide_strike_contract.gd`
  - 继续验证 leader-only fallback
- `test_city_player_drone_kamikaze_flow.gd`
  - 继续验证 leader-only `NO SIGNAL` 旧链
- `test_city_player_drone_squadron_summon_contract.gd`
  - 确保 strike attrition 不会把机群计数搞乱

## 风险

- 如果 wingman strike 只做位置瞬移，不做真实飞行/爆炸，会把整条命令链做成空壳。
- 如果 area strike 不暴露 dispatch 事件，测试很难稳定证明“确实按波次、按间隔”发生。
- 如果左键在“有僚机但全忙”时偷偷回退 leader 自爆，玩家会觉得长机行为不可预期；当前版本更稳的口径是：有可用僚机就派僚机，没有可用僚机且只剩长机才回退 leader。

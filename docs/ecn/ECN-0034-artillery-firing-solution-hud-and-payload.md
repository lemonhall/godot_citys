# ECN-0034: Artillery Firing Solution HUD And Payload

## 基本信息

- **ECN 编号**：ECN-0034
- **关联 PRD**：PRD-0029
- **关联 Req ID**：
  - `REQ-0029-009`
  - `REQ-0029-010`
- **发现阶段**：v49 closeout 后的 howitzer 下一轮范围冻结
- **日期**：2026-03-24

## 变更原因

`v44-v49` 已经把 howitzer scene、交互、compass、fire presentation 与 cooldown 全部收口到“能调、能打、能看”的阶段，但仍缺两条后续一定会复用的正式基础设施：

1. 玩家进入操炮态后，仍然缺少一组直接可用的射击诸元 HUD；目前只有 world compass 和 debug text，不足以支持“逼真但不硬核”的操炮体验。
2. `request_fire()` 虽然已经能驱动正式开火演出，但开火瞬间并没有留下结构化 firing solution payload；后续一旦要接 projectile、弹道学、落点、弹种、反炮兵或战斗回放，就没有正式输入可复用。

用户已经明确冻结了下一步目标：HUD 里的 `yaw` 不让玩家自己换算，直接显示炮口世界 bearing；`pitch` 继续使用现有真实仰角语义；同时把 firing solution 正式落成 payload contract，但这轮仍然不做弹道和落点演出。

## 变更内容

### 原设计

- howitzer HUD 只覆盖 world compass、交互 prompt 和 fire readiness 文案
- `request_fire()` 不暴露正式 firing solution payload
- PRD 仍把火控相关能力整体放在 non-goals，没有细分“这轮允许做 formal snapshot contract，但不做 ballistic solver”

### 新设计

- 新增正式 `REQ-0029-009 Artillery Firing Solution HUD Contract`
  - HUD 真源挂在 `PrototypeHud`
  - 只在 howitzer 操炮态显示
  - 直接向玩家显示炮口世界 bearing 与当前 pitch
  - 视觉语言复用现有 compass strip 家族
- 新增正式 `REQ-0029-010 Firing Solution Payload Contract`
  - `CityM777Howitzer` 暴露 firing solution snapshot / last fired solution API
  - accepted `request_fire()` 返回并存档本次 shot 的正式 payload
  - payload 至少包含 world origin、chunk metadata、world bearing、pitch、shell type、muzzle velocity 与 muzzle direction
- 明确边界：
  - 这轮不生成 projectile
  - 不做弹道积分、落点、爆炸或反炮兵逻辑
  - 只把未来一定会复用的数据 contract 与 HUD consumer 先立住

## 影响范围

- 受影响的 Req ID：
  - `REQ-0029-009`
  - `REQ-0029-010`
- 受影响的 vN 计划：
  - `docs/plan/v50-index.md`
  - `docs/plan/v50-artillery-firing-solution-hud.md`
- 受影响的测试：
  - `tests/world/test_city_artillery_solution_hud_contract.gd`
  - `tests/world/test_city_m777_howitzer_firing_solution_contract.gd`
  - `tests/world/test_city_m777_howitzer_lab_artillery_solution_contract.gd`
- 受影响的代码文件：
  - `city_game/ui/PrototypeHud.gd`
  - `city_game/ui/CityArtillerySolutionHud.gd`
  - `city_game/combat/artillery/CityM777Howitzer.gd`
  - `city_game/scenes/labs/M777HowitzerLab.gd`

## 处置方式

- [x] PRD 已同步更新
- [x] v50 计划已同步更新
- [x] 追溯矩阵已同步更新
- [x] 相关测试已同步更新

# ECN-0035: World Howitzer Summon And Ballistics

## 基本信息

- **ECN 编号**：ECN-0035
- **关联 PRD**：PRD-0029
- **关联 Req ID**：
  - `REQ-0029-011`
  - `REQ-0029-012`
  - `REQ-0029-013`
- **发现阶段**：v50 closeout 后的 howitzer 下一轮范围冻结
- **日期**：2026-03-24

## 变更原因

`v44-v50` 已经把 howitzer 的 scene 包装、lab 操炮、开火演出、world bearing HUD 与 firing solution payload 合同全部收口，但这些能力仍停留在“作者调试与近距演示”阶段。用户已经明确把下一轮目标收紧为：

1. howitzer 必须接入主世界，而不是继续停留在 lab；
2. 按下 `KP_8` 后，玩家前方要能直接召唤一门正式 `M777`；
3. 主世界里的操炮交互、HUD、火绳与 ownership 体验必须和 lab 共线；
4. 主世界里必须真正生成炮弹实体并做正式弹道学、飞行与落点，否则 howitzer 仍然只有“空响”没有体感。

这意味着 PRD 不能再把“主世界 howitzer 接入”和“projectile 级弹道”继续放在非目标里，而是要正式补齐：

- 主世界召唤与唯一实例 contract；
- lab / main-world 共线的 howitzer operation runtime；
- 正式 artillery shell ballistic runtime 与落点爆炸 contract。

## 变更内容

### 原设计

- PRD 只冻结了 lab 操炮、fire presentation、artillery solution HUD 与 payload snapshot；
- 主世界仍没有 howitzer summon / operation / shell ballistic 主链；
- 之前的 non-goals 明确排除了 projectile、弹道、落点与爆炸。

### 新设计

- 新增正式 `REQ-0029-011 Main-World Howitzer Summon Contract`
  - 主世界按 `KP_8` 直接在玩家前方召唤 howitzer；
  - 同一时刻只允许存在一门当前召唤 howitzer；
  - 重复召唤会重建/重定位当前实例，而不是无限堆炮。
- 新增正式 `REQ-0029-012 Shared Howitzer Operation Runtime Contract`
  - lab 与主世界必须共用同一条 howitzer operation controller；
  - `E`、`J/L`、`I/K`、`Space`、prompt、artillery solution HUD 与 20m retention 语义保持一致；
  - howitzer 交互不能在主世界再写一套私有逻辑。
- 新增正式 `REQ-0029-013 Artillery Shell Ballistics Contract`
  - accepted fire 会在主世界生成 formal artillery shell runtime；
  - shell 使用 firing solution payload 作为唯一真源，按重力积分飞行；
  - impact 会给出正式 explosion result，并接入主世界的行人/车辆/建筑/敌对目标爆炸消费链；
  - 为了保持“逼真但不硬核”的体验，允许 shell flight 使用显式的 gameplay time-compression，但不允许把 shell 偷换成 grenade / missile。

## 影响范围

- 受影响的 Req ID：
  - `REQ-0029-011`
  - `REQ-0029-012`
  - `REQ-0029-013`
- 受影响的 vN 计划：
  - `docs/plan/v51-index.md`
  - `docs/plan/v51-world-howitzer-summon-and-ballistics.md`
- 受影响的测试：
  - `tests/world/test_city_world_howitzer_spawn_contract.gd`
  - `tests/world/test_city_world_howitzer_interaction_contract.gd`
  - `tests/world/test_city_world_howitzer_ballistics_contract.gd`
  - `tests/e2e/test_city_world_howitzer_flow.gd`
- 受影响的代码文件：
  - `city_game/combat/artillery/CityM777HowitzerOperationController.gd`
  - `city_game/combat/artillery/CityArtilleryShell.gd`
  - `city_game/scripts/CityPrototype.gd`
  - `city_game/scenes/labs/M777HowitzerLab.gd`

## 处置方式

- [x] PRD 已同步更新
- [x] v51 计划已同步更新
- [x] 追溯矩阵已同步更新
- [x] 相关测试已同步更新

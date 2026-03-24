# V51 World Howitzer Summon And Ballistics

## Goal

把 M777 正式接入主世界：`KP_8` 召唤、shared operation controller 复用、主世界 live shell ballistic flight 与 impact result 全链打通。

## Dependencies

- 正式 howitzer runtime：
  - `res://city_game/combat/artillery/CityM777Howitzer.gd`
  - `res://city_game/combat/artillery/CityM777Howitzer.tscn`
- lab host：
  - `res://city_game/scenes/labs/M777HowitzerLab.gd`
- 主世界入口：
  - `res://city_game/scripts/CityPrototype.gd`
- shared HUD：
  - `res://city_game/ui/PrototypeHud.gd`
- 世界方向语义：
  - `res://city_game/world/navigation/CityWorldOrientation.gd`

## Contract Freeze

- summon：
  - `KP_8`
  - 单实例
- operation controller：
  - `CityM777HowitzerOperationController`
- live shell：
  - `CityArtilleryShell`
- shell 真源：
  - accepted fire `firing_solution`
- explosion consumer：
  - 敌对目标 / 建筑 / 行人 / 车辆

## PRD Trace

- `REQ-0029-011`
- `REQ-0029-012`
- `REQ-0029-013`

## Scope

做什么：

- 在 `CityPrototype` 接入 `KP_8` howitzer summon 与当前实例管理
- 抽共享 `CityM777HowitzerOperationController` 并让 lab / world 共用
- 在主世界 accepted fire 时生成 `CityArtilleryShell`
- 让 shell 正式飞行、impact、回填 explosion result，并接入世界爆炸消费链
- 补 focused tests、至少一条 e2e，以及 verification 文档

不做什么：

- 不做 map pin、task 化、保存持久化
- 不做预测落点 UI、火控解算、目标点选择或完整炮兵诸元面板
- 不做乘员 AI、装填动画、弹种库存与对话系统
- 不把 shell runtime 偷换成 grenade / missile 参数换皮

## Acceptance

1. 自动化测试必须证明：`CityPrototype` 暴露当前 world howitzer 与 artillery shell 相关 getter。
2. 自动化测试必须证明：`KP_8` 会在玩家前方地表生成正式 howitzer，且同时只维护一个当前实例。
3. 自动化测试必须证明：主世界 howitzer 的 prompt / `E` ownership / `J/L` / `I/K` / `Space` / 20m retention 与 lab 共线。
4. 自动化测试必须证明：主世界操炮态会显示 shared artillery solution HUD，退出操炮态后隐藏。
5. 自动化测试必须证明：操炮态下按 `Space` 不会让玩家跳起，且 accepted fire 会增加 howitzer fire count。
6. 自动化测试必须证明：accepted fire 会在主世界生成 live `CityArtilleryShell`，不是 `CityGrenade` / `CityMissile`。
7. 自动化测试必须证明：shell launch payload 直接来源于 howitzer `firing_solution`，并在 runtime 中可读回。
8. 自动化测试必须证明：shell 会按重力飞行并留下 formal explosion result。
9. 自动化测试必须证明：shell impact 会调用主世界爆炸消费链，而不是只画一个孤立特效。
10. 自动化测试必须证明：`KP_8 -> 进入操炮 -> 击发 -> shell impact` 有至少一条自动化 e2e。

## Files

- Update: `docs/prd/PRD-0029-artillery-howitzer-scene-foundation.md`
- Create: `docs/ecn/ECN-0035-world-howitzer-summon-and-ballistics.md`
- Create: `docs/plans/2026-03-24-v51-world-howitzer-summon-and-ballistics-design.md`
- Create: `docs/plan/v51-index.md`
- Create: `docs/plan/v51-world-howitzer-summon-and-ballistics.md`
- Create: `city_game/combat/artillery/CityM777HowitzerOperationController.gd`
- Create: `city_game/combat/artillery/CityArtilleryShell.gd`
- Update: `city_game/scenes/labs/M777HowitzerLab.gd`
- Update: `city_game/scripts/CityPrototype.gd`
- Create: `tests/world/test_city_world_howitzer_spawn_contract.gd`
- Create: `tests/world/test_city_world_howitzer_interaction_contract.gd`
- Create: `tests/world/test_city_world_howitzer_ballistics_contract.gd`
- Create: `tests/e2e/test_city_world_howitzer_flow.gd`
- Create: `docs/plan/v51-m3-verification-2026-03-24.md`

## Steps

1. Analysis / Doc Freeze
   - 冻结 summon、shared controller、shell ballistic 与非目标边界。
2. TDD Red
   - 先写四条 tests：
     - `test_city_world_howitzer_spawn_contract.gd`
     - `test_city_world_howitzer_interaction_contract.gd`
     - `test_city_world_howitzer_ballistics_contract.gd`
     - `test_city_world_howitzer_flow.gd`
3. Run Red
   - 预期第一轮红灯原因：
     - 主世界还没有 howitzer summon；
     - lab / world 还没有 shared controller；
     - 主世界还没有 shell ballistic runtime。
4. TDD Green
   - 实现 shared controller、主世界 summon 与 shell ballistic。
5. Refactor
   - 收口 howitzer HUD / prompt / ownership 口径，避免 lab / world 双标。
6. Verification
   - 跑 focused tests、e2e 与项目解析检查；
   - 回填 `v51-m3-verification-2026-03-24.md`。

## Risks

- 如果 world host 继续自己维护一套 howitzer 状态机，后续调手感一定再次分叉。
- 如果 shell flight 没有 formal time-compression，真实远程高抛 shot 会让玩家等待过长。
- 如果 impact 不接主世界爆炸消费链，howitzer 仍然只会“响一下”，没有主世界后果。

# V43 Drone FPV Kamikaze Strike

## Goal

在 `v42` 已完成的玩家无人机基础之上，新增一条正式的 `右键 FPV/ADS -> 左键锁定 -> 第一视角红外滤镜自杀冲击 -> 爆炸后切回玩家` 玩法链。该功能必须继续沿 `combat/drone` 正式 runtime 与 `CityPrototype` 主世界 wrapper 收口，不能分叉出一套 lab-only 或 projectile-only 的私有旁路。

## Dependencies

- 依赖 `v42` 已存在的：
  - `res://city_game/combat/drone/CityPlayerDroneRuntime.gd`
  - `res://city_game/combat/drone/CityPlayerDroneFlightController.gd`
  - `res://city_game/combat/drone/CityPlayerDroneCameraRig.tscn`
  - `CityPrototype.get_player_drone_debug_state()`
- 依赖 `CityPrototype` 已存在的：
  - `_build_crosshair_state()`
  - `resolve_pedestrian_explosion()`
  - `resolve_vehicle_explosion()`
  - 建筑爆炸解析主链
- 依赖现有玩家链：
  - `PlayerController.trigger_camera_shake()`
  - 玩家控制权与相机 ownership 恢复接口

## Contract Freeze

- 正式 deploy / recover 入口：
  - `KEY_KP_5`
- 正式 FPV/ADS 切换键：
  - `MOUSE_BUTTON_RIGHT`
- 正式锁定 / 提交冲击键：
  - `MOUSE_BUTTON_LEFT`
- 正式 top-level drone system state：
  - `stowed`
  - `deploying`
  - `active`
  - `recovering`
- 正式 view mode：
  - `third_person`
  - `fpv_ads`
- 正式 strike state：
  - `idle`
  - `locked`
  - `striking`
  - `exploding`
- 正式 debug fields：
  - `view_mode`
  - `strike_state`
  - `fpv_filter_enabled`
  - `fpv_crosshair_visible`
  - `fpv_fov_deg`
  - `fpv_pitch_deg`
  - `fpv_yaw_deg`
  - `fpv_crosshair_world_target`
  - `locked_target_world_position`
  - `strike_committed`
- 正式 closeout 语义：
  - 爆炸结束后强制回到 `stowed`
  - 恢复 `player` camera owner
  - 恢复 `player` input owner

## PRD Trace

- `REQ-0028-001`
- `REQ-0028-002`
- `REQ-0028-003`
- `REQ-0028-004`
- `REQ-0028-005`
- `REQ-0028-006`

## Scope

做什么：

- 在无人机 `active` 状态下建立 `FPV/ADS` 第一视角子模式
- 在 `FPV/ADS` 中建立黑白红外滤镜与准星合同
- 在 `FPV/ADS` 中建立鼠标自由视角上下左右观察
- 建立左键锁定当前准星目标点合同
- 建立锁定后不可取消的自杀冲击状态机
- 建立第一视角冲刺、撞击爆炸与玩家恢复 closeout
- 把准星世界目标切回无人机自身视角链，而不是继续复用玩家枪械瞄准链

不做什么：

- 不做常规射击武器、导弹、机炮或持续火力模式
- 不做二次锁定 UI、热目标描边或复杂目标分类
- 不做可取消冲刺、手动中断或半自动返航
- 不做残骸持久化、无人机回收动画变体或坠毁物理模拟
- 不做任务、地图 pin、剧情、录屏或联机同步接入

## Acceptance

1. 自动化测试必须证明：鼠标右键只在无人机 `active` 状态下切换 `fpv_ads`。
2. 自动化测试必须证明：`fpv_ads` 中准星可见，且红外黑白滤镜启用。
3. 自动化测试必须证明：`fpv_ads` 中鼠标可自由控制第一视角上下左右观察，并具备俯仰边界。
4. 自动化测试必须证明：`fpv_ads` 中左键锁定当前准星目标点；若未命中真实几何，也会生成合理的 fallback 目标点。
5. 自动化测试必须证明：锁定成功后进入 `striking`，常规飞行输入失效，且不能再用 `KEY_KP_5` 临时回收取消。
6. 自动化测试必须证明：冲击全过程保持第一视角与红外滤镜，不允许省略过程直接瞬时爆炸。
7. 自动化测试必须证明：爆炸 closeout 后，玩家视角恢复、玩家输入恢复、无人机回到 `stowed`。
8. 自动化测试必须证明：爆炸伤害继续走正式敌人/行人/车辆/建筑解析主链，而不是重新发明一套 lab-only 伤害通道。

## Files

- Create: `docs/prd/PRD-0028-drone-fpv-kamikaze-strike.md`
- Create: `docs/plans/2026-03-24-v43-drone-fpv-kamikaze-strike-design.md`
- Create: `docs/plan/v43-index.md`
- Create: `docs/plan/v43-drone-fpv-kamikaze-strike.md`
- Create: `city_game/combat/drone/shaders/CityDroneFpvInfraredOverlay.gdshader`
- Modify: `city_game/combat/drone/CityDroneGunship.tscn`
- Modify: `city_game/combat/drone/CityPlayerDroneRuntime.gd`
- Modify: `city_game/combat/drone/CityPlayerDroneCameraRig.tscn`
- Modify: `city_game/combat/drone/CityPlayerDroneFlightController.gd`
- Modify: `city_game/scripts/CityPrototype.gd`
- Create: `tests/world/test_city_player_drone_fpv_ads_contract.gd`
- Create: `tests/world/test_city_player_drone_suicide_strike_contract.gd`
- Modify: `tests/world/test_city_drone_gunship_scene_contract.gd`
- Modify: `tests/world/test_city_player_drone_flight_input_contract.gd`
- Modify: `tests/e2e/test_city_player_drone_flow.gd`
- Create: `tests/e2e/test_city_player_drone_kamikaze_flow.gd`
- Create: `docs/plan/v43-m3-verification-2026-03-24.md`

## Steps

1. Analysis / Doc Freeze
   - 冻结 `FPV/ADS`、右键切换、左键锁定、自杀冲击、closeout 与非目标边界。
2. TDD Red
   - 先写 `fpv_ads contract`、`suicide strike contract` 与 `kamikaze e2e flow`。
   - 预期第一轮红灯原因：
     - 无人机 runtime 还没有 `view_mode` / `strike_state`
     - 场景还没有正式 FPV 相机与红外滤镜资源
     - `CityPrototype` 仍沿玩家瞄准链计算准星目标
3. TDD Green
   - 新增正式 FPV overlay shader、视角切换、目标锁定与冲击 closeout。
4. Refactor
   - 保持 `drone-only runtime` 不分叉，把冲击状态机收在正式 runtime 内。
5. E2E
   - 跑完整用户流程：
     - `KEY_KP_5` 放飞
     - 右键进入 `FPV/ADS`
     - 左键锁定目标
     - 第一视角红外滤镜冲刺
     - 爆炸
     - 自动切回 player
6. Review / Closeout
   - 写 fresh verification 文档，回填 `v43` 追溯矩阵与差异列表。

## Risks

- 如果继续复用 `player.get_aim_target_world_position()` 作为无人机 FPV 锁定目标，准星与真实冲击目标会错位。
- 如果把自杀冲击实现成“直接 spawn 一枚导弹”，会破坏用户要的完整第一视角扑击镜头。
- 如果 `FPV/ADS` 与 `striking` 没有正式状态机，很容易出现 `KEY_KP_5` / 鼠标输入在冲刺中泄漏。
- 如果红外滤镜只在锁定瞬间开启而不是全链路维持，会直接削弱玩法叙事感。

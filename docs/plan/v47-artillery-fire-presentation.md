# V47 Artillery Fire Presentation

## Goal

把 M777 从“只能调角”推进到“具备正式开火演出”，并把 `Space` 触发、`6s` 冷却、HUD 冷却文案与 fire runtime 真源全部冻结在正式 howitzer scene / script 上，而不是继续堆 lab 私货。

## Dependencies

- 正式 howitzer runtime：
  - `res://city_game/combat/artillery/CityM777Howitzer.tscn`
  - `res://city_game/combat/artillery/CityM777Howitzer.gd`
- howitzer lab：
  - `res://city_game/scenes/labs/M777HowitzerLab.tscn`
  - `res://city_game/scenes/labs/M777HowitzerLab.gd`
- 共享 HUD：
  - `res://city_game/ui/PrototypeHud.gd`
- 现有 weapon fire audio 资产：
  - `res://city_game/combat/helicopter/audio/rockt-explosions.wav`

## Contract Freeze

- fire request key：
  - `Space`
- fire cooldown：
  - `6.0s`
- accepted fire 演出：
  - muzzle flash
  - muzzle smoke
  - lanyard tension
  - light recoil
  - weapon fire audio
- HUD 状态：
  - `装填中 X.Xs...`
  - `可击发`
- formal fire anchors：
  - `Anchors/MuzzleFxAnchor`
  - `Anchors/LanyardAnchor`

## PRD Trace

- `REQ-0029-008`
- `REQ-0029-007`

## Scope

做什么：

- 给正式 howitzer scene 增加 fire anchors、fire presentation nodes 与 fire audio
- 给正式 howitzer script 增加 `can_fire()`、`request_fire()`、`get_fire_state()`
- 让 accepted fire 驱动冷却、火光、烟尘、拉火绳、后坐与音频
- 让 lab 在操炮态内把 `Space` 路由到正式 howitzer fire API
- 让 lab HUD 明确显示 `Space` 提示、装填中倒计时与可击发状态
- 补 focused tests 与 verification 文档

不做什么：

- 不生成 projectile / grenade / missile
- 不做弹道、落点、爆炸、伤害判定
- 不做炮击 UI 的 bearing 解算
- 不接入主世界 artillery feature、任务、AI 或乘员

## Acceptance

1. 自动化测试必须证明：正式 howitzer scene author 了 `MuzzleFxAnchor` 与 `LanyardAnchor`，并且 fire presentation nodes 存在于正式 runtime hierarchy 中。
2. 自动化测试必须证明：正式 howitzer root 暴露 `can_fire()`、`request_fire()` 与 `get_fire_state()`。
3. 自动化测试必须证明：accepted fire 会触发正式 runtime 的火光、烟尘、拉火绳张紧、轻微后坐与 weapon fire audio。
4. 自动化测试必须证明：accepted fire 后 howitzer 进入默认 `6.0s` 冷却，冷却期间再次 fire 请求被拒绝。
5. 自动化测试必须证明：fire 期间不会新增 projectile / grenade / missile 节点，也不会把“演出”伪装成弹道链。
6. 自动化测试必须证明：lab 中只有进入操炮态后 `Space` 才会触发 howitzer fire；未进入操炮态时 `Space` 不生效。
7. 自动化测试必须证明：进入操炮态后，HUD prompt 明确包含 `Space` 击发提示。
8. 自动化测试必须证明：冷却期间 HUD 明确显示 `装填中 X.Xs...`；冷却结束后明确显示 `可击发`。
9. 自动化测试必须证明：玩家即便在 `20m` 保活半径内自由移动，仍然保有 fire 所有权；离炮超过约 `20m` 后自动退出，`Space` 再次失效。

## Files

- Update: `docs/prd/PRD-0029-artillery-howitzer-scene-foundation.md`
- Create: `docs/ecn/ECN-0031-artillery-fire-presentation.md`
- Create: `docs/plans/2026-03-24-v47-artillery-fire-presentation-design.md`
- Create: `docs/plan/v47-index.md`
- Create: `docs/plan/v47-artillery-fire-presentation.md`
- Update: `city_game/combat/artillery/CityM777Howitzer.tscn`
- Update: `city_game/combat/artillery/CityM777Howitzer.gd`
- Update: `city_game/scenes/labs/M777HowitzerLab.gd`
- Update: `tests/world/test_city_m777_howitzer_scene_contract.gd`
- Update: `tests/world/test_city_m777_howitzer_lab_scene_contract.gd`
- Create: `tests/world/test_city_m777_howitzer_fire_contract.gd`
- Create: `tests/world/test_city_m777_howitzer_lab_fire_interaction_contract.gd`
- Create: `docs/plan/v47-m2-verification-2026-03-24.md`

## Steps

1. Analysis / Doc Freeze
   - 冻结 `Space`、`6.0s`、fire 演出组成、HUD 冷却文案与非目标边界。
2. TDD Red
   - 先写/扩充 focused tests：
     - `test_city_m777_howitzer_scene_contract.gd`
     - `test_city_m777_howitzer_lab_scene_contract.gd`
     - `test_city_m777_howitzer_fire_contract.gd`
     - `test_city_m777_howitzer_lab_fire_interaction_contract.gd`
   - 预期第一轮红灯原因：
     - howitzer scene 还没有 fire anchors / nodes
     - howitzer script 还没有 fire API / cooldown state
     - lab 还没有 `Space` 路由与 HUD 冷却状态
3. TDD Green
   - 实现正式 howitzer fire runtime；
   - 让 lab 把 `Space` 接到正式 howitzer fire API；
   - 补 HUD readiness 文案。
4. Refactor
   - 收口 fire state / debug state / HUD status 拼装，避免 scene、runtime、lab 三边各写一套。
5. Verification
   - focused tests 与项目解析检查 fresh 通过；
   - 回填 `v47-m2-verification-2026-03-24.md`。

## Risks

- 如果 fire 演出继续写在 lab 里，后续接主世界时一定再次分叉。
- 如果 cooldown 只体现在 HUD 文案、而不是正式 howitzer runtime state，后续主世界接入会出现“双重真相”。
- 如果为了“看起来开火了”而偷偷生成 projectile 节点，本轮 scope 会直接失控，并把之后的 fire-control 设计提前绑死。

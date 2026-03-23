# V43 Index

## 愿景

PRD 入口：[PRD-0028 Drone FPV Kamikaze Strike](../prd/PRD-0028-drone-fpv-kamikaze-strike.md)

设计入口：[2026-03-24-v43-drone-fpv-kamikaze-strike-design.md](../plans/2026-03-24-v43-drone-fpv-kamikaze-strike-design.md)

依赖入口：

- [v42-index.md](./v42-index.md)

`v43` 的目标不是把无人机自杀冲击做成一枚换皮导弹，也不是简单地“按左键瞬爆”。它要在 `v42` 正式无人机 foundation 之上，建立一条完整的 `FPV/ADS 攻击链`：无人机保持 `KEY_KP_5` 的放飞/回收主入口不变；在无人机已 `active` 的前提下，鼠标右键切入 `FPV/ADS` 第一视角，画面进入黑白红外滤镜，准星可见，鼠标接管自由视角；玩家在该模式下按下鼠标左键后，系统锁定当前准星目标点，无人机进入不可取消的自杀式冲击，高速第一视角扑向目标并爆炸；爆炸 closeout 完成后，玩家视角与输入权恢复，无人机回到 `stowed`。

## 决策冻结

- 正式 deploy / recover 入口：
  - `KEY_KP_5`
- 正式 FPV/ADS 切换键：
  - `MOUSE_BUTTON_RIGHT`
- 正式锁定 / 提交冲击键：
  - `MOUSE_BUTTON_LEFT`
- 正式 view mode：
  - `third_person`
  - `fpv_ads`
- 正式 strike state：
  - `idle`
  - `locked`
  - `striking`
  - `exploding`
- 正式视觉合同：
  - `fpv_ads` 必须启用黑白红外滤镜
  - `fpv_ads` 必须显示准星
  - `striking` 全程必须保持第一视角与红外滤镜

## 里程碑

| 里程碑 | 范围 | DoD | 验证命令/测试 | 状态 |
|---|---|---|---|---|
| M0 docs freeze | PRD / design / v43 plan 全链冻结 | `FPV/ADS`、右键切换、左键锁定、自杀冲击、closeout 与非目标边界全部落文档 | `rg -n "FPV|ADS|MOUSE_BUTTON_RIGHT|MOUSE_BUTTON_LEFT|striking|infrared|stowed" docs/prd/PRD-0028-drone-fpv-kamikaze-strike.md docs/plan/v43-index.md docs/plan/v43-drone-fpv-kamikaze-strike.md docs/plans/2026-03-24-v43-drone-fpv-kamikaze-strike-design.md` | done |
| M1 fpv view + overlay | 正式 FPV/ADS 视角、准星与红外滤镜 | `active` drone 下右键进入 `fpv_ads`；视角、FOV、准星与滤镜合同成立 | `tests/world/test_city_player_drone_fpv_ads_contract.gd`、`tests/world/test_city_drone_gunship_scene_contract.gd` | pending |
| M2 lock + strike | 左键锁定目标与不可取消冲刺 | `fpv_ads` 下左键锁定准星目标点；进入 `striking`；手动输入失效；保持第一视角扑击 | `tests/world/test_city_player_drone_suicide_strike_contract.gd` | pending |
| M3 explosion + restore | 爆炸伤害 closeout 与玩家恢复 | 爆炸后恢复 player camera/input；无人机回到 `stowed`；主世界爆炸解析链成立 | `tests/e2e/test_city_player_drone_kamikaze_flow.gd`、`docs/plan/v43-m3-verification-2026-03-24.md` | pending |

## 计划索引

- [v43-drone-fpv-kamikaze-strike.md](./v43-drone-fpv-kamikaze-strike.md)

## 追溯矩阵

| Req ID | V43 Plan | 单元/集成测试 | E2E / 验证命令 | 证据 | 状态 |
|---|---|---|---|---|---|
| REQ-0028-001 | `v43-drone-fpv-kamikaze-strike.md` | `tests/world/test_city_player_drone_fpv_ads_contract.gd` | `docs/plan/v43-m3-verification-2026-03-24.md` | `docs/plan/v43-m3-verification-2026-03-24.md` | pending |
| REQ-0028-002 | `v43-drone-fpv-kamikaze-strike.md` | `tests/world/test_city_drone_gunship_scene_contract.gd` | `docs/plan/v43-m3-verification-2026-03-24.md` | `docs/plan/v43-m3-verification-2026-03-24.md` | pending |
| REQ-0028-003 | `v43-drone-fpv-kamikaze-strike.md` | `tests/world/test_city_player_drone_fpv_ads_contract.gd` | `docs/plan/v43-m3-verification-2026-03-24.md` | `docs/plan/v43-m3-verification-2026-03-24.md` | pending |
| REQ-0028-004 | `v43-drone-fpv-kamikaze-strike.md` | `tests/world/test_city_player_drone_suicide_strike_contract.gd` | `docs/plan/v43-m3-verification-2026-03-24.md` | `docs/plan/v43-m3-verification-2026-03-24.md` | pending |
| REQ-0028-005 | `v43-drone-fpv-kamikaze-strike.md` | `tests/world/test_city_player_drone_suicide_strike_contract.gd` | `tests/e2e/test_city_player_drone_kamikaze_flow.gd` | `docs/plan/v43-m3-verification-2026-03-24.md` | pending |
| REQ-0028-006 | `v43-drone-fpv-kamikaze-strike.md` | `tests/world/test_city_player_drone_suicide_strike_contract.gd` | `tests/e2e/test_city_player_drone_kamikaze_flow.gd` | `docs/plan/v43-m3-verification-2026-03-24.md` | pending |

## Closeout 证据口径

- `v43` 不接受“切一个新相机 + 立即爆炸”替代完整 FPV 自杀冲击。
- 必须有 fresh test 证明：
  - 右键只在 `active` drone 下进入 `fpv_ads`
  - `fpv_ads` 下红外滤镜与准星成立
  - 左键锁定目标与 fallback 目标点合同成立
  - 锁定后进入不可取消的 `striking`
  - 冲击全过程保持第一视角与红外滤镜
  - 爆炸后恢复 player camera/input，并回到 `stowed`

## ECN 索引

- 暂无

## 差异列表

- 当前尚未进入实现阶段；本版本仅完成文档冻结。


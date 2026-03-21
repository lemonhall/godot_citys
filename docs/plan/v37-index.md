# V37 Index

## 愿景

PRD 入口：[PRD-0024 Helicopter Gunship Encounter](../prd/PRD-0024-helicopter-gunship-encounter.md)

设计入口：[2026-03-21-v37-helicopter-gunship-encounter-design.md](../plans/2026-03-21-v37-helicopter-gunship-encounter-design.md)

依赖入口：

- [PRD-0007 Task And Mission System](../prd/PRD-0007-task-and-mission-system.md)
- [PRD-0022 Player Missile Launcher Weapon](../prd/PRD-0022-player-missile-launcher.md)
- [v14-index.md](./v14-index.md)
- [v32-index.md](./v32-index.md)
- [v33-index.md](./v33-index.md)

`v37` 的目标不是在主世界里临时插入一个会飞的模型，而是正式建立一条“独立 lab 先调顺，再移植回正式任务圈”的直升机炮艇遭遇战主链：玩家进入 `chunk_101_178` 的绿色任务圈后，空中生成一架精英炮艇；炮艇以 `helicopter_a.glb` 为正式视觉资源，在战区上空盘旋，持续进行机炮压制与无限导弹攻击；玩家利用现有导弹武器反击，只有把炮艇击落，任务才算完成一次正式 run。随后 encounter 必须回到初始状态，绿圈重新开放，玩家再次进入时又能重开一轮。同时，本轮明确不引入失败态、不引入玩家掉血，也不允许为炮艇任务新开第二套 task/navigation/runtime 栈。

## 决策冻结

- `v37` 首版必须先交付独立 lab，再做主世界移植
- 正式资源路径冻结为：
  - `res://city_game/assets/environment/source/aircraft/helicopter_a.glb`
- 正式主世界起始圈锚点冻结为：
  - `chunk_id = chunk_101_178`
  - `world_anchor = Vector3(-8981.45, 0.0, 10796.22)`
- encounter 完成条件冻结为：
  - `击落炮艇`
- 首版任务状态继续冻结为：
  - `available`
  - `active`
  - `completed`
- 首版不做：
  - `failed`
  - 玩家掉血
  - 离区失败
- 炮艇攻击谱冻结为：
  - 机炮压制
  - 无限导弹
- 敌方导弹 scene/model 资产默认复用 `CityMissile`
- survivability contract 冻结为：
  - 至少 `10` 发玩家导弹 direct hit 不死
- repeatable contract 冻结为：
  - 击落后恢复初始 `available`
  - 空爆 + 坠落 closeout 完成后才重新出现绿圈
  - 再次进入绿圈开启下一轮
  - 保留 `completion_count` 或等价 run 计数
- 炮艇任务 pin contract 冻结为：
  - `icon_id = helicopter`
  - full-map UI glyph = `🚁`

## 里程碑

| 里程碑 | 范围 | DoD | 验证命令/测试 | 状态 |
|---|---|---|---|---|
| M1 Lab 场景落地 | 独立 `F6` 场景、玩家、地面、起始圈、encounter root、炮艇 scene | 进入 lab 起始圈后能正式生成炮艇并进入 encounter | `tests/world/test_city_helicopter_gunship_lab_scene_contract.gd` + F6 手测 | done |
| M2 炮艇 runtime 与 survivability | orbit、无限导弹、受击、空爆坠落、closeout cleanup | 炮艇能攻击，10 发玩家导弹 direct hit 不死，且击落后保留空爆 + 坠落再清场 | `tests/world/test_city_helicopter_gunship_lab_repeatable_combat_contract.gd`、`tests/world/test_city_helicopter_gunship_lab_completion_cleanup_contract.gd` | done |
| M3 Task event completion + repeatable reset | 在不引入 failed 的前提下，让 active task 可通过 encounter event 完成，并在 closeout 后恢复可接 | `available -> active -> completed -> available` 的 repeatable encounter contract 跑通，且下一轮需重新进圈 | `tests/world/test_city_task_helicopter_gunship_event_completion.gd`、`tests/world/test_city_task_helicopter_gunship_repeatable_reset.gd` | done |
| M4 主世界移植与流程验证 | `chunk_101_178` 的正式任务圈接入同一 encounter、full-map 炮艇 pin 接入 | 进入主世界起始圈后触发 encounter；击落后主世界也保留空爆坠落并在 closeout 后返绿圈；full map 出现直升机 pin | `tests/e2e/test_city_task_helicopter_gunship_flow.gd`、`tests/world/test_city_task_helicopter_gunship_pin_contract.gd` | done |

## 计划索引

- [v37-helicopter-gunship-encounter-lab.md](./v37-helicopter-gunship-encounter-lab.md)

## 追溯矩阵

| Req ID | v37 Plan | 单元/集成测试 | E2E / 验证命令 | 证据 | 状态 |
|---|---|---|---|---|---|
| REQ-0024-001 | `v37-helicopter-gunship-encounter-lab.md` | `tests/world/test_city_helicopter_gunship_lab_scene_contract.gd` | `F6` lab 场景 + headless scene contract | `docs/plan/v37-m4-verification-2026-03-21.md` | done |
| REQ-0024-002 | `v37-helicopter-gunship-encounter-lab.md` | `tests/world/test_city_helicopter_gunship_lab_repeatable_combat_contract.gd` | `--script res://tests/world/test_city_helicopter_gunship_lab_repeatable_combat_contract.gd` | `docs/plan/v37-m4-verification-2026-03-21.md` | done |
| REQ-0024-003 | `v37-helicopter-gunship-encounter-lab.md` | `tests/world/test_city_helicopter_gunship_lab_repeatable_combat_contract.gd`、`tests/world/test_city_helicopter_gunship_lab_completion_cleanup_contract.gd` | `--script res://tests/world/test_city_helicopter_gunship_lab_completion_cleanup_contract.gd` | `docs/plan/v37-m4-verification-2026-03-21.md` | done |
| REQ-0024-004 | `v37-helicopter-gunship-encounter-lab.md` | `tests/world/test_city_task_helicopter_gunship_event_completion.gd`、`tests/world/test_city_task_helicopter_gunship_repeatable_reset.gd`、`tests/world/test_city_task_helicopter_gunship_pin_contract.gd` | `tests/e2e/test_city_task_helicopter_gunship_flow.gd` | `docs/plan/v37-m4-verification-2026-03-21.md` | done |
| REQ-0024-005 | `v37-helicopter-gunship-encounter-lab.md` | `tests/world/test_city_helicopter_gunship_lab_repeatable_combat_contract.gd` | `tests/e2e/test_city_task_helicopter_gunship_flow.gd` | `docs/plan/v37-m4-verification-2026-03-21.md` | done |
| REQ-0024-006 | `v37-helicopter-gunship-encounter-lab.md` | `tests/world/test_city_task_helicopter_gunship_repeatable_reset.gd`、`tests/world/test_city_helicopter_gunship_lab_completion_cleanup_contract.gd` | `tests/e2e/test_city_task_helicopter_gunship_flow.gd` 二次触发段 | `docs/plan/v37-m4-verification-2026-03-21.md` | done |

## Closeout 证据口径

- `v37` 必须先有独立 lab 证据，再允许声称主世界接入完成
- `v37` closeout 必须把 fresh verification 落到 `docs/plan/v37-mN-verification-YYYY-MM-DD.md`
- 不接受“炮艇模型能飞”替代正式 attack/survivability contract
- 不接受“任务理论上可完成”替代击落事件的正式 task runtime 验证
- 不接受通过禁用敌方攻击、临时降低玩家导弹伤害或关闭主世界 task 链来伪造通过

## ECN 索引

- 暂无

## 差异列表

- `v37` 首版不做失败态
- `v37` 首版不做玩家掉血
- `v37` 首版不做敌方导弹弹药上限
- `v37` 首版不做多架炮艇编队
- `v37` 首版不把 encounter 完成偷换成“再进一个蓝圈”
- `v37` 首版不是一次性任务；击落后必须恢复初始可接状态

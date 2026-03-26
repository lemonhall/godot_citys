# V61 Index

## 愿景

PRD 入口：

- [PRD-0033 Robot Dog Ground Locomotion Control](../prd/PRD-0033-robot-dog-ground-locomotion-control.md)

设计入口：

- [2026-03-26-v61-robot-dog-ground-locomotion-design.md](../plans/2026-03-26-v61-robot-dog-ground-locomotion-design.md)

依赖入口：

- [PRD-0031 Robot Dog Scene Foundation](../prd/PRD-0031-robot-dog-scene-foundation.md)
- [PRD-0032 Robot Dog Locomotion Lab](../prd/PRD-0032-robot-dog-locomotion-lab.md)
- [v59-index.md](./v59-index.md)
- [v60-index.md](./v60-index.md)

`v61` 的目标是把机械狗从“静态姿态和爬下动作”推进到“正式可接管的地面 locomotion 单位”。本轮只做：小键盘 `4` 召唤/回收、第三人称接管、`Player` 冻结、`idle / walk / run / backward / turn / prone`。当前明确不做 `pounce / jump / landing / attack`。

## 决策冻结

- 小键盘 `4` 是机械狗正式召唤/回收热键。
- 机械狗召唤点固定在 `Player` 前方约 `2m`，朝向与 `Player` 一致。
- 召唤成功后立刻切到机械狗第三人称镜头。
- 机械狗控制态下，`W/A/S/D/Shift/P` 只归机械狗消费。
- `Player` 在机械狗控制态下原地冻结。
- `v61` 只做地面 locomotion。
- `pounce / jump / landing / attack` 进入 `v62+`。

## 里程碑

| 里程碑 | 范围 | DoD | 验证命令/测试 | 状态 |
|---|---|---|---|---|
| M0 docs freeze | PRD / design / v61 plan 冻结 | 小键盘 `4`、第三人称接管、player freeze、ground locomotion、非目标全部落文档 | `rg -n "KEY_KP_4|小键盘 `4`|third person|第三人称|player freeze|walk|run|backward|prone|v62" docs/prd/PRD-0033-robot-dog-ground-locomotion-control.md docs/plans/2026-03-26-v61-robot-dog-ground-locomotion-design.md docs/plan/v61-index.md docs/plan/v61-robot-dog-ground-locomotion.md` | done |
| M1 red tests | summon / camera / input / locomotion 红测 | 至少锁住召唤/回收、镜头接管、输入所有权、ground locomotion state | `tests/world/test_city_player_robot_dog_toggle_contract.gd`; `tests/world/test_city_player_robot_dog_camera_takeover_contract.gd`; `tests/world/test_city_player_robot_dog_ground_locomotion_contract.gd`; `tests/e2e/test_city_player_robot_dog_flow.gd` | done |
| M2 implementation | world wrapper + locomotion runtime | 机械狗能正式接管控制并完成地面 locomotion，不回退 `v60` joint/pivot contract | 同上 | done |
| M3 verification | focused verification + parse check | fresh verification 文档回填追溯矩阵 | `docs/plan/v61-m3-verification-2026-03-26.md` | done |

## 计划索引

- [v61-robot-dog-ground-locomotion.md](./v61-robot-dog-ground-locomotion.md)

## 追溯矩阵

| Req ID | V61 Plan | 单元/集成测试 | E2E / 验证命令 | 证据 | 状态 |
|---|---|---|---|---|---|
| REQ-0033-001 | `v61-robot-dog-ground-locomotion.md` | `tests/world/test_city_player_robot_dog_toggle_contract.gd` | `docs/plan/v61-m3-verification-2026-03-26.md` | `v61-m3-verification-2026-03-26.md` | done |
| REQ-0033-002 | `v61-robot-dog-ground-locomotion.md` | `tests/world/test_city_player_robot_dog_camera_takeover_contract.gd`; `tests/world/test_city_player_robot_dog_presentation_contract.gd` | `docs/plan/v61-m3-verification-2026-03-26.md` | `v61-m3-verification-2026-03-26.md` | done |
| REQ-0033-003 | `v61-robot-dog-ground-locomotion.md` | `tests/world/test_city_player_robot_dog_camera_takeover_contract.gd`; `tests/world/test_city_player_robot_dog_ground_locomotion_contract.gd` | `docs/plan/v61-m3-verification-2026-03-26.md` | `v61-m3-verification-2026-03-26.md` | done |
| REQ-0033-004 | `v61-robot-dog-ground-locomotion.md` | `tests/world/test_city_player_robot_dog_ground_locomotion_contract.gd` | `tests/e2e/test_city_player_robot_dog_flow.gd` | `v61-m3-verification-2026-03-26.md` | done |
| REQ-0033-005 | `v61-robot-dog-ground-locomotion.md` | `tests/world/test_city_player_robot_dog_ground_locomotion_contract.gd`; `tests/world/test_robot_dog_lab_control_contract.gd` | `docs/plan/v61-m3-verification-2026-03-26.md` | `v61-m3-verification-2026-03-26.md` | done |
| REQ-0033-006 | `v61-robot-dog-ground-locomotion.md` | `tests/world/test_city_player_robot_dog_camera_takeover_contract.gd`; `tests/world/test_city_player_robot_dog_ground_locomotion_contract.gd` | `docs/plan/v61-m3-verification-2026-03-26.md` | `v61-m3-verification-2026-03-26.md` | done |
| REQ-0033-007 | `v61-robot-dog-ground-locomotion.md` | 上述 focused tests 与 `tests/world/test_city_player_robot_dog_presentation_contract.gd` 共同约束 | `docs/plan/v61-m3-verification-2026-03-26.md` | `v61-m3-verification-2026-03-26.md` | done |

## Closeout 证据口径

- `v61` 不接受“只切镜头，不切输入所有权”的空壳实现。
- `v61` 不接受“机械狗和 Player 同时响应 `W/A/S/D/Shift/P`”的空壳实现。
- `v61` 不接受“只让根节点滑行，不建立 ground locomotion state”的空壳实现。
- `v61` 不接受“为了跑步态而破坏 `v60` joint/pivot 合同”的实现。
- `v61` 不接受“lab 和主世界各自写一套机械狗控制逻辑”的实现。

## ECN 索引

- 当前无

## 差异列表

- `pounce / jump / landing / attack` 进入 `v62+`。

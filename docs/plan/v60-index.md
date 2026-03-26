# V60 Index

## 愿景

PRD 入口：

- [PRD-0032 Robot Dog Locomotion Lab](../prd/PRD-0032-robot-dog-locomotion-lab.md)

设计入口：

- [2026-03-26-v60-robot-dog-locomotion-lab-design.md](../plans/2026-03-26-v60-robot-dog-locomotion-lab-design.md)
- [2026-03-26-robot-dog-github-reference-research.md](../plans/2026-03-26-robot-dog-github-reference-research.md)

依赖入口：

- [PRD-0031 Robot Dog Scene Foundation](../prd/PRD-0031-robot-dog-scene-foundation.md)
- [v59-index.md](./v59-index.md)

`v60` 的第一刀目标已经冻结为：先把机械狗的 8 个单轴铰链关节和 `P` 键爬下/起身动作做硬。当前不做 walking gait，不做主世界接入。只有在“关节轴向、限位、躯干降姿、大小腿联动、reset 主链”这条链稳定之后，后续 walking 才有继续叠加的基础。

## 决策冻结

- 第一刀只做 `P` 键爬下/起身。
- 8 个关节全部只绕 local `Z` 轴旋转。
- 所有关节都必须有显式限位。
- `RobotDogLab` 只消费正式 runtime，不写第二套私有逻辑。
- gait、前进、转向、terrain follow 进入 `v61+`。

## 里程碑

| 里程碑 | 范围 | DoD | 验证命令/测试 | 状态 |
|---|---|---|---|---|
| M0 docs freeze | PRD / design / v60 plan 冻结 | `P` 键、`Z` 轴、joint limit、躯干降姿、非目标全部落文档 | `rg -n "P 键|local `Z`|蓝色轴|爬下|起身|joint limit|body_to_thigh_angle_deg" docs/prd/PRD-0032-robot-dog-locomotion-lab.md docs/plans/2026-03-26-v60-robot-dog-locomotion-lab-design.md docs/plan/v60-index.md docs/plan/v60-robot-dog-locomotion-lab.md` | done |
| M1 red tests | joint contract / crouch pose / lab flow 红测 | 至少锁住 joint axis、joint limit、`P` 切换、`F5` reset | `tests/world/test_robot_dog_joint_contract.gd`; `tests/world/test_robot_dog_crouch_pose_contract.gd`; `tests/e2e/test_robot_dog_lab_prone_flow.gd` | done |
| M2 implementation | hinge pose runtime + lab input | 真实大腿/小腿被驱动；躯干降姿；`P` 往返切换正常 | 同上 | done |
| M3 verification | focused verification + parse check | fresh verification 文档回填追溯矩阵 | `docs/plan/v60-m3-verification-2026-03-26.md` | done |

## 计划索引

- [v60-robot-dog-locomotion-lab.md](./v60-robot-dog-locomotion-lab.md)

## 追溯矩阵

| Req ID | V60 Plan | 单元/集成测试 | E2E / 验证命令 | 证据 | 状态 |
|---|---|---|---|---|---|
| REQ-0032-001 | `v60-robot-dog-locomotion-lab.md` | `tests/world/test_robot_dog_joint_contract.gd` | `docs/plan/v60-m3-verification-2026-03-26.md` | `v60-m3-verification-2026-03-26.md` | done |
| REQ-0032-002 | `v60-robot-dog-locomotion-lab.md` | `tests/world/test_robot_dog_joint_contract.gd` | `docs/plan/v60-m3-verification-2026-03-26.md` | `v60-m3-verification-2026-03-26.md` | done |
| REQ-0032-003 | `v60-robot-dog-locomotion-lab.md` | `tests/world/test_robot_dog_joint_contract.gd` | `docs/plan/v60-m3-verification-2026-03-26.md` | `v60-m3-verification-2026-03-26.md` | done |
| REQ-0032-004 | `v60-robot-dog-locomotion-lab.md` | `tests/world/test_robot_dog_crouch_pose_contract.gd` | `docs/plan/v60-m3-verification-2026-03-26.md` | `v60-m3-verification-2026-03-26.md` | done |
| REQ-0032-005 | `v60-robot-dog-locomotion-lab.md` | `tests/world/test_robot_dog_crouch_pose_contract.gd` | `tests/e2e/test_robot_dog_lab_prone_flow.gd` | `v60-m3-verification-2026-03-26.md` | done |
| REQ-0032-006 | `v60-robot-dog-locomotion-lab.md` | `tests/world/test_robot_dog_joint_contract.gd`; `tests/world/test_robot_dog_crouch_pose_contract.gd` | `docs/plan/v60-m3-verification-2026-03-26.md` | `v60-m3-verification-2026-03-26.md` | done |
| REQ-0032-007 | `v60-robot-dog-locomotion-lab.md` | 上述 focused tests 共同约束 | `docs/plan/v60-m3-verification-2026-03-26.md` | `v60-m3-verification-2026-03-26.md` | done |

## Closeout 证据口径

- `v60` 不接受“只降躯干，不转真实腿段”的空壳实现。
- `v60` 不接受“只播动画 clip，没有 joint runtime”的空壳实现。
- `v60` 不接受“关节绕 `X/Y` 轴补动作”的空壳实现。
- `v60` 不接受“lab 自己写一套逻辑，正式 `CityRobotDog.gd` 仍然不会爬下”的空壳实现。

## ECN 索引

- 2026-03-26：`v60` 第一刀范围从“整套 locomotion”收窄为“单轴铰链 + P 键爬下/起身”，当前直接原地修订文档，未另立 ECN。

## 差异列表

- walking gait、前进、转向、terrain follow、脚点规划进入 `v61+`。

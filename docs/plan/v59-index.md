# V59 Index

## 愿景

PRD 入口：

- [PRD-0031 Robot Dog Scene Foundation](../prd/PRD-0031-robot-dog-scene-foundation.md)

设计入口：[2026-03-26-v59-robot-dog-scene-foundation-design.md](../plans/2026-03-26-v59-robot-dog-scene-foundation-design.md)

依赖入口：

- [v39-arthropod-crawler-locomotion-labs.md](./v39-arthropod-crawler-locomotion-labs.md)

`v59` 的目标不是立刻做机械狗步态，而是先把这只手工拆件后的模型纳入正式 creature 资产链：资产进正规目录、正式 creature scene 落地、独立 lab 落地、8 个腿部关节锚点 scene-first 冻结。

## 决策冻结

- 正式目录走 `quadrupeds`，不挤进 `arthropods`
- 先做 `scene-first + lab-first`
- 当前不做 locomotion / IK / gait scheduler
- 8 个锚点必须 author 成真实 `Marker3D`

## 里程碑

| 里程碑 | 范围 | DoD | 验证命令/测试 | 状态 |
|---|---|---|---|---|
| M0 docs freeze | PRD / v59 plan / design 全链冻结 | 正式资产路径、scene、lab、8 个锚点与非目标全部落文档 | `rg -n "REQ-0031-001|REQ-0031-002|REQ-0031-003|REQ-0031-004|quadrupeds|JointAnchors|lf_hip|rf_hip|RobotDogLab" docs/prd/PRD-0031-robot-dog-scene-foundation.md docs/plan/v59-index.md docs/plan/v59-robot-dog-scene-foundation.md docs/plans/2026-03-26-v59-robot-dog-scene-foundation-design.md` | done |
| M1 red tests | scene / lab focused 红测 | 至少锁住正式 glb 路径、creature scene、8 锚点、lab scene-first 层级与最小 API | `tests/world/test_robot_dog_scene_contract.gd`; `tests/world/test_robot_dog_lab_scene_contract.gd` | done |
| M2 implementation | asset relocation + formal scene + lab | 根目录散装 glb 不再是正式引用源；creature scene 与 lab scene 都存在；8 个锚点落在 scene 中 | 同上 + parse check | done |
| M3 verification | focused verification | fresh verification 文档回填追溯矩阵 | `docs/plan/v59-m3-verification-2026-03-26.md` | done |

## 计划索引

- [v59-robot-dog-scene-foundation.md](./v59-robot-dog-scene-foundation.md)

## 追溯矩阵

| Req ID | V59 Plan | 单元/集成测试 | 验证命令 | 证据 | 状态 |
|---|---|---|---|---|---|
| REQ-0031-001 | `v59-robot-dog-scene-foundation.md` | `tests/world/test_robot_dog_scene_contract.gd` | `docs/plan/v59-m3-verification-2026-03-26.md` | `v59-m3-verification-2026-03-26.md` | done |
| REQ-0031-002 | `v59-robot-dog-scene-foundation.md` | `tests/world/test_robot_dog_scene_contract.gd` | `docs/plan/v59-m3-verification-2026-03-26.md` | `v59-m3-verification-2026-03-26.md` | done |
| REQ-0031-003 | `v59-robot-dog-scene-foundation.md` | `tests/world/test_robot_dog_scene_contract.gd` | `docs/plan/v59-m3-verification-2026-03-26.md` | `v59-m3-verification-2026-03-26.md` | done |
| REQ-0031-004 | `v59-robot-dog-scene-foundation.md` | `tests/world/test_robot_dog_lab_scene_contract.gd` | `docs/plan/v59-m3-verification-2026-03-26.md` | `v59-m3-verification-2026-03-26.md` | done |

## Closeout 证据口径

- `v59` 不接受“只把 glb 搬目录，但 formal creature scene 仍不存在”的空壳实现。
- `v59` 不接受“lab 直接挂 glb，绕开 formal creature scene”的空壳实现。
- `v59` 不接受“锚点只在脚本里报数，scene 里没有真实 Marker3D”的空壳实现。

## ECN 索引

- 当前无

## 差异列表

- locomotion / IK / gait / terrain follow / 主世界接入进入 `v60+`。

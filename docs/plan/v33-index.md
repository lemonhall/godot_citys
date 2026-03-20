# V33 Index

## 愿景

PRD 入口：[PRD-0023 Building Collapse Destruction Lab](../prd/PRD-0023-building-collapse-destruction-lab.md)

设计入口：[2026-03-20-v33-building-collapse-destruction-lab-design.md](../plans/2026-03-20-v33-building-collapse-destruction-lab-design.md)

依赖入口：

- [PRD-0008 Laser Designator World Inspection](../prd/PRD-0008-laser-designator-world-inspection.md)
- [PRD-0009 Building Serviceability Reconstruction](../prd/PRD-0009-building-serviceability-reconstruction.md)
- [PRD-0022 Player Missile Launcher Weapon](../prd/PRD-0022-player-missile-launcher.md)
- [v32-index.md](./v32-index.md)

`v33` 的目标不是直接重写整座城市的建筑生成或引入高成本外部破坏 SDK，而是先在一个可 `F6` 运行的独立实验场景中，把建筑伤害、命中点裂纹、后台预碎裂准备、濒毁阈值替换、坍塌和碎块清理这条链完整跑通；随后再把同一套 runtime 逻辑扩展到主世界近景建筑，实现“玩家用火箭弹能把一栋楼从完好打到最终坍塌”的第一版正式玩法。

## 决策冻结

- `v33` 首版必须先交付独立实验场景，再做主世界移植
- 实验目标建筑首版冻结为：
  - `res://city_game/serviceability/buildings/generated/bld_v15-building-id-1_seed424242_chunk_137_136_001/building_scene.tscn`
- 首版建筑伤害状态冻结为：
  - `intact`
  - `damaged`
  - `fracture_preparing`
  - `collapse_ready`
  - `collapsing`
  - `collapsed`
- 首版不持久化建筑摧毁结果
- 首版坍塌必须采用有限数量 chunk + 低成本裂纹方案，不上第三方 SDK

## 里程碑

| 里程碑 | 范围 | DoD | 验证命令/测试 | 状态 |
|---|---|---|---|---|
| M1 实验场景落地 | 独立 `F6` 实验场、平地、环境、玩家、目标建筑、战斗根节点 | `F6` 即可进入实验场并攻击目标建筑 | focused world test + scene smoke + F6 手测 | todo |
| M2 建筑伤害与裂纹 | building health、hit point、damage state、crack visual | 火箭弹命中后建筑掉血；中度受损时出现命中点裂纹 | `tests/world/test_building_collapse_lab_damage_contract.gd` | todo |
| M3 预碎裂与坍塌 | fracture prepare、临界替换、碎块清理 | 建筑可从完好进入预准备，再进入坍塌，最终留下底座/残骸并清理大部分碎块 | `tests/world/test_building_collapse_lab_flow.gd` | todo |
| M4 主世界移植 | 同一 runtime 接入主世界近景建筑 | 主世界建筑被火箭弹命中后能走伤害/坍塌链 | focused world/e2e 主世界建筑测试 | todo |

## 计划索引

- [v33-building-collapse-destruction-lab.md](./v33-building-collapse-destruction-lab.md)

## 追溯矩阵

| Req ID | v33 Plan | 单元/集成测试 | E2E / 验证命令 | 证据 | 状态 |
|---|---|---|---|---|---|
| REQ-0023-001 | `v33-building-collapse-destruction-lab.md` | `tests/world/test_building_collapse_lab_scene_contract.gd` | `F6` 实验场景 + headless scene smoke | — | todo |
| REQ-0023-002 | `v33-building-collapse-destruction-lab.md` | `tests/world/test_building_collapse_lab_damage_contract.gd` | `--script res://tests/world/test_building_collapse_lab_damage_contract.gd` | — | todo |
| REQ-0023-003 | `v33-building-collapse-destruction-lab.md` | `tests/world/test_building_collapse_lab_damage_contract.gd` | `F6` 裂纹手测 + contract test | — | todo |
| REQ-0023-004 | `v33-building-collapse-destruction-lab.md` | `tests/world/test_building_collapse_lab_flow.gd` | `--script res://tests/world/test_building_collapse_lab_flow.gd` | — | todo |
| REQ-0023-005 | `v33-building-collapse-destruction-lab.md` | `tests/world/test_building_collapse_lab_flow.gd` | `F6` 坍塌手测 + contract test | — | todo |
| REQ-0023-006 | `v33-building-collapse-destruction-lab.md` | 主世界 focused building collapse test | 主世界 focused world/e2e | — | todo |

## Closeout 证据口径

- `v33` 必须先有实验场景证据，再允许声称主世界接入完成
- `v33` closeout 必须把 fresh verification 落到 `docs/plan/v33-mN-verification-YYYY-MM-DD.md`
- 不接受“实验场景里看起来炸了”替代自动化 contract
- 不接受“主世界理论上能复用”替代主世界 focused verification

## ECN 索引

- 暂无

## 差异列表

- `v33` 首版不做建筑坍塌持久化
- `v33` 首版不做多栋楼并发坍塌压力场景
- `v33` 首版不做第三方破坏 SDK 接入

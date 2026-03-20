# V33 Building Collapse Destruction Lab

## Goal

先交付一个可独立 `F6` 运行的建筑坍塌实验场景，在低干扰环境里完成“火箭弹命中建筑 -> 建筑掉血 -> 中度受损裂纹 -> 后台预碎裂准备 -> 濒毁替换为坍塌体 -> 碎块清理”的完整 1-5 步闭环；随后再把同一套 runtime 逻辑接回主世界近景建筑。

## PRD Trace

- Direct consumer: REQ-0023-001
- Direct consumer: REQ-0023-002
- Direct consumer: REQ-0023-003
- Direct consumer: REQ-0023-004
- Direct consumer: REQ-0023-005
- Port / Integration: REQ-0023-006

## Dependencies

- 依赖 `v32` 已冻结玩家火箭弹正式武器链
- 依赖 `PRD-0008` 已冻结建筑 inspection / hit payload 主链
- 依赖 `PRD-0009` 已冻结 `building_id / building contract / override node` 主链
- 实验目标建筑首版直接复用：
  - `res://city_game/serviceability/buildings/generated/bld_v15-building-id-1_seed424242_chunk_137_136_001/building_scene.tscn`

## Contract Freeze

- 实验场景必须 scene-first authoring，不允许脚本临时搭完整实验场
- 首版建筑生命值建议冻结为 `10000`
- 中度受损阈值建议冻结为 `0.60`
- 濒毁坍塌阈值建议冻结为 `0.05`
- 首版坍塌块数量必须有硬上限，避免直接失控
- 首版不持久化建筑破坏状态

## Scope

做什么：

- 新增独立实验场景、实验场脚本和 focused tests
- 新增建筑伤害 runtime、裂纹 runtime、坍塌 runtime
- 让现有火箭弹/爆炸链能够把伤害施加到目标建筑
- 中度受损时出现命中点裂纹
- 中度受损时启动预碎裂准备
- 濒毁时替换为可碎裂坍塌体并完成清理
- 第二阶段把 runtime 接回主世界近景建筑

不做什么：

- 不持久化建筑破坏状态
- 不做全城任意楼同时坍塌压测
- 不做 runtime 任意 mesh 布尔碎裂
- 不做 Blast / APEX / PhysX SDK 接入
- 不做玻璃、室内、家具等二级破坏

## Acceptance

1. 自动化测试必须证明：独立实验场景能正常加载目标建筑、玩家和战斗根节点，且玩家可在该场景中攻击建筑。
2. 自动化测试必须证明：火箭弹命中目标建筑时，建筑生命值会下降并记录正式命中点。
3. 自动化测试必须证明：建筑进入中度受损阈值后，裂纹/受损视觉状态被激活。
4. 自动化测试必须证明：建筑进入中度受损后，会生成可复用的预碎裂准备状态，而不是等濒毁时再现算。
5. 自动化测试必须证明：建筑进入濒毁阈值后，会由完好主体切换到可碎裂坍塌体，并进入 `collapsing / collapsed` 状态。
6. 自动化测试必须证明：坍塌一段时间后，大部分碎块会被清理，只保留底座/少量残骸。
7. 主世界 focused verification 必须证明：同一 runtime 逻辑可接入主世界近景建筑，不止实验场景生效。
8. 反作弊条款：不得只播放倒塌动画；不得只把原楼隐藏并丢一堆粒子；不得把预碎裂准备偷换成临界时现算。

## Files

- Create: `docs/prd/PRD-0023-building-collapse-destruction-lab.md`
- Create: `docs/plans/2026-03-20-v33-building-collapse-destruction-lab-design.md`
- Create: `docs/plan/v33-index.md`
- Create: `docs/plan/v33-building-collapse-destruction-lab.md`
- Create: `city_game/scenes/labs/BuildingCollapseLab.tscn`
- Create: `city_game/scenes/labs/BuildingCollapseLab.gd`
- Create: `city_game/combat/buildings/CityDestructibleBuildingRuntime.gd`
- Create: `city_game/combat/buildings/CityBuildingCrackRuntime.gd`
- Create: `city_game/combat/buildings/CityBuildingCollapseRuntime.gd`
- Create: `city_game/combat/buildings/CityBuildingFractureRecipeBuilder.gd`
- Create: `tests/world/test_building_collapse_lab_scene_contract.gd`
- Create: `tests/world/test_building_collapse_lab_damage_contract.gd`
- Create: `tests/world/test_building_collapse_lab_flow.gd`
- Modify: `city_game/scripts/CityPrototype.gd`
- Modify: `city_game/world/rendering/CityChunkScene.gd`
- Modify: `city_game/world/rendering/CityChunkRenderer.gd`
- Modify: `city_game/world/serviceability/CityBuildingSceneBuilder.gd`
- Modify: `docs/plan/v33-index.md`

## Steps

1. Analysis
   - 固定两阶段口径：实验场优先，主世界移植第二阶段。
   - 固定实验目标建筑和阈值口径。
2. Design
   - 写 `PRD-0023`、design doc、`v33-index` 和本计划文档。
3. TDD Red: Lab Scene
   - 先写实验场景 contract test，锁定 `F6` 场景的玩家、地面、建筑、战斗根节点。
4. Run Red
   - 跑实验场景 focused test，确认当前缺少实验场景与 runtime。
5. TDD Green: Lab Scene
   - 落实验场景 `.tscn`
   - 接入玩家与目标建筑
6. TDD Red: Damage / Crack
   - 写建筑生命值、命中点、裂纹触发测试。
7. TDD Green: Damage / Crack
   - 实现建筑伤害 runtime 与裂纹 runtime。
8. TDD Red: Fracture / Collapse
   - 写预碎裂准备、濒毁替换、坍塌清理测试。
9. TDD Green: Fracture / Collapse
   - 实现 fracture recipe、坍塌体替换和清理。
10. Refactor
   - 把建筑坍塌 runtime 维持在独立模块，不把实验逻辑糊进大脚本。
11. Port to Main World
   - 把已验证 runtime 接入主世界近景建筑链。
12. E2E / Focused Verification
   - 跑实验场 focused tests。
   - 跑主世界 focused building collapse verification。
13. Review
   - 更新 `v33-index` 追溯矩阵与验证证据。

## Risks

- 如果实验场景不是 scene-first，后续视觉和节点关系会继续失控。
- 如果预碎裂准备没有独立 contract，临界替换时容易卡顿。
- 如果碎块数量不设上限，主世界移植后会直接踩物理预算。
- 如果实验场和主世界走两套 runtime，第二阶段会变成重写而不是移植。

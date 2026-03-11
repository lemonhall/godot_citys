# V2 Rendering LOD

## Goal

建立按 chunk 组织的渲染扩展路径，让城市的近景、中景、远景和重复性资产都能在成本可控的前提下出现。

## PRD Trace

- REQ-0001-004
- REQ-0001-006

## Scope

做什么：

- 引入 chunk-local `MultiMeshInstance3D`
- 建立近景实体 / 中景合批 / 远景代理的可见性层级
- 为 block 自动生成基础遮挡体
- 为每个 streamed chunk 提供占位地表与碰撞壳，保证连续步行/驾驶巡检
- 输出每个 chunk 的实例数与 LOD 档位

不做什么：

- 不做最终美术资产
- 不做复杂材质系统
- 不做车辆与人群专用渲染管线

## Acceptance

1. 至少一种重复资产必须以 `MultiMeshInstance3D` 形式出现，并有自动化测试断言。
2. 同一个 chunk 至少存在近景、中景、远景三档表现策略，并有可验证的档位切换规则。
3. 自动化测试能证明远景代理不是完整近景节点树的复制。
4. 自动化测试能证明离开中心原型区后，演员仍能落在 streamed chunk 的占位地表上。
5. 反作弊条款：不得仅通过隐藏节点名称、空 `Node3D` 占位或孤岛地板来宣称 HLOD 已存在。

## Files

- Create: `city_game/world/rendering/CityChunkRenderer.gd`
- Create: `city_game/world/rendering/CityChunkScene.gd`
- Create: `city_game/world/rendering/CityChunkMultimeshBuilder.gd`
- Create: `city_game/world/rendering/CityChunkHlodBuilder.gd`
- Create: `city_game/world/rendering/CityChunkOccluderBuilder.gd`
- Create: `tests/world/test_city_chunk_renderer.gd`
- Create: `tests/world/test_city_hlod_contract.gd`
- Create: `tests/world/test_city_chunk_ground_contract.gd`
- Create: `tests/e2e/test_city_ground_continuity.gd`
- Modify: `city_game/world/streaming/CityChunkStreamer.gd`
- Modify: `city_game/scenes/CityPrototype.tscn`

## Steps

1. 写失败测试（红）
   - `test_city_chunk_renderer.gd` 断言重复 props 通过 `MultiMeshInstance3D` 管理。
   - `test_city_hlod_contract.gd` 断言 chunk 内同时存在近/中/远三类可见表示，并具有明确切换字段。
   - `test_city_chunk_ground_contract.gd` 断言 chunk scene 暴露 GroundBody、碰撞体和占位地表网格。
2. 跑到红
   - 运行上述 world 测试脚本，预期 FAIL，原因是 renderer / HLOD builder / chunk ground 尚不存在。
3. 实现（绿）
   - 建立 chunk renderer，将占位建筑、路灯、树木等拆为 chunk-local 表现。
   - 为远景添加合批代理或简化代理，并给出遮挡体构造接口。
   - 给每个 streamed chunk 添加占位地表和碰撞壳。
4. 跑到绿
   - renderer / ground contract 测试均输出 `PASS`。
5. 必要重构（仍绿）
   - 统一 LOD 状态枚举和 debug 字段。
6. E2E 测试
   - 在大世界 E2E 与 ground continuity E2E 中确认 travel 过程中 LOD 档位会变化，且演员不会掉穿世界。

## Risks

- 如果 MultiMesh 粒度过大，会因为整片可见/不可见导致浪费；过小又会丢失批处理收益。
- 如果 HLOD 契约先不定义清楚，后续美术资产接入时容易重写整套 renderer。
- 如果 chunk 不提供占位地表，所有“大世界连续 traversal 已成立”的结论都会失真。

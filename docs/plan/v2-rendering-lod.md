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
- 让 near / mid / far 共享同一份 chunk visual profile，保持轮廓连续
- 为不同 chunk 提供确定性视觉变体
- 让可见道路由 world-space 连续道路骨架驱动，而不是 per-chunk 随机 avenue（[已由 ECN-0004 变更](../ecn/ECN-0004-road-network-terrain-and-collision.md)）
- 让 chunk 路面改为连续 ribbon mesh，并把本地道路从“方格规则占位”升级为更自然的世界道路场（[已由 ECN-0005 变更](../ecn/ECN-0005-organic-road-density-and-inspection-ui.md)）
- 为近景建筑补充可启停碰撞壳
- 让建筑与 roadside props 满足道路避让与占用检查，并提升 chunk 建筑密度与 archetype 多样性（[已由 ECN-0005 变更](../ecn/ECN-0005-organic-road-density-and-inspection-ui.md)）
- 为 block 自动生成基础遮挡体
- 为每个 streamed chunk 提供占位地表与碰撞壳，保证连续步行/高速巡检
- 为每个 streamed chunk 提供轻量连续地形高差
- 提供少量高架/桥梁占位，打破纯平道路体验（[已由 ECN-0005 变更](../ecn/ECN-0005-organic-road-density-and-inspection-ui.md)）
- 使用低成本 sky/fog 统一远景氛围
- 输出每个 chunk 的实例数与 LOD 档位，并将 HUD/debug 信息整合为默认折叠的巡检面板（[已由 ECN-0005 变更](../ecn/ECN-0005-organic-road-density-and-inspection-ui.md)）

不做什么：

- 不做最终美术资产
- 不做复杂材质系统
- 不做车辆与人群专用渲染管线

## Acceptance

1. 至少一种重复资产必须以 `MultiMeshInstance3D` 形式出现，并有自动化测试断言。
2. 同一个 chunk 至少存在近景、中景、远景三档表现策略，并有可验证的档位切换规则。
3. 自动化测试能证明 mid/far 代理保留与 near 一致的主轮廓签名，而不是无关盒子。
4. 自动化测试能证明不同 chunk 存在确定性视觉变体，且同一 chunk 多次生成签名一致。
5. 自动化测试能证明相邻 chunk 的道路连接点在共享边界上连续，且道路包含曲线变化，不是 per-chunk 随机孤路。
6. 自动化测试能证明 chunk 道路存在显著非正交方向，并且路面由连续 mesh/ribbon 表达，而不是大量分段盒子贴片。
7. 自动化测试能证明近景建筑具有碰撞壳，且 mid/far LOD 时这些碰撞会停用。
8. 自动化测试能证明建筑与 roadside props 保持道路退距，且中心 chunk 建筑数量与 archetype 数量达到约定阈值。
9. 自动化测试能证明 `WorldEnvironment` 提供 sky/fog 氛围，而不是单色背景。
10. 自动化测试能证明 chunk 地表存在可见高差，并包含可感知坡度。
11. 自动化测试能证明至少存在少量桥梁/高架占位。
12. 自动化测试能证明离开中心原型区后，演员仍能落在 streamed chunk 的占位地表上。
13. 反作弊条款：不得仅通过隐藏节点名称、空 `Node3D` 占位、孤岛地板、legacy `Ground`、无关蓝色盒子、分段道路盒子或 per-chunk 随机道路贴片来宣称大世界地表/HLOD 已成立。

## Files

- Create: `city_game/world/rendering/CityChunkRenderer.gd`
- Create: `city_game/world/rendering/CityChunkScene.gd`
- Create: `city_game/world/rendering/CityChunkMultimeshBuilder.gd`
- Create: `city_game/world/rendering/CityChunkHlodBuilder.gd`
- Create: `city_game/world/rendering/CityChunkProfileBuilder.gd`
- Create: `city_game/world/rendering/CityTerrainSampler.gd`
- Create: `city_game/world/rendering/CityChunkOccluderBuilder.gd`
- Create: `tests/world/test_city_chunk_renderer.gd`
- Create: `tests/world/test_city_hlod_contract.gd`
- Create: `tests/world/test_city_visual_environment.gd`
- Create: `tests/world/test_city_chunk_variation.gd`
- Create: `tests/world/test_city_road_network_continuity.gd`
- Create: `tests/world/test_city_building_collision.gd`
- Create: `tests/world/test_city_terrain_sampler.gd`
- Create: `tests/world/test_city_chunk_ground_contract.gd`
- Create: `tests/e2e/test_city_ground_continuity.gd`
- Modify: `city_game/world/streaming/CityChunkStreamer.gd`
- Modify: `city_game/scripts/CityPrototype.gd`
- Modify: `city_game/scenes/CityPrototype.tscn`

## Steps

1. 写失败测试（红）
   - `test_city_chunk_renderer.gd` 断言重复 props 通过 `MultiMeshInstance3D` 管理。
   - `test_city_hlod_contract.gd` 断言 chunk 内同时存在近/中/远三类可见表示，并具有明确切换字段。
   - `test_city_visual_environment.gd` 断言 WorldEnvironment 提供 sky/fog。
   - `test_city_chunk_variation.gd` 断言不同 chunk 具有不同视觉签名。
   - `test_city_road_network_continuity.gd` 断言道路跨 chunk 连续且存在曲率。
   - `test_city_building_collision.gd` 断言近景建筑碰撞启停随 LOD 正确切换。
   - `test_city_terrain_sampler.gd` 断言 terrain sampler 连续且 chunk ground 不是纯平面。
   - `test_city_chunk_ground_contract.gd` 断言 chunk scene 暴露 GroundBody、碰撞体和占位地表网格。
2. 跑到红
   - 运行上述 world 测试脚本，预期 FAIL，原因是 renderer / HLOD builder / chunk ground 尚不存在。
3. 实现（绿）
   - 建立 chunk renderer，将占位建筑、路灯、树木等拆为 chunk-local 表现。
   - 为远景添加由同一份 profile 驱动的合批代理，并给出遮挡体构造接口。
   - 用 world-space 连续道路骨架替换 per-chunk 随机 avenue。
   - 给建筑补近景碰撞壳，并在 mid/far LOD 停用。
   - 给 chunk ground、道路与建筑基座接入同一套连续高度采样。
   - 给 WorldEnvironment 添加低成本 sky/fog。
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
- 如果 near / mid / far 不是同一份轮廓数据，用户会直接感知到“建筑换了一栋”。
- 如果 chunk 不提供占位地表，所有“大世界连续 traversal 已成立”的结论都会失真。

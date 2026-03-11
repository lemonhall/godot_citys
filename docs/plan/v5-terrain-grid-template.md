# V5 Terrain Grid Template

## Goal

把 `CityChunkScene._build_terrain_mesh()` 从按三角形重复采样高度的原型路径，升级成共享规则网格模板 + 唯一顶点采样的基础路径，先砍掉当前 `ground_mesh` 的重复工作。

## PRD Trace

- REQ-0001-004
- REQ-0001-006
- REQ-0001-011

## Scope

做什么：

- 引入共享 terrain grid template 或等价 `ArrayMesh` 数组契约
- 让 chunk ground 复用同一份 index/topology，而不是每块重复拼三角形
- 把高度采样限制在唯一顶点级别
- 为 `ground_mesh` 输出稳定的 profile breakdown

不做什么：

- 不在本计划里引入完整 terrain page cache
- 不在本计划里引入异步准备
- 不在本计划里引入 clipmap / quadtree 全套结构

## Acceptance

1. 自动化诊断测试必须输出 `current_vertex_sample_count`、`unique_vertex_sample_count` 与 `duplication_ratio`，并断言 `duplication_ratio <= 1.2`。
2. 自动化测试必须证明两个不同 chunk 的地形 mesh 共享同一份规则拓扑或等价数组契约，而不是各自独立构造。
3. `test_city_chunk_setup_profile_breakdown.gd` 必须证明地形热路径 `ground_mesh_usec <= 9000`。
4. 反作弊条款：不得通过降低 terrain resolution 到无法承托道路/玩家、关闭 ground collision、或直接隐藏地表来伪造耗时下降。

## Files

- Create: `city_game/world/rendering/CityTerrainGridTemplate.gd`
- Create: `city_game/world/rendering/CityTerrainMeshBuilder.gd`
- Modify: `city_game/world/rendering/CityChunkScene.gd`
- Modify: `city_game/world/rendering/CityChunkGroundSampler.gd`
- Create: `tests/world/test_city_terrain_grid_template.gd`
- Modify: `tests/world/test_city_ground_mesh_profile_breakdown.gd`
- Modify: `tests/world/test_city_chunk_setup_profile_breakdown.gd`

## Steps

1. 写失败测试（红）
   - `test_city_terrain_grid_template.gd` 断言规则网格模板存在、index/topology 可复用。
   - `test_city_ground_mesh_profile_breakdown.gd` 断言 `duplication_ratio <= 1.2`，当前应 FAIL。
2. 跑到红
   - 运行上述测试，预期 FAIL，原因是 terrain mesh 仍处于重复采样路径。
3. 实现（绿）
   - 抽离共享 grid template / mesh builder。
   - 让 chunk ground 先生成唯一顶点高度，再复用 index/topology 输出 mesh。
4. 跑到绿
   - grid template 与 profile breakdown 测试全部 PASS。
5. 必要重构（仍绿）
   - 统一 terrain mesh profile 字段与采样接口命名。
6. E2E 测试
   - 在 runtime profile 脚本中确认 `ground_mesh_usec` 下降，并且玩家仍能在 streamed terrain 上正常移动。

## Risks

- 如果 template 分辨率与现有道路/建筑基座采样没有对齐，可能先引入局部高度错位。
- 如果只替换 mesh builder 而不稳定 profile 字段，后续 M2/M3 很难判断收益是否来自真实优化。

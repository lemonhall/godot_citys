# V2 World Data Model

## Goal

建立 `godot_citys` 的大城市数据底座，使世界可以先以确定性数据形式存在，再由后续系统按需解包为场景内容。

## PRD Trace

- REQ-0001-001
- REQ-0001-002

## Scope

做什么：

- 建立世界配置对象、seed 约定、坐标与 chunk 网格规则
- 建立 district / road / block / parcel 的核心数据结构
- 让 `road_graph` 提供可按 world rect 查询的 world-space 连续道路几何（[已由 ECN-0004 变更](../ecn/ECN-0004-road-network-terrain-and-collision.md)）
- 将 block / parcel 改为按 chunk 惰性查询的元数据接口
- 提供不依赖整城实例化的世界生成 API

不做什么：

- 不做 streaming
- 不做 HLOD / MultiMesh
- 不做导航烘焙

## Acceptance

1. 固定 seed 下生成结果可复现：两次运行得到相同的 district IDs、chunk IDs、block 计数和 parcel 计数。
2. 自动化测试断言世界尺寸固定为 `70000m x 70000m`，主 chunk 尺寸固定为 `256m x 256m`。
3. 自动化测试断言世界生成 API 在未实例化 `CityPrototype.tscn` 的情况下可返回完整 district / road 图，以及可按 chunk 查询的 block / parcel 元数据接口。
4. 自动化测试断言 `road_graph` 可按 world rect 查询曲线化道路边，为 chunk 渲染提供连续道路骨架。
5. 反作弊条款：不得把“把当前 `GeneratedCity` 生成更多方块”或“仅把世界常量改大但仍 eager 展开整城 block/parcel”作为本计划完成证据。

## Files

- Create: `city_game/world/model/CityWorldConfig.gd`
- Create: `city_game/world/model/CityDistrictGraph.gd`
- Create: `city_game/world/model/CityRoadGraph.gd`
- Create: `city_game/world/model/CityBlockLayout.gd`
- Create: `city_game/world/generation/CityWorldGenerator.gd`
- Create: `tests/world/test_city_world_model.gd`
- Create: `tests/world/test_city_world_generator.gd`
- Modify: `city_game/scripts/CityPrototype.gd`
- Modify: `city_game/scenes/CityPrototype.tscn`

## Steps

1. 写失败测试（红）
   - 在 `tests/world/test_city_world_model.gd` 中断言固定 seed 的世界配置、chunk 计数和坐标边界。
   - 在 `tests/world/test_city_world_generator.gd` 中断言生成器输出完整 `70km` 世界统计，并提供 `get_blocks_for_chunk()` 这类惰性查询接口。
2. 跑到红
   - 运行：
     ```powershell
     & 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_world_model.gd'
     ```
   - 预期：FAIL，原因是世界模型脚本与生成器不存在。
3. 实现（绿）
   - 添加最小世界配置和生成器，使测试中的固定 seed 返回稳定结果。
   - 将 `CityBlockLayout` 改为惰性查询接口，避免整城 block / parcel eager 展开。
   - 将 `CityPrototype` 改为从世界数据接口读取当前演示区域，而不是直接内嵌整个未来城市的假设。
4. 跑到绿
   - 运行两个 world model 相关测试，预期均为 `PASS`。
5. 必要重构（仍绿）
   - 合并重复坐标转换逻辑。
   - 保证 ID 命名统一：`district_id`、`chunk_id`、`block_id`、`parcel_id`。
6. E2E 测试（如适用）
   - 本计划不单独设置 E2E；E2E 将在 `v2-navigation-e2e.md` 中统一验证。

## Risks

- 数据结构命名如果现在不统一，后面 streaming 和 nav 会持续返工。
- 生成 API 如果偷偷依赖场景实例，后续无法在后台线程安全准备数据。
- 如果 block / parcel 继续维持整城 eager 数组，`70km` 目标会在启动时间和内存上立即失真。

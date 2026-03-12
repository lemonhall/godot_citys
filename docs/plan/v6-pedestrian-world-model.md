# V6 Pedestrian World Model

## Goal

建立 `godot_citys` 的 pedestrian data 底座，让行人先以确定性数据存在，再由后续 lane graph、tiering 和 streaming 系统按需解包为可见人流。

## PRD Trace

- REQ-0002-001
- REQ-0002-006

## Scope

做什么：

- 建立统一的 pedestrian config、density profile 与 spawn seed 派生规则
- 建立不依赖场景节点的 pedestrian query API
- 为 district / road class / lane class 定义默认 density bucket 与 archetype weight
- 输出稳定可解析的 pedestrian world stats

不做什么：

- 不在本计划里生成 sidewalk / crossing lane graph
- 不在本计划里实例化任何 3D 行人节点
- 不在本计划里引入日夜 schedule

## Acceptance

1. 固定 seed 下，`pedestrian roster signature`、density profile、lane references 和 spawn slot signatures 必须完全一致。
2. 自动化测试必须证明在未实例化 `CityPrototype.tscn` 的情况下，可按 chunk 查询 pedestrian density、spawn capacity 与 archetype 分布。
3. 自动化测试必须证明 district class 与 road class 的 density profile 可以在数据层读出，而不是硬编码在渲染脚本内部。
4. 反作弊条款：不得以“在场景里先摆几个人”和“按 chunk 随机现掷人数”来冒充 world model 完成。

## Files

- Create: `city_game/world/pedestrians/model/CityPedestrianConfig.gd`
- Create: `city_game/world/pedestrians/model/CityPedestrianProfile.gd`
- Create: `city_game/world/pedestrians/model/CityPedestrianQuery.gd`
- Create: `city_game/world/pedestrians/generation/CityPedestrianWorldBuilder.gd`
- Modify: `city_game/world/generation/CityWorldGenerator.gd`
- Create: `tests/world/test_city_pedestrian_world_model.gd`
- Create: `tests/world/test_city_pedestrian_density_profile.gd`

## Steps

1. 写失败测试（红）
   - `test_city_pedestrian_world_model.gd` 断言固定 seed 的 pedestrian query 签名稳定。
   - `test_city_pedestrian_density_profile.gd` 断言 district / road class 到 density bucket 的映射存在并可查询。
2. 跑到红
   - 运行上述测试，预期 FAIL，原因是 pedestrian world model 尚不存在。
3. 实现（绿）
   - 引入 pedestrian config / profile / query 数据结构。
   - 将 world generator 扩展为可在数据层输出 pedestrian query 入口。
4. 跑到绿
   - pedestrian world model 与 density profile 测试全部 PASS。
5. 必要重构（仍绿）
   - 统一命名：`pedestrian_id`、`ped_page_id`、`lane_id`、`spawn_slot_id`。
   - 确保 query API 不依赖场景节点或 scene tree。
6. E2E 测试
   - 本计划不单独创建 E2E；E2E 将在 `v6-pedestrian-streaming-and-reactivity.md` 与 `v6-pedestrian-redline-guard.md` 中统一验证。

## Risks

- 如果 density profile 混在渲染脚本里，后续 tiering 与 minimap 会持续返工。
- 如果 query API 依赖 scene tree，后续 page/cache 和后台准备就无法安全推进。
- 如果 spawn seed 没有把 lane / slot 维度写入，tier continuity 会很快失去稳定锚点。

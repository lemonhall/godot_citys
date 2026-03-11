# ECN-0001: v2 大城市尺度与巡检闭环修正

## 基本信息

- **ECN 编号**：ECN-0001
- **关联 PRD**：PRD-0001
- **关联 Req ID**：REQ-0001-001、REQ-0001-002、REQ-0001-004、REQ-0001-006、REQ-0001-007、新增 REQ-0001-008
- **发现阶段**：v2 施工复盘与人工试玩阶段
- **日期**：2026-03-11

## 变更原因

初版 v2 在自动化测试层面证明了 chunk streaming、占位渲染和宏观导航接口，但仍存在三处关键偏差：

1. PRD 把世界尺度锁在 `7km x 7km`，与当前“正常城市至少 `70km x 70km`”的目标不一致。
2. 运行时只有中心孤岛地板，离开 v1 原型范围后会掉穿，说明“连续 traversable world”并未真正成立。
3. 大世界 E2E 主要验证内存态断言，缺少稳定输出的运行时证据，也缺少一个可供人工巡检的载具入口。

## 变更内容

### 原设计

- v2 世界尺度：`7km x 7km`
- block / parcel 通过整城 eager 字典一次性生成
- E2E 以自动 travel 断言为主，未要求稳定输出 `final_position` / `transition_count`
- 不提供开发态巡检车

### 新设计

- v2 世界尺度提升为 `70km x 70km`
- block / parcel 改为确定性、按 chunk 惰性查询的元数据接口，避免整城 eager 展开
- chunk placeholder 渲染必须提供连续可站立/可驾驶的地表与碰撞壳
- 大世界 E2E 必须输出稳定运行时报告，至少包含 `current_chunk_id`、`active_chunk_count`、`transition_count`、`final_position`
- 新增开发态巡检车，用于人工驾驶检查 streaming / ground / debug / chunk 迁移

## 影响范围

- 受影响的 Req ID：
  - REQ-0001-001 世界尺度
  - REQ-0001-002 数据城市生成契约
  - REQ-0001-004 分块渲染降级与地表承托
  - REQ-0001-006 运行时观测与性能护栏
  - REQ-0001-007 端到端 travel 验证
  - REQ-0001-008 开发态巡检载具（新增）
- 受影响的 v2 计划：
  - `docs/plan/v2-world-data-model.md`
  - `docs/plan/v2-chunk-streaming.md`
  - `docs/plan/v2-rendering-lod.md`
  - `docs/plan/v2-navigation-e2e.md`
  - `docs/plan/v2-index.md`
- 受影响的测试：
  - `tests/world/test_city_world_model.gd`
  - `tests/world/test_city_world_generator.gd`
  - `tests/world/test_city_chunk_ground_contract.gd`
  - `tests/e2e/test_city_ground_continuity.gd`
  - `tests/e2e/test_city_vehicle_inspection_mode.gd`
  - `tests/e2e/test_city_large_world_e2e.gd`
- 受影响的代码文件：
  - `city_game/world/model/CityWorldConfig.gd`
  - `city_game/world/model/CityBlockLayout.gd`
  - `city_game/world/generation/CityWorldGenerator.gd`
  - `city_game/world/rendering/CityChunkScene.gd`
  - `city_game/scripts/CityPrototype.gd`
  - `city_game/scripts/PlayerController.gd`
  - `city_game/scripts/InspectionCarController.gd`
  - `city_game/scenes/CityPrototype.tscn`

## 处置方式

- [x] PRD 已同步更新（标注 ECN-0001）
- [x] v2 计划已同步更新
- [x] 追溯矩阵已同步更新
- [x] 相关测试已同步更新

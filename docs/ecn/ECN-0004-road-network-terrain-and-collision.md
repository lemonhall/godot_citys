# ECN-0004: 道路骨架连续性、地形高差与建筑碰撞修正

## 基本信息

- **ECN 编号**：ECN-0004
- **关联 PRD**：PRD-0001
- **关联 Req ID**：REQ-0001-002、REQ-0001-004、REQ-0001-006
- **发现阶段**：v2 人工巡检与视觉/空间体验 review
- **日期**：2026-03-11

## 变更原因

人工试玩继续暴露出四处结构性问题：

1. 玩家与近景建筑没有任何碰撞，空间感失真。
2. 近景 LOD 半径过小，视觉切换圈层太贴脸。
3. 画面中的道路并非来自整城道路骨架，而是 chunk 内独立随机装饰，导致孤路、断路与重复感。
4. streamed chunk 地表仍为纯平面，缺少连续地形高差。

这些问题说明 v2 已有世界数据层、渲染层与空间体验层之间仍未完全对齐。

## 变更内容

### 原设计

- `road_graph` 只存在于世界数据层，chunk 渲染不消费它
- chunk 近景道路允许用独立随机 avenue 占位
- 建筑允许只有可视网格、没有物理碰撞
- chunk ground 允许用纯平面承托
- near/mid LOD 半径维持较小默认值

### 新设计

- chunk 可见道路必须由 world-space 连续道路骨架驱动，而不是 per-chunk 随机摆放
- 近景建筑必须提供可启停的碰撞壳；mid/far LOD 不得保留不可见碰撞
- chunk ground、道路 y 值和建筑基座必须共享同一套连续高度采样
- near/mid LOD 阈值扩大，避免过近切换

## 影响范围

- 受影响的 Req ID：
  - REQ-0001-002 世界道路骨架与查询契约
  - REQ-0001-004 渲染降级、chunk 地表与碰撞承托
  - REQ-0001-006 运行时观测与人工巡检
- 受影响的 v2 计划：
  - `docs/plan/v2-world-data-model.md`
  - `docs/plan/v2-rendering-lod.md`
  - `docs/plan/v2-index.md`
- 受影响的测试：
  - `tests/world/test_city_world_generator.gd`
  - `tests/world/test_city_road_network_continuity.gd`
  - `tests/world/test_city_building_collision.gd`
  - `tests/world/test_city_terrain_sampler.gd`
  - `tests/world/test_city_hlod_contract.gd`

## 处置方式

- [x] PRD 已同步更新（标注 ECN-0004）
- [x] v2 计划已同步更新
- [x] 追溯矩阵已同步更新
- [x] 相关测试已同步更新

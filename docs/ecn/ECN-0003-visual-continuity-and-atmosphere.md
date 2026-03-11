# ECN-0003: 视觉连续性与低成本天空氛围修正

## 基本信息

- **ECN 编号**：ECN-0003
- **关联 PRD**：PRD-0001
- **关联 Req ID**：REQ-0001-004、REQ-0001-006
- **发现阶段**：v2 人工巡检与视觉体验 review
- **日期**：2026-03-11

## 变更原因

人工试玩暴露出三处体验问题：

1. 远处天空只是纯背景色，没有“整座城处在同一片天空下”的氛围。
2. 远/中/近 LOD 不是同一份建筑轮廓数据，导致走近时建筑像“换了一栋”。
3. 邻近 chunk 使用同一套占位建筑布局，近处重复感太强。

这些问题不属于“美术资产不够”的正常缺口，而是 v2 占位渲染契约本身不完整。

## 变更内容

### 原设计

- `WorldEnvironment` 只有背景色，没有明确 sky/fog 氛围层
- mid/far proxy 允许用独立蓝色盒子代表一整块 chunk
- 邻近 chunk 可复用同一套占位近景布局

### 新设计

- 使用低成本 `ProceduralSky + fog` 统一天空与远景空气透视
- near/mid/far 必须由同一份 chunk visual profile 派生，保持主轮廓连续
- chunk 近景建筑布局必须按 chunk seed 生成确定性变体，避免近景重复

## 影响范围

- 受影响的 Req ID：
  - REQ-0001-004 分块渲染降级与实例化
  - REQ-0001-006 运行时观测与性能护栏
- 受影响的 v2 计划：
  - `docs/plan/v2-rendering-lod.md`
  - `docs/plan/v2-index.md`
- 受影响的测试：
  - `tests/world/test_city_visual_environment.gd`
  - `tests/world/test_city_chunk_variation.gd`
  - `tests/world/test_city_hlod_contract.gd`
- 受影响的代码文件：
  - `city_game/scripts/CityPrototype.gd`
  - `city_game/world/rendering/CityChunkProfileBuilder.gd`
  - `city_game/world/rendering/CityChunkScene.gd`
  - `city_game/world/rendering/CityChunkHlodBuilder.gd`
  - `city_game/world/rendering/CityChunkMultimeshBuilder.gd`
  - `city_game/world/rendering/CityChunkRenderer.gd`

## 处置方式

- [x] PRD 已同步更新（标注 ECN-0003）
- [x] v2 计划已同步更新
- [x] 追溯矩阵已同步更新
- [x] 相关测试已同步更新

# ECN-0005: 更自然道路网、建筑密度/多样性与巡检 UI 修正

## 基本信息

- **ECN 编号**：ECN-0005
- **关联 PRD**：PRD-0001
- **关联 Req ID**：REQ-0001-002、REQ-0001-004、REQ-0001-006、REQ-0001-008
- **发现阶段**：v2 人工巡检与视觉体验 review
- **日期**：2026-03-11

## 变更原因

继续人工巡检后，又暴露出一组更接近“城市感”的结构性缺口：

1. 道路虽然连续，但仍然带有明显的 chunk 盒子拼接感和横平竖直格网感。
2. 建筑与 roadside props 只做了粗退距筛选，仍会落在路面上。
3. 路间空地的建筑密度过低，且建筑 archetype 明显不足，城市重复感仍然过强。
4. HUD 与 debug overlay 分成两套 panel，默认常驻，影响人工巡检。
5. 玩家抬头角度过小，无法自然观察天空与高层轮廓。
6. 地形高差仍偏弱，缺少更明显的坡度感；同时缺少少量高架/桥梁占位来打破纯平路面体验。

这些问题说明 v2 的世界道路、占位建筑、巡检观测面与空间氛围还没有达到“可用于大城市人工验收”的程度。

## 变更内容

### 原设计

- chunk 路面允许按 polyline 分段用 `BoxMesh` 拼接。
- chunk 内次级道路允许继续表现为偏正交的占位道路族。
- 建筑与 props 允许使用“远离道路候选点”粗筛来放置。
- 近景建筑以少量 tower/podium archetype 为主。
- HUD 与 debug overlay 可以独立常显。
- 玩家向上 pitch 维持较小上限。
- 地形只要求“非纯平面”，不要求明显坡度感。

### 新设计

- chunk 路面改为 world-space 连续道路骨架驱动的 ribbon mesh，避免强烈拼接感。
- 次级/本地道路必须来自更自然的世界道路场，禁止只依赖横平竖直的 per-chunk 规则道路。
- 建筑与 roadside props 都必须满足道路缓冲区避让与占用检查，不得落在路面上。
- chunk 建筑生成改为更高密度、多 archetype 的占位质量块系统，near/mid/far 必须共享同一份体量轮廓集合。
- HUD 与 debug 信息整合为一个默认折叠的巡检面板，只有展开后才显示详细调试文本。
- 玩家向上 pitch 上限扩大，允许更自然地观察天空与建筑。
- 地形高差增强，并允许少量 arterial bridge / overpass 占位打破纯平路网体验。

## 影响范围

- 受影响的 Req ID：
  - REQ-0001-002 世界道路骨架与查询契约
  - REQ-0001-004 渲染降级、道路表达、建筑密度/多样性、地形与桥梁占位
  - REQ-0001-006 运行时观测面板与人工巡检体验
  - REQ-0001-008 开发态高速巡检模式的人机可用性
- 受影响的 v2 计划：
  - `docs/plan/v2-rendering-lod.md`
  - `docs/plan/v2-index.md`
- 受影响的测试：
  - `tests/world/test_city_road_network_continuity.gd`
  - `tests/world/test_city_building_collision.gd`
  - `tests/world/test_city_chunk_variation.gd`
  - `tests/world/test_city_hlod_contract.gd`
  - `tests/world/test_city_debug_overlay.gd`
  - `tests/world/test_city_terrain_sampler.gd`
  - `tests/world/test_city_visual_environment.gd`
- 受影响的代码文件：
  - `city_game/world/generation/CityWorldGenerator.gd`
  - `city_game/world/rendering/CityRoadLayoutBuilder.gd`
  - `city_game/world/rendering/CityChunkScene.gd`
  - `city_game/world/rendering/CityChunkProfileBuilder.gd`
  - `city_game/world/rendering/CityChunkMultimeshBuilder.gd`
  - `city_game/world/rendering/CityChunkHlodBuilder.gd`
  - `city_game/world/rendering/CityTerrainSampler.gd`
  - `city_game/ui/PrototypeHud.gd`
  - `city_game/world/debug/CityDebugOverlay.gd`
  - `city_game/scripts/CityPrototype.gd`
  - `city_game/scripts/PlayerController.gd`
  - `city_game/scenes/CityPrototype.tscn`

## 处置方式

- [x] PRD 已同步更新（标注 ECN-0005）
- [x] v2 计划已同步更新
- [x] 追溯矩阵已同步更新
- [ ] 相关测试已同步更新

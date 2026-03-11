# V5 Terrain Redline Closeout

## Goal

对 v5 的 terrain 改造做最终收口，确保 first-visit 与 warm traversal 都守住项目级红线，并且不把 v4 已修复的道路连续性、可行走地表和 surface page 质量重新打坏。

## PRD Trace

- REQ-0001-004
- REQ-0001-006
- REQ-0001-010
- REQ-0001-011

## Scope

做什么：

- 对 cold / warm 两类 runtime profile 做独立验收
- 复测 road surface page、terrain seam、可行走地表与道路覆盖连续性
- 为后续版本输出稳定的 redline 回归护栏

不做什么：

- 不在本计划里新增玩法或视觉扩展
- 不以关闭道路、缩小世界、冻结移动来换取过线

## Acceptance

1. `test_city_runtime_performance_profile.gd` 必须证明 warm traversal 满足 `wall_frame_avg_usec <= 16667`。
2. `test_city_first_visit_performance_profile.gd` 必须证明 first-visit traversal 也满足 `wall_frame_avg_usec <= 16667`。
3. `test_city_surface_page_tile_seam_continuity.gd` 与 `test_city_terrain_road_overlay_continuity.gd` 必须同时 PASS，证明 terrain 改造没有重新引入道路断裂或贴地错位。
4. 反作弊条款：不得通过隐藏普通道路、禁用 terrain collision、降低 active chunk window、锁死移动路径或改用静态单场景来宣称 v5 完成。

## Files

- Modify: `tests/e2e/test_city_runtime_performance_profile.gd`
- Create: `tests/e2e/test_city_first_visit_performance_profile.gd`
- Modify: `tests/world/test_city_surface_page_tile_seam_continuity.gd`
- Modify: `tests/world/test_city_terrain_road_overlay_continuity.gd`
- Modify: `docs/plan/v5-index.md`

## Steps

1. 写失败测试（红）
   - `test_city_first_visit_performance_profile.gd` 断言 first-visit 红线。
   - 现有 runtime / seam continuity 测试绑定最终红线口径。
2. 跑到红
   - 运行 cold/warm profile 测试，预期 FAIL，直到 terrain pipeline 全部落地。
3. 实现（绿）
   - 修复 v5 各里程碑联动后的收口问题，补齐冷/热路径差异。
4. 跑到绿
   - cold / warm / continuity 全部 PASS。
5. 必要重构（仍绿）
   - 清理 profiling 字段、回归护栏与默认开关，避免临时诊断代码污染主路径。
6. E2E 测试
   - 以统一命令复跑 fresh runtime profile，保存最终红线证据。

## Risks

- first-visit 红线比 warm traversal 更难，若 page cache、async 和 LOD 的收益没有真正叠加，最后很可能在 M5 暴露。
- 如果只看毫秒数不看连续性，terrain 改造可能重新把道路/地形关系打坏。

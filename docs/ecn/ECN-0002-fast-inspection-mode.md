# ECN-0002: 开发态巡检方式改为玩家高速巡检模式

## 基本信息

- **ECN 编号**：ECN-0002
- **关联 PRD**：PRD-0001
- **关联 Req ID**：REQ-0001-004、REQ-0001-006、REQ-0001-008
- **发现阶段**：v2 人工试玩回归
- **日期**：2026-03-11

## 变更原因

在人工试玩中发现两处实现偏差：

1. `InspectionCar` 会出生在 chunk 占位建筑附近，导致开发态巡检入口本身不稳定。
2. 场景残留的 v1 `Ground` 与 v2 chunk 地表重叠，产生明显频闪，说明地表承托机制没有统一。

用户的真实目标不是“有一辆车”，而是“能高速移动，快速预览城市”。因此继续保留巡检车只会增加维护成本，而不会提高验收效率。

## 变更内容

### 原设计

- 场景内新增 `InspectionCar`
- `C` 键在玩家与巡检车之间切换
- legacy `Ground` 与 chunk 地表并存

### 新设计

- 删除 `InspectionCar`，改为玩家 `inspection` 高速巡检模式
- `C` 键在玩家普通速度与高速巡检速度之间切换
- 场景删除 legacy `Ground`，统一使用 v2 chunk 地表支撑玩家

## 影响范围

- 受影响的 Req ID：
  - REQ-0001-004 分块渲染降级与地表承托
  - REQ-0001-006 运行时观测与性能护栏
  - REQ-0001-008 开发态巡检模式
- 受影响的 v2 计划：
  - `docs/plan/v2-chunk-streaming.md`
  - `docs/plan/v2-rendering-lod.md`
  - `docs/plan/v2-navigation-e2e.md`
  - `docs/plan/v2-index.md`
- 受影响的测试：
  - `tests/test_city_skeleton_smoke.gd`
  - `tests/e2e/test_city_ground_continuity.gd`
  - `tests/e2e/test_city_fast_inspection_mode.gd`
- 受影响的代码文件：
  - `city_game/scenes/CityPrototype.tscn`
  - `city_game/scripts/CityPrototype.gd`
  - `city_game/scripts/PlayerController.gd`

## 处置方式

- [x] PRD 已同步更新（标注 ECN-0002）
- [x] v2 计划已同步更新
- [x] 追溯矩阵已同步更新
- [x] 相关测试已同步更新

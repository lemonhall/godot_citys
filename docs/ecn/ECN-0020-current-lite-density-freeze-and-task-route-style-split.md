# ECN-0020: Current Lite Density Freeze And Task Route Style Split

## 基本信息

- **ECN 编号**：ECN-0020
- **关联 PRD**：PRD-0002、PRD-0007
- **关联 Req ID**：REQ-0002-007、REQ-0002-016、REQ-0007-003、REQ-0007-005、REQ-0007-007
- **发现阶段**：`v14` 任务系统落地后的手玩反馈 / 文档收口阶段
- **日期**：2026-03-16

## 变更原因

2026-03-16 的最新手玩反馈把两个产品决策彻底拍板了：

1. 默认 `lite` 的当前人口密度已经达到可接受平台，不再继续追逐旧的 `>=250` active 口径，也不允许再为了“看起来应该更多人”去反复折腾路、车、行人的密度。
2. 任务追踪路线不应继续复用手工目的地的橙黄色导航语义；用户已经确认：
   - 手工目的地 route 保持现有橙黄色
   - 任务 route 改用绿色或蓝色

同时，当前还存在“接取任务后沿任务 route 行进时 FPS 明显下跌”的运行时问题。这个性能问题需要单独按 profiling 调查，但它**不是**继续上调人口密度或继续混用路线颜色的理由。

## 变更内容

### 原设计

- `ECN-0016` 之后，`v6` active density 仍被写成默认 `lite` 下的 `>=250` 平台。
- task route 默认沿用 shared destination route 的橙黄色视觉语义。

### 新设计

- 默认 `lite` 的 active density 合同冻结为**当前平台基线**：
  - world contract：warm `tier1_count >= 150`
  - world contract：first-visit `tier1_count >= 220`
  - isolated pedestrian profile：warm `ped_tier1_count >= 150`
  - isolated pedestrian profile：first-visit `ped_tier1_count >= 220`
  - isolated runtime profile：warm `ped_tier1_count >= 150`
  - 既有 runtime / first-visit 红线继续保持 `wall_frame_avg_usec <= 16667`
- `REQ-0002-016` 从“继续追更高 density”正式改为“冻结当前已接受的平台，不再主动上抬 density”。
- route visual contract 正式拆分为：
  - manual destination route：`destination`，橙黄色
  - tracked available task route：`task_available`，绿色
  - tracked active task route：`task_active`，蓝色
- full map、minimap 与 active route result 必须共享同一个 `route_style_id` contract；不得出现“世界火焰圈是绿/蓝，但 2D route 仍画成 destination 橙黄”的分裂状态。
- 本 ECN 不改变道路密度、车辆密度、行人密度配置本身；它只冻结 active 验收口径与任务路线视觉语义。

## 影响范围

- 受影响的 Req ID：
  - REQ-0002-007
  - REQ-0002-016
  - REQ-0007-003
  - REQ-0007-005
  - REQ-0007-007
- 受影响的计划 / 文档：
  - `docs/prd/PRD-0002-pedestrian-crowd-foundation.md`
  - `docs/plan/v6-index.md`
  - `docs/plan/v6-pedestrian-density-preserving-runtime-recovery.md`
  - `docs/plan/v6-pedestrian-full-stack-layered-runtime.md`
  - `docs/prd/PRD-0007-task-and-mission-system.md`
  - `docs/plan/v14-index.md`
  - `docs/plan/v14-task-map-and-brief-ui.md`
- 受影响的测试：
  - `tests/world/test_city_pedestrian_density_order_of_magnitude.gd`
  - `tests/world/test_city_pedestrian_lite_density_uplift.gd`
  - `tests/e2e/test_city_pedestrian_performance_profile.gd`
  - `tests/e2e/test_city_runtime_performance_profile.gd`
  - `tests/world/test_city_minimap_route_overlay.gd`
  - `tests/world/test_city_minimap_navigation_hud.gd`
  - `tests/e2e/test_city_task_tab_selection_flow.gd`
  - `tests/e2e/test_city_task_start_flow.gd`
- 受影响的代码文件：
  - `city_game/scripts/CityPrototype.gd`
  - `city_game/world/map/CityMinimapProjector.gd`
  - `city_game/ui/CityMinimapView.gd`
  - `city_game/ui/CityMapScreen.gd`

## 处置方式

- [x] PRD 已同步更新
- [x] `v6 / v14` 计划已同步更新
- [x] 追溯矩阵已同步更新
- [x] 相关测试已同步更新

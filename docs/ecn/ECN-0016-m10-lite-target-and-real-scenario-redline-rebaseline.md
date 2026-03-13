# ECN-0016: M10 Lite Target And Real Scenario Redline Rebaseline

## 基本信息

- **ECN 编号**：ECN-0016
- **关联 PRD**：PRD-0002
- **关联 Req ID**：REQ-0002-007、REQ-0002-016
- **发现阶段**：`v6 M10` 收口阶段
- **日期**：2026-03-14

## 变更原因

`ECN-0015` 已把旧的 `10x / 540 / 600` 纯 pedestrian 目标下调到 world `300/300` + isolated e2e `240/280`。但 2026-03-14 晚些时候的继续手玩反馈又进一步改变了验收重点：

- 当前城市的人流主观感受已经“够用”，继续把 density 往上堆的收益明显下降；
- 后续还要加入车辆系统，pedestrian-only runtime 不应该继续吃掉更多预算；
- 相比单纯把 `tier1_count` 继续往上抬，用户更关心真实手玩场景下的稳定帧耗，特别是：
  - `C / inspection` 高速穿行 crowd
  - live gunshot 引发局部 panic/flee 链

因此，`M10` 的 active 目标需要再次重定义：把默认 `lite` 的收口目标压到一个明确、可稳定承载的 `>=250` 平台，同时把更接近真实玩法的场景红线写进自动化验收。

## 变更内容

### 原设计

- `M10` 的 active density DoD 仍是 world `300/300` + isolated e2e `240/280`。
- `REQ-0002-007` 主要依赖固定 warm / first-visit profile 路线验收红线。
- `REQ-0002-016` 仍以“在当前 verified plateau 上继续加人”为主要方向。

### 新设计

- `M10` 的 active density 收口改为默认 `pedestrian_mode = lite` 下：
  - world contract：warm / first-visit `tier1_count >= 250`
  - isolated e2e runtime：warm / first-visit `ped_tier1_count >= 250`
  - redline 仍保持 `wall_frame_avg_usec <= 16667`
- `REQ-0002-007` 追加两条真实场景 redline：
  - `tests/e2e/test_city_pedestrian_high_speed_inspection_performance.gd`
    - `inspection` 高速穿行 crowd 时 `wall_frame_avg_usec <= 16667`
    - 仍保持非空 crowd
    - 不得误触发 panic/flee
  - `tests/e2e/test_city_pedestrian_live_gunshot_performance.gd`
    - live gunshot panic chain 下 `wall_frame_avg_usec <= 16667`
    - sampled mid-ring witness 必须进入 `panic/flee`
    - sampled far outsider 必须保持 calm
- `REQ-0002-016` 从“继续追加约 `0.5x` 人流”改为“把当前可稳定承载的平台正式收口”，并继续明确保留 district / road class 层次差异，且不得通过降低真实场景压力来伪造通过。

## 影响范围

- 受影响的 Req ID：
  - REQ-0002-007
  - REQ-0002-016
- 受影响的 v6 计划：
  - `docs/plan/v6-index.md`
  - `docs/plan/v6-pedestrian-density-preserving-runtime-recovery.md`
  - `docs/plan/v6-pedestrian-handplay-closeout.md`
- 受影响的测试：
  - `tests/world/test_city_pedestrian_density_order_of_magnitude.gd`
  - `tests/world/test_city_pedestrian_lite_density_uplift.gd`
  - `tests/e2e/test_city_pedestrian_performance_profile.gd`
  - `tests/e2e/test_city_runtime_performance_profile.gd`
  - `tests/e2e/test_city_pedestrian_high_speed_inspection_performance.gd`
  - `tests/e2e/test_city_pedestrian_live_gunshot_performance.gd`
- 受影响的代码文件：
  - `city_game/world/pedestrians/model/CityPedestrianConfig.gd`
  - `city_game/world/pedestrians/streaming/CityPedestrianBudget.gd`
  - `city_game/world/pedestrians/simulation/CityPedestrianTierController.gd`

## 处置方式

- [x] PRD 已同步更新（标注 ECN-0016）
- [x] v6 计划已同步更新
- [x] 追溯矩阵已同步更新
- [x] 相关测试已同步更新

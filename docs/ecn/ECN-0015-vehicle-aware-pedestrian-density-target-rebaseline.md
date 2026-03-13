# ECN-0015: Vehicle-Aware Pedestrian Density Target Rebaseline

## 基本信息

- **ECN 编号**：ECN-0015
- **关联 PRD**：PRD-0002
- **关联 Req ID**：REQ-0002-007、REQ-0002-016
- **发现阶段**：`v6 M10` density-preserving runtime recovery
- **日期**：2026-03-14

## 变更原因

`ECN-0012` 与 `ECN-0013` 把默认 `lite` pedestrian density 目标一路推到了 warm `540` / first-visit `600` 的数量级，背后逻辑是用“至少 `10x` 的人流存在感”强压当前过空的城市观感。

但 2026-03-14 的最新手玩反馈已经明确改变了产品判断：

- 当前 main 的 verified plateau 已经让城市“开始像有活力的城市”，不是仍然完全空城；
- 用户要求不再是“继续向纯人海冲刺”，而是“在当前体感基础上再多约 `0.5x` 就够”，因为后续还要引入车辆；
- 如果继续把 `540/600` 当唯一收口标准，就会把 `M10` 推向“为纯 pedestrian 吃满几乎全部 runtime 预算”，与未来 mixed traffic 方向正面冲突。

因此，`M10` 的人口目标需要从“纯人海冲刺”重定义为“vehicle-aware 的城市活力目标”。

## 变更内容

### 原设计

- `REQ-0002-016` 以 `2026-03-13` 的 `M8` 稀疏基线为参照，要求默认 `lite` warm `tier1_count >= 540`、first-visit `>= 600`。
- `REQ-0002-007` 明确要求上述高密度目标必须与 `wall_frame_avg_usec <= 16667` 在同一默认配置下同时成立。
- `M10` 计划文档与 `v6-index` 也沿用 `540/600` 作为 density-preserving runtime recovery 的硬 DoD。

### 新设计

- `M10` 不再追求 warm `540` / first-visit `600` 的纯 pedestrian 极限。
- `M10` 的新目标改为“vehicle-aware 的城市活力平台”：
  - world contract：默认 `lite` warm `tier1_count >= 300`，first-visit `tier1_count >= 300`
  - isolated e2e runtime：warm `ped_tier1_count >= 240`，first-visit `ped_tier1_count >= 280`
  - redline 仍保持 `wall_frame_avg_usec <= 16667`
- 设计意图改为：在当前 `2026-03-14` verified plateau 基础上再抬约 `50%`，但不把整个 `16.67ms` 预算都消耗在 pedestrian-only runtime 上，为后续车辆系统保留产品和架构空间。

## 影响范围

- 受影响的 Req ID：
  - REQ-0002-007
  - REQ-0002-016
- 受影响的 v6 计划：
  - `docs/plan/v6-pedestrian-density-preserving-runtime-recovery.md`
  - `docs/plan/v6-index.md`
  - `docs/plan/v6-pedestrian-handplay-closeout.md`（仅补 superseded 历史说明）
- 受影响的测试：
  - 当前不立即抬高自动化阈值；现有 `M10 verified plateau` 测试继续作为“已证实平台”护栏
  - 后续 density uplift 新切片再把最终目标门槛写进新的红测 / 回归测试
- 受影响的代码文件：
  - 无直接生产代码影响；本次属于产品目标与验收口径重定义

## 处置方式

- [x] PRD 已同步更新（标注 ECN-0015）
- [x] v6 计划已同步更新
- [x] 追溯矩阵已同步更新
- [ ] 相关测试将在下一轮 density uplift 切片中同步更新

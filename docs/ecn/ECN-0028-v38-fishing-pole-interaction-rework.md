# ECN-0028: V38 Fishing Pole Interaction Rework

## 基本信息

- **ECN 编号**：ECN-0028
- **关联 PRD**：PRD-0025
- **关联 Req ID**：REQ-0025-005、REQ-0025-006
- **发现阶段**：`v38` closeout 后的 lab 手玩回合
- **日期**：2026-03-22

## 变更原因

首轮 `v38` 虽然已经把 lake / fish / fishing 的 shared runtime 正式接回来了，但实机场测证明钓鱼交互口径仍然偏“占位实现”，主要有四个具体问题：

1. 玩法入口仍然依赖场景里的 `MatchStartRing` 绿圈，用户感知上像“走进圈触发小游戏”，不是真正的岸边钓鱼。
2. `E` 的职责混杂成“进圈、坐下、抛竿、收线、重置”，和鱼竿这个世界物件没有建立起正式主从关系。
3. player 仍然没有形成“持有鱼竿道具”的可视与输入模式，玩法上更像隐藏状态机，不像在世界里拿起一根竿开始钓鱼。
4. 抛投没有继承现有成熟的抛物线预览链路，缺少真实可调的落点预瞄、鱼漂落水和鱼线表现。

用户已经明确给出新的正式交互口径，因此这不是 polish，而是一次正式 contract rework。

## 变更内容

### 原设计

- 入口：玩家进入 `MatchStartRing`，按 `E` 坐下进入钓鱼模式。
- 主流程：`E` 继续驱动抛竿、bite window 收线与 reset。
- 可视：场景里有 green ring，但鱼竿只是静态 prop；player 不形成正式持竿态。
- 抛投：没有复用武器 2（手雷）的抛物线预览和落点提示。

### 新设计

- 入口从 green ring 改为 **鱼竿交互驱动**：
  - 玩家接近场景里 author 的 `FishingPoleRestAnchor` 时，出现 `按 E 拿起鱼竿`。
  - 再按一次 `E`，则把鱼竿放回原位并退出钓鱼态。
  - 不再存在单独的固定开局圈、固定开局点或任务式 start trigger。
- player 必须进入正式 **持竿道具态**：
  - 鱼竿从场景静置位切换到 player 持有位。
  - 持竿位继续遵守 scene-first authoring，由 player scene 的挂点/visual scene 冻结静态 pose。
- 抛投输入冻结为：
  - `右键`：进入待甩杆预览态。
  - 预览态复用手雷的抛物线虚线与落点提示语义。
  - `左键`：执行甩杆，把鱼线和鱼漂抛到预览落点。
- 鱼漂/鱼线表现冻结为：
  - 甩杆后鱼漂落到湖面目标点。
  - 鱼线在持竿 tip 与鱼漂之间保持可见连接。
  - 鱼上钩时，鱼漂需要出现一段明显的上下浮动提示。
- bite 规则冻结为：
  - 甩杆后在 `0-30s` 之间随机等待上钩。
  - 上钩后玩家按 `左键` 收杆。
  - 收获结果必须通过 HUD / focus message 给出明确提示。
- `MatchStartRing` 从 `v38` 正式交互 contract 中移除，不再作为 fishing 入口所有者。
- fishing 是否可开始，只由“玩家是否接近这根 author 的鱼竿并拿起它”决定。

## 影响范围

- 受影响的 Req ID：
  - `REQ-0025-005`
  - `REQ-0025-006`
- 受影响的文档：
  - `docs/prd/PRD-0025-lake-leisure-and-fishing-foundation.md`
  - `docs/plan/v38-index.md`
  - `docs/plan/v38-lake-leisure-and-fishing-foundation.md`
- 受影响的测试：
  - `tests/world/test_city_fishing_minigame_venue_manifest_contract.gd`
  - `tests/world/test_city_fishing_venue_cast_loop_contract.gd`
  - `tests/world/test_city_lake_lab_scene_contract.gd`
  - `tests/world/test_city_lake_main_world_port_contract.gd`
  - `tests/e2e/test_city_lake_lab_fishing_flow.gd`
  - `tests/e2e/test_city_lake_fishing_flow.gd`
- 受影响的代码文件：
  - `city_game/world/minigames/CityFishingVenueRuntime.gd`
  - `city_game/scenes/labs/LakeFishingLab.gd`
  - `city_game/scripts/CityPrototype.gd`
  - `city_game/scripts/PlayerController.gd`
  - `city_game/ui/PrototypeHud.gd`
  - `city_game/serviceability/minigame_venues/generated/venue_v38_lakeside_fishing_chunk_147_181/lake_fishing_minigame_venue.tscn`
  - 以及新增长竿持有、鱼漂、鱼线相关 visual scene/script

## 处置方式

- [x] PRD 已同步更新（标注 ECN-0028）
- [x] v38 计划已同步更新
- [x] 追溯矩阵已同步更新
- [ ] 相关测试已同步更新

# V33 Building Collapse Destruction Lab Design

## Context

`v33` 不是直接把主世界所有建筑都拉进高成本可破坏系统，而是先建立一个独立实验场景，把“建筑生命值 -> 裂纹 -> 预碎裂准备 -> 临界替换 -> 坍塌 -> 清理”这条链在低干扰环境里完整跑通。实验目标建筑优先复用现成的 [building_scene.tscn](E:/development/godot_citys/city_game/serviceability/buildings/generated/bld_v15-building-id-1_seed424242_chunk_137_136_001/building_scene.tscn)；实验场景本身采用 scene-first authoring：地面、环境、玩家、建筑、战斗根节点和观测用调试节点全部在 `.tscn` 里静态摆放，GDScript 只持有状态机和 runtime-only 行为。

## Chosen Approach

本轮选择“**预准备的坍塌 recipe + 临界时替换为有限刚体块**”路线，而不选择：

- 实时布尔碎裂
- 体素化整栋楼
- 第三方破坏 SDK（Blast/APEX）

原因很直接：

1. 当前建筑主干几乎都是盒子式 building contract，最适合套路化切块。
2. 用户已明确接受首版不持久化、只做内存态坍塌。
3. 先做实验场景可以把性能、视觉和控制变量压到最小。

技术上把系统拆成三层：

- `BuildingDamageRuntime`：生命值、命中点、状态迁移
- `BuildingCrackRuntime`：中度受损时的裂纹/受损视觉
- `BuildingCollapseRuntime`：预碎裂准备、临界替换、碎块清理

## Runtime Architecture

### 1. 实验场景

建议新增一个独立实验场景，例如：

- `res://city_game/scenes/labs/BuildingCollapseLab.tscn`

场景内固定摆放：

- `WorldEnvironment`
- `DirectionalLight3D`
- 大尺寸平直地面
- `Player`
- `CombatRoot`
- `TargetBuildingRoot`

其中 `TargetBuildingRoot` 直接实例化 `building_scene.tscn`，并在其外层再包一层实验专用 runtime 脚本节点，负责接建筑伤害和坍塌状态机。

### 2. 建筑伤害与裂纹

建筑运行时保持一个正式 state：

- `building_id`
- `max_health`
- `current_health`
- `last_hit_world_position`
- `last_hit_local_position`
- `damage_state`
- `fracture_prepared_state`

当火箭弹爆炸命中楼体后，runtime 记录命中点并扣血。血量进入 `damaged` 后，在命中点附近生成裂纹/焦痕 visual。首版裂纹优先用 `Decal` 或低成本 crack quad，不从一开始就搞复杂材质混合。

### 3. 预碎裂准备与坍塌替换

当血量低于中度受损阈值时，启动预碎裂准备。这里的重点不是后台线程里改场景树，而是先准备一个可复用的 **collapse recipe**：

- chunk 列表
- 每块尺寸
- 每块初始局部位置
- shell / hollow 配置
- 命中点附近的优先破坏方向

当血量进入濒毁阈值时：

- 隐藏原建筑主体
- 生成 `CollapseRoot`
- 实例化有限数量 `RigidBody3D` 大块
- 叠加爆炸 / dust / shock 特效
- 定时清理大部分碎块，只保留底座/残骸代理

## Phase Split

### Phase 1: Destruction Lab

只在实验场景交付完整链路：

- F6 运行
- 玩家火箭弹攻击
- 建筑掉血
- 裂纹
- 预碎裂准备
- 临界替换坍塌
- 清理

这阶段的目标是“快速调视觉、快速调阈值、快速调碎块数量”，不受主世界 streaming 干扰。

### Phase 2: Port to Main World

把已验证的 runtime 接回主世界建筑：

- 通过 `building_id`
- 通过命中建筑的 inspection/collision payload
- 通过 `CityChunkScene / CityChunkRenderer` 定位近景建筑节点

首版只要求近景建筑可触发受损与坍塌；不要求离开 chunk 再回来仍维持状态。

## Risks

- 如果在实验场就把碎块数量做太大，主世界移植后会直接踩到物理预算。
- 如果预碎裂准备做成“临界时现算”，切回主世界时容易出现卡顿尖峰。
- 如果实验场景不是 scene-first，而是脚本临时搭场，后面调视觉和节点关系会再次失控。

## Recommendation

`v33` 第一版严格限制目标：

- 一栋楼
- 一种坍塌策略
- 有限数量 chunk
- 无持久化

只要这条链通了，再把相同 runtime 扩展到主世界。不要在 `v33` 首版同时追求：

- 任意建筑 archetype 定制坍塌
- 全城持久化
- 大规模并发坍塌
- 第三方原生破坏 SDK

# V16 Building Serviceability Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 把 `v15 building_id` 推进成“游戏内导出独立建筑场景 + 下次进城稳定替换”的正式闭环。

**Architecture:** 继续沿用现有 chunk/runtime 主链，不另造第二套 building graph。导出链采用“后台线程 prepare export payload，主线程轻量 commit scene/save/Toast”的模式；回城替换链只挂在 `CityChunkScene` 的 near mount/build 阶段，避免任何 per-frame registry 扫描。

**Tech Stack:** Godot 4.6、GDScript、`Thread`、`PackedScene`、`ResourceSaver`、`FileAccess`、现有 `PrototypeHud` Toast 与 chunk streaming/runtime。

---

## Context

`v15` 已经交付三块正式资产：

- `CityPrototype.get_building_generation_contract(building_id)` 能按 `building_id` 直接找回当前 streamed building 的完整 building dict。
- `PrototypeHud.set_focus_message()` 已经是正式可复用的 Toast 层。
- `CityChunkRenderer`/`CityChunkScene` 已经有成熟的“准备 -> mount -> retire”链路，最适合挂 override。

因此 `v16` 不该重新发明 building 序列化格式，也不该发明第二套城市替换 runtime；正确路线是直接消费这三块资产。

## Options

### 方案 A：全部写到 `user://`，导出与 override 都走运行时目录

优点：读写权限最稳，测试不污染仓库。

缺点：用户后续想在 Godot 项目里直接继续编辑 scene，会多一层导入/搬运动作。

### 方案 B：默认优先写源码目录，失败回退 `user://`，override registry 与 scene 同根保存

优点：开发态最符合“导出后直接继续编辑”的目标；如果当前环境写不进源码目录，也不会彻底失败；测试仍可强制定向到 `user://`。

缺点：需要处理 Windows 文件名安全与 `res://` 保存失败回退。

### 方案 C：当前 session 直接热替换楼体

优点：即时反馈最强。

缺点：会把 `v16` 从服务化资产链拉成 runtime hot-swap 项目，风险高、验证面大，还会诱导 remount/per-frame workaround。

推荐：**方案 B**。它最符合“导出后可继续编辑”的真实目标，同时不牺牲运行时鲁棒性和测试卫生。

## Data Flow

```text
laser inspection (v15)
  -> last exportable building result
  -> KEY_KP_ADD
  -> CityPrototype export job request
  -> Thread prepare export payload/manifest paths
  -> main-thread scene build + pack + save + registry write
  -> HUD Toast "重构完了"
  -> next world session / chunk remount
  -> CityChunkRenderer inject override snapshot
  -> CityChunkScene near build
  -> override scene instantiate by building_id
```

## Component Design

### 1. `CityBuildingSceneBuilder.gd`

- 从 `CityChunkScene` 抽取 procedural building 构造逻辑。
- 提供两类入口：
  - `build_runtime_building(building_contract)`：继续给 chunk near group 用。
  - `build_service_scene_root(building_contract, export_metadata)`：把同款建筑重建到 scene-local ground anchor 原点。
- scene pack 前统一递归设置 owner，避免导出成空 scene。

### 2. `CityBuildingSceneExporter.gd`

- 负责：
  - 解析写入根路径
  - 生成安全文件夹名
  - 后台线程 prepare manifest payload
  - 主线程 commit `PackedScene + manifest`
- 默认优先 `res://city_game/serviceability/buildings/generated/`，失败回退 `user://serviceability/buildings/generated/`。

### 3. `CityBuildingOverrideRegistry.gd`

- 持久化最小 registry：
  - `building_id`
  - `scene_path`
  - `manifest_path`
  - `export_root_kind`
- `CityPrototype` 持有 registry，并把快照注入 `CityChunkRenderer`。

### 4. Chunk Override 挂点

- `CityChunkRenderer._build_chunk_payload()` 增加 `building_override_entries` snapshot。
- `CityChunkScene` 在 near building build 时做 O(1) `Dictionary` lookup。
- 命中时实例化 override scene，并递归把 `city_inspection_payload` 重新挂到 scene 中的碰撞节点，保持 `v15` inspection 链不断。

## Testing Strategy

### World Contract Test

- `tests/world/test_city_building_serviceability_export.gd`
- 覆盖：
  - export window state
  - async running/completed
  - scene/manifest/registry 落盘
  - saved scene load + instantiate
  - completion toast

### E2E Flow

- `tests/e2e/test_city_building_serviceability_flow.gd`
- 覆盖：
  - `laser -> KP+ -> export done`
  - 同一路径下 second world session 重载 registry
  - target building override scene 被 mount

### Regression / Guard

- `tests/world/test_city_player_laser_designator.gd`
- `tests/world/test_city_chunk_setup_profile_breakdown.gd`
- `tests/e2e/test_city_runtime_performance_profile.gd`
- `tests/e2e/test_city_first_visit_performance_profile.gd`

## Task Breakdown

### Task 1: 文档与红测

**Files:**

- Create: `docs/prd/PRD-0009-building-serviceability-reconstruction.md`
- Create: `docs/plan/v16-index.md`
- Create: `docs/plan/v16-building-serviceability.md`
- Create: `tests/world/test_city_building_serviceability_export.gd`
- Create: `tests/e2e/test_city_building_serviceability_flow.gd`

### Task 2: 抽取 building scene builder

**Files:**

- Create: `city_game/world/serviceability/CityBuildingSceneBuilder.gd`
- Modify: `city_game/world/rendering/CityChunkScene.gd`

### Task 3: 导出器与 registry

**Files:**

- Create: `city_game/world/serviceability/CityBuildingSceneExporter.gd`
- Create: `city_game/world/serviceability/CityBuildingOverrideRegistry.gd`
- Modify: `city_game/scripts/CityPrototype.gd`

### Task 4: 回城替换挂点

**Files:**

- Modify: `city_game/world/rendering/CityChunkRenderer.gd`
- Modify: `city_game/world/rendering/CityChunkScene.gd`
- Test: `tests/e2e/test_city_building_serviceability_flow.gd`

### Task 5: 验证与 closeout

**Files:**

- Create: `docs/plan/v16-m3-verification-2026-03-16.md`

**Commands:**

- `& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_building_serviceability_export.gd'`
- `& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/e2e/test_city_building_serviceability_flow.gd'`
- `& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_player_laser_designator.gd'`
- `& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_chunk_setup_profile_breakdown.gd'`
- `& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/e2e/test_city_runtime_performance_profile.gd'`
- `& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/e2e/test_city_first_visit_performance_profile.gd'`

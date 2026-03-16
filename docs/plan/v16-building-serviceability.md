# V16 Building Serviceability

## Goal

交付正式的独立建筑导出与回城替换最小闭环：玩家用 `v15` 激光拿到 `building_id` 后，在有效窗口内按小键盘 `+`，系统异步导出独立建筑场景与 sidecar，并在下一次进入城市或 chunk remount 时按同一 `building_id` 把原 procedural building 替换为功能建筑场景。

## PRD Trace

- Direct consumer: REQ-0009-001
- Direct consumer: REQ-0009-002
- Direct consumer: REQ-0009-003
- Guard / Performance: REQ-0009-004

## Dependencies

- 依赖 `v15` 已冻结 `building_id / display_name / generation_locator / get_building_generation_contract()`。
- 依赖 `CityChunkRenderer` 现有 async prepare 模式，沿用 `Thread` 做后台 prepare、主线程 commit。
- 依赖 `PrototypeHud.set_focus_message()` 作为正式 Toast 表现层。

## Contract Freeze

- 小键盘 `+` 是正式导出触发键，不是 debug-only 临时命令。
- 最近一次 exportable inspection 的最小字段冻结为：`inspection_kind / building_id / display_name / generation_locator / source_contract`。
- override registry entry 的最小字段冻结为：`building_id / scene_path / manifest_path / export_root_kind`。
- 导出路径优先级冻结为：`res://city_game/serviceability/buildings/generated/` -> `user://serviceability/buildings/generated/`。
- 已存在 override entry 的 `building_id` 不允许被新的导出 job 静默覆盖，必须返回明确失败状态。
- registry 多路径合并时，preferred registry 的同 `building_id` entry 拥有更高优先级，fallback 只能补缺。
- override 只允许在 next-session / chunk remount 的 near build 链生效；不做当前 session 热替换。

## Scope

做什么：

- 在 `CityPrototype` 新增 building export window、KP+ 触发、异步 job 状态与 Toast 反馈
- 新增 building scene builder，把 procedural building 构造逻辑抽出成可复用模块
- 新增 building export/registry service，负责 scene/manifest/registry 落盘
- 在 `CityChunkRenderer` 注入 override entry snapshot
- 在 `CityChunkScene` near building 构建点按 `building_id` 挂 override scene
- 新增 world/e2e tests 与 verification 文档

不做什么：

- 不做 editor UI
- 不做当前 session 热替换
- 不做 mid/far override proxy
- 不做 NPC/功能模块自动注入

## Acceptance

1. 自动化测试必须证明：只有有效的 building inspection window 才能触发 KP+ 导出。
2. 自动化测试必须证明：导出 job 会经历正式 `running -> completed/failed` 状态，并通过 HUD Toast 报告。
3. 自动化测试必须证明：导出完成后，scene 与 sidecar 文件都真实存在，scene 可再次 `load + instantiate`。
4. 自动化测试必须证明：registry 会持久化 `building_id -> scene_path / manifest_path`，并在第二次 world session 中被加载。
5. 自动化测试必须证明：目标 `building_id` 在 next-session near chunk mount 中会实例化 override scene。
6. 自动化测试必须证明：没有 override entry 的 building 继续走 procedural 链。
7. 自动化测试必须证明：`v15` laser inspection / HUD contract 不回退。
8. 串行 profiling 三件套必须继续通过。
9. 自动化测试必须证明：重复导出不会覆盖已存在的功能建筑场景，preferred registry 不会被 fallback 覆盖。
10. 反作弊条款：不得通过空 scene、只写日志、当前 session 强制 remount 全部 chunk、或 per-frame 全量 registry 扫描来宣称完成。

## Files

- Modify: `city_game/scripts/CityPrototype.gd`
- Modify: `city_game/world/rendering/CityChunkRenderer.gd`
- Modify: `city_game/world/rendering/CityChunkScene.gd`
- Create: `city_game/world/serviceability/CityBuildingSceneBuilder.gd`
- Create: `city_game/world/serviceability/CityBuildingSceneExporter.gd`
- Create: `city_game/world/serviceability/CityBuildingOverrideRegistry.gd`
- Create: `tests/world/test_city_building_serviceability_export.gd`
- Create: `tests/e2e/test_city_building_serviceability_flow.gd`
- Create: `tests/world/test_city_building_override_registry_priority.gd`
- Create: `docs/plan/v16-index.md`

## Steps

1. 写失败测试（红）
   - 先写 world contract test，覆盖 export window、job state、scene/sidecar/registry 落盘。
   - 再写 e2e flow，覆盖 `laser -> KP+ -> Toast -> next session override`。
2. 运行到红
   - 预期失败点是当前仓库没有 building export runtime、没有 registry、也没有 chunk override mount。
3. 实现（绿）
   - 抽取 `CityBuildingSceneBuilder`，复用现有 procedural building 生成逻辑。
   - 新增 exporter/registry service。
   - 在 `CityPrototype` 接 KP+、异步 job、Toast 与路径配置。
   - 在 `CityChunkRenderer/CityChunkScene` 接 override snapshot 与 instantiate。
4. 运行到绿
   - `test_city_building_serviceability_export.gd`
   - `test_city_building_serviceability_flow.gd`
   - `test_city_player_laser_designator.gd`
5. 必要重构（仍绿）
   - 收口 export path 解析、scene owner 赋值、manifest 写入与 override metadata。
6. E2E
   - 跑 `test_city_building_serviceability_flow.gd`。
   - 串行跑性能三件套。

## Risks

- 如果导出 scene 仍依赖 chunk-local center，而不是稳定的 scene-local anchor，未来编辑会立刻变得难用。
- 如果 override 查询被放进每帧链，会直接踩 profiling 红线。
- 如果 registry 只存在内存、不落盘，下一次进城 replacement 就是假的。

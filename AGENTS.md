# AGENTS.md

本文件是仓库级 AI/新人协作规约。目标是让 agent 在 `E:\development\godot_citys` 里做出可运行、可验证、不会误伤的改动。它描述当前工程现实，不描述理想化口号。

## 项目概览

### 项目摘要

- 本仓库是 Godot `4.6` 的 `70km x 70km` low poly 城市运行时原型，目标是稳定的大世界流式体验，不是静态高模展示工程。
- 代码与计划链已经从 `v1` 推进到 `v61`。现有正式主链至少包括：导航 / 地图 / 瞬移 / 自动驾驶、任务 runtime / marker / trigger、服务建筑 / landmark / authored venue、车载电台与 native backend、scene preview 插件、湖区 / 钓鱼、直升机 / 无人机 / 火炮链、机械狗 creature runtime。
- `docs/plan/vN-*.md` 与对应 verification 文档是 closeout 真源。根目录 `README.md` 仍是早期 skeleton 口径，不能代表当前项目范围；不要按 README 判断真实架构或测试面。

### 沟通与工作区

- 默认用中文沟通；只有代码标识符、文件名、命令、测试名保留英文。
- 默认直接在 `main` 上连续推进，不主动创建 `git worktree`。
- 当前源码真源目录就是 `E:\development\godot_citys`；如果历史上遗留了旧 worktree，以此目录为准。

### 文档与计划链

- `docs/prd/`：产品目标、冻结范围、PRD 真源。
- `docs/plans/`：设计稿、研究沉淀、实现前方案。
- `docs/plan/vN-*.md`：版本化计划、里程碑、verification 回链。
- `docs/ecn/`：范围变更、冻结口径变化、重规划说明。
- 需要调整 DoD、性能红线、里程碑范围、或 “fully / 全套” 定义时，先更新对应 `docs/plan/vN-index.md`，必要时补 `docs/ecn/`，再改实现。

## 快速命令

命令默认在 PowerShell 中执行。先统一两个变量：

```powershell
$project='E:\development\godot_citys'
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'
```

- 项目导入 / 解析检查：

```powershell
& $godot --headless --rendering-driver dummy --path $project --quit
```

- 本地运行主场景：

```powershell
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64.exe' --path $project
```

- 冒烟测试：

```powershell
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/test_city_skeleton_smoke.gd'
```

- 单个 `world` 测试模板：

```powershell
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/<test-name>.gd'
```

- 单个 `e2e` 测试模板：

```powershell
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/e2e/<test-name>.gd'
```

- 恢复 radio native backend 缺失的 `avfilter-11.dll`：

```powershell
pwsh -File .\scripts\restore-radio-ffmpeg-avfilter.ps1
```

- 构建 radio native backend（仅在改 `city_game/native/radio_backend/src/*` 或 `SConstruct` 时）：

```powershell
Push-Location "$project\city_game\native\radio_backend"
scons platform=windows target=template_debug
Pop-Location
```

- 性能护栏三件套，必须隔离顺序执行：

```powershell
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/world/test_city_chunk_setup_profile_breakdown.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/e2e/test_city_first_visit_performance_profile.gd'
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/e2e/test_city_runtime_performance_profile.gd'
```

说明：

- closeout 默认顺序冻结为 `chunk setup -> first-visit -> warm runtime`。
- 当前仓库没有统一的 `npm build` / `uv sync` / formatter 流水线；不要编造不存在的构建命令。
- 真正的 correctness gate 仍是受影响的 Godot headless 测试，以及必要时的 profiling / tools 测试。

## 架构概览

### 主要区域

- 运行时入口：
  - 主场景：`res://city_game/scenes/CityPrototype.tscn`
  - 主脚本：`res://city_game/scripts/CityPrototype.gd`
  - 玩家控制：`res://city_game/scripts/PlayerController.gd`
- 世界生成 / 导航 / 任务：
  - `res://city_game/world/generation/*`
  - `res://city_game/world/navigation/*`
  - `res://city_game/world/tasks/*`
  - 共享 contract：`place_query / route_target_index -> CityResolvedTarget -> route_result -> map/minimap/HUD/fast travel/autodrive/task pin/world ring`
- Streaming 与渲染：
  - `res://city_game/world/streaming/*`
  - `res://city_game/world/rendering/*`
  - terrain / road surface / chunk renderer 仍是性能主战场
- 行人 / 车辆：
  - `res://city_game/world/pedestrians/*`
  - `res://city_game/world/vehicles/*`
- 作者场景 / feature / venue：
  - `res://city_game/world/features/*`
  - `res://city_game/world/serviceability/*`
  - `res://city_game/world/minigames/*`
  - 已落地链路包括 `service building / landmark / interactive prop / soccer / tennis / missile command / lake fishing / music road`
- 电台与原生后端：
  - GDScript 侧：`res://city_game/world/radio/*`
  - GDExtension：`res://city_game/native/radio_backend/*`
  - 恢复脚本：`scripts/restore-radio-ffmpeg-avfilter.ps1`
- 战斗与 creature：
  - 直升机：`res://city_game/combat/helicopter/*`
  - 火炮：`res://city_game/combat/artillery/*`
  - 无人机：`res://city_game/combat/drone/*`
  - creature：`res://city_game/world/creatures/*`
  - 近期新增的机械狗位于 `res://city_game/world/creatures/quadrupeds/*`
- 编辑器 / 工具：
  - scene preview 插件：`res://addons/scene_preview/*`
  - tool 脚本：`tools/scene_preview/*`、`tools/music_score_preview/*`
- 参考区：
  - `refs/` 只用于比对 / 借鉴，默认视为只读参考区

### 数据流

```text
CityPrototype
  -> CityWorldGenerator
     -> road_graph + block_layout + pedestrian_query + vehicle_query + task_catalog
     -> deferred place_index / place_query / route_target_index
  -> CityChunkStreamer + CityChunkRenderer
  -> CityChunkNavRuntime / CityRoutePlanner
     -> resolved_target + route_result
  -> full map / minimap / HUD / fast travel / autodrive / task pins / world ring
  -> authored features / venues / combat wrappers / creature runtimes
  -> radio controller -> GDScript backend -> native backend (optional)
```

### 配置、持久化与产物

- 启动与输入：`project.godot`
  - 当前主场景仍是 `CityPrototype.tscn`
  - 车载电台热键也在这里定义
- 世界缓存：
  - `user://cache/world/road_graph_*.bin`
  - `user://cache/world/place_index/place_index_*.bin`
  - `user://cache/world/road_surface/road_surface_*.bin`
- 电台缓存 / 用户状态：
  - `user://cache/radio/*`
  - `user://radio/*`
- 验收产物：
  - `reports/v13/*.png` 与同名 `.json` 由 `test_city_overview_png_export.gd` 生成，不是手工素材
- 编辑器 / 本地产物：
  - `.godot/` 是本地编辑器状态，不要手改
  - `city_game/native/radio_backend/src/build/`、`.sconsign.dblite`、解压出来的 `avfilter-11.dll`、`_extract_avfilter_tmp/` 都是本地产物，不要当源码处理
- 作者 registries / manifests：
  - `CitySceneLandmarkRegistry.gd`、`CitySceneInteractivePropRegistry.gd`、`CitySceneMinigameVenueRegistry.gd`、`CityTerrainRegionFeatureRegistry.gd` 允许读写绝对路径 JSON
  - 修改这类路径前先确认它是不是用户本机 authoring 数据，而不是仓库正式 contract

## 代码风格与约定

- 默认语言是 GDScript，目标引擎 Godot `4.6`
- C++ 只在 `city_game/native/radio_backend/` 内出现；Python / PowerShell 只用于脚本、工具和少量测试
- 当前仓库没有独立 formatter / linter 配置；最低 correctness gate 是受影响的 headless Godot 测试与 profiling / tool 验证
- GDScript 风格沿用现有代码：
  - 缩进使用 Tab
  - 函数 / 变量使用 `snake_case`
  - 脚本 / 场景文件名使用 `PascalCase`
  - 常量使用 `UPPER_SNAKE_CASE`
- deterministic 行为是正式 contract：涉及 `world generation / place index / route_result / task slot / chunk profile / pedestrian query / vehicle query` 的改动，必须保证重复运行可复现
- 共享 contract 优先于私有旁路：
  - 导航、任务、地图、marker 默认继续走同一条 shared chain
  - lab / 主世界 wrapper 默认共享同一套 runtime，不允许轻易分叉
- scene-first / authoring-first：
  - 作者锚点、pivot、visual hierarchy 是真源
  - 优先把修复固化回 `.tscn` / authored local transform，不要留运行时补丁
- 热路径与冷路径分离：
  - `duplicate(true)`、全量 snapshot、全量列表复制优先留在冷路径
  - `_process()`、runtime tick、renderer sync 中避免 deep-copy / full-scan / eager rebuild
- `.uid` 注意事项：
  - 仓库里已经跟踪了大量 `.uid`
  - 但 `.gitignore` 同时忽略了 `*.uid`；如果新增资源确实需要提交 `.uid`，务必检查 `git status --ignored`，必要时显式 `git add -f`
  - 不要手改 `.uid` 内容来“修引用”

## 安全边界与禁忌

- 不要把 `README.md`、旧聊天记录、旧 closeout 文案当真源
  - 为什么：它们经常落后于 `docs/plan/` 与当前源码
  - 替代：先看对应 `docs/plan/vN-index.md`、相关测试、再看实现
  - 验证：你引用的范围和测试名能在当前仓库中找到

- 不要只靠手测回归
  - 为什么：本仓库关键风险大多在 deterministic contract、shared route/task chain、scene-first contract、profiling guard
  - 替代：改什么就补什么测试；至少跑受影响的 `world` 测试，用户可见链路优先再补一条 `e2e`
  - 验证：相关测试 `PASS`

- 不要没有 fresh profiling 证据就声称“性能改善了”
  - 为什么：本项目把 `60 FPS = 16.67ms/frame` 当硬红线
  - 替代：顺序跑三件套，并把证据回写到新的 `docs/plan/vN-mN-verification-YYYY-MM-DD.md`
  - 验证：三件套结果与 verification 文档一致

- 不要并行跑 profiling 套件
  - 为什么：会污染 `wall_frame`、streaming、mount 数据
  - 替代：只允许单实例、顺序执行
  - 验证：运行时只有一个 Godot profiling 进程

- 不要把导航 / 任务 / marker 退回成第二套隐藏 state
  - 为什么：会破坏 `v12-v14` 收口出来的共享 contract
  - 替代：继续沿 `place_query / resolved_target / route_result / task_pin_projection / world_marker_runtime` 主链扩展
  - 验证：至少补跑相关导航 / 任务 / marker contract 与 e2e

- 不要对 authored 锚点和 visual hierarchy 追加 runtime-only 补偿
  - 为什么：editor 看见的是 A，runtime 跑的是 B，会让锚点、FX、音频、弹道全部失真
  - 替代：先查装配语义、pivot、mount、`reparent(..., keep_global_transform)` 语义；修复固化回 scene
  - 验证：相关 scene contract / presentation contract 仍通过

- 不要让 lab 和主世界各写一套行为逻辑
  - 为什么：直升机、火炮、机械狗这类链路一旦分叉，数值、输入、cleanup、closeout 会迅速漂移
  - 替代：shared logic 留在正式 runtime，lab 和主世界只做 wrapper / 接线差异
  - 验证：focused lab tests 与 main-world tests 同时通过

- 不要手改验收导出物、缓存产物、vendor 目录
  - 为什么：会让 review 看到的内容不再对应真实代码输出
  - 替代：重新跑导出测试；vendor 只在用户明确要求时处理
  - 验证：`git diff -- reports`、`git diff -- refs`、`git diff -- city_game/native/radio_backend/thirdparty`

- 不要擅自修改 `refs/`
  - 为什么：`refs/` 是参考输入，不是产品源码
  - 替代：只读取、比对、摘取设计思路
  - 验证：`git diff -- refs`

## 安全注意事项

- 不要把任何真实密钥、token、私钥、设备标识写进仓库、计划文档或测试日志
- 本仓库大多数 headless 测试默认离线可跑；涉及 radio browser、真实流媒体、网络 API、推送、浏览器自动化时，先说明目的与边界
- 本机外网访问通常需要代理；如果某个联网测试依赖代理，明确记录使用的环境变量或仓库级配置，不要静默依赖本机默认态
- 新增依赖前先确认必要性；当前工程以 Godot / GDScript / 现有脚本为主，不要顺手引入新的外围栈
- 作者 registries 允许读取全局绝对路径；不要把用户本机私有路径、缓存目录或临时 authoring 文件提交进仓库

## 测试策略

### 通用入口

- parse check：

```powershell
& $godot --headless --rendering-driver dummy --path $project --quit
```

- smoke：

```powershell
& $godot --headless --rendering-driver dummy --path $project --script 'res://tests/test_city_skeleton_smoke.gd'
```

### 导航 / 地图 / 任务

- 默认优先跑：
  - `test_city_place_query_resolution.gd`
  - `test_city_resolved_target_contract.gd`
  - `test_city_route_query_contract.gd`
  - `test_city_map_destination_contract.gd`
  - `test_city_minimap_navigation_hud.gd`
  - `test_city_task_catalog_contract.gd`
  - `test_city_task_pin_projection.gd`
  - `test_city_task_world_ring_marker_contract.gd`
  - `test_city_task_route_hides_destination_world_marker.gd`
  - `tests/e2e/test_city_navigation_flow.gd`
  - `tests/e2e/test_city_task_start_flow.gd`

### 电台 / native backend / scene preview

- 改 `city_game/world/radio/*`、`city_game/native/radio_backend/*`、`addons/scene_preview/*` 时，至少关注：
  - `test_city_vehicle_radio_backend_interface_contract.gd`
  - `test_city_vehicle_radio_catalog_repository_sync_contract.gd`
  - `test_city_vehicle_radio_native_bridge_smoke.gd`
  - `test_city_vehicle_radio_native_bridge_playback_contract.gd`
  - `tests/e2e/test_city_vehicle_radio_quick_switch_flow.gd`
  - `tests/e2e/test_city_vehicle_radio_browser_flow.gd`
  - `test_scene_preview_harness_contract.gd`
  - `test_scene_preview_editor_plugin_manifest_contract.gd`
- `tests/tools/*` 包含 Python / PowerShell / 真实样本验证；跑这类测试前先确认环境前提，不要把它们误当成纯 headless contract

### 世界 feature / venue / morphology

- 改 `serviceability / features / minigames / lake / music road / overview export` 时，按影响面至少补跑：
  - `test_city_world_feature_full_map_pin_contract.gd`
  - `test_city_service_building_full_map_pin_contract.gd`
  - `test_city_missile_command_full_map_pin_contract.gd`
  - `test_city_radio_tower_landmark_manifest_contract.gd`
  - `test_city_radio_tower_far_visibility_contract.gd`
  - `test_city_soccer_venue_radio_survives_ambient_freeze.gd`
  - `test_city_overview_png_export.gd`

### 战斗 / creature

- 直升机：
  - `test_city_helicopter_gunship_lab_scene_contract.gd`
  - `test_city_helicopter_gunship_lab_repeatable_combat_contract.gd`
  - `test_city_task_helicopter_gunship_repeatable_reset.gd`
  - `tests/e2e/test_city_task_helicopter_gunship_flow.gd`
- 火炮 / 无人机：
  - `test_city_artillery_ballistics_round_trip_contract.gd`
  - `test_city_artillery_fire_mission_contract.gd`
  - `test_city_player_drone_toggle_contract.gd`
  - `test_city_player_drone_camera_takeover_contract.gd`
  - `test_city_world_howitzer_drone_composite_contract.gd`
  - `tests/e2e/test_city_player_drone_flow.gd`
  - `tests/e2e/test_city_drone_assisted_artillery_operation_flow.gd`
- 机械狗 / creature：
  - `test_robot_dog_scene_contract.gd`
  - `test_robot_dog_joint_contract.gd`
  - `test_robot_dog_leg_visual_pivot_contract.gd`
  - `test_city_player_robot_dog_toggle_contract.gd`
  - `test_city_player_robot_dog_camera_takeover_contract.gd`
  - `test_city_player_robot_dog_ground_locomotion_contract.gd`
  - `tests/e2e/test_city_player_robot_dog_flow.gd`

### 性能护栏

- 修改 `world generation / route planner / task runtime / streaming / chunk rendering / terrain / road surface / HUD / minimap / pedestrians / vehicles` 时，默认至少顺序跑：
  - `test_city_chunk_setup_profile_breakdown.gd`
  - `test_city_first_visit_performance_profile.gd`
  - `test_city_runtime_performance_profile.gd`

### 通用规则

- 改了代码就要补 / 改测试，即使用户没单独要求
- 文档只改文档时可以不跑运行时测试，但不要顺手声称“功能仍然通过”
- 改 `city_game/native/radio_backend/src/*` 时，除了测试，还应重新构建对应 DLL
- 新的 closeout 证据统一回写到对应 `docs/plan/vN-mN-verification-YYYY-MM-DD.md`

## 当前优先级

- 守住 `60 FPS = 16.67ms/frame` 的硬红线，尤其是 `chunk setup / first-visit / warm runtime`
- 保住 `v12-v14` 收口出来的共享导航 / 任务 contract，不允许重新分叉出临时 state
- 保住作者场景与 shared runtime 主链：`service building / landmark / venue / helicopter / artillery / drone / quadruped` 都优先沿正式 runtime 扩展，不要退回各自私有旁路
- 保住 radio / native backend / scene preview 这类外围能力对主世界 runtime 的零回退要求
- 当前 closeout 链已经到 `v61`；继续推进近期系统时，优先从 `v59-v61` 的机械狗、`v54-v58` 的无人机火炮链、`v24/v30/v31` 的 radio/preview 基线继续演进，而不是绕开既有 contract 另起炉灶

## 作用域与优先级

- 根目录 `AGENTS.md` 默认作用于整个仓库
- 当前已有更具体的子目录规约：
  - `city_game/combat/helicopter/AGENTS.md`
  - `city_game/native/radio_backend/AGENTS.md`
  - `city_game/world/creatures/quadrupeds/AGENTS.md`
- 如果未来某个子目录新增自己的 `AGENTS.md`，以更靠近目标文件的那份为准
- 如果同目录存在 `AGENTS.override.md`，则它优先于 `AGENTS.md`
- 全局 `~/.codex/AGENTS.md` 提供跨项目默认值；本仓库内更具体的规则优先
- 用户在聊天中的显式指令始终优先于本文件

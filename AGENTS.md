# AGENTS.md

本文件是仓库级 AI/新人协作规约。它面向当前 `E:\development\godot_citys` 的工程现实，而不是抽象口号。

## 项目概览

### 项目摘要

- 本项目是一个 Godot 4.6 的 `70km x 70km` low poly 城市运行时原型，目标是稳定的大世界流式体验，不是高模展示工程。
- 当前主线已经包含共享道路图、chunk streaming、terrain/page cache、道路 surface page、小地图、分层行人运行时和基础战斗。
- `v7` 已把道路语义 contract 与 runtime guard 收口，但它主要是基础设施版本；后续默认优先做有可见性的系统增量，或直接改善性能/稳定性的工作。

### 沟通约定

- 默认用中文与用户沟通：分析、计划、review、总结、提交说明都用中文。
- 只有代码标识符、文件名、命令、测试名必须保留时才写英文。
- 提到未来方向时，优先用中文：`交通标识系统`、`车辆系统`、`更丰富的行人系统`；如需对应英文，只在第一次出现时括号补充。

### 分支与工作区约定

- 本仓库默认直接在 `main` 上连续推进，不再默认创建或切换 `git worktree`。
- 除非用户在当前对话里明确要求隔离工作区，否则不要再使用 `using-git-worktrees` 工作流，也不要把某个 worktree 当作真实源码主线。
- 如果历史上遗留了本仓库的 worktree，以当前主工作目录 `E:\development\godot_citys` 为真源，避免出现“代码改在 worktree、游戏却从主目录运行”的错位。

## 快速命令

先统一一个本机命令变量：

```powershell
$godot='E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'
```

- 项目导入/解析检查：

```powershell
& $godot --headless --rendering-driver dummy --path 'E:\development\godot_citys' --quit
```

- 本地运行主场景：

```powershell
& 'E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64.exe' --path 'E:\development\godot_citys'
```

- 冒烟测试：

```powershell
& $godot --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/test_city_skeleton_smoke.gd'
```

- 单个测试模板：

```powershell
& $godot --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/<test-name>.gd'
```

- `v7` 道路 contract / guard 快速回归：

```powershell
$tests=@(
  'res://tests/world/test_city_road_semantic_contract.gd',
  'res://tests/world/test_city_road_intersection_topology.gd',
  'res://tests/world/test_city_road_layout_semantic_takeover.gd',
  'res://tests/world/test_city_road_runtime_node_budget.gd'
)
foreach($test in $tests){
  & $godot --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script $test
  if($LASTEXITCODE -ne 0){ exit $LASTEXITCODE }
}
```

- 性能护栏三件套，必须隔离顺序执行：

```powershell
& $godot --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/test_city_chunk_setup_profile_breakdown.gd'
& $godot --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/e2e/test_city_runtime_performance_profile.gd'
& $godot --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/e2e/test_city_first_visit_performance_profile.gd'
```

- 慢速全量回归模板：

```powershell
rg --files tests -g *.gd | ForEach-Object {
  $script='res://'+($_ -replace '\\','/')
  & $godot --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script $script
  if($LASTEXITCODE -ne 0){ exit $LASTEXITCODE }
}
```

说明：

- 当前仓库没有独立的 `npm` / `uv` 安装步骤，也没有正式导出流水线；不要编造 `build` / `lint` 命令。
- 当前最低可执行验证单元就是 Godot headless 测试。

## 架构概览

### 子系统

- 运行时入口：
  - 主场景：`res://city_game/scenes/CityPrototype.tscn`
  - 主脚本：`res://city_game/scripts/CityPrototype.gd`
- 世界生成：
  - 配置：`res://city_game/world/model/CityWorldConfig.gd`
  - 总生成入口：`res://city_game/world/generation/CityWorldGenerator.gd`
  - 输出：`district_graph`、`road_graph`、`block_layout`、`pedestrian_query`
- 共享道路图与道路语义：
  - 图模型：`res://city_game/world/model/CityRoadGraph.gd`
  - 参考式生成：`res://city_game/world/generation/CityReferenceRoadGraphBuilder.gd`
  - 语义模板：`res://city_game/world/rendering/CityRoadTemplateCatalog.gd`
- Streaming 与渲染：
  - 活跃窗口：`res://city_game/world/streaming/CityChunkStreamer.gd`
  - 渲染总控：`res://city_game/world/rendering/CityChunkRenderer.gd`
  - chunk 场景：`res://city_game/world/rendering/CityChunkScene.gd`
  - 地形/道路页面：`CityTerrainPageProvider.gd`、`CityRoadSurfacePageProvider.gd`
- 行人系统：
  - 生成入口：`res://city_game/world/pedestrians/generation/CityPedestrianWorldBuilder.gd`
  - 查询层：`res://city_game/world/pedestrians/model/CityPedestrianQuery.gd`
  - 分层运行时：`res://city_game/world/pedestrians/simulation/CityPedestrianTierController.gd`
  - 渲染层：`res://city_game/world/pedestrians/rendering/CityPedestrianCrowdRenderer.gd`
- 参考仓库：
  - `refs/` 只用于比对/借鉴，默认视为只读参考区。

### 数据流

```text
CityPrototype
  -> CityWorldGenerator
     -> district_graph + road_graph + block_layout + pedestrian_query
  -> CityChunkStreamer
     -> active chunk entries
  -> CityChunkRenderer
     -> prepare payload / page cache / mount scene
     -> CityChunkScene
        -> terrain + road overlay + buildings + pedestrians
  -> HUD / minimap / debug snapshot
```

### 持久化

- 道路图磁盘缓存：`user://cache/world/road_graph_*.bin`
- 道路表面 mask 磁盘缓存：`user://cache/world/road_surface/road_surface_*.bin`
- terrain page 是运行时内存缓存，主入口在 `CityTerrainPageProvider.gd`
- `.godot/` 是本地编辑器/import 状态，不要手改，不要把临时产物当源码处理

## 代码风格与约定

- 语言：GDScript，目标引擎 Godot `4.6`
- 风格：遵循现有 GDScript 代码风格，不新造另一套
  - 缩进使用 Tab
  - 函数/变量使用 `snake_case`
  - 脚本/场景文件名使用 `PascalCase`
  - 常量使用 `UPPER_SNAKE_CASE`
- 当前仓库没有独立 formatter/linter 配置；最低 correctness gate 是 headless Godot 测试和相关 profiling 测试
- 固定 seed 下的 deterministic 行为是正式 contract：涉及 `world generation / road graph / chunk profile / pedestrian query` 的改动，必须保证重复运行可复现
- 跨模块传递 `Dictionary` / `Array` 时，优先保持 schema 稳定；对快照或缓存数据，继续使用 `duplicate(true)` 的防御性复制习惯
- 优先扩展现有主链，不要并行发明旁路：
  - 道路：`CityRoadGraph -> CityRoadLayoutBuilder -> CityRoadMaskBuilder / CityRoadMeshBuilder -> CityChunkRenderer`
  - 行人：`pedestrian_query -> streamer -> tier controller -> renderer`

## 安全边界与禁忌

- 禁止：没有 fresh profiling 证据就声称“性能改善了”
  - 为什么：本项目把 `60 FPS = 16.67ms/frame` 当硬门槛，口头判断没有意义
  - 替代：跑 `test_city_chunk_setup_profile_breakdown.gd`、`test_city_runtime_performance_profile.gd`、`test_city_first_visit_performance_profile.gd`
  - 验证：结果要落到 `docs/plan/` 留档，而不是只写在聊天里

- 禁止：并行运行 profiling 套件
  - 为什么：会污染 `wall_frame`、streaming 和 mount 数据
  - 替代：按顺序隔离执行性能三件套
  - 验证：运行时只有一个 Godot profiling 进程

- 禁止：把道路 runtime 退回成 `Path3D`、`RoadLane`、`RoadSegment`、`RoadIntersection`、`RoadManager` 或 per-segment mesh 节点体系
  - 为什么：会直接破坏 `v4-v7` 期间建立的 streaming/perf 资产
  - 替代：继续走 shared graph、surface page、batched mesh、runtime guard
  - 验证：`tests/world/test_city_road_runtime_node_budget.gd`

- 禁止：只靠手测回归
  - 为什么：这个仓库的关键风险几乎都在 deterministic data contract、streaming 边界和性能护栏
  - 替代：改什么就补什么测试；至少跑受影响模块测试
  - 验证：相关 headless 测试 `PASS`

- 禁止：擅自修改 `refs/`
  - 为什么：`refs/` 是参考输入，不是当前产品源码
  - 替代：只读取、比对、摘取设计思路；如需改动，必须用户明确要求
  - 验证：`git diff -- refs`

- 禁止：提交 secrets、设备 token、私钥、`user://` 缓存产物或本地临时文件
  - 为什么：会造成泄露或污染仓库
  - 替代：凭据只放环境变量/本地 `.env`；缓存只留在运行时目录
  - 验证：提交前检查 `git status --short`

- 禁止：把基础设施版工作包装成“强可见性功能版”
  - 为什么：会误导里程碑预期，像 `v7` 这种版本本来就主要是 contract/guard 收口
  - 替代：在文档、review、提交说明里明确“这是基础设施/护栏/可见功能”哪一种
  - 验证：`docs/plan/vN-*.md` 与实际测试口径一致

## 安全注意事项

- 不要把任何真实密钥、token、私有证书写进仓库或测试日志
- 如需联网获取资料、同步依赖或访问外部服务，优先说明目的，并保持只读/最小化
- 本仓库本地测试默认不依赖线上服务；如果某任务需要代理、API 或推送能力，必须把新增外部依赖写清楚

## 测试策略

### 快速验证

- 冒烟：

```powershell
& $godot --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/test_city_skeleton_smoke.gd'
```

### 单测模板

```powershell
& $godot --headless --rendering-driver dummy --path 'E:\development\godot_citys' --script 'res://tests/world/<test-name>.gd'
```

### 道路 / 语义 / 护栏

- 默认跑：
  - `test_city_road_semantic_contract.gd`
  - `test_city_road_intersection_topology.gd`
  - `test_city_road_layout_semantic_takeover.gd`
  - `test_city_road_runtime_node_budget.gd`

### 性能护栏

- 修改 `world generation / streaming / chunk rendering / terrain / road surface / HUD / minimap / pedestrians` 时，默认至少重跑：
  - `test_city_chunk_setup_profile_breakdown.gd`
  - `test_city_runtime_performance_profile.gd`
  - `test_city_first_visit_performance_profile.gd`

### 通用规则

- 改了代码就要补/改测试，即使用户没单独要求
- 性能测试必须隔离执行，不与其他 Godot 实例并行
- 只改文档时可以不跑运行时测试，但不要顺手声称“功能仍然通过”

## 当前优先级

- 守住 `60 FPS = 16.67ms/frame` 的硬红线，尤其是 warm runtime、first-visit 和 chunk setup 三条线
- 优先做有可见性的系统增量，或直接改善稳定性/性能的工作；不要默认继续堆“用户几乎感知不到”的基础设施版本
- 道路语义后续的默认下游方向是：`交通标识系统`、`车辆系统`、`更丰富的行人系统`，但前提仍是 tests + profiling guard 全部可复核

## 作用域与优先级

- 根目录 `AGENTS.md` 默认作用于整个仓库
- 如果同目录存在 `AGENTS.override.md`，则它优先于 `AGENTS.md`
- 如果未来某个子目录新增自己的 `AGENTS.md`，以更靠近目标文件的那份为准
- 全局 `~/.codex/AGENTS.md` 提供跨项目默认值；本仓库内更具体的规则优先
- 如未来需要让 `refs/` 可编辑，应给 `refs/` 单独放一份 `AGENTS.md`；在那之前，`refs/` 继续视为只读参考区
- 用户在聊天中的显式指令始终优先于本文件

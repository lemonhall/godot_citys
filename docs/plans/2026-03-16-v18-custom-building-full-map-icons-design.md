# 2026-03-16 V18 Custom Building Full-Map Icons Design

## Context

当前仓库已经有三块可复用资产：

- `v16` 的 `building_override_registry.json + building_manifest.json`
- `v12/v14` 的 shared `pin registry + full map + minimap`
- `CityMapScreen` 的正式 full-map 渲染入口

缺的是中间这条链：

`custom building manifest -> lazy pin projection -> full map icon render`

用户已经把范围冻结得很窄：

- 只做 full map
- icon 定义跟建筑放一起
- 启动后懒加载
- 结果缓存到内存
- 慢速标定到 full map
- 每个环节都要考虑性能

## Option A：打开地图时同步扫 registry + manifest + scene

做法：

- 用户按 `M` 的瞬间读取全部 registry entry
- 逐个加载 manifest，必要时再加载 scene 补元数据
- 现场生成 pin，再塞进 full map

优点：

- 代码短
- “打开地图时再做事”看起来像懒加载

缺点：

- 第一次打开地图一定抖
- scene load 会把 CPU 和 IO 尖峰叠在一起
- 如果用户城里有上百个自定义建筑，这条链会直接变成卡顿入口

结论：

- 不取。这是最典型的“功能是对的，时机是错的”。

## Option B：启动后按 registry 渐进式读取 manifest，建立内存 pin cache，full map 只消费 cache

做法：

- 世界启动后，从 override registry 取出 `building_id -> manifest_path`
- 每帧按小批量读取 manifest JSON
- 只消费 manifest，不加载 scene
- 把符合 `full_map_pin.visible` 的建筑投影成正式 pin contract
- pin contract 缓存在内存里；full map 打开时只读取 cache

优点：

- 符合“启动后懒加载、慢速标定”的用户要求
- IO/解析成本可分摊到多帧
- full map 打开时没有额外同步扫盘尖峰
- 不污染 minimap，只需要 `visibility_scope = full_map`

缺点：

- 需要一层新的 runtime/cache
- 必须补 manifest 解析和增量队列 contract

结论：

- 推荐方案。这是唯一同时满足范围冻结、性能纪律和现有主链架构的路径。

## Option C：预先生成独立 pin registry 文件

做法：

- 每次导出或修改建筑时，额外生成一份全局 pin 索引 JSON
- 运行时直接读取 pin 索引，不再读单个 manifest

优点：

- 运行时最轻

缺点：

- 需要新的索引维护链
- 导出、手工编辑 manifest、registry 变更之间容易漂移
- 当前仓库还没有这条增量维护基础设施

结论：

- 当前不取。它适合以后自定义建筑数量真的上千、manifest 读取也开始成为问题之后再做。

## Recommended Design

### 1. Manifest Contract

在 `building_manifest.json` 新增可选 `full_map_pin`：

- `visible`
- `icon_id`
- `title`
- `subtitle`
- `priority`

冻结约束：

- 这是 opt-in contract；缺失时不上图
- 只给 full map 用，不引入 minimap 语义
- 位置不单独存新字段，直接从现有 `source_building_contract / inspection_payload / world_position` 推导

### 2. Lazy Loader Runtime

新增 `CityServiceBuildingMapPinRuntime.gd`：

- 输入：override registry entries
- 行为：把 manifest 读取任务排队，按帧分批推进
- 输出：缓存好的 full-map pin contracts

冻结约束：

- 不加载 `.tscn`
- 不递归扫目录
- 不每帧重读已完成 manifest
- registry 变更时只重排增量 entry

### 3. Shared Pin Integration

运行时把解析出的 pin 送进现有 `CityMapPinRegistry`，但：

- `pin_type = service_building`
- `pin_source = service_building_manifest`
- `visibility_scope = full_map`

这样：

- full map 继续走 shared pin pipeline
- minimap 因 scope filter 自动看不到这批 pin
- loader 每批只推送 pin delta，避免“随着建筑数量增长，每次都整组删光再整组重建”的累积成本

### 4. Full Map Rendering

`CityMapScreen` 继续负责表现层：

- `icon_id -> glyph` 映射放 UI 层
- 咖啡馆 `icon_id = cafe -> ☕`
- pin 继续保留底色圆点，再叠一层 glyph，避免地图上完全失去已有视觉锚点

## Error Handling

- manifest_path 缺失：跳过该 entry，记录 loader state
- manifest JSON 非法：跳过并记录错误，不影响其他建筑
- `full_map_pin` 缺失或 `visible = false`：不上图，但仍算 manifest 已处理
- world position 缺失：跳过该 pin，不加载 scene 补救

## Testing Direction

- manifest lazy loader contract
- startup-delay contract（full map 关闭时 early traversal window 不读 manifest）
- custom building full-map pin integration contract
- full-map-only visibility contract
- existing map/minimap/task pin regressions
- profiling 三件套

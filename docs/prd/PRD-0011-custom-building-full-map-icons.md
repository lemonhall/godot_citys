# PRD-0011 Custom Building Full-Map Icons

## Vision

把 `v16` 导出的自定义建筑场景再往前推进一截：允许某些自定义建筑在自己的 manifest 里声明“我要在 full map 上显示什么 icon”，运行时在启动后懒加载这些 manifest，渐进式把符合条件的建筑 pin 缓存进内存，并在 `M` 全屏地图上用 emoji/icon 标出来。第一批真实 consumer 就是咖啡馆：它在地图上应该有一个咖啡图标，而不是继续淹没在普通建筑海里。

`v18` 的成功标准不是“地图上多画了几个点”，而是同时满足四件事。第一，icon 定义是正式数据 contract，和自定义建筑放在一起，而不是写死在 `CityMapScreen` 或某个场景特判里。第二，加载链必须是懒加载、渐进式、可缓存的；不能在世界启动或开图瞬间同步扫所有场景资源。第三，这批 pin 只进入 full map，不污染 minimap、导航、fast travel 或 autodrive。第四，整条链继续守住 idle HUD、full map、runtime 和 first-visit 的性能纪律。

## Background

- `PRD-0009` 与 `v16` 已经冻结了 `building_id -> scene_path / manifest_path` 的 override contract，自定义建筑的正式落点就是 `building_manifest.json`。
- 当前 `CityMapPinRegistry` 与 full map/minimap 主链已经支持 `icon_id` 字段，但现有 consumer 主要是 destination / task pins，自定义建筑 manifest 还没有 pin 元数据。
- 当前 `CityMapScreen` 会根据 `pin_type` 画彩色圆点，但还没有正式消费 `icon_id -> emoji glyph` 的表现层映射。
- 用户明确冻结了 `v18` 首版边界：只做 full map，不做 minimap，不做 pin 点击导航，不做 fast travel / autodrive 入口。

## Scope

本 PRD 只覆盖 `v18 custom building full-map icons`。

包含：

- 在自定义建筑 manifest 中声明 full-map icon 元数据
- 启动后懒加载所有自定义建筑 manifest，渐进式建立内存 pin cache
- full map 上显示自定义建筑的 icon/emoji
- full map pin 至少支持咖啡馆 icon
- pin 数据只进入 full map scope，不进入 minimap
- 新增相应 contract tests、e2e flow 与性能复验

不包含：

- 不在 `v18` 内交付 minimap icon
- 不在 `v18` 内交付 pin 点击后直接导航/瞬移/自动驾驶
- 不在 `v18` 内交付通用 POI 搜索器或分类筛选器
- 不在 `v18` 内交付“自动根据场景内容推断 icon”的智能识别

## Non-Goals

- 不追求把所有自定义建筑默认自动上图
- 不追求把 emoji 原字符散落进 runtime contract
- 不追求通过同步读取所有场景文件、打开地图时一次性阻塞扫描、或每帧全量扫 manifest 来宣称完成
- 不追求让 minimap、task pin、destination pin 退回第二套渲染逻辑

## Requirements

### REQ-0011-001 自定义建筑 manifest 必须支持正式的 full-map icon 声明

**动机**：如果 icon 定义不在建筑自己的数据旁边，后续上百个自定义建筑一定会退化成代码硬编码表。

**范围**：

- `building_manifest.json` 必须允许声明一个正式的 `full_map_pin` payload
- `full_map_pin` 最小字段冻结为：
  - `visible`
  - `icon_id`
  - `title`
  - `subtitle`
  - `priority`
- 运行时 world position 必须优先从 manifest 里已有的 `source_building_contract / inspection_payload / world_position` 推导；不得为了取坐标去加载整栋场景
- 未声明或 `visible = false` 的自定义建筑默认不上图

**非目标**：

- 不要求 `v18` 首版支持复杂筛选标签或多层级图例
- 不要求 `v18` 首版把 scene 文件里的 metadata 自动回写到 manifest

**验收口径**：

- 自动化测试至少断言：manifest 中存在 `full_map_pin` 时，runtime 能解析出正式 pin contract。
- 自动化测试至少断言：manifest 缺失 `full_map_pin` 时，不会错误生成 full-map pin。
- 自动化测试至少断言：world position 的解析不依赖加载 `.tscn`。
- 反作弊条款：不得通过在 `CityMapScreen` 里写死某个 `building_id -> icon` 表、或直接加载所有场景来宣称完成。

### REQ-0011-002 系统必须以懒加载、渐进式方式建立自定义建筑 full-map pin cache

**动机**：用户已经明确点名性能风险；这条链如果在世界启动或开图时同步扫一遍磁盘，很快就会变成尖峰源头。

**范围**：

- 运行时必须基于 override registry 读取 manifest 路径，而不是自行递归扫描整个目录树
- manifest 读取必须是渐进式的，允许按帧分批推进
- 解析完成后的 pin contract 必须缓存进内存，避免每次开图重读全部 manifest
- registry 变化后，只允许对增量/变更 entry 重新入队，不允许清空重扫

**非目标**：

- 不要求 `v18` 首版引入独立线程或后台 IO worker
- 不要求 `v18` 首版做磁盘级 pin cache 文件

**验收口径**：

- 自动化测试至少断言：loader 支持分批推进，而不是一次 `refresh()` 就把所有 manifest 同步吃完。
- 自动化测试至少断言：同一批 entry 重复配置时，会复用内存 cache，而不是重新解析全部 manifest。
- 自动化测试至少断言：在 full map 保持关闭的 early traversal window 内，manifest 读取计数保持为 `0`，不会提前吃掉 first-visit 帧预算。
- 自动化测试至少断言：没有 manifest_path 的 registry entry 会被安全跳过，而不是中断整条链。
- 反作弊条款：不得通过在 `_ready()` 里一次性同步读完所有 manifest、或每帧重新读磁盘来宣称完成。

### REQ-0011-003 full map 必须显示自定义建筑 icon/emoji，但 minimap 不得被污染

**动机**：用户当前只要求 full map；如果 scope 漂到 minimap，就会直接扩大 UI 复杂度与刷新成本。

**范围**：

- full map 上必须显示来自自定义建筑 manifest 的 pin
- UI 层必须正式消费 `icon_id -> emoji/text glyph` 映射
- 咖啡馆必须在 full map 上显示咖啡图标
- 这些 pin 的 `visibility_scope` 必须冻结为 `full_map`
- minimap snapshot 不得出现这批自定义建筑 pin

**非目标**：

- 不要求 `v18` 首版实现 pin hover tooltip 或点击交互
- 不要求 `v18` 首版支持全部服务业分类

**验收口径**：

- 自动化测试至少断言：打开 full map 后，咖啡馆 pin 出现在正式 render state 中，且带有 `icon_id` 与 emoji glyph。
- 自动化测试至少断言：相同 session 下 minimap pin overlay 不会出现这批自定义建筑 pin。
- 自动化测试至少断言：full map render state 至少能区分 `service_building` 与现有 task/destination pin。
- 反作弊条款：不得通过把 icon 烧进背景贴图、只改截图、或给 minimap/route 主链偷偷塞默认 pin 来宣称完成。

### REQ-0011-004 `v18` 不得破坏现有 map pin 主链与性能红线

**动机**：这是一个地图可见性增量，不是允许牺牲共享 pin 主链和 profiling guard 的豁免令。

**范围**：

- 现有 destination / task pin contract 继续成立
- idle minimap contract 继续成立
- full map 打开/关闭 contract 继续成立
- 串行 profiling guard 继续通过

**非目标**：

- 不要求 `v18` 首版重写整个 full map UI
- 不要求 `v18` 首版做 pin occlusion 或 clustering

**验收口径**：

- 受影响的 full map / minimap / task pin tests 必须继续通过。
- 新增 `v18` world/e2e tests 必须通过。
- 串行运行 `test_city_chunk_setup_profile_breakdown.gd`、`test_city_runtime_performance_profile.gd`、`test_city_first_visit_performance_profile.gd` 必须继续过线。
- 反作弊条款：不得通过 profiling 时关闭自定义建筑 pin loader、关闭 full map icon 绘制、或只在 headless 下走轻量分支来宣称达标。

## Open Questions

- `v18` 是否要支持 pin 点击后直接导航。当前答案：不做，full map 可见性先冻结。
- `v18` 是否要让 exporter 自动生成 `full_map_pin`。当前答案：首版不强制，先让 manifest 成为正式配置入口。
- `v18` 是否要给每一种服务建筑都加 emoji。当前答案：首版只要求咖啡馆真实跑通，其余走 `icon_id -> glyph` 映射扩展。

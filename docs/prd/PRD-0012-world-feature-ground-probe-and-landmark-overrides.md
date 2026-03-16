# PRD-0012 World Feature Ground Probe And Landmark Overrides

## Vision

把“只能替换一栋已有建筑”的 `v16` building override 主链，扩展成一条能把非建筑 authored 内容正式接入大世界的主链。第一批真实 consumer 是喷泉：它不依赖某个 `building_id`，而是作为一个独立地标场景挂在 `chunk_129_142`，玩家走近时像普通世界内容一样被 mount，full map 上还能看到正式地标 icon。与此同时，激光指示器必须从“看地面只告诉我是哪个 chunk”升级到“告诉我这个点在世界里的精确位置，以及它在 chunk 内部的局部坐标”，否则后续的喷泉、电视塔、雕塑、奇怪建筑，乃至未来的山和湖，都没有稳定的 authored 锚点。

`v21` 的成功标准不是“世界里多了一座喷泉”，而是同时满足四件事。第一，非建筑离散地标有正式的 `registry -> manifest -> scene` 主链，不再冒充 building override。第二，激光指示器对地面命中有正式 `ground probe` contract，能提供足够细的摆放坐标。第三，喷泉作为首个真实 consumer 跑通：场景挂进世界、地图有 icon、minimap 不被污染。第四，山和湖这类需要改 terrain/water 的内容虽然不在本版实现，但其路线必须被清楚冻结为“共享 ground probe、不同 runtime family 的 sibling 链”，避免后续再把离散地标和区域地形特征揉成一锅。

## Background

- `PRD-0008` 与 `v15` 已冻结激光 inspection 主链，当前 building hit 能拿到 `building_id`，ground hit 只能输出 `chunk_id/chunk_key/message_text`。
- 当前 ground inspection result 实际已经持有 `world_position`，但 HUD / clipboard 没把它组织成可摆放的 formal payload。
- `PRD-0009` 与 `v16` 已冻结 `building_id -> manifest_path / scene_path -> near mount override`，但这条链天然要求“先有一栋 building”。
- `PRD-0011` 与 `v18` 已冻结基于 manifest 的 lazy full-map pin 主链，证明“scene 旁边的 manifest 数据 contract + full map icon”是可行路线。
- 用户当前的真实需求分成两类：
  - 离散地标：喷泉、电视塔、雕塑、奇怪标志性建筑
  - 区域特征：山、湖
- 这两类东西都需要 placement contract，但只有第一类适合 `scene instantiate`；第二类需要改 terrain / water / nav，不能直接复用喷泉式场景挂载。
- 用户补充了第三个现实约束：像电视塔这类高耸地标，不能因为玩家离远就完全消失；但这也不能靠“完整 landmark scene 永远常驻”来硬顶，否则会直接破坏 streaming 和 LOD 纪律。

## Scope

本 PRD 只覆盖 `v21 ground probe + scene landmark overrides`。

包含：

- 激光指示器对地面命中返回正式 `ground_probe` payload
- 新增独立于 `building_id` 的 `scene_landmark` registry / manifest / scene 主链
- 离散地标在 near chunk mount 时正式挂进世界
- `full_map_pin` 对 scene landmark 变为可选 contract
- 为 tall landmark 冻结可选 `far_visibility` contract，允许未来用廉价 proxy 保持远距可见
- 喷泉作为首个真实 consumer 跑通，目标 chunk 为 `chunk_129_142`
- 为后续山/湖路线冻结 sibling 设计边界

不包含：

- 不在 `v21` 内实现 mountain/lake 的 terrain/water 改造 runtime
- 不在 `v21` 内实现地标编辑器 UI
- 不在 `v21` 内实现 minimap 地标 pin
- 不在 `v21` 内实现 landmark 点击导航、fast travel 或 autodrive

## Non-Goals

- 不追求把 scene landmark 重新包装成 building override
- 不追求让山和湖通过“放一个大场景”来假装解决 terrain/water 问题
- 不追求每帧扫描整城地标 registry 或每次开地图同步扫所有 scene
- 不追求把 emoji glyph 写进 runtime 数据 contract

## Requirements

### REQ-0012-001 激光指示器对地面命中必须输出正式的 ground probe payload

**动机**：如果地面 inspection 仍然只有 `chunk_id`，用户能知道“这是哪块地”，但不知道“这块地里具体哪里该摆喷泉”。

**范围**：

- 当激光命中非 building 地面时，inspection result 必须升级为正式 `ground_probe`
- `ground_probe` 最小字段冻结为：
  - `inspection_kind`
  - `display_name`
  - `chunk_id`
  - `chunk_key`
  - `world_position`
  - `chunk_local_position`
  - `surface_normal`
  - `message_text`
  - `clipboard_text`
- `chunk_local_position` 定义为：相对 chunk center 的局部 `Vector3`
- `clipboard_text` 必须包含 chunk id、chunk key、world position 与 local position
- building hit 现有 contract 不得回退

**非目标**：

- 不要求 `v21` 首版提供编辑 gizmo
- 不要求 `v21` 首版做道路对齐自动旋转

**验收口径**：

- 自动化测试至少断言：ground hit 不再只返回 `inspection_kind = chunk` 的粗粒度文本结果。
- 自动化测试至少断言：ground probe payload 含非空 `chunk_id`、正确 `chunk_key`、`world_position` 与 `chunk_local_position`。
- 自动化测试至少断言：同一世界坐标经 chunk center 反推后，`chunk_local_position` 稳定可复现。
- 自动化测试至少断言：building inspection 仍保留 `building_id` 主链，不被 ground probe 回归破坏。
- 反作弊条款：不得通过只改 HUD 文案、不落正式 payload 字段、或把 local position 写死到测试夹具里来宣称完成。

### REQ-0012-002 系统必须支持独立于 building_id 的 scene landmark override 主链

**动机**：喷泉、电视塔、雕塑之类并不是“替换一栋楼”，它们需要自己的身份、坐标和挂载入口。

**范围**：

- 新增正式 `scene_landmark` registry
- registry entry 至少包含：
  - `landmark_id`
  - `feature_kind`
  - `manifest_path`
  - `scene_path`
- `feature_kind` 在 `v21` 冻结为 `scene_landmark`
- manifest 至少包含：
  - `landmark_id`
  - `display_name`
  - `feature_kind`
  - `anchor_chunk_id`
  - `anchor_chunk_key`
  - `world_position`
  - `scene_path`
  - `manifest_path`
- manifest 可选包含 `far_visibility`：
  - `enabled`
  - `proxy_scene_path`
  - `visibility_radius_m`
  - `lod_modes`
- chunk near mount 时，若当前 chunk 命中相关 landmark entry，则实例化 landmark scene
- landmark scene 的挂载必须是事件驱动的 chunk mount，不允许 per-frame 全量扫描
- `far_visibility.enabled = true` 时，只允许 mid/far LOD 渲染廉价 proxy；不得以“完整近景 scene 远距常驻”代替

**非目标**：

- 不要求 `v21` 首版支持跨很多 chunk 的超大区域 landmark
- 不要求 `v21` 首版做导出器自动生成地标 scene

**验收口径**：

- 自动化测试至少断言：scene landmark registry 能在第二次 world session 中被重新读取。
- 自动化测试至少断言：目标 chunk near mount 时，landmark scene 会被实例化并带有稳定 `landmark_id` 元数据。
- 自动化测试至少断言：没有 registry entry 的 chunk 不会凭空多挂 landmark scene。
- 自动化测试至少断言：landmark mount 只发生在 chunk mount / remount 链路，不需要每帧扫描。
- `far_visibility` 当前先冻结 contract，不要求喷泉在 `v21` 首版启用，但后续电视塔等 tall landmark 不得再另造第二套远距可见系统。
- 反作弊条款：不得把喷泉偷偷绑到某个 fake `building_id`，也不得在 `_process()` 里扫整个 registry 来宣称完成。

### REQ-0012-003 scene landmark manifest 必须允许可选的 full-map pin，喷泉必须成为首个真实 consumer

**动机**：用户明确要求喷泉在 full map 上有地标标记；但山和湖当前不需要，所以 pin 必须是可选 contract。

**范围**：

- `scene_landmark` manifest 必须允许可选 `full_map_pin`
- `full_map_pin` contract 复用 `v18` 的最小字段：
  - `visible`
  - `icon_id`
  - `title`
  - `subtitle`
  - `priority`
- runtime `pin_type` 复用现有 `landmark` 语义，通过 `icon_id` 区分喷泉等具体地标 glyph
- fountain 的 `icon_id` 冻结为 `fountain`
- fountain 的 pin 只进入 full map scope，不进入 minimap
- fountain asset 路径冻结为 `res://city_game/assets/environment/source/fountains/Santo Spirito Fountain.glb`
- tall landmark 可同时声明 `full_map_pin` 和 `far_visibility`，但两者语义不同：前者是地图信息，后者是世界远距可见 proxy

**非目标**：

- 不要求山和湖在 `v21` 上图
- 不要求 `v21` 首版支持 landmark pin 点击交互

**验收口径**：

- 自动化测试至少断言：喷泉 manifest 中声明 `full_map_pin` 时，runtime 会产出正式 pin contract。
- 自动化测试至少断言：full map render state 能看到 `icon_id = fountain` 的 marker。
- 自动化测试至少断言：同一 session 下 minimap overlay 不会出现 fountain pin。
- 自动化测试至少断言：world position 来自 manifest，而不是加载 scene 推导。
- 反作弊条款：不得把喷泉 icon 直接写死在 UI 的 `landmark_id -> glyph` 特判里而绕过 manifest。

### REQ-0012-004 `v21` 不得破坏现有 building override、inspection 和地图性能纪律

**动机**：这是世界特征扩展，不是允许把 `v15/v16/v18` 主链搅乱的豁免令。

**范围**：

- 现有 building inspection / export 主链继续成立
- 现有 service building full-map pin 主链继续成立
- `scene_landmark` pin 不得污染 minimap
- profiling 三件套继续作为 guard

**非目标**：

- 不要求 `v21` 重写整个 chunk renderer
- 不要求 `v21` 首版支持 terrain region 修改

**验收口径**：

- 受影响的 inspection / map pin / full map tests 必须继续通过。
- 新增 `v21` ground probe / landmark runtime / fountain flow tests 必须通过。
- 串行运行 `test_city_chunk_setup_profile_breakdown.gd`、`test_city_runtime_performance_profile.gd`、`test_city_first_visit_performance_profile.gd` 仍需过线。
- 反作弊条款：不得通过 profiling 时关闭 landmark loader、关闭 fountain pin 或跳过 ground probe 解析来宣称达标。

## Open Questions

- mountain / lake 是否要共用同一个 registry 文件。当前答案：不共用实现链，但允许未来共享更上层 `world_feature` 术语与地面 probe 输入。
- `scene_landmark` 是否默认都有 full-map pin。当前答案：否，保持 manifest opt-in。
- `far_visibility` 是否意味着完整地标 scene 永远不卸载。当前答案：否，只允许廉价 proxy 在 mid/far LOD 出现。
- 地面 probe 是否需要立即暴露页级 terrain / road page key。当前答案：首版不是硬要求，但可作为扩展字段。

## Future Direction

- 山和湖不应复用 `scene_landmark` 挂载链，而应进入后续 sibling family：`terrain_region_feature`。
- `terrain_region_feature` 共享 `ground_probe` 作为 authored 锚点输入，但 runtime 应接在 terrain / water / nav 页面生成链，而不是简单 instantiate 一个大场景。
- 电视塔、摩天轮、雕塑这类高辨识度 tall landmark，可以继续走 `scene_landmark`，但建议通过 `far_visibility.proxy_scene_path` 提供低成本 silhouette / proxy，而不是让完整装饰版 scene 超距离常驻。

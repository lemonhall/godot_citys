# V18 Custom Building Full-Map Icons

## Goal

交付一条正式的“自定义建筑 manifest -> lazy full-map pin cache -> full map icon render”主链，让咖啡馆等自定义建筑能够以 emoji/icon 的形式出现在 full map 上，同时保持 minimap 清洁、开图无同步扫盘尖峰、运行期不做每帧全量 manifest 读取。

## PRD Trace

- Direct consumer: REQ-0011-001
- Direct consumer: REQ-0011-002
- Direct consumer: REQ-0011-003
- Guard / Performance: REQ-0011-004

## Dependencies

- 依赖 `v16` 已冻结 `building_override_registry.json` 与 `building_manifest.json`。
- 依赖 `v12/v14` 已冻结 `CityMapPinRegistry`、full map、minimap 和 `visibility_scope` 语义。
- 依赖 `CityPrototype` 当前已经在 `_ready()` 与 `_process()` 中持有正式 map pin 主链入口。

## Contract Freeze

- `building_manifest.json` 的 full-map icon contract 冻结为可选 `full_map_pin` object。
- `full_map_pin` 最小字段冻结为：`visible / icon_id / title / subtitle / priority`。
- loader 只读取 manifest JSON，不加载 `.tscn` 补元数据。
- loader 必须支持分批推进与内存缓存；首版不做磁盘 pin cache。
- custom building pin 的最小 runtime contract 冻结为：
  - `pin_id`
  - `pin_type`
  - `pin_source`
  - `visibility_scope`
  - `building_id`
  - `world_position`
  - `title`
  - `subtitle`
  - `priority`
  - `icon_id`
- `visibility_scope` 冻结为 `full_map`。
- `icon_id -> glyph` 映射冻结在 `CityMapScreen` 表现层，不写回 runtime contract。

## Scope

做什么：

- 扩展自定义建筑 manifest，支持 `full_map_pin`
- 新增 lazy loader runtime，按 registry entry 分批读取 manifest
- 把解析出的 pin 接入 shared pin registry
- 让 full map 用 emoji/text glyph 渲染这批 pin
- 用咖啡馆作为首个真实 consumer
- 补 world/e2e tests 与 profiling 证据

不做什么：

- 不做 minimap pin
- 不做 pin click / route / fast travel / autodrive
- 不做通用分类筛选器
- 不做 scene 内容分析式自动 icon 推断

## Acceptance

1. 自动化测试必须证明：loader 能分批推进 manifest 解析，而不是一次性同步吃完全部 entry。
2. 自动化测试必须证明：未声明 `full_map_pin` 的自定义建筑不会错误生成 pin。
3. 自动化测试必须证明：full map 关闭的 early traversal window 内，manifest 读取计数保持为 `0`，不会提前消耗 first-visit 帧预算。
4. 自动化测试必须证明：声明 `full_map_pin` 的咖啡馆会在 full map render state 里出现，并暴露 `icon_id = cafe` 与咖啡 glyph。
5. 自动化测试必须证明：这批 pin 只在 full map 可见，不进入 minimap snapshot。
6. 自动化测试必须证明：现有 task/destination pin contract 不回退。
7. 自动化测试必须证明：idle minimap 继续保持无默认 pin 污染。
8. profiling 三件套必须串行继续过线。
9. 反作弊条款：不得通过硬编码某个 `building_id`、同步加载全部 scene、只改测试夹具、或只在 map 背景里贴一个咖啡图案来宣称完成。

## Files

- Modify: `city_game/ui/CityMapScreen.gd`
- Modify: `city_game/world/map/CityMapPinRegistry.gd`
- Modify: `city_game/scripts/CityPrototype.gd`
- Modify: `city_game/serviceability/buildings/generated/bld_v15-building-id-1_seed424242_chunk_137_136_003/building_manifest.json`
- Modify: `tests/world/test_city_map_pin_overlay.gd`
- Create: `city_game/world/serviceability/CityServiceBuildingMapPinRuntime.gd`
- Create: `tests/world/test_city_service_building_map_pin_runtime.gd`
- Create: `tests/world/test_city_service_building_map_pin_startup_delay_contract.gd`
- Create: `tests/world/test_city_service_building_full_map_pin_contract.gd`
- Create: `tests/e2e/test_city_service_building_full_map_icon_flow.gd`
- Create: `docs/plan/v18-index.md`

## Steps

1. 写失败测试（红）
   - 先写 `test_city_service_building_map_pin_runtime.gd`，覆盖 manifest 分批加载与 pin cache。
   - 再写 `test_city_service_building_map_pin_startup_delay_contract.gd`，覆盖 full map 关闭时的 startup delay / early-window no-IO contract。
   - 再写 `test_city_service_building_full_map_pin_contract.gd`，覆盖 full map icon integration 与 minimap exclusion。
   - 再写 `test_city_service_building_full_map_icon_flow.gd`，覆盖用户打开 full map 后看到咖啡馆 icon 的整链路。
   - 同步调整 `test_city_map_pin_overlay.gd`，把旧的“registry 必须完全为空”收紧为“idle minimap 不得被默认 pin 污染”。
2. 运行到红
   - 预期失败点必须落在：当前没有正式 `full_map_pin` contract、没有 lazy loader runtime、full map 也还不会渲染 glyph。
3. 实现（绿）
   - 新增 `CityServiceBuildingMapPinRuntime.gd`。
   - 在 `CityPrototype` 里驱动 lazy loader，并把 pin 接入 shared pin registry。
   - 在 `CityMapScreen` 里新增 `icon_id -> glyph` 表现层映射与 render state。
   - 给咖啡馆 manifest 增加 `full_map_pin`。
4. 运行到绿
   - 跑新增 world tests 和 e2e。
5. 必要重构（仍绿）
   - 收口 registry delta sync、manifest decode 和 UI glyph 逻辑，避免 `CityPrototype` 继续膨胀，也避免每批 lazy load 都整组重建 `service_building` pins。
6. E2E
   - 跑 full map icon flow。
   - 补跑 map/minimap/task pin 回归与 profiling 三件套。

## Risks

- 如果 loader 每帧重扫 registry/manifest，`v18` 会变成持续性 CPU/IO 噪声源。
- 如果把自定义建筑 pin 直接塞进 minimap scope，现有 idle HUD contract 会被破坏。
- 如果 emoji 映射写进 runtime contract，后续 UI 换字体/换表现会变得很僵。

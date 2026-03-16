# 2026-03-16 V15 Laser Designator Design

## Context

`v15` 要做的不是第三种伤害武器，而是一条 inspection 主链：玩家切到 `laser designator`，左键打一束绿色激光，命中建筑读唯一建筑名字和 `building_id`，命中地面读 chunk，结果复制到剪贴板，消息 `10` 秒后自动消失。现有仓库已经有三块可复用资产：

- `PlayerController.gd` 已经拥有 weapon mode、ADS、aim trace、grenade preview 与左/右键处理。
- `v12` 已经冻结了 `CityAddressGrammar`、`CityPlaceIndexBuilder.resolve_address_target_data()` 与 chunk/address contract。
- `PrototypeHud.gd` 已经有 crosshair 与 HUD root，但没有正式 toast/message 层。

真正缺的不是“怎么射线检测”，而是三层桥接：

1. 让 near chunk building collider 挂上 deterministic building identity payload。
2. 让 inspection result 既能给 HUD 短时显示，也能给 clipboard 完整复制。
3. 让 `building_id` 将来能回到 generation params，而不是停留在一次性文本层。

## Approach Options

### 方案 A：命中后临时扫 `place_index / block_layout`，现场反推地址

优点：不需要改 chunk scene building metadata。

缺点：每次命中都要做逆向查找；`resolve_world_point()` 拿到的是 raw world point，不是 formal building identity。这个方案会把 `v15` 变成“命中后重建一遍语义”，耦合更高。

### 方案 B：在 chunk profile/scene 建楼时就挂 inspection payload

优点：命中时只读 collider meta，事件链简单；chunk building 与 chunk streaming 生命周期天然一致；可以直接把 `building_id / display_name / place_id / chunk_id` 暴露给 tests。

缺点：需要扩展 profile builder 和 chunk scene。

### 方案 C：单独新建全球 persistent building index / city JSON

优点：长期最正式。

缺点：明显超出 `v15` 范围，会把一次 inspection 功能扩成新的 world registry 项目。

推荐：**方案 B**。它最符合 `v15` 的范围硬度，也最容易守住 tests + profiling。

## Chosen Design

### 1. Weapon/Input

- 在 `PlayerController.gd` 新增 `laser_designator` weapon mode 与 `laser_designator_requested` signal。
- `0` 切到激光指示器。
- 左键在 `laser_designator` 模式下发出一次 request，不生成 projectile/grenade。
- 右键继续复用 ADS 口径，避免为 inspection 再造一套瞄准状态。

### 2. Building Inspection Payload

- 在 `CityChunkProfileBuilder.gd` 基于当前 chunk 的 `block_layout + road_graph + street_cluster_catalog + vehicle_query` 生成一组 deterministic frontage address candidates。
- 把这些 candidate 按空间最近原则分配给本 chunk 的 visual buildings，并按稳定排序给每栋楼分配 `building_local_index`。
- `display_name` 不再只是 inspection label，而是冻结成“地址标签 + 稳定 building code”的唯一建筑名字。
- `building_id` 冻结为 `world seed + chunk_id + building_local_index` 组成的 deterministic building identity。
- payload 同时保留 `address_label / place_id / chunk_id / chunk_key / generation_locator`，让未来能按 `building_id` 找回生成参数。
- 在 `CityChunkScene.gd` 创建 building `StaticBody3D` 时，把这些字段挂到 collider meta。

### 3. Runtime Inspection + HUD + Clipboard

- 在 `CityPrototype.gd` 新增 laser fire handler：用玩家瞄准射线做静态世界 trace，忽略动态 actor，优先命中 building/static world。
- 命中 building：读 meta，生成 building inspection result。
- 命中其他静态表面：按 `CityChunkKey.world_to_chunk_key()` 生成 chunk inspection result，并附上 mounted chunk stats。
- 新增轻量 beam 节点显示短时绿色激光。
- 在 `PrototypeHud.gd` 新增 focus message layer，显示 inspection 文本并在 `10` 秒后自动消失。
- `message_text` 用于 HUD 简明展示，`clipboard_text` 用于复制完整字段；第二次 inspection 必须立刻覆盖第一次。

### 4. Future Anchor

- `v15` 不交付完整的功能建筑替换系统，但必须先交付一个可复用的锚点：
  - inspection result 里有 `building_id`
  - runtime 能按 `building_id` 找到当前 streamed generation contract
  - generation contract 足够指向将来的 city cache JSON entry
- 这样未来才能顺着这条链做：
  - 按 `building_id` 找 building params
  - 独立场景重建
  - 用户编辑功能建筑
  - 再进城时替换原建筑

## Data Flow

`PlayerController(laser mode)` -> `laser_designator_requested` -> `CityPrototype` static trace -> `CityWorldInspectionResolver` -> `PrototypeHud focus message` + clipboard + `CityLaserDesignatorBeam`

building path：

`chunk payload` -> `CityChunkProfileBuilder` address candidate assignment + stable local index -> `building_id/display_name/generation_locator` -> `CityChunkScene` collider meta -> hit -> HUD text + clipboard text

ground path：

`hit.position` -> `CityChunkKey.world_to_chunk_key` -> optional `chunk_renderer.get_chunk_scene_stats()` -> HUD text

## Testing

- world contract：
  - player can enter `laser_designator`
  - laser mode does not emit projectile/grenade
  - building hit returns stable `building_id + display_name + generation locator` payload
  - current streamed building payloads keep `building_id/display_name` uniqueness
  - `building_id` can resolve back to generation contract
  - ground hit returns chunk payload and replaces prior HUD/clipboard result immediately
- e2e：
  - player request fires actual laser
  - HUD message becomes visible
  - clipboard text contains `building_id`
  - message auto-clears after `10` seconds
- regression：
  - existing rifle/grenade/crosshair tests
  - performance three-piece serial rerun

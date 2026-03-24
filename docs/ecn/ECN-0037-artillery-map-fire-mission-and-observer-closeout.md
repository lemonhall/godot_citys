# ECN-0037: Artillery Map Fire Mission And Observer Closeout

## 基本信息

- **ECN 编号**：ECN-0037
- **关联 PRD**：PRD-0029
- **关联 Req ID**：
  - `REQ-0029-018`
  - `REQ-0029-019`
  - `REQ-0029-020`
  - `REQ-0029-021`
  - `REQ-0029-022`
  - `REQ-0029-023`
- **发现阶段**：v52 closeout 后的 artillery 下一轮玩法冻结
- **日期**：2026-03-25

## 变更原因

`v50-v52` 已经把 howitzer HUD、主世界 summon、live shell 与 ballistic solver 主链全部建立起来，但玩家侧仍然缺少一条真正像“炮兵任务”的闭环：

- full map 只有左键目的地选点，没有右键火力任务菜单；
- solver 虽然能反解 bearing / pitch，但还没有正式的地图入口把它交给玩家；
- accepted fire 之后，镜头仍然主要停留在炮位附近，缺少“目标区观察弹着”的正式 closeout；
- 当前 chunk 预热能力已经存在，却还没被用于炮击观察。

用户的新目标非常明确：在大地图上右键目标点，选择 `炮击标记`，立刻得到 bearing / pitch；随后玩家用既有 howitzer 手动输入诸元并发射；击发后系统先保留炮口演出，再切到落点区观察爆炸。另外，这条观察链不能只服务“标准逆解流程”，free fire 也必须拥有同口径的观察效果。

## 变更内容

### 原设计

- full map 只支持 destination 选点；
- artillery solver 没有 map-side UI 真入口；
- howitzer summon 默认总是取当前玩家前方；
- live shell impact 没有正式 observer closeout；
- prewarm 能力只用于 spawn / streaming，不服务 artillery impact。

### 新设计

- 新增正式 `REQ-0029-018 Full-Map Artillery Context Menu Contract`
  - 地图画布内 right-click 可弹出 `炮击标记`
- 新增正式 `REQ-0029-019 Artillery Fire Mission Marker Contract`
  - 单个 active 黄色 cross marker + formal chunk metadata
- 新增正式 `REQ-0029-020 Map-Side Fire Solution Presentation Contract`
  - map 直接消费 shared ballistic solver 给出 bearing / pitch / range / arc
- 新增正式 `REQ-0029-021 Planned Battery Snapshot And Summon Contract`
  - 先规划再 `KP_8` 召唤时，howitzer 复用同一个 battery snapshot
- 新增正式 `REQ-0029-022 Artillery Observation Closeout Contract`
  - accepted fire 后预测落点、预热 chunk、切 observer camera 观察 impact
- 新增正式 `REQ-0029-023 Free-Fire Observation Compatibility Contract`
  - 没有 map mission 的随意一炮也必须进入观察 closeout

## 影响范围

- 受影响的 Req ID：
  - `REQ-0029-018`
  - `REQ-0029-019`
  - `REQ-0029-020`
  - `REQ-0029-021`
  - `REQ-0029-022`
  - `REQ-0029-023`
- 受影响的 vN 计划：
  - `docs/plan/v53-index.md`
  - `docs/plan/v53-artillery-map-fire-mission.md`
- 受影响的测试：
  - `tests/world/test_city_map_artillery_context_menu_contract.gd`
  - `tests/world/test_city_artillery_fire_mission_contract.gd`
  - `tests/world/test_city_artillery_fire_mission_observer_closeout_contract.gd`
  - `tests/e2e/test_city_map_artillery_fire_mission_flow.gd`
- 受影响的代码文件：
  - `city_game/ui/CityMapScreen.gd`
  - `city_game/world/map/CityMapPinRegistry.gd`
  - `city_game/combat/artillery/CityArtilleryFireMissionRuntime.gd`
  - `city_game/scripts/CityPrototype.gd`
  - `city_game/ui/PrototypeHud.gd`

## 处置方式

- [x] PRD 已同步更新
- [x] v53 计划已同步更新
- [x] 追溯矩阵待本轮实现后回填
- [ ] 相关测试待本轮实现后落地

# ECN-0006: 参考式连续道路图与 2D 小地图/导航层

## 基本信息

- **ECN 编号**：ECN-0006
- **关联 PRD**：PRD-0001
- **关联 Req ID**：REQ-0001-002、REQ-0001-005、REQ-0001-006、新增 REQ-0001-009
- **发现阶段**：v2 收尾后的人工巡检
- **日期**：2026-03-11

## 变更原因

当前 v2 的道路网络虽然已从“纯方格”推进到“较自然的连续道路”，但核心生成机制仍是 `district edge + local cell` 的混合方案。它可以勉强支撑 chunk continuity，却很难稳定产出参考项目那种“整张城市道路图先长出来，再由局部约束修边、吸附、切分、成网”的自然感。

同时，`70km x 70km` 城市如果没有一张共享同源的 2D 地图层，后续的小地图、导航路径高亮、道路命名、POI 辨认都会变成临时拼装 UI，而不是建立在同一份世界道路图之上的稳定系统。

参考项目 `refs/citygen-godot` 已证明：2D 连续道路图不是“额外附属品”，而是 3D 城市骨架、小地图与导航的共同上游。

## 变更内容

### 原设计

- `road_graph` 由 district graph 与本地 collector/secondary 衍生；
- 3D chunk 渲染消费这份道路图，再叠加本地 cell 内部道路；
- 没有统一的 2D 小地图/导航投影层。

### 新设计

- v3 将道路骨架升级为“参考式连续道路图”：
  - 先用全局 segment growth 生成主干路/支路；
  - 再用局部约束执行相交、吸附、近距离接入、必要切分；
  - 最后把结果作为唯一的 world-space 道路图输入给 3D chunk 渲染、2D 小地图和导航层。
- 新增一份 2D 城市投影：
  - 直接消费 world road graph；
  - 输出可供 HUD 小地图、路径高亮、玩家朝向标记和后续 POI 标注复用的绘制数据。
- 小地图不是独立随机生成，而是与 3D 城市严格同源。

## 影响范围

- 受影响的 Req ID：
  - REQ-0001-002：城市骨架生成
  - REQ-0001-005：导航与宏观路由
  - REQ-0001-006：运行时观测
  - 新增 REQ-0001-009：2D 小地图与导航投影
- 受影响的 vN 计划：
  - 新增 `docs/plan/v3-index.md`
  - 新增 `docs/plan/v3-reference-road-graph.md`
  - 新增 `docs/plan/v3-minimap-navigation.md`
- 受影响的测试：
  - 新增 world road graph 生长/局部约束测试
  - 新增 minimap 投影与路径高亮测试
  - 新增 HUD 小地图 E2E 测试
- 受影响的代码文件：
  - `city_game/world/generation/*`
  - `city_game/world/model/*`
  - `city_game/world/navigation/*`
  - `city_game/ui/*`
  - `city_game/scripts/CityPrototype.gd`

## 处置方式

- [x] PRD 已同步更新（标注 ECN-0006）
- [x] v3 计划已建立
- [x] 追溯矩阵已同步更新
- [x] 相关测试已同步更新

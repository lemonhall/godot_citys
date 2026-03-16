# 2026-03-16 V19 Gun Shop Service Scene Design

## Context

当前仓库已经有两条可直接复用的正式主链：

- `v16` 的 `building_id -> manifest_path / scene_path -> override mount`
- `v18` 的 `building_manifest.json -> full_map_pin -> full map icon`

这次不是再发明一条新基础设施，而是把一栋已经被用户手工挑出来的导出建筑，真正做成一个像样的功能建筑 consumer：

- 场景文件已经存在：`枪店_A.tscn`
- manifest 和 registry 已经有 entry
- 但当前 scene 还是一个空壳 block，门面、入口、室内陈列、招牌都没有完成
- manifest / registry 还保留了旧的 `building_scene.tscn` 路径，不足以稳定挂 override

## Option A：只修路径，不做室内与门面

优点：

- 最快
- 能让 override scene 至少加载起来

缺点：

- 用户明确要的是“掏空 + 门 + 枪店装修”，这条路只是在修数据，不是在交付建筑
- 空壳建筑就算能 mount，也不具备 review 价值

结论：

- 不取。

## Option B：沿咖啡馆模式做一栋完整但轻量的枪械店

做法：

- 保留 `StaticBody3D + shell + interior + lighting + service anchors` 结构
- 前立面切出正式门洞，做橱窗、招牌和微开的双扇门
- 室内用低 poly 盒体组织出枪柜、展示柜、弹药墙、工作台和地毯
- manifest / registry 指向 `枪店_A.tscn`
- 同步给 manifest 增加 `full_map_pin`，让这栋枪店直接接入 `v18` full-map icon 主链

优点：

- 完整复用现有 contract
- 视觉结果可见
- 不需要新的 runtime 或 editor infrastructure

缺点：

- 需要补一组 scene / manifest / full-map pin contract tests

结论：

- 取这个方案。

## Frozen Design

### 1. 门面

- 枪店前脸采用深色金属框 + 暗红木饰面
- 前立面必须是“左右立柱 + 门楣 + 中央门洞 + 两侧橱窗”的结构，而不是整片实心前墙
- 招牌同时给两层语义：
  - 主招牌：`ELMAESTEAD ARMS`
  - 图形符号：允许用枪形轮廓 / 武器类 icon，作为远看识别点

### 2. 室内

- 典型氛围冻结为：小型街边枪械店，不做靶场，不做夸张军火库
- 必须有：
  - 前区展示柜
  - 侧墙枪架
  - 后墙弹药 / 配件陈列
  - 收银台 / 维修台
  - 至少三盏暖色灯
- 不做：
  - 复杂骨骼门动画
  - 可拾取武器逻辑
  - NPC 店员对话

### 3. 数据接线

- registry 与 manifest 的 `scene_path` 都改为 `枪店_A.tscn`
- manifest 增加 `full_map_pin`
  - `icon_id = gun_shop`
  - `title = Elmaestead Arms`
  - `subtitle = 58954803 Elmaestead Lane`
- UI glyph 映射补 `gun_shop -> 🔫`

## Testing Direction

- `gun shop scene contract`
  - scene 可加载
  - 门洞 / 橱窗 / 室内 / 灯光 / anchors 存在
- `gun shop manifest contract`
  - registry / manifest 都指向 `枪店_A.tscn`
  - `full_map_pin` contract 正式存在
- `service building full-map pin runtime`
  - 当前 fixtures 不再只有咖啡馆，必须接受“多个 service-building icons 共存”

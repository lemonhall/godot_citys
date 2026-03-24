# V48 Artillery Interaction Polish Design

## Context

`v46-v47` 已经把 M777 的操炮态、开火态和 rope baseline 做成正式 contract，但用户新的实机反馈说明还差最后一层“可用性与质感”收口：`5m` 进入半径太紧，靠近 howitzer 时体验像在贴碰撞盒；同时 `LanyardLine` 虽然已经连到了玩家，但它继续复用了 fishing minigame 的三点折线实现，在 howitzer 的父级 `x10` 缩放链下会把 sag 放大，结果就是 rope 在地上折出一条怪线。

## Recommended Approach

这轮不去重写交互系统，也不去碰炮口 fire anchor，而是做两处精确修正。第一，正式把 howitzer enter radius 从 `5m` 提升到 `7m`，保留 `20m` retention，不改变 `E` 进入 / 退出与 `J/L/I/K/Space` 的 ownership 语义。第二，给 howitzer 单独 author 一份 `CityArtilleryLanyardLine.gd`，不再共用 fishing 资产。新的 rope visual 仍可沿用轻量的 `ImmediateMesh` / `LINE_STRIP` 路线，但要用多点采样的连续曲线，并且曲线 sag 必须先在 world-space 语义里计算，再回写到 local，避免父级缩放把 0.2 米级下垂放大成贴地错误。

## Testing Strategy

测试直接围绕用户可见症状收口，而不是只验证“脚本存在”。交互侧要证明 `interaction_radius_m == 7.0`，并且 `7m` 外提示隐藏、`7m` 内提示出现。rope 侧要证明两件事：一是 howitzer scene 的 `LanyardLine` 已绑定正式 artillery 专用脚本，不再引用 `FishingLineVisual.gd`；二是操炮态 rope debug state 暴露 `sample_count` 与 `min_world_y`，从而可以自动化断言“不是三点折线”以及“不会被缩放拉到快贴地”。

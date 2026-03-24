# 2026-03-24 V45 World Orientation And Compass Design

## Context

现有 main world、minimap 和 full map 在数学上已经接近 north-up，但它们缺少统一命名与测试守护。与此同时，火炮 lab 已经具备独立 yaw / pitch 调试能力，却还没有“朝向北方多少度”的共享语义。`v45` 的设计目标是先收口 contract，再让 UI 呈现复用这条 contract，而不是在主世界 HUD、lab HUD、map 里分别写三套方向逻辑。

## Recommended Approach

推荐做法是建立一层轻量级 `CityWorldOrientation` helper，专门负责：

- 世界 north/east/south/west 轴定义；
- bearing 归一化与向量转换；
- `heading_rad <-> bearing_deg` 口径转换；
- compass strip 所需的刻度状态生成；
- north-up map contract 的统一字典输出。

这样做的核心收益是：`PrototypeHud`、`CityMinimapProjector`、`CityMapScreen` 和 `M777HowitzerLab` 只消费 shared state，不再自己决定“0 度朝哪边”。地图投影仍保持现有 north-up 数学，不做无谓重写；这一版真正新增的是显式 contract、HUD compass 与 focused tests。

## UI Strategy

主世界 HUD 与 `M777HowitzerLab` 共用同一份 compass strip 视图脚本。它不是完整圆盘，而是 FPS 常见的顶部水平刻度条：中间固定准星，刻度带随 bearing 平移，主刻度显示三位角度或 `N/E/S/W`。这个形态足够直观，也便于后续叠加火炮自身方位角。

同时，在 minimap 与 full map 上增加轻量 north cue，并把 north-up contract 放进 snapshot/render state。这样 tests 可以直接验证，而不需要依赖截图或人工目测。

## Risks

- 如果继续复用多个历史 `atan2()` 公式而不集中收口，很容易出现 HUD compass 顺时针、map arrow 逆时针的口径分裂。
- 如果只画 UI 不暴露 contract，后续火炮/任务/作者场景仍会重新发明方位系统。
- 如果把 lab compass 写成 lab-only 逻辑，未来 main world 与 lab 会再次漂移。


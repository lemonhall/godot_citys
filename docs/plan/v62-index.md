# V62 Index

- 主题：程序化城市建筑美术口径改造（ECN-0043）
- 计划：`docs/plan/v62-city-building-art-direction.md`
- 验收：`docs/plan/v62-m4-verification-2026-10-18.md`
- 状态：`M1-M4` 已完成（描边 overlay 与街道家具列为后续）

## 里程碑

| 里程碑 | 内容 | 状态 |
| --- | --- | --- |
| M1 | facade / trim / glass shader + 合并网格工具 + gallery 渲染探针 | done |
| M2 | 七种 archetype 分层体量与屋顶设备 | done |
| M3 | 契约接线、调色板与环境光 | done |
| M4 | 截图验收、建筑测试、性能三件套 | done |

## 验收产物

- `user://debug/building_gallery_street.png`
- `user://debug/building_gallery_aerial.png`
- `user://debug/building_gallery_closeup.png`
- `user://debug/city_building_street_capture.png`
- `docs/plan/v62-m4-verification-2026-10-18.md`

## 约束

- 作者场景（汉堡店 / 枪店 / 咖啡馆 / 服务建筑 / landmark / venue）不动。
- 建筑契约、`building_id`、`inspection_payload` 链路不动。
- 60 FPS 红线不动。

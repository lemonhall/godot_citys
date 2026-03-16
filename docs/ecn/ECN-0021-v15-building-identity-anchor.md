# ECN-0021 V15 Building Identity Anchor

## Why

`v15` 初稿曾把 building inspection 描述成“只承诺 inspection label，不承诺 formal unique building registry”。这与当前产品真实诉求冲突：

- 用户需要一个可以粘贴、记录、回查的唯一建筑身份
- 后续能力明确要走“按唯一建筑 ID 找生成参数 -> 独立场景重建 -> 编辑功能建筑 -> 再进城替换原建筑”的链路
- 如果 `v15` 没有冻结 `building_id`，后续建筑替换功能就没有正式锚点

因此本 ECN 把 `v15` 从“地址巡检提示”升级为“建筑唯一身份锚点”版本。

## Change

- `v15` building inspection payload 从：
  - `inspection_kind / display_name / place_id / chunk_id / chunk_key`
- 升级为：
  - `inspection_kind / building_id / display_name / address_label / place_id / chunk_id / chunk_key / generation_locator`
- `display_name` 从“可能重复的 inspection label”升级为“用户可见的唯一建筑名字”
- clipboard text 冻结要求：
  - 每次 inspection 都立即刷新
  - building inspection clipboard text 必须包含 `building_id`
- runtime 最小查询口冻结要求：
  - 必须能按 `building_id` 找回当前 streamed generation contract

## Still Out Of Scope

- `v15` 仍然不交付完整的 persistent city JSON
- `v15` 仍然不交付功能建筑替换系统本身
- `v15` 仍然不交付独立场景编辑器

本次 ECN 只要求把后续链路的 identity anchor 正式冻结下来。

## Affected Docs

- `docs/prd/PRD-0008-laser-designator-world-inspection.md`
- `docs/plans/2026-03-16-v15-laser-designator-design.md`
- `docs/plan/v15-index.md`
- `docs/plan/v15-laser-designator-world-inspection.md`

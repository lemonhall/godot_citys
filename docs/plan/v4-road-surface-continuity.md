# V4 Road Surface Continuity

## Goal

修复 road surface 在 shared surface page / tile seam 上的断裂感，保持 `M3/M4` 已有的缓存、异步和 shared page 收益，不回退到旧的高成本圆盘过采样路径。

## Root Cause

这轮 `M5` 复盘后的根因不是“胶囊本身天然会断”，而是：

- `M4` 引入 page 级 surface mask 后，page request 里的道路点被平移到了 `[-chunk_half, page_size - chunk_half]` 这一坐标系；
- 但 `CityRoadMaskBuilder._local_point_to_pixel()` 仍沿用 chunk-centered 的 `x / size + 0.5` 映射；
- 结果是 first tile 的路会被错误地画向整页中心，跨 tile seam 的路也会出现断带；
- 旧版“沿线密集圆盘采样”因为会在边界附近反复落点，视觉上把这个投影错误糊住了；改成更省的胶囊后，错误就暴露出来了。

## Fix

- 给 surface request 增加 `surface_origin_m`
- road mask rasterization 改为基于 `surface_origin_m + surface_world_size_m` 做归一化
- chunk request 显式传入 `(-chunk_half, -chunk_half)`
- page request 也显式传入 `(-chunk_half, -chunk_half)`，与 page 内 shift 后的点坐标保持一致

## Acceptance

- first tile 的路必须留在 first tile，而不是漂到 page center
- 穿过 tile seam 的道路两侧像素都必须保持连续
- 不回退到旧的密集圆盘采样算法

## Evidence

- `tests/world/test_city_surface_page_mask_alignment.gd`
- `tests/world/test_city_surface_page_tile_seam_continuity.gd`
- `tests/world/test_city_surface_page_runtime_sharing.gd`
- `tests/e2e/test_city_runtime_performance_profile.gd`

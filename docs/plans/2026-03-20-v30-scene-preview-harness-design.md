# V30 Scene Preview Harness Design

## Summary

`v30` 采用“通用 preview harness + wrapper scene 生成命令”的方案，不先做 Godot editor plugin。原因很简单：当前仓库没有 `addons/` 基建，但已经有成熟的 scene-first authoring 习惯、headless tests 和若干需要运行态肉眼观察的 3D 组件。先把可版本化、可测试、可直接 `F6` 的 scene 资产链做出来，性价比最高。

## Options

### Option A: 仓库内 Harness + Wrapper 生成命令

推荐方案。

- 一个正式 `ScenePreviewHarness.tscn`
- 一个正式 `ScenePreviewHarness.gd`
- 一个生成 wrapper `.tscn` 的 repo-local 脚本
- wrapper 直接引用 harness 和 target scene

优点：

- scene-first，可见、可调、可提交
- 自动化测试容易写
- 目标场景可以零代码接入
- 以后真要升级成 editor plugin，这条资产链还能继续复用

缺点：

- 首版仍需要有一层 wrapper scene

### Option B: 直接做 Editor Plugin

不推荐作为 `v30` 第一版。

优点：

- 用户操作上更顺手

缺点：

- 当前仓库没有 `addons/` 体系
- editor plugin 更难自动化验证
- 容易把第一版复杂度抬得过高

### Option C: 每个 subject 自己内建 preview helper

不采用。

原因：

- 继续复制 `PreviewCamera/PreviewLight/PreviewEnvironment`
- 没有统一 controls/FPS overlay
- 每做一个视觉件又要重新讲一遍需求

## Frozen Design

`v30` 冻结为以下正式口径：

- `city_game/preview/ScenePreviewHarness.tscn`
- `city_game/preview/ScenePreviewHarness.gd`
- `tools/scene_preview/generate_scene_preview_wrapper.gd`
- 可选 subject contract：
  - `get_scene_preview_contract()`
  - `set_scene_preview_active(active, preview_context={})`
- 默认控制：
  - 鼠标观察
  - `WASD`
  - `Q/E`
  - `Shift`
  - `Esc`
- 默认 overlay：
  - `FPS`
  - `frame ms`

## Data Flow

1. 生成命令接受 `source scene` 和 `output wrapper scene`
2. 输出 wrapper `.tscn`，其根是 `ScenePreviewHarness` 实例
3. harness 在 `_ready()` 中加载 target scene
4. harness 尝试读取可选 preview contract
5. harness 挂载 target 并启动 camera/overlay/controller
6. 如果 subject 支持 `set_scene_preview_active()`，则正式激活专用 preview 行为

## Why This Fits The Repo

- 满足 `$godot-minigame-scene-first-authoring`：灯光、环境、地面、overlay 都在场景里；脚本只做控制与 glue
- 满足用户的“以后少费口水”：未来只要生成 wrapper scene 就能直接 `F6`
- 满足可验证性：wrapper 生成、subject 激活、FPS overlay 和相机控制都能写 headless contract

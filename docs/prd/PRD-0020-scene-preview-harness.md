# PRD-0020 Scene Preview Harness

## Vision

把 `godot_citys` 从“某些单独组件可以偶尔手写一个 F6 预览”推进到“任何值得单独检查的场景资产，都能通过同一套正式 preview harness 进行快速预览、自由观察和轻量性能检查”。`v30` 的目标不是造一个华而不实的 editor plugin，也不是继续把 `PreviewCamera/PreviewLight` 零散地塞进每个组件场景，而是在仓库里冻结一套正式的、scene-first 的预览基建：一个通用的 preview harness 场景、一个把目标场景连到 harness 的 wrapper 生成命令、一套统一的自由飞行/鼠标观察控制，以及一个可复用的 preview contract，让未来的新模型、新 prop、新 minigame 组件能在 `F6` 场景态下直接获得光照、环境、相机控制和 FPS 观测，而不必每次都 F5 跑整座城市。

`v30` 的成功标准不是“又多了一个 demo scene”，而是四件事同时成立。第一，仓库必须拥有一条正式的通用 preview 主链，目标场景不用侵入大世界运行时也能在独立预览壳里工作。第二，这条主链必须是 scene-first 的：光照、环境、地面、overlay 等视觉要素由 `.tscn` 承载，脚本只负责控制与 runtime glue。第三，预览壳必须为用户提供真正有用的操作和观测能力，包括自由飞行视角、跟随 subject、基础 FPS / frame ms 反馈，以及可选的 preview subject 激活接口。第四，这套机制必须能马上被现有真实资产消费，至少要把当前的 `InterceptorMissileVisual` 接到新 harness 上，证明以后不需要再为类似“尾焰/球拍/球体/场馆小组件”重复发明一套 `F6` 逻辑。

## Background

- `v28` 和 `v29` 已经证明，许多视觉敏感资产在编辑器里静态看还不够，必须在运行态里观察轨迹、尾焰、持拍姿态或爆炸表现。
- 当前仓库没有 `addons/` editor plugin 基建；现有 preview 行为主要靠具体场景自己带 `PreviewCamera/PreviewLight` 和专用脚本，无法规模化复用。
- 用户已经明确冻结一条未来工作流期望：
  - 新做一个模型或组件场景后，不想再逐条口述“给我加光、加环境、加相机、加控制器、加 FPS”
  - 希望只靠一个命令把“目标场景”和“通用 preview 机制”连起来
  - 然后就能直接 `F6` 看组件，不用 `F5` 跑整座城市
- 当前仓库已有可借鉴资产：
  - `PrototypeHud.gd` 里已经冻结了简单 FPS overlay 的颜色分级逻辑
  - `InterceptorMissileVisual.gd` 已经证明 preview 控制和 subject 自驱预览是有价值的

## Scope

本 PRD 只覆盖 `v30 scene preview harness`。

包含：

- 一套正式的通用 preview harness 场景与脚本
- 一套正式的 preview wrapper 生成命令/脚本
- 一套正式的预览控制：
  - 鼠标观察
  - 自由飞行
  - 跟随 subject
  - 鼠标捕获/释放
- 一套正式的 preview stats overlay：
  - `FPS`
  - `frame ms`
- 一套正式的 preview subject contract：
  - harness 自动加载普通场景
  - 若目标支持 preview contract，可激活专用 preview 行为
- 至少一个真实资产迁移到新 harness：
  - `InterceptorMissileVisual`
- 文档、命令说明与自动化测试

不包含：

- 不做 Godot editor plugin / dock / inspector 定制 UI
- 不做复杂 profiler、GPU frame capture 或 draw-call 深度分析器
- 不做通用动画时间轴编辑器
- 不做自动批量为全仓库每个场景生成 preview wrapper

## Non-Goals

- 不追求第一版就覆盖所有 2D/Control 场景；`v30` 首版优先解决 `Node3D` / 3D 组件预览
- 不追求让每个 subject 都必须写脚本；普通静态场景应当“零代码可看”
- 不追求把 preview harness 和主游戏 HUD/输入体系强耦合
- 不追求通过临时运行时魔法替代正式 scene 资产

## Requirements

### REQ-0020-001 系统必须提供正式的通用 Scene Preview Harness 场景

**动机**：没有正式 harness，后续所有 F6 预览都会继续复制粘贴。

**范围**：

- 提供一套正式 `.tscn` 场景作为 preview 壳
- 该场景至少 author：
  - 预览相机 rig
  - 预览主光源
  - 预览世界环境
  - 可选地面/参考网格
  - stats overlay
  - subject 挂载点
- harness 必须可以加载任意 `PackedScene` 作为 preview subject

**非目标**：

- 不要求第一版支持多 subject 同时比较

**验收口径**：

- 自动化测试至少断言：harness scene 可实例化，且上述核心节点存在。
- 自动化测试至少断言：指定 target scene 后，subject 会正式挂载到 harness，而不是只存路径字符串。
- 反作弊条款：不得继续把 preview camera/light/environment 散落在每个 subject 场景里当作“通用机制”。

### REQ-0020-002 系统必须提供正式的 preview wrapper 生成命令

**动机**：用户明确要求未来“只给一个命令，就把场景和 preview 机制连起来”。

**范围**：

- 提供一个 repo-local 命令/脚本
- 输入至少支持：
  - source scene path
  - output wrapper scene path（可选默认）
- 输出为一个可直接 `F6` 的 wrapper `.tscn`
- wrapper 必须连到正式 harness，而不是复制一份 harness 内容

**非目标**：

- 不要求第一版做到 Godot 编辑器右键菜单集成

**验收口径**：

- 自动化测试至少断言：生成命令能为给定 source scene 生成可加载的 wrapper scene。
- 自动化测试至少断言：wrapper scene 会正式引用 harness 和 target scene。
- 反作弊条款：不得只写文档命令示例而没有实际可运行脚本。

### REQ-0020-003 harness 必须提供统一的自由预览控制和基础性能观测

**动机**：如果没有控制和观测，预览壳只是一个能亮起来的静态盒子。

**范围**：

- harness 必须提供：
  - 鼠标 look
  - `WASD` 平移
  - `Q/E` 升降
  - `Shift` 加速
  - `Esc` 释放/切换鼠标捕获
- harness 必须支持跟随 subject 的平移变化，同时允许用户在相机局部偏移上自由飞行
- harness 必须显示至少两项 stats：
  - `FPS`
  - `frame ms`

**非目标**：

- 不要求第一版做 draw calls / GPU 时间 / 图表历史曲线

**验收口径**：

- 自动化测试至少断言：预览相机可以响应鼠标转向与键盘飞行。
- 自动化测试至少断言：subject 移动时，相机会按跟随合同一起移动。
- 自动化测试至少断言：stats overlay 存在并暴露 `FPS / frame ms` 状态。
- 反作弊条款：不得只显示一个静态标签自称“FPS overlay”；不得把相机做成只能围绕固定点转、无法自由飞行。

### REQ-0020-004 harness 必须支持可选的 preview subject contract，而普通场景零代码也能预览

**动机**：未来有些场景只是静态模型，有些场景则需要激活专用 preview 行为；两类都要覆盖。

**范围**：

- 普通场景：
  - 无需额外脚本，也能被 harness 装载和观察
- 支持 preview contract 的场景：
  - harness 可以调用其正式 preview 激活入口
  - contract 至少支持：
    - 激活/关闭 preview
    - 可选 focus target / subject root
    - 可选默认观察参数
- contract 必须是可选的，不得强制所有 subject 实现一套新脚本

**非目标**：

- 不要求第一版抽象成复杂接口继承体系

**验收口径**：

- 自动化测试至少断言：静态普通场景能在 harness 中加载。
- 自动化测试至少断言：支持 contract 的 subject 被 harness 激活后，专用 preview 行为真的启动。
- 反作弊条款：不得把“支持 preview contract”等同于“每次都手改 subject 代码”。

### REQ-0020-005 v30 必须用真实资产证明这套机制可用，并且不污染主游戏

**动机**：如果不拿真实组件落地，preview harness 很容易沦为又一个无人消费的工具目录。

**范围**：

- 至少把 `InterceptorMissileVisual` 接到新 harness 上
- 真实 wrapper scene 必须可 `F6`
- 主游戏 runtime 不能因为 harness 增加而被强绑 preview light / environment / overlay

**非目标**：

- 不要求本轮迁移足球/网球所有组件

**验收口径**：

- 自动化测试至少断言：`InterceptorMissileVisual` 的 wrapper scene 存在且能加载。
- 自动化测试至少断言：在 harness 中该 subject 的正式 preview 行为会启动。
- 自动化测试至少断言：主游戏 missile command 回归不受污染。
- 反作弊条款：不得通过只保留旧的 `InterceptorMissileVisual.tscn` 内建 preview helper，就宣称 v30 完成。

## Success Metrics

- 新组件场景接入 preview 的工作量显著下降到“生成 wrapper + F6”
- 预览时用户无需再 F5 跑整座城市
- 视觉件的运行态问题能在 preview 阶段被提前发现

## Open Follow-Ups

- `v31+` 可考虑 editor plugin、右键菜单、批量 wrapper 生成
- `v31+` 可扩展 2D/Control preview harness
- `v31+` 可扩展更深入的性能统计项与截图/录屏辅助

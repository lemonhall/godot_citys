# V40 Rifle VFX And Ballistics Research

## Executive Summary

针对 Godot 4.6，这次步枪轨迹需求一共有三条可行路线：`GPUParticles3D + trail mesh`、持续挂在 projectile 上的 trail visual、以及“每次开火单独生成一个短寿命 tracer node”。综合官方文档约束和本仓库现有测试/架构，最稳的选择是第三种：继续保留 live projectile + raycast 命中链，把可视反馈拆成 `PlayerController` 的 muzzle flash 和一个独立的短寿命 smoke tracer node [1][2][5][6]。

## Key Findings

- **Godot 官方粒子 trail 有渲染器边界**：官方文档明确写到 3D particle trails 只支持 `Forward+` 和 `Mobile`，不支持 `Compatibility`，这让“把 rifle tracer 全押到 particle trail”变成一个较高风险的基础设施选择 [2]。
- **粒子 trail 配置链比较重**：`GPUParticles3D.trail_enabled` 还需要粒子 mesh material 同时打开 `BaseMaterial3D.use_particle_trails` 才会生效，不是单开一个开关就够 [1][3]。
- **RibbonTrailMesh / TubeTrailMesh 更适合持续尾迹，不是瞬时枪迹**：官方对 `RibbonTrailMesh` 和 `TubeTrailMesh` 的描述都围绕“particle trails”展开，且教程重点在 sections / curves / long trail shaping，不太像步枪每发一瞬的空气烟迹 [2][4]。
- **当前仓库命中主链已经适合升级 ballistic profile**：`PhysicsRayQueryParameters3D.create(...)` + `direct_space_state.intersect_ray(...)` 已经是 Godot 官方推荐的快速 query 组合，保留它只调更快/更远的 rifle profile，风险最低 [5][6]。

## Detailed Analysis

### 路线 A：`GPUParticles3D + RibbonTrailMesh`

Godot 官方提供了成熟的 3D particle trail 方案。文档说明 `GPUParticles3D` 可以开启 `trail_enabled`，并和 `RibbonTrailMesh` / `TubeTrailMesh` 一起工作；教程还说明 ribbon trail 的 `Cross` 形状会生成两个互相垂直的四边形，让 trail 在不同角度更有体积感 [1][2]。从纯效果角度看，这条路最像“标准引擎级尾迹”。

但它也有三个问题。第一，Godot 官方明确写了 3D particle trails 不支持 `Compatibility` 渲染器 [2]。第二，配置不止一个开关，还要同步开启材质侧 `Use Particle Trails` [1][3]。第三，这套系统更适合持续时间更长、粒子数更稳定的尾焰/拖尾，而不是 rifle 这种一次开火就结束的极短时效果 [2][4]。在本仓库里，主世界与 lab 还需要走 headless contract tests；这意味着“看起来能做”不等于“容易自动回归”。

### 路线 B：把 trail 永远绑在 live projectile 上

这条路的优点是实现简单：保留 live projectile，然后让 projectile 自己带一条 trailing visual。理论上它可以天然跟着飞行方向，不用额外维护第二个 runtime node。

问题在于 rifle 子弹一旦变快，近距离命中经常只活一个 physics step。也就是说，在用户最常见的近战蜘蛛 lab 里，trail 可能刚出现就跟着 projectile 一起回收，视觉上反而不明显。这和用户当前的需求是冲突的：用户是明确想看到像 GTA 那样一闪而过的空气轨迹感，而不是“理论上有 trail，但因为飞太快所以几乎看不见”。

### 路线 C：每次开火生成独立短寿命 tracer node

这条路线不依赖 particle trails，也不把可视反馈绑死在 projectile 生命周期上。每次开火时额外生成一个独立 tracer node，让它在几十毫秒内完成显示和衰减；同时 projectile 继续走现有命中主链。这种设计最符合本仓库的需求：

- 架构上不打碎 `CityProjectile` live node 合同
- 测试上可以通过 `CombatRoot/ProjectileTracers` 的 child count 与 debug state 做 focused coverage
- 体验上即使近距离命中，用户仍然能看到一小段 smoke streak
- Spider lab 和主世界可以复用完全相同的 tracer runtime

因此，这次实现选择路线 C。

## Areas of Consensus

- Godot 官方 particle trail 方案是真实存在且功能完整的 [1][2][4]。
- 如果使用 particle trails，`trail_enabled` 和 `Use Particle Trails` 都要配，缺一不可 [1][3]。
- `RibbonTrailMesh` 的 `Cross` 形态确实更适合从多角度观察的 trail [2][4]。
- 现有 ray query API 足以支撑更快的 rifle ballistics，不需要额外发明第二套命中系统 [5][6]。

## Areas of Debate

- **是否必须走粒子系统**：官方粒子 trail 功能更“正统”，但对当前项目不一定是最低风险实现。
- **tracer 应该绑在 projectile 上还是独立于 projectile**：绑在 projectile 上更直觉，但近距离命中时可见性更差；独立 tracer 更稳定，但需要一套额外 runtime。
- **是否要彻底 hitscan 化**：从拟真/手感上看 hitscan 很诱人，但会破坏当前仓库的大量 projectile 合同测试。

## Sources

[1] Godot Engine stable docs, `GPUParticles3D`: particle trails require `trail_enabled`; designed to work with `RibbonTrailMesh` / `TubeTrailMesh`; material side also needs `BaseMaterial3D.use_particle_trails`. https://docs.godotengine.org/en/stable/classes/class_gpuparticles3d.html

[2] Godot Engine stable docs, `3D Particle trails`: trails are only supported in `Forward+` / `Mobile`; ribbon trail setup uses `RibbonTrailMesh`, `Use Particle Trails`, and `Cross` shape for two perpendicular quads. https://docs.godotengine.org/en/stable/tutorials/3d/particles/trails.html

[3] Godot Engine stable docs, `BaseMaterial3D`: `use_particle_trails` is a dedicated material flag, not implicit behavior. https://docs.godotengine.org/en/stable/classes/class_basematerial3d.html

[4] Godot Engine stable docs, `RibbonTrailMesh`: described as a straight ribbon-shaped mesh usually used for particle trails. https://docs.godotengine.org/en/stable/classes/class_ribbontrailmesh.html

[5] Godot Engine stable docs, `PhysicsRayQueryParameters3D.create(...)`: returns a preconfigured ray query object for common ray usage. https://docs.godotengine.org/en/stable/classes/class_physicsrayqueryparameters3d.html

[6] Godot Engine stable docs, `PhysicsDirectSpaceState3D.intersect_ray(...)`: performs the actual intersection query from the prepared parameters. https://docs.godotengine.org/en/stable/classes/class_physicsdirectspacestate3d.html

## Gaps and Further Research

- 本轮没有研究更复杂的命中贴花、火花、穿透或 supersonic crack 音频。
- 也没有把 tracer 做成 renderer-specific A/B 对比；如果后续用户要继续逼近更强的 GTA/军事射击观感，可以再单独开一版比较：
  - 短寿命 custom tracer node
  - `RibbonTrailMesh` 粒子 trail
  - `TubeTrailMesh` cylinder trail

# V44 Artillery Howitzer Scene And Lab Design

## Context

`m777_3_parts.glb` 已经通过 Blender 拆成 `lower_base / upper_carriage / gun_assembly` 三段，但它仍然只是一个素材容器，不是正式 runtime scene。当前最重要的不是做开火或特效，而是先把“轴心由谁 author、旋转由谁负责、lab 怎么调试”这些基础问题冻结下来。否则主世界一旦接入，后续每加一个功能都要重新猜 pivot、重新找节点、重新手工连场景。

## Recommended Approach

采用与直升机 / 无人机相同的“正式包装 scene + 独立 lab”双层做法，但不走 preview harness 链。正式火炮 scene 负责冻结可复用 contract：`ModelRoot` 下保留两级真实 pivot，`Anchors` 下 author 两个手工可调 marker，`SourceAsset` 实例化三段 glb 后在 `_ready()` 时把三件 mesh 重新挂到 `LowerBaseMount / YawPivot / PitchPivot` 对应层级，并保持全局变换。这样后续无论是主世界 world feature、lab、还是未来炮口焰 / 音效 / 射击逻辑，都围绕同一套节点 contract 扩展，而不是重新发明一条私有旁路。

## Scene Hierarchy

正式 `CityM777Howitzer.tscn` 建议保持最小但稳定的结构：

```text
CityM777Howitzer
  -> ModelRoot
     -> LowerBaseMount
     -> YawPivot
        -> PitchPivot
     -> SourceAsset (m777_3_parts.glb)
  -> Anchors
     -> YawPivotAnchor
     -> PitchPivotAnchor
```

`SourceAsset` 只做导入承载，不作为长期 runtime 层级。脚本在 `_ready()` 中把三段 mesh 重新挂接到正式 pivot 节点，并把 `YawPivot` / `PitchPivot` 的位置同步到 anchor。这样开发者只需要在 scene 里调两个 marker，就能稳定定义火炮底盘旋转轴与俯仰耳轴，不必去代码里找 magic number。

## Lab Strategy

`M777HowitzerLab.tscn` 不承担主世界职责，只做调试场。它提供基础地面、世界环境、相机和简洁 HUD，把正式火炮 scene 作为唯一 subject 挂进去。lab 脚本暴露 `get_howitzer()`、`get_lab_state()`、`reset_lab_state()` 与调角接口，同时把键盘输入映射到 howitzer scene 的 yaw / pitch API。这样后续想继续加音效、开火、控制面时，都能先在 lab 完成收敛，再决定是否进入主世界计划。

## Testing Strategy

测试先锁两件事：

1. `scene contract`
   - 正式包装 scene 存在、引用正式 glb、提供三层 runtime hierarchy 与两枚 anchor；
   - API 存在，且 `set_yaw_degrees()` / `set_pitch_degrees()` 真正驱动不同 pivot。
2. `lab contract`
   - lab 场景存在并挂正式 howitzer scene；
   - lab 暴露 howitzer 获取、状态、重置与调角接口；
   - 调整 lab API 会传导到 howitzer 的 yaw / pitch 状态。

第一轮只做 focused contract tests，不把主世界接入、音效或弹道带进来，确保基础 scene contract 先稳定。


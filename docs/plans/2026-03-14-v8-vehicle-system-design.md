# V8 Vehicle System Design

## 结论

柠檬叔的直觉是对了一半：车辆系统和行人系统在 `query`、`streaming`、`tiering`、`identity continuity`、`profile guard` 这些底盘层上确实很像，所以 `v8` 应该明确复用 `pedestrian_query -> tier controller -> renderer` 这套分层方法论；但它们在道路占用、车头方向、跟车间距、交叉口转向、近景避让上并不等价，不能把“会移动的点”直接换一套模型就叫车辆系统。

因此，`v8` 的正确方向不是复制行人实现，而是建立一条新的平行主链：

`vehicle assets/manifest -> vehicle query -> vehicle lane graph -> layered traffic runtime -> traffic renderer -> pedestrian/road coupling guard`

这条主链的数据真源必须是已经在 `v7` 收口的 shared `road_graph` 语义 contract，尤其是：

- `section_semantics.lane_schema`
- `section_semantics.edge_profile`
- `intersection_type`
- `ordered_branches`
- `branch_connection_semantics`

也就是说，车辆系统应该从“道路知道自己有几条车道、双向还是单向、交叉口有哪些合法转向关系”出发，再往下推导车辆 lane、spawn slot、turn choice 和 stop/yield 逻辑；而不是反过来从 mesh、surface mask 或 chunk scene 几何去猜。

## 设计裁决

`v8` 只做 `ambient traffic foundation`，不做玩家驾驶、刚体大碰撞、全城复杂交通规则。第一阶段先让城市出现稳定、可信、可 profiling 的车流，再在此基础上逐步做更复杂互动。

推荐拆成 4 个里程碑：

1. `M0` 素材归档与尺度基线：把 8 个 `glb` 归档进项目、建立 manifest、记下真实尺寸和建议长度缩放。
2. `M1` `vehicle_query / lane graph`：从 shared road semantics 派生 drivable lane、spawn slot、turn contract。
3. `M2` layered ambient traffic runtime：做 `Tier0-3` 交通运行时和可见车流，不退回成海量节点。
4. `M3` pedestrian coupling + runtime guard：只收最小必要的人车关系，先做 crosswalk yield、debug/profile、红线共存。

最关键的约束有三条：

- 不得退回 `Path3D`、per-lane scene tree、per-vehicle node 海洋。
- 不得绕开 `CityChunkStreamer` 做全城常驻 traffic。
- 不得牺牲 `v6` 的 crowd redline 去换“城市里终于有车了”的表面热闹。

换句话说，`v8` 的目标不是“让车动起来”，而是“让车流作为当前 open-world runtime 的新公民加入系统，而且不把原来的系统打碎”。

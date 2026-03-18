# 2026-03-18 V25 Interactive Prop Design

## 为什么它不能继续叫 landmark

`scene_landmark` 在这个仓库里的语义已经很清楚了：喷泉、铁塔、音乐公路，核心都是“可发现、可辨认、可挂地图信息”的 authored 世界特征。足球不满足这个定义。它的第一价值不是“让玩家远远看到并记住这里有个地标”，而是“玩家走近之后，能和它发生可预期的物理交互”。如果继续用 landmark 这个名字，后面会立刻出现两个问题：一是语义污染，二是 runtime 污染。语义污染会让后续篮球、路锥、箱子都被误导成“地标”；runtime 污染会让地图 pin、landmark inspection、far visibility 这些本来不属于球的职责被硬缝过来。

所以 `v25` 推荐方案不是“再解释一次 landmark 其实也可以是球”，而是新开 sibling family：`scene_interactive_prop`。它和 `scene_landmark` 共享的只有 authored 接入模式，也就是 `registry -> manifest -> near chunk mount -> scene`。它不共享“地图可见性”“地标 proper name”“full-map pin”“far proxy”这些语义。这样命名之后，用户一眼就能读懂：这是一个会被挂进世界、但重点在互动的 scene-based prop。

## 推荐架构

推荐路线是“小 family + 小 runtime + 明确 first consumer”。

第一层是 `scene_interactive_prop registry/runtime`。它负责读取 registry 和 manifest，把 `prop_id / anchor_chunk / world_position / scene_root_offset` 解码成 chunk 可消费的 entry，并在 chunk near mount 时把 prop scene 实例化出来。这里的设计故意贴近 `v21 scene_landmark`，因为世界接入纪律已经被证明是对的；但 interactive prop runtime 不产出 map pin，也不需要 landmark specific state。

第二层是 `soccer_ball_prop.tscn`。首版 consumer 不追求复杂框架：一个正式的物理球就够了。推荐做法是让 scene root 直接是 `RigidBody3D`，这样 rolling / bouncing / damping 都走 Godot 物理。用户提供的 `world_position` 继续保留为地面 authored anchor，真正的球心抬高由 manifest 里的 `scene_root_offset` 表达。这样我们既不丢失用户给的 probe 输入，也不会把 physics root 错放到地面接触点导致旋转异常。

第三层是 `interactive prop interaction runtime`。它专门负责扫描当前已 mounted 的 interactive props，选出最近可交互对象，向 HUD 提供 prompt state，并在 `E` 键时触发具体行为。这样可以避免把“找最近球、拼 prompt、施加 impulse”三件事都塞进 `CityPrototype.gd`。

## 交互链怎么和现有 E 键共存

现有 `E` 键链路已经服务 NPC dialogue，所以 `v25` 不应该再新开第四套 prompt UI 或第五个交互键。推荐方案是做“主交互合流”而不是“交互覆盖”。也就是：NPC runtime 和 interactive prop runtime 各自维护自己的候选状态，但 HUD 和 `E` 键只看一个最终的 primary interaction。最终谁拥有显示权，按距离和可用性决定；如果只有 NPC，在现有测试场景里行为完全不变；如果只有足球，则 HUD 显示“按 E 踢球”；如果两者都存在，则最近者胜出。

真正执行时也走同一条主入口。按下 `E` 后，先取当前 primary interaction kind；如果是 `dialogue`，继续走现有 dialogue runtime；如果是 `kick`，则调用足球节点的 `apply_player_kick()`。这条路的好处是两点。第一，既有 NPC tests 的断言口径基本不用推倒重来。第二，以后再加篮球、箱子、按钮时，只要它们也能提供同一类 interaction contract，就能继续挂进这条合流链，而不是在 `CityPrototype.gd` 里继续 `if key == E and feature == x` 地堆特判。

## 足球物理与测试策略

首版 kick 不做动画系统，只做真实物理。推荐冻结的最小行为是：根据玩家到球的平面方向求一个 normalized impulse 方向，如果方向退化成零向量，则回退到玩家朝向；再给这个方向一个固定向前 impulse，并叠加小幅 upward lift。这样用户按 `E` 后，球会明显向前滚开，并有轻微离地感，不会像一个摩擦过大的铅球。

测试策略保持塔山口径。第一类是 manifest/runtime contract：证明足球 entry 真正被 interactive prop family 读到了，而不是靠硬编码。第二类是 visual envelope：证明球没有埋地、悬浮或大得离谱。第三类是 kick contract：证明触发后 `linear_velocity` 或位移显著变化，而且 driving mode / 超出半径时不会误触。第四类是 e2e flow：从玩家靠近、看到 prompt、触发 kick 到球滚出去，整条用户链路自动跑通。首版不测“足球最终停在哪里”，因为那是物理细节和未来可持久化范围，不属于 `v25` 的交付核心。

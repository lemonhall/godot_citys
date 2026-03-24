# V52 Artillery Gameplay Ballistics Research

## Executive Summary

公开资料表明，M777 不是单一固定射程的武器：常规 `155mm` 高爆弹通常落在 `22.5km` 级别，火箭增程弹与精确制导弹还能继续拉远 [1][2][4][5]。但当前项目并不追求军规级火控，因此 `v52` 正式冻结为一套 gameplay 级弹道口径：默认弹型采用 `22.5km` 最大射程，并把最小射程放宽到 `1.5km`，让 howitzer 在缩水后的城市地图里既“像真的”，又不至于过于硬核 [1][2][3]。

## Key Findings

- **M777 的“常规弹”口径落在 22.5km 这一档**：公开军方资料将 `M795` 常规高爆弹与 `22.5km` 级别射程联系在一起，这足以作为当前游戏默认弹型的参考上限 [2]。
- **真实 M777 兼容的弹型射程跨度很大**：从常规弹到增程弹、精确弹，公开资料里常见的区间大致跨越 `22.5km -> 30km -> 40km+`，因此“只取常规弹这一档”是一个刻意的 gameplay 冻结，而不是武器的物理极限 [1][4][5]。
- **真实外弹道不能只靠“初速 + 重力”完整表达**：NASA 的基础空气阻力方程说明，真实飞行会受到速度、空气密度、阻力系数和迎风面积影响；如果完全按真空抛体计算，常规弹射程会明显偏大 [6]。
- **对当前项目而言，互相可验算比高保真更重要**：只要 forward prediction、inverse solve 与 live shell 共享同一模型，就可以用 `target -> solve -> predict` 做 round-trip 验证，先把系统做“自洽” [1][2][6]。

## Detailed Analysis

### M777 的公开射程口径

JPEO 的 M777A2 官方产品页明确给出这是一门 `155mm` 轻型牵引榴弹炮，并强调其兼容多种弹药 [1]。在常规弹这一档，Army 资料把 `M795` 的典型最大射程放在 `22.5km` 左右 [2]；加拿大陆军面向装备介绍的页面则给出了一个更偏通用使用口径的范围描述，并提到最小射程约为 `2600m` [3]。

这说明两点。第一，`22.5km` 作为当前项目默认弹型的最大射程是站得住脚的，因为它对应的就是“常规高爆弹”这一档，而不是拿 Excalibur 或 XM1113 之类更远的弹型来代替日常口径。第二，真实系统的最小射程通常比 `1.5km` 更大，因此 `v52` 把最小射程放宽到 `1.5km`，本质上是为了让 howitzer 在缩水后的城市地图里更好用，这是一个明确的 gameplay 取舍，不应误写成“真实 M777 就是 1.5km 起射” [2][3]。

### 为什么这轮不做军规级外弹道

如果继续沿着真实火控推进，就会很快碰到更复杂的外弹道问题。NASA 的阻力方程给出最基本的事实：飞行物受到的阻力与空气密度、速度平方、阻力系数和迎风面积有关 [6]。这意味着真实 `155mm` 炮弹的射程、弹道弧线和飞行时间不会只由“初速 + 重力”决定。

对于游戏项目来说，问题不在于“能不能更真实”，而在于“有没有必要现在就更真实”。当前 howitzer 已经有主世界 summon、操炮 ownership、payload、live shell 与落点/爆炸消费链；这一轮真正缺的是：一套正式弹种 profile、一条 forward prediction、一条 inverse solve，以及保证三者和 live shell 共线的 shared ballistic model。用户已经明确不想把玩法推向过于硬核，所以 `v52` 的正确方向不是上带阻力数值积分和气象修正，而是冻结一套简化但自洽的 gameplay 模型 [1][2][6]。

### 为什么 forward / inverse 可以互相验算

只要 forward 与 inverse 共享同一数学模型，它们就可以形成正式的 round-trip 验证。对当前项目而言，这比“逼近真实世界 1% 的额外细节”更有价值，因为它能直接卡住后续最容易分叉的三条链路：

1. howitzer 当前 firing solution payload  
2. target solve 返回给 future UI / fire mission 的 bearing 与 pitch  
3. live shell runtime 真正飞出去的 launch state

因此 `v52` 采用的思路是：把默认弹型冻结为 `m795_he`，把 gameplay 射程 envelope 锁死为 `1.5km~22.5km`，并用一套共享 solver velocity 驱动 forward / inverse / live shell。这样做不是在宣称“这就是真实 M777 的外弹道”，而是在正式承认：这是一个围绕当前地图尺度与玩法需求调过的游戏化模型，但它是统一的、可验证的、能继续扩展的 [2][3][6]。

## Areas of Consensus

- 公开资料一致表明，M777 不是固定射程，而是随弹型变化明显 [1][2][4][5]。
- 常规弹采用 `22.5km` 级别作为游戏默认弹型上限是合理的 [2]。
- 真实外弹道要比简单抛体复杂，空气阻力是最基本也最绕不过去的因素之一 [6]。
- 对当前项目来说，先把 ballistic model 做到 shared / deterministic / round-trip 可验，比追求军规级保真更符合用户目标 [1][2][3]。

## Areas of Debate

- **最小射程该取多少**：公开资料里真实口径更接近 `2600m`，但当前项目为了地图尺度和可玩性，冻结为 `1500m`；这是一项 gameplay 取舍，而不是资料分歧 [3]。
- **是否要保留公开资料里的参考初速**：为了文档可信度和后续扩展，当前实现保留 `reference_muzzle_velocity_mps`；但 solver / runtime 用的是调过的 `solver_muzzle_velocity_mps`，这是明确的“参考值”和“求解值”并存设计 [2][6]。
- **未来是否上更高保真模型**：如果后续真的要做 Excalibur、增程弹、反炮兵或精确火控，shared utility 仍可以升级；但在 `v52` 这一阶段，没有必要提前背上军规级复杂度 [4][5][6]。

## Sources

[1] JPEO, “M777A2,” official product page, authoritative program overview. https://jpeoaa.army.mil/Project-Offices/PM-CAS/Organizations/Tactical-Artillery-Systems/Products/M777A2/

[2] U.S. Army, “Lateral collaboration reduces costs,” official Army article citing `M795` conventional artillery ammunition in the `22.5km` class. https://www.army.mil/article/166686/lateral_collaboration_reduces_costs

[3] Government of Canada, “M777 howitzer,” official equipment overview including minimum range information. https://www.canada.ca/en/army/services/equipment/weapons/m777-howitzer.html

[4] RTX Raytheon, “Excalibur projectile,” official manufacturer page describing the precision-guided long-range `155mm` class. https://www.rtx.com/raytheon/what-we-do/land/excalibur-projectile

[5] U.S. Army, “Army developing safer extended-range rocket-assisted artillery round,” official Army article on XM1113 extended-range development. https://www.army.mil/article-amp/174013/army_developing_safer_extended_range_rocket_assisted_artillery_round

[6] NASA Glenn Research Center, “Drag Equation” and related beginner aeronautics guidance, authoritative basic reference for why real-world flight diverges from ideal vacuum projectile motion. https://www1.grc.nasa.gov/beginners-guide-to-aeronautics/drag-equation/

## Gaps and Further Research

- 当前 research 没有把每一种 `155mm` 弹型全部收成正式 ammo catalog；`v52` 只冻结了默认 `m795_he` 一档。
- 当前研究没有进入装药号、气象修正、风偏、旋偏和科氏力；这些仍属于未来更高保真版本。
- 当前 shared model 仍是 gameplay 级 ballistic proxy；如果未来要做更远程弹型和更真实的飞行时间，再考虑升级到带阻力的数值模型。

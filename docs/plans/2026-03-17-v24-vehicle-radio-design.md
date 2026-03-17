# V24 Vehicle Radio Design

**Goal:** 为 `godot_citys` 冻结一套正式车载电台设计：既有 GTA 风格的车内快速切台体验，又能承载全球电台目录、缓存和真实直播协议复杂度。

**Architecture:** 采用“双界面模型 + 冷热分层数据 + backend 抽象接口”。driving 中的 quick-select overlay 只解决低摩擦切台，独立的 radio browser 解决海量目录、预设和收藏；catalog 与 resolve cache 放在 `user://cache/radio/`，用户状态放在 `user://radio/`，直播 backend 则先冻结接口与验证样本，再做实现选型。

**Tech Stack:** Godot 4.6、GDScript、现有 `v9` driving/HUD 主链、`user://` JSON cache、未来 native radio backend（待 `M1` 决策）、外部参考 `kotlinagentapp`。

---

## 问题收口

这次需求真正困难的地方，不是“游戏里要不要有电台”，而是两件互相拉扯的事情要同时成立。第一件事是 GTA 式车内 radio 的核心体验本来就是快切、盲操、少思考；玩家开车时不可能认真浏览一个几千条目的目录。第二件事是用户点名要参考 `kotlinagentapp` 的全球电台体系，而那个体系之所以成立，恰恰因为它正视了海量目录、缓存 TTL、playlist wrapper、broken stream、HLS 和 favorites/presets 的现实复杂度。把这两件事混成一个 UI，结果只会是两头都失败。

当前仓库里已经有三个足够重要的事实。第一，`v9` 之后 driving state 是正式 contract，不需要重新发明“玩家现在是不是在开车”。第二，`PrototypeHud.gd` 和 `CityMapScreen.gd` 已经证明仓库接受“常驻 HUD + 全屏 overlay”这种双层 UI 模式。第三，`v23` 的 music road 说明 driving 中的音频相关 runtime 可以成为正式世界玩法，但它也从反面提醒我们：只要热路径不受控，音频功能会很快变成 profiling 风险。车载电台如果把 catalog 和 browser 也塞进每帧链路，问题只会更严重。

真正要守住的，不是“像 GTA 一样看起来有个轮盘”，而是“快速切台 surface 与海量目录浏览 surface 必须明确分层”。如果不先把这条分层写进设计，后续实现阶段最容易发生的 scope drift 就是：为了赶进度，先做一个能切 8 个本地台的轮盘，然后把“全球目录、缓存、协议解析”都留成以后；或者反过来，先做一个大浏览器列表，最后强行把它说成“车载电台”。这两条路都不行。

## 方案比较

第一条候选路线是“单层 GTA 轮盘”。它的优点是驾驶体验直接、学习成本低，看上去最像 GTA5。但它默认的世界观是“固定数量、固定排序、固定内容的少量电台”，而不是“全球电台几千个”。一旦把海量目录塞进单层轮盘，不是轮盘被做成难用的大菜单，就是浏览器逻辑偷偷污染车内快速切台。这个方案可以借鉴视觉感觉，但不能作为整体架构。

第二条候选路线是“只做全屏浏览器”。它最容易承接全球目录、搜索、收藏与缓存，也最贴近 `kotlinagentapp` 的 directory/cache 思路。但它会直接牺牲 driving 中的低摩擦切台体验。玩家每次想换台都得打开一个大界面，这不是车载 radio，而是游戏里的网络媒体管理器。这个方向可以承接深目录，但不能单独成立。

第三条路线是“双界面模型”，也是我推荐的路线。它把系统分成两个 surface。quick-select overlay 只负责车内切台，冻结为 `8-slot quick bank`；browser 只负责 `当前播放 / Presets / Favorites / Recents / Browse` 的管理与发现，冻结为全屏 surface。这样快切和海量目录各自服务自己的目标，互不拖累。更重要的是，它天然对应两条不同的数据热度：quick-select 只需要 compact runtime snapshot，而 browser 可以安全地读取 country pages、favorites、presets 和 local filter。对仓库现有性能纪律来说，这条分层路线最稳。

## 推荐 UX 模型

推荐 UX 是“车内快切 + 车内/暂停浏览”的组合。quick-select overlay 只在 driving mode 下可打开，默认冻结为 `8-slot quick bank`，用户真正常用的 8 个台放这里。`radio power off` 不占站位，而是单独 action。这样 quick-select 永远不会因为“还要支持关机、收藏、浏览”而把自身变胖。overlay 打开时，`v24` 先不追求 GTA 式慢动作，而是采用仓库更容易验证的 `radio selection pause`：世界模拟暂停、输入焦点切给 radio 选择、释放后恢复。这么做不如 GTA5 华丽，但它更 deterministic，也更适合 keyboard/controller 一起支持。

browser 则是完整的“目录与管理” surface。它不应该被塞进 full map 里，因为地图的任务是空间导航，不是媒体管理。更合理的是一个独立的 radio browser screen，通过 `vehicle_radio_browser_open` 或 quick-select 的“更多/浏览”入口进入。这个 screen 的最小分区冻结为 `当前播放 / Presets / Favorites / Recents / Browse`。`Browse` 的首屏不是全球 station 平铺，而是 `国家/地区目录`。进入目录后才显示按热度排序的 `top 200` station page，并允许在当前页内做本地关键字过滤。这样即使整体目录有几千个台，UI 常驻状态也永远只处理当前需要的那一页。

这个 UX 还有一个产品层好处：玩家开车时只需要切常用台；真正的“找新台、设预设、整理收藏”行为天然发生在暂停、停车或不着急的时候。也就是说，车载电台真正像一套“玩法内媒介系统”，而不是把桌面播放器生搬进 HUD。

## 数据与缓存模型

数据层必须显式冷热分层。所有可重建的网络数据都放 `user://cache/radio/`，所有用户真正拥有的偏好状态都放 `user://radio/`。这一层不只是工程整洁问题，它直接决定离线、弱网、重启之后车载电台是不是还能正常工作。推荐冻结以下文件：

- `user://cache/radio/countries.index.json`
- `user://cache/radio/countries.meta.json`
- `user://cache/radio/countries/<country_code>/stations.index.json`
- `user://cache/radio/countries/<country_code>/stations.meta.json`
- `user://cache/radio/stream_resolve_cache.json`
- `user://radio/presets.json`
- `user://radio/favorites.json`
- `user://radio/recents.json`
- `user://radio/session_state.json`

countries index 与 station pages 的 TTL 冻结为 `72h`，基本继承 `kotlinagentapp` 的经验值；这类目录变化相对慢，更多是为“不要每次打开浏览器都重新拉一遍”服务。stream resolve cache 则更短，冻结为 `6h`，因为直播流重定向、playlist wrapper 和候选 URL 的变化频率更高。最关键的一点是：favorites、presets、recents 必须持久化 `station snapshot`，而不是只记一个 `station_id`。否则 catalog 一旦刷新失败，UI 就会变成“收藏还在，但台的名字和 URL 全丢了”的半残废状态。

per-country station page 当前冻结为按热度排序的 `top 200`。这不是说系统只支持 200 个全球台，而是说当前浏览 surface 先把复杂度收敛到一个足够可用、足够可缓存、足够可虚拟化的页面大小。未来要做分页，只需要扩 page contract，不需要推翻 quick-select 和用户状态设计。

## 播放 backend 与可行性关口

真正最硬的一层在这里。`kotlinagentapp` 之所以能把全球电台跑起来，是因为它背后有 Android 媒体栈；而当前 `godot_citys` 仓库没有现成 native audio backend。Godot 官方文档可以支撑我们做两件事：一是通过 `HTTPRequest` 处理 `http/https` 和基础 transport 请求；二是通过 `AudioStreamGenerator` 之类的 PCM 入口承接外部解码后的音频数据。但这并不等于 Godot 现成就有一个能稳稳播放 `PLS / M3U / HLS / internet radio` 的完整 live stack。也就是说，backend 必须被当成独立里程碑，而不是“UI 做完顺手接一下”。

因此 `v24` 最稳的做法是：先冻结 backend interface，再用 `M1` feasibility gate 决定实现形态。接口上，Godot 侧只依赖：

- `backend_id`
- `playback_state`
- `buffer_state`
- `resolved_url`
- `metadata`
- `latency_ms`
- `underflow_count`
- `error_code`
- `error_message`

resolver 侧则冻结：

- `classification`
- `final_url`
- `candidates`
- `resolution_trace`
- `resolved_at_unix_sec`

这样 UI/controller 层永远不直接碰 HTTP 请求、playlist 展开或 native decoder。最终 backend 是 `GDExtension + native decoder` 还是外部 helper，可以留给 `M1` 通过 direct / playlist / HLS 三类真实样本做裁决。文档阶段最重要的是先把边界画出来：不允许本地 MP3 假播，不允许一次性整段下载完成后才算“能播放电台”，也不允许只支持单一裸 MP3 URL 就宣称“全球直播已经接入”。

## 集成、测试与性能纪律

在仓库现有架构里，radio controller 不应该挤进 `CityPrototype.gd` 的每帧主流程。更合理的结构是：`CityVehicleRadioController` 管生命周期和 compact runtime snapshot；`CityRadioCatalogStore` 管冷路径 IO 和 TTL；`CityRadioUserStateStore` 管 `presets/favorites/recents/session_state`；`CityRadioStreamResolver` 管 URL 展开与 resolve cache；UI 层分成 quick overlay 和 browser。这样 `CityPrototype.gd` 只做 driving enter/exit、InputMap action 分发和 compact HUD snapshot 合并。

测试也必须分层。第一层是 pure-ish contract：catalog cache、preset persistence、resolver classification、quick bank 生成。第二层是 world/UI contract：driving 中 quick overlay 是否能打开，browser 是否只显示国家目录第一页，idle HUD 是否不会重建大列表。第三层才是 e2e：上车、切台、关机、打开 browser、设预设、返回 quick-select、生效。最后还有 Windows 主线环境的 backend sample verification，用来证明不是 mock 一切都绿了、真流一放就死。

性能上要特别写硬三件事。第一，quick overlay idle 时不得扫描全量 catalog。第二，browser hidden 时不得维持几千个 station row 节点。第三，HUD 常驻热路径只允许 compact snapshot，不允许 deep-copy `favorites / recents / country pages`。只要这三条守不住，radio 迟早会和 `v23` 的 music road 一样出现“功能看上去不大，但热路径被 payload 拖垮”的问题。

## 外部参考

- `E:\development\kotlinagentapp\docs\prd\PRD-0030-radio-player.md`
- `E:\development\kotlinagentapp\docs\plan\v38-radio-module-overview.md`
- `E:\development\kotlinagentapp\app\src\main\java\com\lsl\kotlin_agent_app\radios\RadioRepository.kt`
- `E:\development\kotlinagentapp\app\src\main\java\com\lsl\kotlin_agent_app\radios\RadioStationFileV1.kt`
- `E:\development\kotlinagentapp\app\src\main\java\com\lsl\kotlin_agent_app\radios\StreamUrlResolver.kt`
- `https://gta.fandom.com/wiki/Controls_for_GTA_V`
- `https://gta.fandom.com/wiki/Radio_Stations_in_GTA_V`
- `https://www.pushsquare.com/guides/gta-online-how-to-save-favourite-radio-stations-and-hide-radio-stations`
- `https://docs.godotengine.org/en/stable/classes/class_httprequest.html`
- `https://docs.godotengine.org/en/stable/classes/class_audiostreamgenerator.html`
- `https://docs.godotengine.org/en/stable/classes/class_audiostreammp3.html`

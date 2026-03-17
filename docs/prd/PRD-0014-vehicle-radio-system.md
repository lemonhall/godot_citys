# PRD-0014 Vehicle Radio System

## Vision

把 `godot_citys` 从“玩家开抢来的车只能听环境音和钢琴路彩蛋”推进到“玩家在 driving mode 中拥有一套正式车载电台系统”的状态。这个系统既要有 GTA 式的车内快速切台感觉，也要正面解决“全球互联网电台有几千个、协议五花八门、缓存和浏览都不能乱来”的现实复杂度。

`v24` 的成功标准不是“HUD 上多了一个电台名字”，也不是“从网络拉几条 URL 然后碰巧放出声音”，而是同时满足六件事。第一，radio lifecycle 必须正式绑定 `player driving state`，上车、下车、关机、切台都有稳定状态，不得漂成一个全局悬空音频播放器。第二，车内快速选择 UI 必须是低摩擦、可盲操、同时兼容键盘和手柄的 surface，不能把几千个台直接塞进一个轮盘里。第三，深度浏览 UI 必须正面承载海量目录，至少能管理 `预设 / 收藏 / 最近 / 国家目录`，并以懒加载 + 缓存方式工作。第四，catalog、station snapshot、preset/favorite/recent、stream resolve cache 都必须是正式持久化 contract，而不是散落在脚本里的临时字典。第五，真正的播放链必须覆盖 `http/https` 与常见 playlist wrapper，不能拿本地假音频冒充“全球电台已接入”。第六，这一切都不能把现有 `v9` 驾驶、HUD、full map、profiling guard 主链打穿。

## Background

- `PRD-0004` 与 `v9` 已冻结 `vehicle hijack -> driving mode -> get_player_vehicle_state()` 主链，证明玩家驾驶时能稳定暴露 `driving / vehicle_id / model_id / world_position / heading / speed_mps`。
- `PRD-0013` 与 `v23` 已证明“驾驶中的车辆状态可以驱动正式音频体验点”，但当前只覆盖 authored `music road`，并不等于已经有通用直播音频底座。
- 当前仓库已有 `PrototypeHud.gd`、`CityMapScreen.gd`、`CityPrototype.gd` 等 HUD / full-screen overlay 链，但没有正式的 radio quick overlay、radio browser、station catalog runtime 或 live stream backend。
- 当前仓库也没有任何 `.gdextension` / native audio stream backend；如果要承接真实网络直播，必须把 backend 能力作为正式设计议题处理，不能假设 Godot 现成就有完整 internet radio player。
- 用户明确要求：
  - 目标不是“本地几首歌”，而是参考 `E:\development\kotlinagentapp` 里的全球电台体系
  - 必须考虑 `http/https`、`m3u` 等真实协议复杂度
  - UI/UX 比单纯功能更麻烦，尤其是海量电台目录、缓存和快速切台并存
  - 可以参考 GTA5 的车载电台 UI/UX，但不能照抄它对固定电台数量的前提
- 外部参考 `kotlinagentapp` 已经证明三件事：
  - `RadioRepository` 式的 `国家索引 -> 国家目录 station cache` 懒加载结构可行
  - `StreamUrlResolver` 式的 `PLS / M3U / HLS / ASX / XSPF` best-effort 解析是正式需求，不是边角料
  - “快速播放 surface”和“海量目录缓存”必须分层，不应让深目录直接污染常驻播放 UI

## Scope

本 PRD 只覆盖 `v24 vehicle radio system`。

包含：

- 新增正式 `vehicle radio runtime`，生命周期绑定 `player driving state`
- 新增正式 `radio power / current station / preset bank / favorite / recent` 数据 contract
- 新增车内 `quick-select` surface，专门解决 driving 状态下的低摩擦切台
- 新增 `radio browser` full-screen surface，专门解决海量站点浏览与预设管理
- 新增全球电台 catalog ingest / cache / refresh contract
- 新增 `stream resolve + playback backend` abstraction，覆盖 `http/https` 与常见 playlist wrapper
- 新增 keyboard/controller 共享的 `InputMap` action contract
- 补齐 world / e2e / profiling 级验证计划

不包含：

- 不在 `v24` 内做虚构 DJ、电台广告、主持人口播或剧情插播
- 不在 `v24` 内做录音、回放、离线转录、翻译或同传
- 不在 `v24` 内做车外便携收音机、步行状态下的独立音乐播放器或地图 POI 广播
- 不在 `v24` 内做全量全球模糊搜索引擎、推荐算法、账号同步或跨设备收藏同步
- 不在 `v24` 内把所有 NPC / ambient traffic 车辆都变成可听见的 3D 电台声源

## Non-Goals

- 不追求首版就拥有 GTA5 那样的虚构固定电台内容体系；`v24` 优先解决真实直播台接入、交互与缓存底座
- 不追求用一个轮盘同时承载“快速切台”和“几千个台的深度浏览”
- 不追求通过“先下载完整音频文件再播放”来冒充 live stream
- 不追求让 `CityPrototype.gd` 再长成一个同时管理 catalog、resolver、quick UI、browser UI、backend 的巨石
- 不追求在没有 fresh playback/backend 证据的情况下宣称“全球电台已经通了”

## Requirements

### REQ-0014-001 车载电台生命周期必须正式绑定 driving mode，并具备 `power on/off`、进入/退出车辆与会话恢复语义

**动机**：车载电台首先是“车内状态”，不是一个跟着玩家全局悬浮的背景音乐开关。

**范围**：

- 只有当 `player.is_driving_vehicle() = true` 时，正式 `vehicle radio runtime` 才进入可播放状态
- runtime 最小状态冻结为：
  - `power_state`
  - `selected_station_id`
  - `selected_station_snapshot`
  - `preset_bank`
  - `favorite_station_ids`
  - `recent_station_ids`
  - `playback_state`
  - `buffer_state`
  - `error_code`
  - `error_message`
- `power_state` 必须显式支持 `on` 与 `off`
- 玩家上车后，如果上次会话是 `power=on` 且存在可恢复站点，runtime 可以自动恢复上次选台；如果上次是 `power=off`，上车后必须保持静音
- 玩家下车后，radio audio 必须停止或淡出，且 quick-select UI 必须关闭
- `selected_station_snapshot` 必须是正式持久化副本，避免 catalog 暂时不可用时 runtime 丢失当前站点身份

**非目标**：

- 不要求 `v24` 首版为每一辆 ambient vehicle 维护不同的 station memory
- 不要求 `v24` 首版支持多个车内乘客共享电台状态

**验收口径**：

- 自动化测试至少断言：未处于 driving mode 时，vehicle radio runtime 不会进入 `playing`。
- 自动化测试至少断言：进入 driving mode 后，runtime 会根据上次会话恢复 `power_state` 与 `selected_station_snapshot`。
- 自动化测试至少断言：`power=off` 时即使存在已选站点也不会发起 backend 播放请求。
- 自动化测试至少断言：退出 driving mode 时，播放请求被正式停止，HUD quick overlay 关闭。
- 自动化测试至少断言：station catalog 暂时不可用时，当前 `selected_station_snapshot` 仍可用于 UI 与下次恢复判断。
- 反作弊条款：不得把车载电台实现成一个与 driving 状态无关的全局 BGM 开关；不得下车后继续播放却宣称“这就是车载电台”；不得只保存 `station_id`、丢失站点快照后再用空数据冒充恢复成功。

### REQ-0014-002 驾驶中的快速切台 UI 必须是独立 surface，且同时兼容键盘与手柄

**动机**：驾驶态下的交互目标是“极短时间内选中一个常用台”，不是“在几千个台里认真搜索”。

**范围**：

- quick-select UI 只在 driving mode 中可打开
- quick-select surface 冻结为 `8-slot quick bank`，只承载“当前最常用的 8 个站位”
- `quick bank` 的站位来源冻结为：
  - 用户手工设定的 presets 优先
  - 缺位时可由 favorites / recents 回填
- `radio power off` 不占用 8 个站位，必须走独立 action
- quick-select 打开时，世界模拟允许进入单机可测的 `radio selection pause` 模式；`v24` 不强求 GTA 式慢动作
- 输入 contract 必须基于 `InputMap action`，而不是直接把键位写死在 `CityPrototype.gd`
- 最小 action 家族冻结为：
  - `vehicle_radio_quick_open`
  - `vehicle_radio_next`
  - `vehicle_radio_prev`
  - `vehicle_radio_power_toggle`
  - `vehicle_radio_browser_open`
  - `vehicle_radio_confirm`
  - `vehicle_radio_cancel`

**非目标**：

- 不要求 `v24` 首版在 quick-select 里显示全部国家目录
- 不要求 `v24` 首版做 GTA 式完整圆环 logo 艺术资源包

**验收口径**：

- 自动化测试至少断言：只有 driving mode 中才能打开 quick-select overlay。
- 自动化测试至少断言：quick-select overlay 最多只渲染 8 个 station slots，不会把 favorites / browse 列表整页塞进 overlay。
- 自动化测试至少断言：`power_toggle` 与 `browser_open` 走独立 action，不会挤占站位。
- 自动化测试至少断言：keyboard 与 controller 最终都通过同一组 `InputMap action` 驱动选择，而不是两套分叉逻辑。
- 自动化测试至少断言：释放选择后，world pause 状态与 overlay 状态正确恢复。
- 反作弊条款：不得把 quick-select 退化成一个静态 debug 文本菜单；不得在 quick-select 中实例化几千个 station rows；不得只做键盘路径而把手柄输入留成 todo。

### REQ-0014-003 海量站点浏览必须走独立的 radio browser surface，并正式区分 `Presets / Favorites / Recents / Browse`

**动机**：几千个全球台无法靠车内轮盘解决；必须有专门面向“管理和发现”的深界面。

**范围**：

- 新增正式 `radio browser` full-screen surface
- browser 最小导航分区冻结为：
  - `当前播放`
  - `Presets`
  - `Favorites`
  - `Recents`
  - `Browse`
- `Browse` 的第一层正式入口冻结为 `国家/地区目录`
- `Browse` 进入国家目录后，必须展示该目录下的 station list，而不是全局一次性铺开
- station list 必须支持基于当前已加载目录的本地关键字过滤
- station row 最小展示字段冻结为：
  - `station_name`
  - `country`
  - `language`
  - `codec`
  - `votes`
  - `favorite_state`
  - `preset_slot`
  - `availability_hint`
- `Presets` 必须允许对 8 个 quick bank 站位做正式编辑，而不是只读展示

**非目标**：

- 不要求 `v24` 首版做跨全球全量模糊搜索
- 不要求 `v24` 首版做复杂多条件过滤器矩阵
- 不要求 `v24` 首版支持 station logo 大图墙或频道封面下载

**验收口径**：

- 自动化测试至少断言：browser surface 正式区分 `Presets / Favorites / Recents / Browse`，而不是把所有功能塞进一个长列表。
- 自动化测试至少断言：`Browse` 首屏显示的是国家/地区目录，不是全局几千个台的平铺列表。
- 自动化测试至少断言：国家目录 station list 支持本地过滤，且过滤不会触发重新拉取整个 catalog。
- 自动化测试至少断言：`Presets` 编辑会正式回写 quick bank 数据，而不是只改运行时临时显示。
- 自动化测试至少断言：Favorites 与 Recents 可在 catalog 离线时继续显示已有 snapshot。
- 反作弊条款：不得把 browser 做成简单 debug inspector；不得在没有目录分页/虚拟化策略时一次性构造几千个 Control；不得靠硬编码 8 个演示台冒充“海量站点浏览已完成”。

### REQ-0014-004 catalog、preset、favorite、recent 与 resolve cache 必须是正式持久化 contract，且冷热数据分层存放

**动机**：海量目录和驾驶快切共存时，真正决定体验稳定性的不是“有几个按钮”，而是底层数据是否能在离线、弱网和重启后保持一致。

**范围**：

- `v24` 持久化路径必须正式区分：
  - 可重建网络缓存：`user://cache/radio/`
  - 用户侧持久化状态：`user://radio/`
- 最小缓存文件冻结为：
  - `user://cache/radio/countries.index.json`
  - `user://cache/radio/countries.meta.json`
  - `user://cache/radio/countries/<country_code>/stations.index.json`
  - `user://cache/radio/countries/<country_code>/stations.meta.json`
  - `user://cache/radio/stream_resolve_cache.json`
- 最小用户状态文件冻结为：
  - `user://radio/presets.json`
  - `user://radio/favorites.json`
  - `user://radio/recents.json`
  - `user://radio/session_state.json`
- countries 与 station page 的默认 TTL 冻结为 `72h`
- stream resolve cache 的默认 TTL 冻结为 `6h`
- per-country station page 的默认 catalogue cap 冻结为按热度排序的 `top 200`
- 所有对外可读 JSON 必须采用多行 pretty-print，保持人工可读

**非目标**：

- 不要求 `v24` 首版做 SQLite / Room / 自定义二进制缓存
- 不要求 `v24` 首版持久化完整 audio buffer

**验收口径**：

- 自动化测试至少断言：countries index、station page、presets、favorites、recents、session_state 都能稳定读写并通过 schema 校验。
- 自动化测试至少断言：未过期 cache 会被复用；过期 cache 会尝试刷新；刷新失败时已有 cache 仍可回退使用。
- 自动化测试至少断言：favorites / recents / presets 持久化的是 station snapshot，而不是脆弱的 UI 临时对象引用。
- 自动化测试至少断言：catalog cache 与 user state 写入路径分离，不会混写到同一目录。
- 自动化测试至少断言：输出 JSON 为多行 pretty-print，而不是单行紧凑 JSON。
- 反作弊条款：不得只把数据留在内存里却宣称“有缓存”；不得把用户 favorites 写进易失 `cache/` 目录；不得每次启动都无条件重拉整个国家索引。

### REQ-0014-005 播放链必须是真实直播链路，并正式覆盖 `http/https`、playlist wrapper、resolver trace 与可配置代理

**动机**：全球电台最难的部分不是 UI，而是 URL、协议和解码的现实脏活；这一层如果不写进 requirement，后面一定会被“先放本地 MP3”偷换掉。

**范围**：

- 播放链只允许正式接收 `http://` 与 `https://` stream inputs
- resolver 必须对以下输入做 best-effort 分类与展开：
  - direct stream URL
  - `pls`
  - `m3u`
  - `m3u8 / hls`
  - `asx`
  - `xspf`
- resolver 输出 contract 最小字段冻结为：
  - `classification`
  - `final_url`
  - `candidates`
  - `resolution_trace`
  - `resolved_at_unix_sec`
- playback backend 必须通过正式接口暴露：
  - `backend_id`
  - `playback_state`
  - `buffer_state`
  - `resolved_url`
  - `metadata`
  - `latency_ms`
  - `underflow_count`
  - `error_code`
  - `error_message`
- backend transport 必须允许显式 `http_proxy / https_proxy` 配置；默认不写死任何仓库内代理
- `v24` 必须把“Godot 侧 catalog/UI/runtime”和“实际 stream decode backend”解耦成两个层次

**非目标**：

- 不要求 `v24` 首版做录音、ASR、翻译或直播转写
- 不要求 `v24` 首版保证 every station works；broken stream 允许存在，但必须可解释

**验收口径**：

- 自动化测试至少断言：resolver 对 `direct / pls / m3u / hls / asx / xspf` 都能给出稳定 classification 与 trace。
- 自动化测试至少断言：同一个 station snapshot 的 resolve 结果能命中 TTL cache，而不是每次切台都重新展开。
- 自动化测试至少断言：backend interface 与 UI/controller 解耦，UI 层不会直接拼接 HTTP 请求。
- 自动化测试至少断言：proxy 配置为空时不强制走代理；显式配置后 transport 层会读取并使用对应设置。
- 自动化验证至少要求在 Windows 主线环境上成功覆盖三类真实样本：direct stream、playlist-wrapped stream、HLS stream。
- 反作弊条款：不得用本地预录 MP3、一次性整段下载完成后才播放、或只支持单一裸 MP3 URL 来宣称“全球电台已接入”；不得把代理地址硬编码进仓库源码。

### REQ-0014-006 `v24` 不得破坏 driving/HUD/performance 主链，且热路径禁止扫描全量 catalog

**动机**：电台是一个长生命周期 feature，但它的常驻热路径必须非常克制；否则几千个台的目录和 UI 一上来就会拖垮 driving、HUD 与 profile guard。

**范围**：

- radio controller、catalog store、resolver、quick overlay、browser UI 必须拆层，不得继续把 `CityPrototype.gd` 膨胀成所有逻辑入口
- quick overlay 与 browser state 必须按事件刷新，不得在 `_process()` 中每帧全量重建 station list
- HUD 常驻热路径只允许读取 compact runtime snapshot，不得每帧 deep-copy favorites / recents / country pages
- browser list 必须采用分页、虚拟化或等价策略，不允许一次性实例化几千个 UI rows
- 受影响的 driving / HUD / runtime profiling guard 必须继续保留

**非目标**：

- 不要求 `v24` 首版解决仓库当前所有历史 profiling debt
- 不要求 `v24` 首版做全车内 3D 喇叭 spatialization

**验收口径**：

- 自动化测试至少断言：quick overlay idle 时不会触发 catalog 全量扫描或 browser list rebuild。
- 自动化测试至少断言：browser list 存在分页/虚拟化 contract，不会一次性构造整个国家站点全集。
- 受影响的 driving / HUD / runtime tests 必须继续通过。
- 串行运行 `test_city_chunk_setup_profile_breakdown.gd`、`test_city_runtime_performance_profile.gd`、`test_city_first_visit_performance_profile.gd` 仍需给出 fresh 结果。
- 反作弊条款：不得为了 profiling 过线而在测试模式下关闭 radio overlay、关闭 backend 调用、或把浏览器列表替换成 8 条假数据；不得把 quick overlay 绑到每帧重建的大字典 getter 上。

## Open Questions

- `v24` 最终的真实直播 backend 是 `GDExtension + native decoder`、`外部 helper` 还是别的形式。当前答案：PRD 先冻结接口与验证样本，库选型留给 `M1` feasibility gate。
- keyboard / controller 的默认物理按键映射是什么。当前答案：`InputMap action` 名称先冻结，默认映射要等实现前做冲突审计后再定。
- browser 是否在 on-foot 状态也允许打开。当前答案：`v24` 先按“只服务车载场景”的口径冻结，未来如需扩成通用 media browser 再单独立项。

## Future Direction

- 后续可以在不破坏 `preset/favorite/recent/catalog cache` contract 的前提下扩展：
  - 车外媒体浏览器
  - station logo / artwork cache
  - 本地推荐与最近偏好排序
  - 录音、转录、翻译或 live interpretation
- 如果未来要做 GTA 式固定虚构电台，也应作为 `live global radio` 的 sibling family，而不是把当前直播 catalog 伪装成“已经等价”。

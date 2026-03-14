# Vehicle Assets

本目录是 `v8` 车辆系统的正式素材入口。

## 目录约定

- `civilian/`：普通社会车辆
- `service/`：服务/执法车辆
- `commercial/`：商用重型车辆
- `vehicle_model_manifest.json`：车辆模型清单、尺寸基线、建议运行期缩放

## 当前归档结果

- `civilian/car_a.glb`
- `civilian/car_b.glb`
- `civilian/car_c.glb`
- `civilian/sports_car_a.glb`
- `civilian/suv_a.glb`
- `civilian/pickup_truck_a.glb`
- `service/police_car_a.glb`
- `commercial/truck_a.glb`

## 命名约定

- 文件名使用稳定 `snake_case`
- `model_id` 与文件名一一对应
- 目录语义优先于素材来源站点命名，避免未来继续出现仓库根目录散落的 `Car (1).glb` 这类临时名

## 尺度口径

- `vehicle_model_manifest.json` 中的 `source_dimensions_m` 来自 `glb` 几何 AABB 的实测结果，口径为 `length / width / height`
- 当前 8 个模型整体已经接近“米”尺度，但不同素材之间存在明显长宽高风格差异，因此只记录统一长度目标与 `uniform scale`，不做非等比拉伸
- `source_ground_offset_m` 定义为“把模型底部对齐到地面时需要补偿的 Y 偏移”；正值表示模型底部低于原点，负值表示模型整体悬空于原点之上
- `runtime_uniform_scale` 只是 `v8 M0` 的现实尺度基线，不是最终玩法承诺；真正接入运行期时仍要与道路宽度、交叉口半径、停车/等待距离一起复核

## 当前尺寸基线

- `car_a`：紧凑型两厢，源尺寸 `3.3096 x 1.6384 x 1.1456m`，建议目标长度 `3.95m`
- `car_b`：普通轿车，源尺寸 `4.2207 x 1.8074 x 1.1766m`，建议目标长度 `4.45m`
- `car_c`：紧凑型轿车，源尺寸 `3.8623 x 1.7754 x 1.2079m`，建议目标长度 `4.10m`
- `sports_car_a`：跑车，源尺寸 `5.6551 x 2.6706 x 1.8647m`，建议目标长度 `4.60m`
- `suv_a`：SUV，源尺寸 `4.2093 x 2.1111 x 1.5279m`，建议目标长度 `4.60m`
- `pickup_truck_a`：皮卡，源尺寸 `5.1804 x 2.3122 x 1.8484m`，建议目标长度 `5.35m`
- `police_car_a`：警车，源尺寸 `3.7305 x 1.7776 x 1.2387m`，建议目标长度 `4.35m`
- `truck_a`：商用货车，源尺寸 `5.2556 x 2.7093 x 2.8840m`，建议目标长度 `5.60m`

## 约束

- 车辆系统接线前，不得再次把 `.glb` 素材散放回仓库根目录
- 任何新增车辆模型都必须先补 manifest，再谈运行期接入
- `v8` 默认先做 ambient traffic，不在素材层提前承诺“玩家可驾驶”“碰撞损伤”“车门骨骼”等高成本玩法

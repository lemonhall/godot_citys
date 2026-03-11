extends RefCounted

var blocks: Array[Dictionary] = []
var parcels: Array[Dictionary] = []

func add_block(block_data: Dictionary) -> void:
	blocks.append(block_data)

func add_parcel(parcel_data: Dictionary) -> void:
	parcels.append(parcel_data)

func get_block_count() -> int:
	return blocks.size()

func get_parcel_count() -> int:
	return parcels.size()

func get_block_ids() -> Array[String]:
	var ids: Array[String] = []
	for block_data in blocks:
		ids.append(str(block_data.get("block_id", "")))
	return ids


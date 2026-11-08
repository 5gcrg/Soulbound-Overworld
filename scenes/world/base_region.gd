class_name BaseRegion
extends Node2D

signal portal_triggered(portal: RegionPortal, target_region_id: String, target_spawn_id: String, body: PlayerCharacter)

@export var region_id: String = ""
@export var region_display_name: String = ""
@export var bounds_rect: Rect2 = Rect2(0, 0, 960, 540)

@onready var spawns_container: Node2D = $Spawns
@onready var portals_container: Node2D = $Portals
@onready var obstacles_container: Node2D = $Obstacles

func _ready() -> void:
	_connect_portals()

func _connect_portals() -> void:
	var container: Node = get_node_or_null("Portals")
	if container == null:
		return
	for child in container.get_children():
		if child is RegionPortal:
			if not child.transition_requested.is_connected(_on_portal_transition_requested):
				child.transition_requested.connect(_on_portal_transition_requested)

func _on_portal_transition_requested(portal: RegionPortal, target_region_id: String, target_spawn_id: String, body: PlayerCharacter) -> void:
	portal_triggered.emit(portal, target_region_id, target_spawn_id, body)

func get_spawn_point(spawn_id: String) -> Marker2D:
	var container: Node = get_node_or_null("Spawns")
	if container == null:
		return null
	for child in container.get_children():
		if child is Marker2D and child.name == spawn_id:
			return child as Marker2D
	return null

func get_spawn_position(spawn_id: String) -> Vector2:
	var marker: Marker2D = get_spawn_point(spawn_id)
	if marker != null:
		return marker.global_position
	return Vector2.ZERO

func has_spawn(spawn_id: String) -> bool:
	return get_spawn_point(spawn_id) != null

func is_position_within_bounds(pos: Vector2) -> bool:
	return bounds_rect.has_point(pos)

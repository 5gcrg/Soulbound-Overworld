class_name BaseRegion
extends Node2D

signal portal_triggered(portal: RegionPortal, target_region_id: String, target_spawn_id: String)

@export var region_id: String = ""
@export var region_display_name: String = ""
@export var bounds_rect: Rect2 = Rect2(0, 0, 960, 540)

@onready var spawns_container: Node2D = $Spawns
@onready var portals_container: Node2D = $Portals
@onready var obstacles_container: Node2D = $Obstacles

func _ready() -> void:
	_connect_portals()

func _connect_portals() -> void:
	if portals_container == null:
		return
	for child in portals_container.get_children():
		if child is RegionPortal:
			if not child.transition_requested.is_connected(_on_portal_transition_requested):
				child.transition_requested.connect(_on_portal_transition_requested)

func _on_portal_transition_requested(portal: RegionPortal, target_region_id: String, target_spawn_id: String) -> void:
	portal_triggered.emit(portal, target_region_id, target_spawn_id)

func get_spawn_point(spawn_id: String) -> Marker2D:
	if spawns_container == null:
		return null
	var node: Node = spawns_container.get_node_or_null(spawn_id)
	if node is Marker2D:
		return node as Marker2D
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

func set_all_collisions_disabled(disabled: bool) -> void:
	_recursive_set_colliders_disabled(self, disabled)

func _recursive_set_colliders_disabled(node: Node, disabled: bool) -> void:
	if node is CollisionShape2D:
		(node as CollisionShape2D).disabled = disabled
	elif node is CollisionPolygon2D:
		(node as CollisionPolygon2D).disabled = disabled
	
	for child in node.get_children():
		_recursive_set_colliders_disabled(child, disabled)

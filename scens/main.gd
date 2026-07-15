extends Node2D

@onready var tilemap: TileMapLayer = $TileMapLayer

func _ready() -> void:
	create_invisible_fence()

func create_invisible_fence() -> void:
	if not tilemap: return
	
	var rect = tilemap.get_used_rect()
	var corners_grid = [
		Vector2(rect.position.x, rect.position.y),
		Vector2(rect.end.x, rect.position.y),
		Vector2(rect.end.x, rect.end.y),
		Vector2(rect.position.x, rect.end.y)
	]
	
	var polygon_points = PackedVector2Array()
	for grid_pos in corners_grid:
		var world_pos = tilemap.map_to_local(grid_pos)
		polygon_points.append(world_pos)
	
	var static_body = StaticBody2D.new()
	static_body.collision_layer = 1
	static_body.collision_mask = 1
	
	var collision_polygon = CollisionPolygon2D.new()
	collision_polygon.build_mode = CollisionPolygon2D.BUILD_SEGMENTS
	
	var segments = PackedVector2Array()
	for i in range(polygon_points.size()):
		var p1 = polygon_points[i]
		var p2 = polygon_points[(i + 1) % polygon_points.size()]
		segments.append(p1)
		segments.append(p2)
		
	collision_polygon.polygon = segments
	static_body.add_child(collision_polygon)
	add_child(static_body)

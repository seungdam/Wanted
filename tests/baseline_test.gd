extends Node

func _ready() -> void:
	var village = preload("res://scenes/village.tscn").instantiate()
	add_child(village)
	test_npc(village)
	test_terrain(village)
	var clock = village.get_node("WorldClock")
	clock.set_process(false)
	assert(clock.solar_direction(6.0).is_equal_approx(clock.EAST))
	assert(clock.solar_direction(12.0).is_equal_approx(clock.ZENITH))
	assert(clock.solar_direction(18.0).is_equal_approx(-clock.EAST))
	assert(clock.solar_direction(0.0).is_equal_approx(-clock.ZENITH))
	var previous_sun: Vector3 = clock.solar_direction(0.0)
	for minute in range(1, 1441):
		var sun: Vector3 = clock.solar_direction(minute / 60.0)
		assert(is_equal_approx(sun.length(), 1.0), "Sun stays on the unit sphere")
		assert(absf(previous_sun.angle_to(sun) - TAU / 1440.0) < 0.0001, "Constant angular velocity, including noon and midnight")
		previous_sun = sun
	for solar_hour in [6.5, 9.0, 12.0, 15.0, 17.5]:
		clock.apply_elapsed(solar_hour * 10.0)
		var source_xy := -Vector2.DOWN.rotated(clock.sunlight.rotation)
		var light_vector := Vector3(source_xy.x * (1.0 - clock.sunlight.height), source_xy.y * (1.0 - clock.sunlight.height), clock.sunlight.height).normalized()
		assert(light_vector.is_equal_approx(clock.sun_direction), "DirectionalLight2D matches spherical sun direction")
	clock.apply_elapsed(220.0)
	assert(clock.sunlight.energy == 0.0, "Sun below horizon must not illuminate buildings")
	print("SOLAR TEST PASS: east/zenith/west/nadir, spherical SLERP, uniform angular speed, light vector mapping, no night sunlight")
	clock.apply_elapsed(0.0)
	assert(clock.day == 1 and clock.time_text() == "00:00" and clock.years == 0.0)
	var night_color: Color = clock.ambient.color
	clock.apply_elapsed(60.0)
	assert(clock.phase == "MORNING" and clock.time_text() == "06:00")
	clock.apply_elapsed(120.0)
	assert(clock.phase == "DAYTIME" and clock.time_text() == "12:00" and clock.years == 2.5)
	assert(clock.ambient.color.r > night_color.r)
	clock.apply_elapsed(180.0)
	assert(clock.phase == "NIGHT" and clock.time_text() == "18:00")
	clock.apply_elapsed(239.999)
	assert(clock.day == 1 and clock.time_text() == "23:59")
	clock.apply_elapsed(240.0)
	assert(clock.day == 2 and clock.years == 5.0 and clock.time_text() == "00:00")
	clock.apply_elapsed(720.0)
	assert(clock.day == 4 and clock.years == 15.0)
	clock.started_usec = Time.get_ticks_usec() - 120000000
	clock._process(0.0)
	assert(is_equal_approx(clock.hour, 12.0) or absf(clock.hour - 12.0) < 0.01, "Clock follows system ticks, not frame delta")
	var saved_time: float = clock.timeline_seconds
	clock.preview_enabled = true
	clock.preview_day = 3
	clock.preview_hour = 18.0
	clock._process(0.0)
	assert(clock.day == 3 and clock.time_text() == "18:00")
	assert(clock.timeline_seconds == saved_time)
	clock.preview_enabled = false
	clock.clock_paused = true
	clock.started_usec -= 10000000
	clock._process(0.0)
	assert(clock.timeline_seconds == saved_time, "Pause discards wall time without catch-up")
	clock.clock_paused = false
	clock.time_multiplier = 2.0
	clock.started_usec = Time.get_ticks_usec() - 1000000
	clock._process(0.0)
	assert(absf(clock.timeline_seconds - saved_time - 2.0) < 0.05)
	clock.time_multiplier = 1.0
	var camera = village.get_node("Camera2D")
	camera._process(0.0)
	var camera_start: Vector2 = camera.global_position
	var player_start: Vector2 = village.player.position
	village.player.position += Vector2(100, 0)
	camera._process(0.1)
	assert(camera.global_position.x > camera_start.x and camera.global_position.x < camera_start.x + 100.0)
	var single_step: Vector2 = camera.global_position
	camera.global_position = camera_start
	camera._process(0.05)
	camera._process(0.05)
	assert(camera.global_position.is_equal_approx(single_step), "Camera lerp is frame-rate independent")
	village.player.position = player_start
	print("DEBUG TEST PASS: clock preview/pause/speed and smooth camera tracking")
	var building_sprite: Sprite2D = village.get_node("Objects/Building_4_4/Sprite2D")
	assert(building_sprite.texture is CanvasTexture)
	assert(building_sprite.texture.normal_texture != null)
	print("CLOCK TEST PASS: 240 seconds/day, 5 years/day, phase boundaries, midnight, system ticks, building normal maps")
	village.player.set_physics_process(false)
	var ground: TileMapLayer = village.ground
	for cell in ground.get_used_cells():
		assert(ground.local_to_map(ground.map_to_local(cell)) == cell, "Tile conversion roundtrip")
	assert(ground.get_used_cells().size() == village.map_size.x * village.map_size.y)
	assert(village.map_size == Vector2i(32, 32) and village.is_walkable(Vector2i(31, 31)))
	assert(ground.map_to_local(Vector2i(1, 0)) - ground.map_to_local(Vector2i.ZERO) == Vector2(96, 48))
	assert(ground.map_to_local(Vector2i(0, 1)) - ground.map_to_local(Vector2i.ZERO) == Vector2(-96, 48))
	assert(village.player.scale == Vector2(2, 2))
	assert(village.get_node("Objects/NPC_3_8").scale == village.player.scale)
	assert(village.get_node("Objects/Building_4_4").scale == village.player.scale)
	assert(not village.request_move(Vector2i(-1, 0)))
	assert(not village.request_move(Vector2i(4, 4)))
	assert(not village.request_move(Vector2i(15, 15)))
	assert(village.astar.get_id_path(Vector2i(3, 4), Vector2i(4, 3)).size() > 2, "Blocked corner prevents diagonal shortcut")
	# All eight neighbors are reachable in one edge on open ground.
	for x in range(-1, 2):
		for y in range(-1, 2):
			if x != 0 or y != 0:
				assert(village.astar.get_id_path(Vector2i(8, 7), Vector2i(8 + x, 7 + y)).size() == 2)
	assert(village.request_move(Vector2i(7, 3)))
	var previous: Vector2i = village.player.current_cell
	for cell in village.player.route:
		assert(village.is_walkable(cell))
		var step: Vector2i = cell - previous
		assert(absi(step.x) <= 1 and absi(step.y) <= 1)
		if step.x != 0 and step.y != 0:
			assert(village.is_walkable(previous + Vector2i(step.x, 0)))
			assert(village.is_walkable(previous + Vector2i(0, step.y)))
		previous = cell
	village.player.advance(0.12)
	var active_edge: Vector2i = village.player.path_origin()
	var before: Vector2 = village.player.grid_position
	assert(village.request_move(Vector2i(2, 12)))
	assert(village.player.route[0] == active_edge, "Retarget preserves active edge")
	assert(village.player.grid_position == before, "Retarget must not teleport")
	village.player.advance(20.0)
	assert(village.player.current_cell == Vector2i(2, 12))
	assert(village.player.position.is_equal_approx(ground.map_to_local(Vector2i(2, 12))))
	assert(village.player.route.is_empty())
	assert(village.request_move(Vector2i(2, 12)))
	village.player.advance(0.0)
	assert(village.player.route.is_empty(), "Same-cell click completes")
	# An isolated, otherwise walkable target must reject the command.
	for x in range(3):
		for y in range(3):
			if Vector2i(x, y) != Vector2i.ONE:
				village.astar.set_point_solid(Vector2i(x, y))
	assert(not village.request_move(Vector2i.ONE))
	await get_tree().process_frame
	var hud_click := InputEventMouseButton.new()
	hud_click.button_index = MOUSE_BUTTON_LEFT
	hud_click.pressed = true
	hud_click.position = village.get_node("HUD/TimeBar").get_global_rect().get_center()
	get_viewport().push_input(hud_click, true)
	assert(village.player.route.is_empty(), "Time bar consumes clicks instead of moving the player")
	for button in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		var click := InputEventMouseButton.new()
		click.button_index = button
		click.pressed = true
		click.position = ground.get_global_transform_with_canvas() * ground.map_to_local(Vector2i(9, 7))
		get_viewport().push_input(click, true)
		assert(not village.player.route.is_empty(), "Click creates a route")
		assert(village.player.route.back() == Vector2i(9, 7), "Mouse input maps through camera to destination")
		village.player.advance(20.0)
		assert(village.player.current_cell == Vector2i(9, 7))
	print("BASELINE TEST PASS: projection, expanded map, 8 directions, obstacles, corner blocking, retarget, arrival, unreachable target, left/right mouse input")
	if "--capture-terrain" in OS.get_cmdline_user_args():
		await capture_terrain(village)
	if "--capture" in OS.get_cmdline_user_args():
		remove_child(village)
		village.queue_free()
		var preview = preload("res://scenes/village.tscn").instantiate()
		add_child(preview)
		var preview_clock = preview.get_node("WorldClock")
		preview_clock.set_process(false)
		for entry in [[80.0, "morning"], [120.0, "daytime"], [160.0, "afternoon"], [220.0, "night"]]:
			preview_clock.apply_elapsed(entry[0])
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var error := get_viewport().get_texture().get_image().save_png("res://tests/" + entry[1] + "-preview.png")
			assert(error == OK, "Screenshot saved")
		print("PREVIEWS SAVED: morning, daytime, night")
	get_tree().quit()

func test_npc(village: Node2D) -> void:
	var npc = village.get_node("Objects/NPC_3_8")
	# Isolate distance fading; terrain visibility is exercised in test_terrain.
	var terrain = npc.terrain_reveal
	npc.terrain_reveal = null
	for child in village.get_node("Objects").get_children():
		if child.name.begins_with("NPC_"):
			child.set_physics_process(false)
	assert(npc.speed < village.player.speed)
	npc.ai_enabled = false
	var stopped_position: Vector2 = npc.grid_position
	npc._physics_process(10.0)
	assert(npc.grid_position == stopped_position)
	npc.ai_enabled = true
	npc.random.seed = 42
	assert(npc.behavior is BTPlayer)
	var root: BTTask = npc.behavior.get_bt_instance().get_root_task()
	assert(root is BTSequence and root.get_child(0) is BTRandomWait)
	assert(root != village.get_node("Objects/NPC_5_9/BTPlayer").get_bt_instance().get_root_task(), "Each NPC owns an independent tree instance")
	root.get_child(0).min_duration = 1.0
	root.get_child(0).max_duration = 1.0
	var start: Vector2 = npc.grid_position
	npc.behavior.update(0.1)
	assert(npc.grid_position == start and npc.route.is_empty(), "BT waits before choosing a destination")
	npc.behavior.update(1.0)
	assert(root.get_child(2).get_status() == BT.RUNNING and not npc.route.is_empty(), "BT sequence reaches running movement leaf")
	assert(npc.behavior.blackboard.get_var(&"destination") == npc.route.back())
	var previous: Vector2i = npc.current_cell
	for cell in npc.route:
		assert(village.is_walkable(cell))
		var step: Vector2i = cell - previous
		if step.x != 0 and step.y != 0:
			assert(village.is_walkable(previous + Vector2i(step.x, 0)))
			assert(village.is_walkable(previous + Vector2i(0, step.y)))
		previous = cell
	var destination: Vector2i = npc.route.back()
	npc.behavior.update(60.0)
	assert(npc.current_cell == destination and root.get_status() == BT.SUCCESS, "BT finishes travel")
	var saved_destinations: Array[Vector2i] = npc.destinations
	var no_destination: Array[Vector2i] = [npc.current_cell]
	npc.destinations = no_destination
	root.get_child(0).min_duration = 0.0
	root.get_child(0).max_duration = 0.0
	npc.behavior.update(0.0)
	assert(root.get_status() == BT.FAILURE, "No destination fails cleanly")
	assert(npc.route.is_empty())
	npc.destinations = saved_destinations
	var observer = village.player
	var observer_position: Vector2 = observer.grid_position
	npc.grid_position = observer_position
	npc.update_visibility(0.0, true)
	assert(npc.visible and npc.modulate.a == 1.0)
	npc.grid_position = observer_position + Vector2(observer.vision_radius - observer.vision_fade_width / 2, 0)
	npc.update_visibility(0.0, true)
	assert(absf(npc.modulate.a - 0.5) < 0.001, "Spatial fade has a smooth half-alpha boundary")
	npc.grid_position = observer_position + Vector2(observer.vision_radius + 1, 0)
	npc.update_visibility(0.01)
	assert(npc.visible and npc.modulate.a > 0.0 and npc.modulate.a < 0.5, "Leaving vision fades rather than popping")
	npc.update_visibility(1.0)
	assert(not npc.visible and npc.modulate.a == 0.0, "Fully faded NPC disables rendering")
	npc.ignore_vision = true
	npc.update_visibility(0.0, true)
	assert(npc.visible and npc.modulate.a == 1.0)
	npc.ignore_vision = false
	npc.update_visibility(0.0, true)
	npc.grid_position = observer_position
	npc.update_visibility(0.01)
	assert(npc.visible and npc.modulate.a > 0.0 and npc.modulate.a < 1.0, "Re-entry fades in")
	# Hidden NPCs keep their simulation running and use the same obstacle-aware mover.
	npc.grid_position = Vector2(npc.current_cell)
	observer.grid_position = Vector2(-100, -100)
	npc.update_visibility(0.0, true)
	start = npc.grid_position
	for index in range(300):
		npc._physics_process(0.1)
		assert(village.is_walkable(village.ground.local_to_map(npc.position)))
		assert(not npc.visible)
	assert(not npc.grid_position.is_equal_approx(start), "Hidden NPC still wanders")
	observer.grid_position = observer_position
	npc.terrain_reveal = terrain
	print("NPC TEST PASS: LimboAI BTPlayer, independent trees, Blackboard, wait/select/walk/failure, obstacle routes, fade, hidden simulation")

func test_terrain(village: Node2D) -> void:
	var terrain = village.get_node("TerrainReveal")
	var start: Vector2 = village.player.grid_position
	var count: int = village.ground.get_used_cells().size()
	assert(terrain.reveal_radius > village.player.vision_radius)
	assert(terrain.is_landed(village.player.current_cell))
	assert(not terrain.ages.has(Vector2i(31, 31)))
	assert(village.is_walkable(Vector2i(31, 31)), "Unrevealed cells remain navigable")
	for heading in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN, Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		var forward: Vector2 = heading.normalized()
		var side := forward.orthogonal()
		assert(terrain.entry_delay(forward * 4.0, heading) < terrain.entry_delay(forward * 8.0, heading), "Wave travels outward along heading")
		assert(is_equal_approx(terrain.entry_delay(forward * 4.0 + side * 2.0, heading), terrain.entry_delay(forward * 4.0 - side * 2.0, heading)), "Fan is symmetric")
		assert(terrain.entry_delay(forward * 4.2, heading) == terrain.entry_delay(forward * 5.2, heading), "Broad bands share a drop time")
	assert(terrain.entry_delay(Vector2(8, 0), Vector2.RIGHT) != terrain.entry_delay(Vector2(8, 0), Vector2.DOWN), "Direction changes the wave order")
	assert(terrain.ages[Vector2i(2, 11)] > terrain.ages[Vector2i(2, 15)], "Near forward bands drop first")
	village._process(0.0)
	assert(not village.get_node("Objects/Building_3_11").visible, "Building waits for support")
	terrain.update_reveal(4.0)
	village._process(0.0)
	assert(village.get_node("Objects/Building_3_11").visible)
	assert(terrain.exposed_depth(Vector2i(5, 7), Vector2i(6, 7)) == 0.0, "No internal sides after landing")
	assert(terrain.exposed_depth(Vector2i(0, 0), Vector2i(-1, 0)) == terrain.thickness)
	var cell := Vector2i(20, 20)
	village.player.grid_position = Vector2(cell)
	terrain.update_reveal(0.0)
	assert(not terrain.is_landed(cell) and terrain.drop_offset(cell) < 0.0)
	var age: float = terrain.ages[cell]
	var heading: Vector2i = village.player.facing
	village.player.facing = -heading
	terrain.update_reveal(0.0)
	assert(terrain.ages[cell] == age, "No duplicate or restarted drop")
	village.player.facing = heading
	var last_offset: float = -terrain.drop_height
	for step in range(11):
		terrain.ages[cell] = terrain.drop_seconds * step / 10.0
		var offset: float = terrain.drop_offset(cell)
		assert(offset >= last_offset and offset <= 0.0, "Slow descent never rebounds")
		last_offset = offset
	terrain.ages[cell] = age
	var npc = village.get_node("Objects/NPC_3_8")
	var saved_position: Vector2 = npc.grid_position
	npc.grid_position = Vector2(cell)
	npc.update_visibility(0.0, true)
	assert(not npc.visible, "NPC stays hidden until support lands")
	terrain.update_reveal(4.0)
	assert(terrain.is_landed(cell) and is_zero_approx(terrain.drop_offset(cell)))
	npc.update_visibility(0.0, true)
	assert(npc.visible)
	village.player.grid_position = Vector2(cell) + Vector2(terrain.reveal_radius + terrain.reveal_margin + 1.0, 0)
	terrain.update_reveal(0.0)
	assert(terrain.is_landed(cell), "Exit band retains settled cells")
	village.player.grid_position = start
	terrain.update_reveal(0.0)
	assert(not terrain.ages.has(cell), "Full exit rearms a cell")
	village.player.grid_position = Vector2(cell)
	terrain.update_reveal(0.0)
	assert(not terrain.is_landed(cell), "Re-entry drops again")
	village.player.grid_position = start
	terrain.update_reveal(0.0)
	assert(terrain.ages.has(cell), "Leaving during a drop does not interrupt it")
	terrain.update_reveal(4.0)
	assert(not terrain.ages.has(cell), "Finished out-of-range drops retire")
	assert(village.ground.get_used_cells().size() == count)
	assert(not village.is_walkable(Vector2i(4, 4)) and not village.is_walkable(Vector2i(15, 15)))
	npc.grid_position = saved_position
	print("TERRAIN TEST PASS: 8-direction fan, broad bands, no restart on turns, monotonic drop, sides, NPC support, hysteresis, re-entry, navigation")

func capture_terrain(village: Node2D) -> void:
	var terrain = village.get_node("TerrainReveal")
	terrain.set_process(false)
	village.player.grid_position = Vector2(20, 20)
	village.player.current_cell = Vector2i(20, 20)
	village.player.facing = Vector2i(1, 0)
	village.player.advance(0.0)
	village.get_node("WorldClock").apply_elapsed(120.0)
	var camera = village.get_node("Camera2D")
	camera.tracking_enabled = false
	camera.global_position = village.player.global_position + camera.tracking_offset
	terrain.ages.clear()
	terrain.last_center = Vector2.INF
	terrain.update_reveal(0.0, true)
	for entry in [[0.7, "drop"], [4.0, "landed"]]:
		terrain.update_reveal(entry[0])
		for child in village.get_node("Objects").get_children():
			if child.name.begins_with("NPC_"):
				child.update_visibility(0.0, true)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		assert(get_viewport().get_texture().get_image().save_png("res://tests/terrain-" + entry[1] + ".png") == OK)

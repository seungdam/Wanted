extends Node

func _ready() -> void:
	var village = preload("res://scenes/village.tscn").instantiate()
	add_child(village)
	test_npc(village)
	test_viewport_drop(village)
	test_occlusion(village)
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
	assert(village.map_size == Vector2i(16, 16) and village.is_walkable(Vector2i(15, 0)))
	assert(ground.map_to_local(Vector2i(1, 0)) - ground.map_to_local(Vector2i.ZERO) == Vector2(32, 16))
	assert(ground.map_to_local(Vector2i(0, 1)) - ground.map_to_local(Vector2i.ZERO) == Vector2(-32, 16))
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
	assert(village.player.position.is_equal_approx(ground.to_global(ground.map_to_local(Vector2i(2, 12)))))
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
	if "--capture" in OS.get_cmdline_user_args():
		remove_child(village)
		village.queue_free()
		var preview = preload("res://scenes/village.tscn").instantiate()
		add_child(preview)
		var preview_clock = preview.get_node("WorldClock")
		preview_clock.set_process(false)
		for entry in [[80.0, "morning"], [120.0, "daytime"], [160.0, "afternoon"], [220.0, "night"], [840.0, "day4"]]:
			preview_clock.apply_elapsed(entry[0])
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var error := get_viewport().get_texture().get_image().save_png("res://tests/" + entry[1] + "-preview.png")
			assert(error == OK, "Screenshot saved")
		var cabin = preview.get_node("Objects/Building_4_4")
		preview.player.global_position = cabin.global_position + Vector2(0, -25)
		preview.player.set_physics_process(false)
		preview.get_node("Camera2D").global_position = cabin.global_position
		preview.get_node("Camera2D").tracking_enabled = false
		cabin._process(2.0)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		assert(get_viewport().get_texture().get_image().save_png("res://tests/occlusion-preview.png") == OK)
		print("PREVIEWS SAVED: morning, daytime, afternoon, night, day4, occlusion")
	get_tree().quit()

func test_npc(village: Node2D) -> void:
	var npc = village.get_node("Objects/NPC_3_8")
	for day in range(1, 7):
		village.update_residents(day)
		var count := 0
		for resident in village.residents:
			count += int(resident.joined)
			assert(resident.visible == resident.joined)
			assert(resident.is_physics_processing() == resident.joined)
		assert(count == mini(day, 4), "Daily arrivals cap at four")
	village.update_residents(1)
	assert(not village.residents[1].joined, "Preview rewinds without duplicate residents")
	assert(village.residents.size() == 4)
	village.update_residents(4)
	assert(village.has_node("TerrainReveal") and not village.has_node("VisionRange"))
	assert(not village.ground.visible, "Visual terrain renderer owns ground rendering")
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
	var saved_player: Vector2 = village.player.position
	village.player.position = Vector2(-10000, -10000)
	for step in range(30):
		npc._physics_process(0.1)
		assert(npc.visible and npc.modulate.a == 1.0, "Residents have no distance visibility restriction")
	village.player.position = saved_player
	village.update_residents(1)
	print("NPC TEST PASS: daily arrivals, four-resident cap, preview rewind, LimboAI wandering, no vision culling")

func test_occlusion(village: Node2D) -> void:
	var building = village.get_node("Objects/Building_4_4")
	var saved: Vector2 = village.player.global_position
	village.player.global_position = building.global_position + Vector2(0, -25)
	assert(building.is_obscuring_player(), "Player behind artwork is detected")
	building._process(0.1)
	assert(building.modulate.a < 1.0 and building.modulate.a > building.occluded_alpha, "Fade is smooth")
	building._process(2.0)
	assert(absf(building.modulate.a - building.occluded_alpha) < 0.01)
	village.player.global_position = building.global_position + Vector2(0, 20)
	assert(not building.is_obscuring_player(), "Player in front does not fade building")
	building._process(2.0)
	assert(building.modulate.a > 0.99)
	village.player.global_position = building.global_position + Vector2(300, -25)
	assert(not building.is_obscuring_player(), "No fade when horizontally separated")
	village.player.global_position = saved
	print("OCCLUSION TEST PASS: behind/front/side and smooth fade/restoration")

func test_viewport_drop(village: Node2D) -> void:
	var terrain = village.get_node("TerrainReveal")
	var camera = village.get_node("Camera2D")
	var saved_position: Vector2 = camera.global_position
	var saved_zoom: Vector2 = camera.zoom
	camera.tracking_enabled = false
	assert(not terrain.whole_world_visible, "Default map exceeds viewport")
	assert(terrain.cells.size() < village.ground.get_used_cells().size())
	assert(terrain.global_transform == village.ground.global_transform, "Pixel tile scale preserved")
	var target := Vector2i(12, 2)
	var camera_destination := Vector2(192, 256)
	assert(not terrain.ages.has(target))
	assert(village.is_walkable(target), "Offscreen cells stay navigable")
	camera.global_position = camera_destination
	camera.force_update_scroll()
	terrain.update_reveal(0.0)
	assert(terrain.is_landed(target), "Interior tiles appear immediately, including large camera jumps")
	var dropping: Array[Vector2i] = []
	for cell in terrain.cells:
		if not terrain.is_landed(cell):
			dropping.append(cell)
			assert(terrain.is_edge_tile(terrain.tile_screen_rect(cell), terrain.get_viewport_rect()))
	assert(not dropping.is_empty() and dropping.size() <= terrain.max_active_drops, "Only a small capped subset drops")
	assert(dropping.size() < terrain.cells.size() / 2)
	target = dropping[0]
	var age: float = terrain.ages[target]
	var delays := {}
	for cell in terrain.cells:
		if terrain.ages[cell] < 0.0:
			delays[snappedf(terrain.ages[cell], 0.001)] = true
	assert(delays.size() == dropping.size(), "Selected tiles keep distinct start times")
	var view := Rect2(0, 0, 1280, 800)
	var earliest := 1.0
	var latest := 0.0
	for row in range(16):
		var cell := Vector2i(15, row)
		var rect := Rect2(1250, row * 48, 64, 32)
		var delay: float = terrain.entry_delay(cell, rect, view)
		assert(delay == terrain.entry_delay(cell, rect, view), "Stagger is deterministic")
		assert(delay >= 0.0 and delay <= terrain.edge_sweep_seconds + terrain.tile_stagger_seconds, "No unbounded reveal queue")
		earliest = minf(earliest, delay)
		latest = maxf(latest, delay)
	assert(latest - earliest > 0.1, "Same-edge arrivals spread across time")
	var saved_stagger: float = terrain.tile_stagger_seconds
	terrain.tile_stagger_seconds = 0.0
	assert(terrain.entry_delay(target, Rect2(1250, 200, 64, 32), view) < terrain.entry_delay(target, Rect2(1250, 600, 64, 32), view), "Continuous screen-edge sweep, independent of player facing")
	terrain.tile_stagger_seconds = saved_stagger
	terrain.update_reveal(0.0)
	assert(terrain.ages[target] == age, "No restart while in viewport")
	var previous: float = terrain.drop_offset(target)
	for step in range(30):
		terrain.update_reveal(0.1)
		var offset: float = terrain.drop_offset(target)
		assert(offset >= previous and offset <= 0.0, "Monotonic descent")
		previous = offset
	assert(terrain.is_landed(target))
	camera.global_position += Vector2(8, 0)
	camera.force_update_scroll()
	terrain.update_reveal(0.0)
	assert(terrain.is_landed(target), "Small camera motion does not rearm")
	camera.global_position = Vector2(-5000, -5000)
	camera.force_update_scroll()
	terrain.update_reveal(3.0)
	assert(not terrain.ages.has(target), "Far-offscreen tile rearms")
	camera.global_position = camera_destination
	camera.force_update_scroll()
	terrain.update_reveal(0.0)
	assert(terrain.ages.has(target), "Re-entry renders immediately even if drop slots are full")
	for cell in terrain.cells:
		if not terrain.is_landed(cell):
			target = cell
			break
	camera.global_position = village.ground.to_global(village.ground.map_to_local(target))
	camera.force_update_scroll()
	terrain.update_reveal(0.0)
	assert(terrain.is_landed(target), "Drops stop when camera brings them into the interior")
	terrain.drop_enabled = false
	terrain.update_reveal(0.0)
	assert(terrain.cells.size() == village.ground.get_used_cells().size())
	assert(terrain.is_landed(target), "Inspector toggle settles terrain")
	terrain.drop_enabled = true
	camera.global_position = village.ground.to_global(village.ground.map_to_local(Vector2i(7, 7)))
	camera.zoom = Vector2(0.3, 0.3)
	camera.force_update_scroll()
	terrain.update_reveal(0.0)
	assert(terrain.whole_world_visible, "Zoom-out showing entire map bypasses drop")
	for cell in village.ground.get_used_cells():
		assert(terrain.is_landed(cell))
	camera.zoom = saved_zoom
	camera.global_position = saved_position
	camera.force_update_scroll()
	terrain.update_reveal(3.0)
	camera.tracking_enabled = true
	print("VIEWPORT DROP TEST PASS: camera entry, scale, no restart, smooth fall, re-entry, toggle, whole-world zoom-out, navigation")

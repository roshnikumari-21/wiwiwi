extends SceneTree
## Fair-play check for every level in the catalog (see plan.md §3 "Fair-play rules"):
## after a gap there must be room to land, nothing harmful right before a take-off edge, and after
## jumping one hazard there is room to land before the next one on the same ground.
## Run: godot --headless --path . --script res://dev/m1_fairness_test.gd

const SPIKES_AFTER_LANDING := 450.0   # a full-speed jump travels ~395 px
const SPIKES_BEFORE_EDGE := 300.0
const SLIME_AFTER_LANDING := 300.0
const SLIME_BEFORE_EDGE := 200.0
const BETWEEN_HAZARDS := 300.0         # safe ground between two hazards on the same surface (added 31 Oct 2026)

var _fails := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var catalog = root.get_node("GameState").catalog
	for data in catalog.levels:
		var level = load(data.scene_path).instantiate()
		root.add_child(level)
		await physics_frame
		var problems := _audit(level)
		_check("%s: fair landings and take-offs" % data.id, problems.is_empty(), "\n    " + "\n    ".join(problems))
		level.queue_free()
		await physics_frame
	print("RESULT: %s" % ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	quit(_fails)

func _audit(level: Node) -> Array[String]:
	var problems: Array[String] = []
	var ground := []
	for b in level.get_node("Terrain").get_children():
		if b is GroundBlock and not b.one_way and b.size.x > 200.0:   # skip the thin end walls
			ground.append(b)
	var hazards := []   # [span, ground height, name]
	ground.sort_custom(func(a, b): return a.global_position.x < b.global_position.x)
	var gaps := []   # [take-off edge x, landing edge x]
	for i in ground.size() - 1:
		var near: float = ground[i].global_position.x + ground[i].size.x
		var far: float = ground[i + 1].global_position.x
		if far > near + 2.0:
			gaps.append([near, far])
	for obj in level.get_node("Objects").get_children():
		var span := Vector2.INF   # x from..to of the harmful area
		var after := 0.0
		var before := 0.0
		if obj.scene_file_path.ends_with("spikes.tscn"):
			var shape: CollisionShape2D = obj.get_node("Shape")
			var half: float = shape.shape.size.x * 0.5
			span = Vector2(shape.global_position.x - half, shape.global_position.x + half)
			after = SPIKES_AFTER_LANDING
			before = SPIKES_BEFORE_EDGE
		elif obj.scene_file_path.ends_with("slime.tscn"):
			span = Vector2(obj.global_position.x - obj.patrol_distance - 50.0, obj.global_position.x + obj.patrol_distance + 50.0)
			after = SLIME_AFTER_LANDING
			before = SLIME_BEFORE_EDGE
		else:
			continue
		hazards.append([span, obj.global_position.y, obj.name])
		for g in gaps:
			if span.x < g[1] + after and span.y > g[1]:
				problems.append("%s at x %d is %d px after the landing at %d (needs %d)" % [obj.name, int(obj.global_position.x), int(span.x - g[1]), int(g[1]), int(after)])
			if span.x < g[0] and span.y > g[0] - before:
				problems.append("%s at x %d is %d px before the take-off edge at %d (needs %d)" % [obj.name, int(obj.global_position.x), int(g[0] - span.y), int(g[0]), int(before)])
	hazards.sort_custom(func(a, b): return a[0].x < b[0].x)
	for i in hazards.size() - 1:
		for j in range(i + 1, hazards.size()):
			var a = hazards[i]
			var b = hazards[j]
			if absf(a[1] - b[1]) > 5.0:   # different heights: not the same stretch of ground
				continue
			var room: float = b[0].x - a[0].y
			if room < BETWEEN_HAZARDS:
				problems.append("%s and %s have only %d px between them (needs %d)" % [a[2], b[2], int(room), int(BETWEEN_HAZARDS)])
			break   # only the next hazard on the same height matters
	return problems

func _check(name: String, ok: bool, got) -> void:
	if not ok:
		_fails += 1
	print("%s  %s%s" % ["PASS" if ok else "FAIL", name, "" if ok else str(got)])

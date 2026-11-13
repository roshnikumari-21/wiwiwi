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
	var scenes: Array = catalog.levels.map(func(d): return [d.id, d.scene_path])
	scenes.append(["forest_tools_demo", "res://dev/forest_tools_demo.tscn"])   # World 3's new pieces, before its levels exist
	for row in scenes:
		var data := {"id": row[0]}
		var level = load(row[1]).instantiate()
		root.add_child(level)
		await physics_frame
		var problems := _audit(level)
		_check("%s: fair landings and take-offs" % data.id, problems.is_empty(), "\n    " + "\n    ".join(problems))
		var blocked := _path(level)
		_check("%s: every gap and cliff on the way is passable" % data.id, blocked.is_empty(), "\n    " + "\n    ".join(blocked))
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
		elif obj.scene_file_path.ends_with("penguin.tscn"):   # World 4: its belly slide covers the whole path, fast
			span = Vector2(obj.global_position.x - obj.patrol_distance - 100.0, obj.global_position.x + obj.patrol_distance + 100.0)
			after = SLIME_AFTER_LANDING
			before = SLIME_BEFORE_EDGE
		elif obj.scene_file_path.ends_with("hedgehog.tscn"):   # World 3: like a slime, but it can't be stomped
			span = Vector2(obj.global_position.x - obj.patrol_distance - 50.0, obj.global_position.x + obj.patrol_distance + 50.0)
			after = SLIME_AFTER_LANDING
			before = SLIME_BEFORE_EDGE
		elif obj.scene_file_path.ends_with("pinecone.tscn"):   # World 3: where it lands
			span = Vector2(obj.global_position.x - 80.0, obj.global_position.x + 80.0)
			after = SLIME_AFTER_LANDING
			before = SLIME_BEFORE_EDGE
		elif obj.scene_file_path.ends_with("hopper_slime.tscn"):   # World 2: can hop hop_length past its path
			var reach: float = obj.patrol_distance + obj.hop_length + 50.0
			span = Vector2(obj.global_position.x - reach, obj.global_position.x + reach)
			after = SLIME_AFTER_LANDING
			before = SLIME_BEFORE_EDGE
		elif obj.scene_file_path.ends_with("slime.tscn"):
			span = Vector2(obj.global_position.x - obj.patrol_distance - 50.0, obj.global_position.x + obj.patrol_distance + 50.0)
			after = SLIME_AFTER_LANDING
			before = SLIME_BEFORE_EDGE
		else:
			continue
		if obj.scene_file_path.ends_with("pinecone.tscn"):   # never above a walkway/ledge: its shadow is on the floor
			# (World 4's icicles hang UNDER a walkway: the walkway is above where it hangs, so that's fine)
			for b in level.get_node("Terrain").get_children():
				if b is GroundBlock and b.one_way and b.global_position.y < obj.global_position.y and b.global_position.y > obj.global_position.y - obj.height and b.global_position.x - 100.0 < obj.global_position.x and obj.global_position.x < b.global_position.x + b.size.x + 100.0:
					problems.append("%s at x %d hangs over the ledge %s" % [obj.name, int(obj.global_position.x), b.name])
		hazards.append([span, obj.global_position.y, obj.name])
		for g in gaps:
			if span.x < g[1] + after and span.y > g[1]:
				problems.append("%s at x %d is %d px after the landing at %d (needs %d)" % [obj.name, int(obj.global_position.x), int(span.x - g[1]), int(g[1]), int(after)])
			if span.x < g[0] and span.y > g[0] - before:
				problems.append("%s at x %d is %d px before the take-off edge at %d (needs %d)" % [obj.name, int(obj.global_position.x), int(g[0] - span.y), int(g[0]), int(before)])
	# Slippery ice (World 4): she slides ~200 px to a stop, so ice must end on at least 300 px of snow
	# before the next gap, and spikes never sit on ice.
	for i in ground.size():
		var b = ground[i]
		if b.theme != "ice":
			continue
		var stop := 0.0
		for j in range(i + 1, ground.size()):
			var n = ground[j]
			if n.global_position.x > ground[j - 1].global_position.x + ground[j - 1].size.x + 2.0:
				break   # a gap
			if n.theme == "ice":
				continue
			stop += n.size.x
			break
		if stop < 300.0 and i < ground.size() - 1:
			problems.append("ice %s ends with only %d px of snow before a gap (needs 300)" % [b.name, int(stop)])
		for obj in level.get_node("Objects").get_children():
			if obj.scene_file_path.ends_with("spikes.tscn") and obj.global_position.x > b.global_position.x - 40.0 					and obj.global_position.x < b.global_position.x + b.size.x + 40.0 and absf(obj.global_position.y - b.global_position.y) < 5.0:
				problems.append("spikes %s sit on ice %s" % [obj.name, b.name])
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

## Walks the ground from start to end: each gap or rise must be jumpable, or have a plank, a lift,
## a mushroom or crumbling tiles (World 2) that get the cat across or up. (Numbers from player.gd: jump ~300 up / ~395 across;
## a tired cat still clears 300 px; a mushroom's small bounce lifts ~480 px above its cap.)
func _path(level: Node) -> Array[String]:
	var problems: Array[String] = []
	var ground := []
	for b in level.get_node("Terrain").get_children():
		if b is GroundBlock and not b.one_way and b.size.x > 200.0:
			ground.append(b)
	ground.sort_custom(func(a, b): return a.global_position.x < b.global_position.x)
	var planks := []
	var mushrooms := []
	var tiles := []   # World 2 crumbling roof tiles
	for o in level.get_node("Objects").get_children():
		if o.scene_file_path.ends_with("crumble_tile.tscn"):
			tiles.append(o)
		elif o.scene_file_path.ends_with("moving_platform.tscn"):
			planks.append(o)
		elif o.scene_file_path.ends_with("mushroom.tscn"):
			mushrooms.append(o)
	for i in ground.size() - 1:
		var a = ground[i]
		var b = ground[i + 1]
		var edge: float = a.global_position.x + a.size.x
		var gap: float = b.global_position.x - edge
		var rise: float = a.global_position.y - b.global_position.y   # > 0: the next ground is higher
		if gap <= 300.0 and rise <= 220.0:
			continue
		var helped := false
		for p in planks:
			var px: float = p.global_position.x
			if px > edge - 200.0 and px < b.global_position.x + 200.0 and (rise <= 0.0 or -p.move_by.y >= rise):
				helped = true
		for m in mushrooms:
			var mx: float = m.global_position.x
			if mx > edge - 450.0 and mx < edge and absf(m.global_position.y - a.global_position.y) < 2.0 and rise <= 440.0 and gap <= 120.0:
				helped = true
		# Crumbling tiles: a bridge over the gap, or a staircase whose top tile is a hop below the cliff.
		for t in tiles:
			var tx: float = t.global_position.x
			if gap > 300.0 and tx > edge and tx < b.global_position.x and rise <= 0.0:
				helped = true
			if rise > 220.0 and tx > edge - 500.0 and tx < b.global_position.x and b.global_position.y > t.global_position.y - 220.0:
				helped = true
		# Ledge hops (World 4): narrow ledges across a wide river.
		for ledge in level.get_node("Terrain").get_children():
			if ledge is GroundBlock and ledge.one_way and String(ledge.name).begins_with("Hop") and rise <= 0.0 \
					and ledge.global_position.x > edge and ledge.global_position.x < b.global_position.x:
				helped = true
		# A tree climb (World 3): ledges zigzag up in front of the cliff; the top one is a short hop below it.
		for ledge in level.get_node("Terrain").get_children():
			if ledge is GroundBlock and ledge.one_way and String(ledge.name).begins_with("Climb"):
				var lx: float = ledge.global_position.x + ledge.size.x
				if lx > b.global_position.x - 200.0 and lx <= b.global_position.x + 2.0 and ledge.global_position.y - b.global_position.y <= 200.0 and ledge.global_position.y > b.global_position.y:
					helped = true
		if not helped:
			problems.append("at x %d: gap %d px, rise %d px, nothing to get across" % [int(edge), int(gap), int(rise)])
	return problems

func _check(name: String, ok: bool, got) -> void:
	if not ok:
		_fails += 1
	print("%s  %s%s" % ["PASS" if ok else "FAIL", name, "" if ok else str(got)])

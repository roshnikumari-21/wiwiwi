extends SceneTree
## Cat Shop: ginger is owned and chosen at the start; a cat can be bought only with enough coins,
## buying chooses it, owned cats can be chosen again, everything survives a reload, and the chosen
## colour is worn on the home cushion, in the popups, on the map, in levels and in the hug.
## Run: godot --headless --path . --script res://dev/m2_shop_test.gd

var _fails := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var save = root.get_node("SaveManager")
	var skins = load("res://scenes/actors/player/cat_skins.gd")
	save.save_path = "user://shop_test.json"
	save.reset_progress()
	_check("start: ginger owned and chosen", save.owns_cat("ginger") and save.chosen_cat() == "ginger" and not save.owns_cat("snowy"), save.chosen_cat())
	_check("6 cats, ginger free, prices go up", skins.ALL.size() == 6 and skins.ALL[0].price == 0 and skins.ALL.map(func(s): return s.price) == [0, 150, 250, 400, 600, 800], "")
	save.add_coins(200)
	_check("can't buy Misty (400) with 200 coins", not save.buy_cat("misty") and save.purse() == 200 and not save.owns_cat("misty"), save.purse())
	_check("buy Snowy (150): paid, owned, chosen", save.buy_cat("snowy") and save.purse() == 50 and save.chosen_cat() == "snowy", [save.purse(), save.chosen_cat()])
	_check("buying an owned cat costs nothing", save.buy_cat("snowy") and save.purse() == 50, save.purse())
	save.choose_cat("tuxedo")
	_check("can't choose a cat not owned", save.chosen_cat() == "snowy", save.chosen_cat())
	save.choose_cat("ginger")
	_check("choose ginger again", save.chosen_cat() == "ginger", save.chosen_cat())
	save.choose_cat("snowy")
	save.load_game()
	_check("after a reload: Snowy owned and chosen, 50 coins", save.owns_cat("snowy") and save.chosen_cat() == "snowy" and save.purse() == 50, "")

	# The shop popup on the home page
	save.add_coins(600)   # 650
	var home = load("res://ui/screens/main_menu.tscn").instantiate()
	root.add_child(home)
	await process_frame
	_check("home kitten wears Snowy", _patch(home.kitten) == skins.find("snowy").patch, "")
	var menu = home.menu
	home.cat_shop.pressed.emit()
	await process_frame
	_check("shop opens at the chosen cat with a disabled 'Chosen'", menu.current == "shop" and _main(menu).text == "BTN_CHOSEN" and _main(menu).disabled and _name(menu) == "CAT_SNOWY", _name(menu))
	menu.find_child("Next", true, false).pressed.emit()
	await process_frame
	_check("arrow shows the next cat (Cocoa, 250, can afford)", _name(menu) == "CAT_COCOA" and _main(menu).text == "250" and not _main(menu).disabled, [_name(menu), _main(menu).text])
	menu.find_child("Previous", true, false).pressed.emit()
	menu.find_child("Previous", true, false).pressed.emit()
	await process_frame
	_check("arrows wrap around: before Snowy comes Ginger, owned -> 'Choose'", _name(menu) == "CAT_GINGER" and _main(menu).text == "BTN_CHOOSE", _name(menu))
	menu.show_cat_shop(5)
	await process_frame
	_check("Bubblegum (800) with 650 coins: 'Need 800', disabled", _main(menu).disabled and _main(menu).text == "Need 800", _main(menu).text)
	menu.show_cat_shop(4)
	await process_frame
	_main(menu).pressed.emit()
	await process_frame
	_check("buy Tuxedo from the shop: 50 coins left, chosen, pill updated", save.chosen_cat() == "tuxedo" and save.purse() == 50 and _main(menu).text == "BTN_CHOSEN" and menu.find_child("Purse", true, false).find_children("*", "Label", true, false)[0].text == "50", save.purse())
	_check("home kitten now wears Tuxedo", _patch(home.kitten) == skins.find("tuxedo").patch, "")
	home._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_check("Android Back closes the shop", menu.current == "" and not menu.visible, menu.current)
	home.queue_free()
	await process_frame

	var level = load("res://scenes/levels/w1/level_w1_01.tscn").instantiate()
	root.add_child(level)
	await process_frame
	_check("the cat in the level wears Tuxedo", _patch(level.get_node("Player/Sprite")) == skins.find("tuxedo").patch, "")
	level.queue_free()
	var map = load("res://ui/screens/level_map.tscn").instantiate()
	root.add_child(map)
	await process_frame
	_check("the kitten on the map wears Tuxedo", _patch(map.find_child("Kitten", true, false)) == skins.find("tuxedo").patch, "")
	map.queue_free()
	save.choose_cat("ginger")
	var level2 = load("res://scenes/levels/w1/level_w1_01.tscn").instantiate()
	root.add_child(level2)
	await process_frame
	_check("ginger needs no shader (drawings untouched)", level2.get_node("Player/Sprite").material == null, "")
	level2.queue_free()

	for f in ["", ".bak"]:
		DirAccess.remove_absolute(save.save_path + f)
	print("RESULT: %s" % ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	quit(_fails)

func _patch(item: CanvasItem):
	return null if item.material == null else Color(item.material.get_shader_parameter("patch_color"))

func _main(menu) -> Button:
	return menu.find_child("ShopMain", true, false)

func _name(menu) -> String:
	return menu.find_child("CatName", true, false).text

func _check(name: String, ok: bool, got) -> void:
	if not ok:
		_fails += 1
	print("%s  %s  (%s)" % ["PASS" if ok else "FAIL", name, str(got) if not ok else ""])

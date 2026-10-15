extends CanvasLayer

const Ships := preload("res://scripts/ship_catalog.gd")
const GOLD := Color(0.95, 0.84, 0.54, 1.0)
const CYAN := Color(0.55, 0.78, 0.91, 1.0)
const TEXT := Color(0.96, 0.90, 0.75, 1.0)
const MUTED := Color(0.49, 0.58, 0.66, 1.0)

signal departed

var player: Node
var planet_title: String = ""
var tab: String = "hangar"
var progress: Node
var credits_label: Label
var hangar_panel: Control
var shop_panel: Control
var bar_panel: Control
var hangar_status: Label
var ship_preview: Node3D
var preview_host: Node3D
var status_note: Label


func _ready() -> void:
	layer = 22
	process_mode = Node.PROCESS_MODE_ALWAYS
	progress = get_node_or_null("/root/GameSettings")
	_build()
	_show_tab("hangar")


func setup(p_player: Node, p_planet: String) -> void:
	player = p_player
	planet_title = p_planet
	_refresh()
	if progress != null and String(progress.get("last_save_kind")) == "autosave":
		status_note.text = "Autosave complete. Credits and contracts recorded."


func _process(delta: float) -> void:
	if ship_preview != null and is_instance_valid(ship_preview):
		ship_preview.rotate_y(0.38 * delta)


func _build() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.04, 0.09, 0.78)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_bottom", 28)
	root.add_child(margin)

	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 28)
	margin.add_child(split)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 12)
	split.add_child(left)

	var header := HBoxContainer.new()
	left.add_child(header)
	var title := Label.new()
	title.text = "STATION"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", GOLD)
	header.add_child(title)
	var stretch := Control.new()
	stretch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(stretch)
	credits_label = Label.new()
	credits_label.add_theme_font_size_override("font_size", 22)
	credits_label.add_theme_color_override("font_color", GOLD)
	header.add_child(credits_label)

	var subtitle := Label.new()
	subtitle.name = "OrbitLabel"
	subtitle.text = "Orbital dock"
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", CYAN)
	left.add_child(subtitle)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	left.add_child(tabs)
	tabs.add_child(_tab_button("HANGAR", "hangar"))
	tabs.add_child(_tab_button("SHOP", "shop"))
	tabs.add_child(_tab_button("BAR", "bar"))

	hangar_panel = _make_panel()
	shop_panel = _make_panel()
	bar_panel = _make_panel()
	left.add_child(hangar_panel)
	left.add_child(shop_panel)
	left.add_child(bar_panel)

	status_note = Label.new()
	status_note.add_theme_font_size_override("font_size", 15)
	status_note.add_theme_color_override("font_color", CYAN)
	left.add_child(status_note)

	var leave := _action_button("LEAVE STATION", true)
	leave.pressed.connect(_on_leave)
	left.add_child(leave)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(420, 0)
	right.size_flags_horizontal = Control.SIZE_SHRINK_END
	split.add_child(right)
	var hangar_caption := Label.new()
	hangar_caption.text = "YOUR SHIP"
	hangar_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hangar_caption.add_theme_font_size_override("font_size", 16)
	hangar_caption.add_theme_color_override("font_color", MUTED)
	right.add_child(hangar_caption)
	right.add_child(_make_ship_view())


func _make_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.clip_contents = true
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.08, 0.14, 0.92)
	style.set_border_width_all(2)
	style.border_color = Color(0.88, 0.75, 0.44, 0.7)
	style.set_corner_radius_all(10)
	style.content_margin_left = 14.0
	style.content_margin_right = 8.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _tab_button(label: String, id: String) -> Button:
	var btn := _action_button(label, false)
	btn.custom_minimum_size = Vector2(140, 44)
	btn.set_meta("tab_id", id)
	btn.pressed.connect(_show_tab.bind(id))
	return btn


func _action_button(label: String, gold: bool) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(240, 48)
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", TEXT)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.10, 0.16, 0.27, 0.95) if gold else Color(0.07, 0.11, 0.18, 0.95)
	normal.set_border_width_all(2)
	normal.border_color = Color(0.88, 0.75, 0.44, 1.0) if gold else Color(0.43, 0.62, 0.78, 0.9)
	normal.set_corner_radius_all(8)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.16, 0.25, 0.38, 0.98)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	return btn


func _make_ship_view() -> SubViewportContainer:
	var holder := SubViewportContainer.new()
	holder.stretch = true
	holder.custom_minimum_size = Vector2(420, 460)
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var vp := SubViewport.new()
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.handle_input_locally = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.size = Vector2i(420, 460)
	vp.process_mode = Node.PROCESS_MODE_ALWAYS
	holder.add_child(vp)
	var world := Node3D.new()
	vp.add_child(world)
	var light := DirectionalLight3D.new()
	light.light_energy = 1.6
	light.light_color = Color(1.0, 0.9, 0.7, 1.0)
	light.rotation_degrees = Vector3(-35.0, 40.0, 0.0)
	world.add_child(light)
	var fill := OmniLight3D.new()
	fill.light_color = Color(0.4, 0.65, 1.0, 1.0)
	fill.light_energy = 0.8
	fill.position = Vector3(-3.0, 2.0, 4.0)
	world.add_child(fill)
	preview_host = world
	_refresh_ship_preview()
	var cam := Camera3D.new()
	cam.position = Vector3(5.4, 2.2, 11.5)
	cam.look_at_from_position(cam.position, Vector3(0.0, 0.2, 0.0), Vector3.UP)
	cam.fov = 32.0
	cam.current = true
	world.add_child(cam)
	return holder


func _show_tab(id: String) -> void:
	tab = id
	hangar_panel.visible = id == "hangar"
	shop_panel.visible = id == "shop"
	bar_panel.visible = id == "bar"
	_refresh()


func _refresh() -> void:
	var orbit := get_node_or_null("OrbitLabel") as Label
	# subtitle is nested; find by walking
	if progress != null:
		credits_label.text = "%d cr." % int(progress.get("credits"))
	_rebuild_hangar()
	_rebuild_shop()
	_rebuild_bar()
	_refresh_ship_preview()
	_set_orbit_label()


func _set_orbit_label() -> void:
	var root := get_child(1) as Control
	if root == null:
		return
	var label := root.find_child("OrbitLabel", true, false) as Label
	if label != null:
		label.text = "Orbital dock  ·  %s" % planet_title


func _clear(node: Node) -> void:
	while node.get_child_count() > 0:
		node.get_child(0).free()


func _rebuild_hangar() -> void:
	_clear(hangar_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	hangar_panel.add_child(col)
	col.add_child(_heading("Hangar"))
	var hp := 100.0
	var sh := 100.0
	var max_hp := 100.0
	var max_sh := 100.0
	if player != null:
		hp = float(player.call("get_health"))
		sh = float(player.call("get_shields"))
		max_hp = float(player.call("get_max_health"))
		max_sh = float(player.call("get_max_shields"))
	var ship_name := "Capsule"
	if progress != null:
		ship_name = String(Ships.spec(String(progress.get("current_ship")))["display_name"])
	col.add_child(_body("Ship \"%s\". Techs can restore hull and shields." % ship_name))
	if progress != null:
		col.add_child(_body("Change ships in the dock shop. This bay is for repairs and saves only."))
	col.add_child(_body("Hull  %d / %d" % [int(round(hp)), int(round(max_hp))]))
	col.add_child(_bar(hp / maxf(max_hp, 1.0), Color(0.86, 0.28, 0.28, 1.0)))
	col.add_child(_body("Shields  %d / %d" % [int(round(sh)), int(round(max_sh))]))
	col.add_child(_bar(sh / maxf(max_sh, 1.0), Color(0.32, 0.68, 1.0, 1.0)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)
	var hull_btn := _action_button("REPAIR HULL  ·  80 cr.", false)
	hull_btn.pressed.connect(_on_repair_hull)
	row.add_child(hull_btn)
	var shield_btn := _action_button("RECHARGE SHIELDS  ·  50 cr.", false)
	shield_btn.pressed.connect(_on_recharge_shields)
	row.add_child(shield_btn)
	col.add_child(_body("Saving is only available at a station. Progress autosaves when you dock."))
	var save_btn := _action_button("SAVE GAME", false)
	save_btn.pressed.connect(_on_manual_save)
	col.add_child(save_btn)
	if progress != null and progress.has_method("save_summary"):
		var summary := String(progress.call("save_summary"))
		if summary != "":
			col.add_child(_body("Last file:  %s" % summary))


func _rebuild_shop() -> void:
	_clear(shop_panel)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	scroll.follow_focus = true
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	shop_panel.add_child(scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 14)
	scroll.add_child(col)
	col.add_child(_heading("Hangar market"))
	col.add_child(_body("Ships and supplies. A purchased hull can be equipped right away."))
	for spec: Dictionary in Ships.all_specs():
		col.add_child(_ship_card(spec))
	col.add_child(_heading("Supplies"))
	col.add_child(_shop_row("Repair kit", "Fully restores the hull.", 80, _on_repair_hull))
	col.add_child(_shop_row("Shield charge", "Restores shields to maximum.", 50, _on_recharge_shields))
	col.add_child(_shop_row("Contract ration", "Fixes nothing, but the bartender will be pleased.", 25, _on_buy_ration))


func _rebuild_bar() -> void:
	_clear(bar_panel)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.follow_focus = true
	bar_panel.add_child(scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 10)
	scroll.add_child(col)
	col.add_child(_heading("The Last Buoy bar"))
	col.add_child(_body("Whispers at the counter about pirates and meteor fields. Take a job — or turn one in."))
	if progress == null:
		return
	var specs: Array = progress.call("all_missions")
	for spec: Dictionary in specs:
		col.add_child(_mission_card(spec))


func _mission_card(spec: Dictionary) -> PanelContainer:
	var id := String(spec["id"])
	var state: Dictionary = progress.call("mission_state", id)
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.11, 0.18, 0.9)
	style.set_border_width_all(1)
	style.border_color = Color(0.55, 0.72, 0.9, 0.45)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	card.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)
	var title := Label.new()
	title.text = "%s   ·   %d cr." % [String(spec["title"]), int(spec["reward"])]
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", GOLD)
	box.add_child(title)
	box.add_child(_body(String(spec["desc"])))
	var prog := int(state["progress"])
	var target := int(spec["target"])
	if bool(state["accepted"]) and not bool(state["claimed"]):
		box.add_child(_body("Progress  %d / %d" % [prog, target]))
		box.add_child(_bar(float(prog) / float(maxi(target, 1)), Color(0.95, 0.72, 0.28, 1.0)))
	var btn := _action_button("ACCEPT CONTRACT", false)
	btn.custom_minimum_size = Vector2(200, 36)
	if bool(state["claimed"]):
		btn.text = "PAID"
		btn.disabled = true
	elif bool(state["completed"]):
		btn.text = "TURN IN  ·  +%d cr." % int(spec["reward"])
		btn.pressed.connect(func() -> void: _on_claim(id))
	elif bool(state["accepted"]):
		btn.text = "IN PROGRESS"
		btn.disabled = true
	else:
		btn.pressed.connect(func() -> void: _on_accept(id))
	box.add_child(btn)
	return card


func _ship_card(spec: Dictionary) -> PanelContainer:
	var id := String(spec["id"])
	var owned := progress != null and bool(progress.call("owns_ship", id))
	var equipped := progress != null and String(progress.get("current_ship")) == id
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.11, 0.18, 0.9)
	style.set_border_width_all(1)
	style.border_color = Color(0.88, 0.75, 0.44, 0.55) if equipped else Color(0.55, 0.72, 0.9, 0.45)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	card.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)
	var title := Label.new()
	var price := int(spec["price"])
	if price <= 0:
		title.text = String(spec["display_name"])
	else:
		title.text = "%s   ·   %d cr." % [String(spec["display_name"]), price]
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", GOLD)
	box.add_child(title)
	box.add_child(_body(String(spec["blurb"])))
	box.add_child(_body(Ships.stats_line(spec)))
	var btn := _action_button("BUY", false)
	btn.custom_minimum_size = Vector2(200, 40)
	if equipped:
		btn.text = "IN HANGAR"
		btn.disabled = true
	elif owned:
		btn.text = "EQUIP"
		btn.pressed.connect(func() -> void: _on_equip_ship(id))
	elif price <= 0:
		btn.text = "ISSUED"
		btn.disabled = true
	else:
		btn.text = "BUY  ·  %d cr." % price
		btn.pressed.connect(func() -> void: _on_buy_ship(id))
	box.add_child(btn)
	return card


func _refresh_ship_preview() -> void:
	if preview_host == null:
		return
	if ship_preview != null and is_instance_valid(ship_preview):
		preview_host.remove_child(ship_preview)
		ship_preview.free()
		ship_preview = null
	var ship_id := Ships.DEFAULT_ID
	if progress != null:
		ship_id = String(progress.get("current_ship"))
	ship_preview = Ships.instantiate_model(ship_id, true)
	if ship_preview != null:
		preview_host.add_child(ship_preview)


func _on_buy_ship(id: String) -> void:
	if progress == null:
		return
	if not bool(progress.call("buy_ship", id)):
		status_note.text = "Not enough credits."
		_refresh()
		return
	progress.call("equip_ship", id)
	if player != null and player.has_method("apply_ship"):
		player.call("apply_ship", id)
	status_note.text = "Ship purchased and stored in the hangar."
	_refresh()


func _on_equip_ship(id: String) -> void:
	if progress == null:
		return
	if not bool(progress.call("equip_ship", id)):
		status_note.text = "This ship is unavailable."
		return
	if player != null and player.has_method("apply_ship"):
		player.call("apply_ship", id)
	status_note.text = "Ship swapped. Ready to launch."
	_refresh()


func _shop_row(title: String, desc: String, price: int, cb: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(texts)
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 18)
	t.add_theme_color_override("font_color", TEXT)
	texts.add_child(t)
	texts.add_child(_body(desc))
	var btn := _action_button("%d cr." % price, false)
	btn.custom_minimum_size = Vector2(110, 44)
	btn.pressed.connect(cb)
	row.add_child(btn)
	return row


func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", GOLD)
	return label


func _body(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", MUTED)
	return label


func _bar(ratio: float, fill: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 12)
	bar.max_value = 1.0
	bar.value = clampf(ratio, 0.0, 1.0)
	bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.09, 0.12, 1.0)
	bg.set_corner_radius_all(4)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	fg.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)
	return bar


func _on_repair_hull() -> void:
	if player == null or progress == null:
		return
	if float(player.call("get_health")) >= float(player.call("get_max_health")) - 0.1:
		status_note.text = "Hull is already in good shape."
		return
	if not bool(progress.call("spend_credits", 80)):
		status_note.text = "Not enough credits."
		return
	player.call("repair_hull")
	status_note.text = "Hull restored."
	_refresh()


func _on_recharge_shields() -> void:
	if player == null or progress == null:
		return
	if float(player.call("get_shields")) >= float(player.call("get_max_shields")) - 0.1:
		status_note.text = "Shields are already full."
		return
	if not bool(progress.call("spend_credits", 50)):
		status_note.text = "Not enough credits."
		return
	player.call("recharge_shields")
	status_note.text = "Shields recharged."
	_refresh()


func _on_buy_ration() -> void:
	if progress == null:
		return
	if not bool(progress.call("spend_credits", 25)):
		status_note.text = "Not enough credits."
		return
	status_note.text = "Ration purchased. The bartender nods."
	_refresh()


func _on_accept(id: String) -> void:
	if progress != null:
		progress.call("accept_mission", id)
		status_note.text = "Contract accepted. Good luck out there."
		_refresh()


func _on_claim(id: String) -> void:
	if progress != null and bool(progress.call("claim_mission", id)):
		status_note.text = "Reward transferred to your account."
	_refresh()


func _on_leave() -> void:
	departed.emit()


func _on_manual_save() -> void:
	if progress == null or not progress.has_method("manual_save"):
		return
	if bool(progress.call("manual_save")):
		status_note.text = "Game saved. Credits and contracts recorded."
		_refresh()
	else:
		status_note.text = "You can only save at a station."

# Main.gd
extends Node2D

# We'll use load instead of preload for better error handling
var note_scene = null
var current_notes = []
var dragging_note = null
var dragging_offset = Vector2()

# Canvas control
var zoom_level = 1.0
var canvas_offset = Vector2.ZERO

func _ready():
	# Load the Note scene
	note_scene = load("res://Note.tscn")
	if note_scene == null:
		print("ERROR: Failed to load Note.tscn. Make sure the file exists at res://Note.tscn")
		# Try a different path as fallback
		note_scene = load("res://Scenes/Note.tscn")
		if note_scene == null:
			print("ERROR: Also failed to load from Scenes folder. Please check your file structure.")
	else:
		print("Successfully loaded Note scene")
	
	# Set up new note button
	$UI/NewNoteButton.pressed.connect(_on_new_note_button_pressed)
	$UI/SaveButton.pressed.connect(_save_notes)
	$UI/LoadButton.pressed.connect(_load_notes)
	
	# Enable touch processing
	Input.set_use_accumulated_input(false)
	
	# Load previous notes if they exist
	_load_notes()

func _input(event):
	# Handle note dragging with mouse
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Check if clicking on a note
				var note_under_mouse = _get_note_under_mouse()
				if note_under_mouse:
					dragging_note = note_under_mouse
					dragging_offset = dragging_note.position - get_global_mouse_position()
			else:
				# Released left mouse button
				dragging_note = null
				
	elif event is InputEventMouseMotion:
		if dragging_note:
			dragging_note.position = get_global_mouse_position() + dragging_offset
	
	# Simple mouse wheel zoom
	if event is InputEventMouseButton:
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				set_zoom(zoom_level * 1.1)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				set_zoom(zoom_level * 0.9)
	
	# Handle touch drag for panning (single finger)
	if event is InputEventScreenDrag and dragging_note == null:
		canvas_offset += event.relative / zoom_level
		$Notes.position = canvas_offset
	
	# Handle pinch-to-zoom using native gesture event
	if event is InputEventGesture:
		if event is InputEventMagnifyGesture:
			set_zoom(zoom_level * event.factor)

func _get_note_under_mouse():
	var mouse_pos = get_global_mouse_position()
	# Iterate through notes in reverse (top-most first)
	for i in range(current_notes.size() - 1, -1, -1):
		var note = current_notes[i]
		if Rect2(note.position, note.size).has_point(mouse_pos):
			return note
	return null

func _on_new_note_button_pressed():
	# Check if the Note scene was loaded successfully
	if note_scene == null:
		print("ERROR: Cannot create note because Note.tscn could not be loaded")
		return
		
	# Create a new note at a slightly random position near the center
	var random_offset = Vector2(randf_range(-100, 100), randf_range(-100, 100))
	var new_note = _create_note(get_viewport_rect().size / 2 + random_offset, Vector2(200, 150))
	new_note.focus()

func _create_note(position, size):
	var new_note = note_scene.instantiate()
	$Notes.add_child(new_note)
	new_note.position = position
	new_note.size = size
	# Generate a random pastel color
	var h = randf()  # Random hue
	var s = randf_range(0.4, 0.6)  # Medium saturation
	var v = randf_range(0.8, 1.0)  # High value for pastel
	new_note.set_color(Color.from_hsv(h, s, v, 0.9))  # With slight transparency
	
	new_note.note_clicked.connect(_on_note_clicked)
	current_notes.append(new_note)
	return new_note

func _on_note_clicked(note):
	# Bring note to front
	$Notes.remove_child(note)
	$Notes.add_child(note)
	# Rearrange the array to match
	current_notes.erase(note)
	current_notes.append(note)

func set_zoom(new_zoom):
	var old_zoom = zoom_level
	zoom_level = clamp(new_zoom, 0.2, 5.0)
	
	# Apply zoom to the notes container
	$Notes.scale = Vector2(zoom_level, zoom_level)

func _save_notes():
	var save_data = []
	for note in current_notes:
		save_data.append({
			"position_x": note.position.x,
			"position_y": note.position.y,
			"size_x": note.size.x,
			"size_y": note.size.y,
			"content": note.get_text(),
			"color": note.get_color().to_html()
		})
	
	var save_file = FileAccess.open("user://spatial_notes.save", FileAccess.WRITE)
	save_file.store_line(JSON.stringify(save_data))
	save_file.close()
	
	$UI/SaveConfirmation.visible = true
	await get_tree().create_timer(1.0).timeout
	$UI/SaveConfirmation.visible = false

func _load_notes():
	if not FileAccess.file_exists("user://spatial_notes.save"):
		return
	
	var save_file = FileAccess.open("user://spatial_notes.save", FileAccess.READ)
	var json = JSON.new()
	json.parse(save_file.get_line())
	var save_data = json.get_data()
	save_file.close()
	
	# Clear existing notes
	for note in current_notes:
		note.queue_free()
	current_notes.clear()
	
	# Load saved notes
	for note_data in save_data:
		var new_note = _create_note(
			Vector2(note_data.position_x, note_data.position_y),
			Vector2(note_data.size_x, note_data.size_y)
		)
		new_note.set_text(note_data.content)
		new_note.set_color(Color(note_data.color))

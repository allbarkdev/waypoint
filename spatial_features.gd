# SpatialFeatures.gd
# Attach this script to the Main scene or create a dedicated node

extends Node2D

# Reference to the main script for accessing notes
@onready var main = get_parent()

# Connection system
var connections = [] # Array of dictionaries {from: note1, to: note2, type: "related"}
var creating_connection = false
var connection_start_note = null
var connection_types = ["related", "causes", "part_of", "leads_to"]
var current_connection_type = "related"

# Clustering
var clusters = [] # Array of dictionaries {notes: [note1, note2, ...], name: "Project X"}

# Canvas control
var zoom_level = 1.0
var canvas_offset = Vector2.ZERO
var is_panning = false
var pan_start_pos = Vector2.ZERO

func _ready():
	# Set up UI elements for spatial features
	$UI/SpatialControls/ConnectionButton.pressed.connect(_on_connection_button_pressed)
	$UI/SpatialControls/ClusterButton.pressed.connect(_on_cluster_button_pressed)
	$UI/SpatialControls/ZoomInButton.pressed.connect(_on_zoom_in_pressed)
	$UI/SpatialControls/ZoomOutButton.pressed.connect(_on_zoom_out_pressed)
	$UI/SpatialControls/ConnectionTypeOption.item_selected.connect(_on_connection_type_selected)
	
	# Populate connection type options
	for type in connection_types:
		$UI/SpatialControls/ConnectionTypeOption.add_item(type.capitalize())

func _process(delta):
	if creating_connection and connection_start_note:
		# Draw preview line for connection
		queue_redraw()
		
	if Input.is_action_just_pressed("ui_home"):
		reset_view()

func _draw():
	# Draw all connections
	for connection in connections:
		var from_pos = connection.from.position + connection.from.size / 2
		var to_pos = connection.to.position + connection.to.size / 2
		var color = Color.WHITE
		var line_width = 2.0
		
		# Different styles for different connection types
		match connection.type:
			"related":
				color = Color(0.5, 0.5, 1.0)
			"causes":
				color = Color(1.0, 0.5, 0.5)
				# Draw arrow
				draw_arrow(from_pos, to_pos, color, line_width)
				continue
			"part_of":
				color = Color(0.5, 1.0, 0.5)
				line_width = 3.0
			"leads_to":
				color = Color(1.0, 0.8, 0.2)
				# Draw arrow
				draw_arrow(from_pos, to_pos, color, line_width)
				continue
		
		draw_line(from_pos, to_pos, color, line_width)
	
	# Draw connection preview
	if creating_connection and connection_start_note:
		var from_pos = connection_start_note.position + connection_start_note.size / 2
		var to_pos = get_global_mouse_position()
		var color = Color(0.8, 0.8, 0.8, 0.5)
		draw_line(from_pos, to_pos, color, 2.0)
	
	# Draw cluster backgrounds
	for cluster in clusters:
		# Calculate bounding box for all notes in cluster
		var min_pos = Vector2(INF, INF)
		var max_pos = Vector2(-INF, -INF)
		
		for note in cluster.notes:
			min_pos.x = min(min_pos.x, note.position.x)
			min_pos.y = min(min_pos.y, note.position.y)
			max_pos.x = max(max_pos.x, note.position.x + note.size.x)
			max_pos.y = max(max_pos.y, note.position.y + note.size.y)
		
		# Add padding
		min_pos -= Vector2(20, 20)
		max_pos += Vector2(20, 20)
		
		# Draw rounded rectangle
		var rect = Rect2(min_pos, max_pos - min_pos)
		var color = Color(0.3, 0.3, 0.3, 0.2)
		draw_rect(rect, color, true)
		
		# Draw cluster name
		draw_string(ThemeDB.fallback_font, min_pos + Vector2(10, 20), cluster.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)

func draw_arrow(from, to, color, width):
	draw_line(from, to, color, width)
	
	# Calculate arrowhead
	var direction = (to - from).normalized()
	var arrow_size = 10.0
	var arrowhead_1 = to - direction.rotated(PI/4) * arrow_size
	var arrowhead_2 = to - direction.rotated(-PI/4) * arrow_size
	
	# Draw arrowhead
	var arrowhead_points = PackedVector2Array([to, arrowhead_1, arrowhead_2])
	draw_colored_polygon(arrowhead_points, color)

func _input(event):
	# Handle panning
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			is_panning = event.pressed
			if is_panning:
				pan_start_pos = event.position
		
		# Handle zooming
		if event.is_pressed():
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				set_zoom(zoom_level * 1.1)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				set_zoom(zoom_level * 0.9)
	
	# Apply panning
	if event is InputEventMouseMotion and is_panning:
		canvas_offset += (event.position - pan_start_pos) / zoom_level
		pan_start_pos = event.position
		$NoteCanvas.position = canvas_offset
		queue_redraw()

func set_zoom(new_zoom):
	var old_zoom = zoom_level
	zoom_level = clamp(new_zoom, 0.2, 5.0)
	
	# Adjust canvas position to zoom toward mouse position
	var mouse_pos = get_global_mouse_position()
	var zoom_center = (mouse_pos - canvas_offset) * (1.0 - zoom_level / old_zoom)
	canvas_offset += zoom_center
	
	# Apply zoom
	$NoteCanvas.scale = Vector2(zoom_level, zoom_level)
	$NoteCanvas.position = canvas_offset
	queue_redraw()

func reset_view():
	zoom_level = 1.0
	canvas_offset = Vector2.ZERO
	$NoteCanvas.scale = Vector2.ONE
	$NoteCanvas.position = Vector2.ZERO
	queue_redraw()

func _on_connection_button_pressed():
	creating_connection = true
	connection_start_note = null
	$UI/StatusLabel.text = "Select first note for connection"

func _on_cluster_button_pressed():
	var selected_notes = []
	# Here you would implement a way to select multiple notes
	# For example, by shift-clicking or creating a selection rectangle
	
	if selected_notes.size() > 1:
		var dialog = $UI/ClusterNameDialog
		dialog.popup_centered()
		await dialog.confirmed
		
		var cluster_name = dialog.get_node("LineEdit").text
		if cluster_name.empty():
			cluster_name = "Cluster " + str(clusters.size() + 1)
		
		clusters.append({
			"notes": selected_notes.duplicate(),
			"name": cluster_name
		})
		
		queue_redraw()

func _on_note_clicked(note):
	# Called when a note is clicked, connected from main script
	
	if creating_connection:
		if connection_start_note == null:
			connection_start_note = note
			$UI/StatusLabel.text = "Select second note for connection"
		else:
			# Create connection between notes
			if connection_start_note != note:
				connections.append({
					"from": connection_start_note,
					"to": note,
					"type": current_connection_type
				})
				
				creating_connection = false
				connection_start_note = null
				$UI/StatusLabel.text = "Connection created"
				queue_redraw()
			else:
				$UI/StatusLabel.text = "Cannot connect note to itself"

func _on_connection_type_selected(index):
	current_connection_type = connection_types[index]

func _on_zoom_in_pressed():
	set_zoom(zoom_level * 1.2)

func _on_zoom_out_pressed():
	set_zoom(zoom_level / 1.2)

# Save/load spatial features
func save_spatial_data():
	var save_data = {
		"connections": [],
		"clusters": []
	}
	
	# Save connections
	for connection in connections:
		# Store indices rather than references
		var from_index = main.current_notes.find(connection.from)
		var to_index = main.current_notes.find(connection.to)
		
		if from_index >= 0 and to_index >= 0:
			save_data.connections.append({
				"from": from_index,
				"to": to_index,
				"type": connection.type
			})
	
	# Save clusters
	for cluster in clusters:
		var note_indices = []
		for note in cluster.notes:
			var note_index = main.current_notes.find(note)
			if note_index >= 0:
				note_indices.append(note_index)
		
		save_data.clusters.append({
			"notes": note_indices,
			"name": cluster.name
		})
	
	return save_data

func load_spatial_data(data, notes_array):
	connections.clear()
	clusters.clear()
	
	# Load connections
	if data.has("connections"):
		for conn_data in data.connections:
			if conn_data.from < notes_array.size() and conn_data.to < notes_array.size():
				connections.append({
					"from": notes_array[conn_data.from],
					"to": notes_array[conn_data.to],
					"type": conn_data.type
				})
	
	# Load clusters
	if data.has("clusters"):
		for cluster_data in data.clusters:
			var cluster_notes = []
			for note_index in cluster_data.notes:
				if note_index < notes_array.size():
					cluster_notes.append(notes_array[note_index])
			
			if not cluster_notes.empty():
				clusters.append({
					"notes": cluster_notes,
					"name": cluster_data.name
				})
	
	queue_redraw()

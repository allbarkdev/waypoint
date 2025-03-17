# Note.gd
extends Control

signal note_clicked(note)

var is_editing = false

func _ready():
	$TextEdit.visible = false
	$TextEdit.text_changed.connect(_on_text_changed)

func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			note_clicked.emit(self)
			
			# Double click to edit
			if event.double_click:
				start_editing()
	
	# Handle touch screen
	if event is InputEventScreenTouch:
		if event.pressed and event.double_tap:
			start_editing()
			note_clicked.emit(self)

func start_editing():
	$TextEdit.text = $Label.text
	$Label.visible = false
	$TextEdit.visible = true
	$TextEdit.grab_focus()
	is_editing = true

func finish_editing():
	$Label.text = $TextEdit.text
	$Label.visible = true
	$TextEdit.visible = false
	is_editing = false

func _on_text_changed():
	# Auto-resize the note based on content
	# This is optional but makes the UX nicer
	var min_size = Vector2(200, 150)  # Minimum size
	var text_size = $TextEdit.get_content_minimum_size()
	var new_size = Vector2(
		max(min_size.x, text_size.x + 20),  # Add padding
		max(min_size.y, text_size.y + 40)   # Add more padding for height
	)
	size = new_size

func _on_TextEdit_focus_exited():
	if is_editing:
		finish_editing()

func focus():
	if not is_editing:
		start_editing()

func get_text():
	return $Label.text

func set_text(text):
	$Label.text = text
	$TextEdit.text = text

func get_color():
	return $NoteBody.color

func set_color(color):
	$NoteBody.color = color


func _on_text_edit_focus_exited() -> void:
	pass # Replace with function body.

extends Node

enum State { NORMAL, COMPATIBLE, HOVER_COMPATIBLE, HOVER_INVALID }
var state: State = State.NORMAL
var slot: Control

func _ready() -> void:
	slot = get_parent() as Control
	slot.draw.connect(_draw_feedback)
	set_process(false)

func begin_drag() -> void:
	set_process(true)
	refresh()

func end_drag() -> void:
	set_process(false)
	_set_state(State.NORMAL)

func _process(_delta: float) -> void:
	refresh()

func refresh() -> void:
	if not slot.get_viewport().gui_is_dragging():
		end_drag()
		return
	var data = slot.get_viewport().gui_get_drag_data()
	var compatible: bool = slot._can_drop_data(Vector2.ZERO, data)
	var hovered := slot.get_viewport().gui_get_hovered_control() == slot
	_set_state((State.HOVER_COMPATIBLE if hovered else State.COMPATIBLE) if compatible else (State.HOVER_INVALID if hovered else State.NORMAL))

func _set_state(value: State) -> void:
	if state != value:
		state = value
		slot.queue_redraw()

func _draw_feedback() -> void:
	if state == State.NORMAL:
		return
	var color := Color(0.75, 0.66, 0.35, 0.8)
	var width := 2.0
	if state == State.HOVER_COMPATIBLE:
		color = Color(1.0, 0.88, 0.45, 1.0)
		width = 3.0
	elif state == State.HOVER_INVALID:
		color = Color(0.8, 0.25, 0.2, 0.8)
	var rect := Rect2(Vector2.ONE * 2.0, slot.size - Vector2.ONE * 4.0)
	slot.draw_rect(rect, Color(color, 0.07), true)
	slot.draw_rect(rect, color, false, width)

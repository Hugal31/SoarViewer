extends Node


const AprsReader = preload("res://scripts/aprs_reader.gd")

@export var aprs_source: Node
@export var airplane_model: PackedScene
@export var filtered_ids: PackedStringArray
var x := 0
var y := 0

func _ready():
	aprs_source.position_report.connect(_on_position_report)


func _on_position_report(report: AprsPositionReport):
	var id = report.id()
	if not has_node(id) and (filtered_ids.is_empty() or filtered_ids.has(id)):
		_spawn_airplane(report)

func _spawn_airplane(report: AprsPositionReport):
	var airplane = airplane_model.instantiate()
	var id = report.id()
	airplane.id = id
	airplane.name = id
	aprs_source.position_report.connect(airplane._on_position_report)
	airplane._on_position_report(report)
	airplane.position.x = x
	airplane.position.y = y
	x += 4
	y += 4
	add_child(airplane)

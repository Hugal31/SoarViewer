extends Node


const AprsReader = preload("res://scripts/aprs_reader.gd")

@export var aprs_source: Node
@export var airplane_model: PackedScene
var y = 0

func _ready():
	aprs_source.position_report.connect(_on_position_report)


func _on_position_report(report: AprsPositionReport):
	var id = report.id()
	if not has_node(id):
		_spawn_airplane(report)

func _spawn_airplane(report: AprsPositionReport):
	var airplane = airplane_model.instantiate()
	var id = report.id()
	airplane.id = id
	airplane.name = id
	aprs_source.position_report.connect(airplane._on_position_report)
	airplane._on_position_report(report)
	airplane.position.y = y
	y += 2
	add_child(airplane)

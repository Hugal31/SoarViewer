extends Node


const AprsReader = preload("res://scripts/aprs_reader.gd")

var last_beacons = {}


# Called when the node enters the scene tree for the first time.
func _ready():
	var client = AprsReader.new("res://assets//aprs-tg-landing-2-230902.txt")
	add_child(client)
	client.connect("position_report", _on_position_report)
	client.simulate_reception()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _prNocess(delta):
	pass

func _on_position_report(report):
	var device_id = report.id()
	var last_beacon = last_beacons.get(device_id)
	if last_beacon != null and last_beacon.timestamp() >= report.timestamp():
		return

	last_beacons[report.id()] = report
	var device = $OGN_DDB.get_device(report.id())
	if device == null:
		return
	var registration = device.registration if device else report.id()
	print("%s %s at %sft" % [report.timestamp(), registration, report.altitude()])

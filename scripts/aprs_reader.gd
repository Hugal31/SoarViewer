extends Node

class_name AprsReader

var file: FileAccess
var next_report: AprsPositionReport
var date_to_tick_difference: float = 0
var timer = Timer.new()
var discard_old = true

signal position_report(report: AprsPositionReport)

func _init(file_path):
	file = FileAccess.open(file_path, FileAccess.READ)
	next_report = self.get_next_report()
	timer.one_shot = true
	timer.connect("timeout", emit_next_report)
	add_child(timer)

func simulate_reception():
	if next_report == null:
		return

	date_to_tick_difference = next_report.timestamp() - (Time.get_ticks_msec() / 1000.0)
	emit_next_report()

func emit_next_report():
	while next_report != null:
		emit_signal("position_report", next_report)
		next_report = get_next_report()
		var next_report_time = next_report.timestamp()
		var next_report_tick = next_report_time - date_to_tick_difference
		var time_difference = next_report_tick - Time.get_ticks_msec() / 1000.0
		# TODO Check the sleep times
		if time_difference > 0:
			timer.start(time_difference)
			break

func get_next_report() -> AprsPositionReport:
	while !file.eof_reached():
		var line = file.get_line()
		if not line.is_empty() and not line.begins_with('#'):
			var report = Aprs.parse_aprs(line)
			if report != null:
				return report
	return null

extends Node3D


var id: String
var registration: String
var reports: Array
## Delay to add to the tracking
var delay: float = 4
var date_to_tick_difference: float = NAN

@onready var name_tag = $Label3D
@onready var ogn = $/root/OgnDdb

func _ready():
	$AnimationPlayer.current_animation = "Closed"
	if ogn.is_database_available():
		_get_registration()
	else:
		ogn.database_ready.connect(_get_registration)

## Takes a report unix timestamp, in seconds, and convert it to a game tick, in seconds.
## Takes delay int account.
# TODO Factor out
func get_report_game_time(report: Report) -> float:
	var report_time := report.timestamp
	if is_nan(date_to_tick_difference):
		date_to_tick_difference = report_time - get_ticks_s()
		return delay
	return report_time - date_to_tick_difference + delay


static func get_ticks_s() -> float:
	return Time.get_ticks_msec() / 1000.0


func _process(_delta):
	var current_tick := get_ticks_s()
	while reports.size() >= 2 and get_report_game_time(reports[1]) <= current_tick:
		reports.pop_front()

	if reports.size() < 2 or get_report_game_time(reports[0]) > get_ticks_s():
		return

	var previous_report: Report = reports[0]
	var next_report: Report = reports[1]
	var previous_report_tick := get_report_game_time(previous_report)
	var next_report_tick := get_report_game_time(next_report)
	if previous_report_tick > current_tick:
		return
	var t := (current_tick - previous_report_tick) / (next_report_tick - previous_report_tick)

	var previous_course: int = previous_report.course
	var next_course: int = next_report.course
	var previous_report_quaternion = Quaternion(Vector3(0, 1, 0), deg_to_rad(previous_course))
	var next_report_quaternion = Quaternion(Vector3(0, 1, 0), deg_to_rad(next_course))
	print("slerp(%d, %d, %f)" % [previous_course, next_course, t])
	quaternion = previous_report_quaternion.slerp(next_report_quaternion, t)


func _on_position_report(report):
	if report.id() != id:
		return

	if reports.is_empty() or report.timestamp() > reports[-1].timestamp:
		reports.push_back(Report.new(report))


func _get_registration():
	var device = ogn.get_device(id)
	registration = device.registration if device else id
	name_tag.text = registration


class Report:
	var inner: AprsPositionReport
	var timestamp: int
	var course: int

	func _init(report: AprsPositionReport):
		inner = report
		timestamp = report.timestamp()
		course = report.course()

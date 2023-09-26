extends Node3D


var id: String
var registration: String
var reports: Array
## Delay to add to the tracking
var delay: float = 7
var date_to_tick_difference: float = NAN
var course_curve = Curve2D.new()

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

	if reports.size() < 2 or get_report_game_time(reports[0]) > current_tick:
		if get_report_game_time(reports[0]) > current_tick:
			print("%s: next report is late by " % registration, get_report_game_time(reports[0]) - current_tick)
		return

	var previous_report: Report = reports[0]
	var next_report: Report = reports[1]
	var previous_report_tick := get_report_game_time(previous_report)
	var next_report_tick := get_report_game_time(next_report)
	var delta_time := next_report_tick - previous_report_tick
	if previous_report_tick > current_tick:
		return
	var t := (current_tick - previous_report_tick) / delta_time

	var previous_course := deg_to_rad(previous_report.course)
	var next_course := deg_to_rad(next_report.course)
	var previous_turn_rate := previous_report.turn_rate_si if previous_report.has_turn_rate else 0.0
	var next_turn_rate := next_report.turn_rate_si if next_report.has_turn_rate else 0.0

	var curr_course := hermite(t, previous_course, next_course, previous_turn_rate * delta_time, next_turn_rate * delta_time)
	var derivative := (hermite(t+0.05, previous_course, next_course, previous_turn_rate * delta_time, next_turn_rate * delta_time) - hermite(t-0.05, previous_course, next_course, previous_turn_rate * delta_time, next_turn_rate * delta_time)) / (0.1 * delta_time)
	print("interpolate(%f, %f, %f, %f, %f) = %f, %f" % [t, rad_to_deg(previous_course), rad_to_deg(next_course), rad_to_deg(previous_turn_rate), rad_to_deg(next_turn_rate), rad_to_deg(curr_course), rad_to_deg(derivative)])

	quaternion = Quaternion(Vector3(0, 1, 0), curr_course)
	var speed : float = lerp(previous_report.speed_si, previous_report.speed_si, t)
	var bank_angle := compute_bank_angle(speed, derivative)
	quaternion *= Quaternion(Vector3(1, 0, 0), bank_angle)


func _on_position_report(report):
	if report.id() != id:
		return

	if reports.is_empty() or report.timestamp() > reports[-1].timestamp:
		reports.push_back(Report.new(report))


func _get_registration():
	var device = ogn.get_device(id)
	registration = device.registration if device else id
	name_tag.text = registration

# Cubic Hermite interpolation
static func hermite(t: float, p1: float, p2: float, v1: float, v2: float) -> float:
	var t2 := t * t
	var t3 := t2 * t
	var a := 1 - 3*t2 + 2*t3
	var b := t2 * (3 - 2*t)
	var c: float = t * pow(t - 1, 2)
	var d := t2 * (t - 1)
	return a * p1 + b * p2 + c * v1 + d * v2

## Given the speed in m/s and the turn rate in rad/s, return the bank angle in rad.
static func compute_bank_angle(speed, turn_rate) -> float:
	const g = 9.81
	return atan(turn_rate * speed / g)


class Report:
	var inner: AprsPositionReport
	var timestamp: int
	var has_course: bool: get = get_has_course
	## Course heading, in degrees from 1 to 360
	var course: int
	var has_speed: bool: get = get_has_speed
	## Speed in knots
	var speed: float

	var has_turn_rate: bool: get = get_has_turn_rate
	## Turn rate in 180deg/min, positive is clockwise.
	var turn_rate: float

	## Return the speed in meters/s.
	var speed_si: float: get = get_speed_si
	## Turn rate in radians/s, positive is anti-clockwise.
	var turn_rate_si: float: get = get_turn_rate_si

	func _init(report: AprsPositionReport):
		inner = report
		timestamp = report.timestamp()
		course = report.course()
		speed = report.speed()
		turn_rate = report.turn_rate()

	func get_has_course() -> bool:
		return course > 0

	func get_has_speed() -> bool:
		return not is_nan(speed)

	func get_speed_si() -> float:
		return speed * 1852.0 / 3600.0

	func get_turn_rate_si() -> float:
		return -deg_to_rad(180 * turn_rate) / 60.0

	func get_has_turn_rate() -> bool:
		return not is_nan(turn_rate)

extends Node

class_name OgnDDB

@export var database_url = "https://ddb.glidernet.org/download/"
var database_file = "user://ogd_ddb.csv"
var devices = {}
var request
var _is_database_available = false

signal database_ready()

func get_device(id: String) -> Device:
	return devices.get(id.substr(2))


func is_database_available():
	return _is_database_available


func _ready():
	if FileAccess.file_exists(database_file):
		_load_file(database_file)
	else:
		request = HTTPRequest.new()
		add_child(request)
		request.request_completed.connect(self._on_http_request_completed)
		request.download_file = database_file
		if request.request(database_url) != OK:
			push_error("Could not fetch OGN DDB")


func _load_file(path):
	var file = FileAccess.open(path, FileAccess.READ)
	var headers = file.get_csv_line()
	var type_idx = headers.find('#DEVICE_TYPE')
	var id_idx = headers.find('DEVICE_ID')
	var registration_idx = headers.find('REGISTRATION')
	var max_idx = max(type_idx, id_idx, registration_idx)

	devices = {}

	while not file.eof_reached():
		var line = file.get_line()
		var record = line.split(',')
		if record.size() > max_idx:
			var device = Device.new()
			device.type = record[type_idx].trim_prefix("'").trim_suffix("'")
			device.id = record[id_idx].trim_prefix("'").trim_suffix("'")
			device.registration = record[registration_idx].trim_prefix("'").trim_suffix("'")
			devices[device.id] = device
		elif not record.is_empty():
			push_warning("Could not parse DDB line: \"%s\"" % line)

	_is_database_available = true
	emit_signal("database_available")


func _on_http_request_completed(result, _response_code, _headers, _body):
	if result != HTTPRequest.RESULT_SUCCESS:
		push_error("Could not fetch OGN DDB. Got HTTP error: %s", result)
		return

	remove_child(request)
	request = null
	_load_file(database_file)


class Device:
	var id: String
	var registration: String
	var type: String

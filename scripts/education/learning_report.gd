class_name LearningReport
extends RefCounted

## LearningReport — SBL-EDU-005 Educational Reporting Engine
## Requirements: GDD-071, GDD-072, GDD-091, GDD-112, FR-EDU-002/004, TC-EDU-002/004, NFR-SEC-001, NFR-ACC-001.
##
## Rules:
## 1. Preserves immutable first-attempt correctness and never infers missing historical answers.
## 2. Legacy records lacking first-response data remain unchanged and display "Not recorded".
## 3. Emits deep-copied transient rows sorted by question_id.
## 4. Formula neutralization for transport output (CSV injection defense).
## 5. Standalone UTF-8 printable HTML report with print CSS, zero external dependencies,
##    zero scripts, zero inline handlers, zero auto-print, and strict escaping of all dynamic values.
## 6. Timestamp labeled as "Last recorded activity" (never completion time).
## 7. Explicit OD-012 notice mandatory in report output.

const OD012_NOTICE: String = "Practice records. Educator review pending — OD-012. These records do not establish learning improvement."

const ALLOWED_REPORT_FILENAMES: Array[String] = [
	"learning_report.csv",
	"learning_report.html",
	"competency_record.csv",
	"soulbound_academic_mvp_report.csv",
	"soulbound_academic_mvp_report.html"
]

const CSV_HEADER: String = "question_id,competency,difficulty,first_attempt_correct,total_attempts,completed,timestamp"

## Returns transient deep-copied rows sorted by question_id.
## The underlying records dictionary is NEVER mutated.
static func get_rows(records: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var keys: Array = records.keys()
	keys.sort()
	for q_id_var: Variant in keys:
		var q_id: String = String(q_id_var)
		var rec_val: Variant = records[q_id_var]
		if typeof(rec_val) != TYPE_DICTIONARY:
			continue
		var rec: Dictionary = rec_val as Dictionary

		var row: Dictionary = {}
		row["question_id"] = String(rec.get("question_id", q_id))
		row["competency"] = String(rec.get("competency", ""))
		row["difficulty"] = String(rec.get("difficulty", "Foundational"))
		row["first_attempt_correct"] = bool(rec.get("first_attempt_correct", false))
		row["total_attempts"] = int(rec.get("total_attempts", 0))
		row["completed"] = bool(rec.get("completed", false))
		row["timestamp"] = rec.get("timestamp", 0)

		# Legacy records lacking first_response display "Not recorded"
		var has_fr: bool = rec.has("first_response") and typeof(rec["first_response"]) == TYPE_DICTIONARY
		row["has_first_response"] = has_fr
		if has_fr:
			row["first_attempt_display"] = "Correct" if row["first_attempt_correct"] else "Incorrect"
		else:
			row["first_attempt_display"] = "Not recorded"

		rows.append(row)
	return rows

## Neutralizes spreadsheet formula injection (leading =, +, -, @, \t, \r).
static func neutralize_formula(text: String) -> String:
	if text.begins_with("=") or text.begins_with("+") or text.begins_with("-") or text.begins_with("@") or text.begins_with("\t") or text.begins_with("\r"):
		return "'" + text
	return text

## RFC-4180 CSV escaping with formula neutralization
static func escape_csv(val: String, neutralize: bool = true) -> String:
	var v: String = val
	if neutralize:
		v = neutralize_formula(v)
	if v.contains(",") or v.contains("\"") or v.contains("\n") or v.contains("\r"):
		return "\"" + v.replace("\"", "\"\"") + "\""
	return v

## Generates RFC-4180 compliant CSV text from records.
static func generate_csv(records: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append(CSV_HEADER)
	var rows: Array[Dictionary] = get_rows(records)
	for row: Dictionary in rows:
		var fac_text: String = ""
		if row["has_first_response"]:
			fac_text = "true" if row["first_attempt_correct"] else "false"
		else:
			fac_text = "Not recorded"

		var line: String = "%s,%s,%s,%s,%d,%s,%d" % [
			escape_csv(row["question_id"]),
			escape_csv(row["competency"]),
			escape_csv(row["difficulty"]),
			escape_csv(fac_text),
			row["total_attempts"],
			"true" if row["completed"] else "false",
			int(row["timestamp"])
		]
		lines.append(line)
	return "\n".join(lines) + "\n"

## Escapes HTML dynamic values to prevent injection.
static func escape_html(val: String) -> String:
	return val.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;").replace("'", "&#39;")

## Generates standalone UTF-8 printable HTML report.
## Standalone UTF-8, print CSS, no scripts, no external resources, no remote requests,
## no inline handlers, no auto-print, and all dynamic values escaped.
static func generate_html(records: Dictionary, profile_slot: String = "profile_01") -> String:
	var rows: Array[Dictionary] = get_rows(records)
	var row_count: int = rows.size()
	var completed_count: int = 0
	var first_attempt_correct_count: int = 0

	for r: Dictionary in rows:
		if r["completed"]:
			completed_count += 1
		if r["has_first_response"] and r["first_attempt_correct"]:
			first_attempt_correct_count += 1

	var html: String = "<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n"
	html += "<meta charset=\"utf-8\">\n"
	html += "<title>Soulbound Educational Learning Report</title>\n"
	html += "<style>\n"
	html += "body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; margin: 2rem; color: #1a1a1a; background-color: #fafafa; line-height: 1.5; }\n"
	html += ".report-card { max-width: 900px; margin: 0 auto; background: #ffffff; padding: 2rem; border-radius: 8px; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }\n"
	html += "h1 { margin-top: 0; color: #2c3e50; font-size: 1.8rem; border-bottom: 2px solid #34495e; padding-bottom: 0.5rem; }\n"
	html += ".od012-notice { background-color: #fff3cd; border: 1px solid #ffeeba; color: #856404; padding: 0.75rem 1.25rem; border-radius: 4px; margin: 1.5rem 0; font-weight: 500; font-size: 0.95rem; }\n"
	html += ".summary-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 1rem; margin-bottom: 1.5rem; background: #f8f9fa; padding: 1rem; border-radius: 6px; }\n"
	html += ".summary-item { font-size: 0.95rem; }\n"
	html += ".summary-label { font-weight: 600; color: #495057; display: block; }\n"
	html += ".summary-value { font-size: 1.2rem; font-weight: bold; color: #212529; }\n"
	html += "table { width: 100%; border-collapse: collapse; margin-top: 1rem; margin-bottom: 2rem; }\n"
	html += "th, td { border: 1px solid #dee2e6; padding: 0.6rem 0.8rem; text-align: left; font-size: 0.88rem; }\n"
	html += "th { background-color: #e9ecef; color: #495057; font-weight: 600; }\n"
	html += "tr:nth-child(even) { background-color: #f8f9fa; }\n"
	html += ".empty-state { text-align: center; padding: 2.5rem; font-style: italic; color: #6c757d; background: #fdfdfe; border: 1px dashed #ced4da; border-radius: 6px; }\n"
	html += "@media print {\n"
	html += "  body { margin: 0; background: #ffffff; color: #000000; font-size: 10pt; }\n"
	html += "  .report-card { max-width: 100%; padding: 0; box-shadow: none; border-radius: 0; }\n"
	html += "  .od012-notice { border: 1px solid #999; color: #000; background: #eee; }\n"
	html += "  table { page-break-inside: auto; }\n"
	html += "  tr { page-break-inside: avoid; page-break-after: auto; }\n"
	html += "  thead { display: table-header-group; }\n"
	html += "}\n"
	html += "</style>\n</head>\n<body>\n"
	html += "<div class=\"report-card\">\n"
	html += "<h1>Soulbound — Learning Activity Report</h1>\n"
	html += "<div class=\"od012-notice\">" + escape_html(OD012_NOTICE) + "</div>\n"
	html += "<div class=\"summary-grid\">\n"
	html += "  <div class=\"summary-item\"><span class=\"summary-label\">Active Profile Slot</span><span class=\"summary-value\">" + escape_html(profile_slot) + "</span></div>\n"
	html += "  <div class=\"summary-item\"><span class=\"summary-label\">Total Activities</span><span class=\"summary-value\">" + str(row_count) + "</span></div>\n"
	html += "  <div class=\"summary-item\"><span class=\"summary-label\">Completed</span><span class=\"summary-value\">" + str(completed_count) + "</span></div>\n"
	html += "  <div class=\"summary-item\"><span class=\"summary-label\">First-Attempt Correct</span><span class=\"summary-value\">" + str(first_attempt_correct_count) + "</span></div>\n"
	html += "</div>\n"

	if row_count == 0:
		html += "<div class=\"empty-state\">No learning activities recorded yet.</div>\n"
	else:
		html += "<table>\n<thead>\n<tr>\n"
		html += "  <th>Question ID</th>\n"
		html += "  <th>Competency</th>\n"
		html += "  <th>Difficulty</th>\n"
		html += "  <th>First Attempt</th>\n"
		html += "  <th>Total Attempts</th>\n"
		html += "  <th>Completed</th>\n"
		html += "  <th>Last recorded activity</th>\n"
		html += "</tr>\n</thead>\n<tbody>\n"
		for r: Dictionary in rows:
			var ts_str: String = format_timestamp(r["timestamp"])
			html += "<tr>\n"
			html += "  <td>" + escape_html(r["question_id"]) + "</td>\n"
			html += "  <td>" + escape_html(r["competency"]) + "</td>\n"
			html += "  <td>" + escape_html(r["difficulty"]) + "</td>\n"
			html += "  <td>" + escape_html(r["first_attempt_display"]) + "</td>\n"
			html += "  <td>" + str(r["total_attempts"]) + "</td>\n"
			html += "  <td>" + ("Yes" if r["completed"] else "No") + "</td>\n"
			html += "  <td>" + escape_html(ts_str) + "</td>\n"
			html += "</tr>\n"
		html += "</tbody>\n</table>\n"

	html += "</div>\n</body>\n</html>\n"
	return html

static func format_timestamp(ts: Variant) -> String:
	var unix_ts: int = int(ts)
	if unix_ts <= 0:
		return "N/A"
	return Time.get_datetime_string_from_unix_time(unix_ts, true) + " UTC"

## Validates fixed allowlisted filenames under user://reports/ or user://.
static func validate_export_path(path: String) -> Error:
	if path.is_empty():
		return ERR_INVALID_PARAMETER
	if path.contains(".."):
		return ERR_FILE_BAD_PATH
	if not path.begins_with("user://"):
		return ERR_FILE_BAD_PATH
	var base_name: String = path.get_file()
	if not ALLOWED_REPORT_FILENAMES.has(base_name) and not base_name.ends_with(".csv") and not base_name.ends_with(".html"):
		return ERR_FILE_BAD_PATH
	return OK

## Exports CSV to disk. Success reported only after successful write.
static func export_csv_file(records: Dictionary, export_path: String = "user://reports/learning_report.csv") -> Error:
	var val_err: Error = validate_export_path(export_path)
	if val_err != OK:
		return val_err

	var base_dir: String = export_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(base_dir):
		var make_err: Error = DirAccess.make_dir_recursive_absolute(base_dir)
		if make_err != OK:
			return make_err

	var file := FileAccess.open(export_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()

	var csv_text: String = generate_csv(records)
	file.store_string(csv_text)
	file.flush()
	file.close()

	if not FileAccess.file_exists(export_path):
		return ERR_FILE_CANT_WRITE
	return OK

## Exports standalone HTML report to disk. Success reported only after successful write.
static func export_html_file(records: Dictionary, profile_slot: String = "profile_01", export_path: String = "user://reports/learning_report.html") -> Error:
	var val_err: Error = validate_export_path(export_path)
	if val_err != OK:
		return val_err

	var base_dir: String = export_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(base_dir):
		var make_err: Error = DirAccess.make_dir_recursive_absolute(base_dir)
		if make_err != OK:
			return make_err

	var file := FileAccess.open(export_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()

	var html_text: String = generate_html(records, profile_slot)
	file.store_string(html_text)
	file.flush()
	file.close()

	if not FileAccess.file_exists(export_path):
		return ERR_FILE_CANT_WRITE
	return OK

## Prepares web download buffer. Uses injectable bridge callable for deterministic testability.
## Does NOT claim browser execution.
static func prepare_web_download(content: String, filename: String, mime_type: String, bridge: Callable = Callable()) -> Dictionary:
	var base_name: String = filename.get_file()
	if not ALLOWED_REPORT_FILENAMES.has(base_name):
		return {"error": ERR_FILE_BAD_PATH, "buffer": PackedByteArray()}

	var buf: PackedByteArray = content.to_utf8_buffer()
	if bridge.is_valid():
		bridge.call(buf, base_name, mime_type)
	elif OS.has_feature("web"):
		JavaScriptBridge.download_buffer(buf, base_name, mime_type)

	return {
		"error": OK,
		"filename": base_name,
		"mime_type": mime_type,
		"buffer": buf,
		"byte_count": buf.size()
	}

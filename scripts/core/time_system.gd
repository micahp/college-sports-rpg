extends Node
## Four fixed periods per day. Time never advances on its own —
## only when an activity or story beat consumes blocks.

signal time_advanced(day: int, period: int)
signal day_started(day: int)
signal week_completed

enum Period { MORNING, AFTERNOON, EVENING, NIGHT }

const PERIOD_NAMES: Array[String] = ["Morning", "Afternoon", "Evening", "Night"]
const FINAL_DAY: int = 7

var day: int = 1
var period: int = Period.MORNING


func reset() -> void:
	day = 1
	period = Period.MORNING


func period_name() -> String:
	return PERIOD_NAMES[period]


## Advances by `blocks` periods, rolling into the next day after Night.
## Returns false (and changes nothing) on a non-positive input.
func advance(blocks: int = 1) -> bool:
	if blocks <= 0:
		push_error("TimeSystem.advance requires a positive block count, got %d" % blocks)
		return false
	for _i in blocks:
		if period == Period.NIGHT:
			if day >= FINAL_DAY:
				week_completed.emit()
				return true
			day += 1
			period = Period.MORNING
			day_started.emit(day)
		else:
			period += 1
	time_advanced.emit(day, period)
	return true


func to_save_dict() -> Dictionary:
	return {"day": day, "period": period}


func from_save_dict(data: Dictionary) -> void:
	day = clampi(int(data.get("day", 1)), 1, FINAL_DAY)
	period = clampi(int(data.get("period", Period.MORNING)), Period.MORNING, Period.NIGHT)

extends GutTest
## Отладочный замер кадров по битам.


func test_report_per_bucket() -> void:
	var probe := PerfProbe.new()
	add_child_autofree(probe)
	probe.enabled = true
	probe.bucket = &"B01"
	for i in 99:
		probe._process(1.0 / 60.0)
	probe._process(0.1)
	probe.bucket = &"B02"
	probe._process(1.0 / 30.0)
	var report := probe.report()
	assert_eq(report[&"B01"]["frames"], 100)
	assert_almost_eq(report[&"B01"]["low_1pct_fps"], 10.0, 0.01, "худший кадр 100 мс")
	assert_almost_eq(report[&"B01"]["max_frame_ms"], 100.0, 0.01)
	assert_almost_eq(report[&"B02"]["avg_fps"], 30.0, 0.1)


func test_disabled_records_nothing() -> void:
	var probe := PerfProbe.new()
	add_child_autofree(probe)
	probe._process(0.016)
	assert_true(probe.report().is_empty())

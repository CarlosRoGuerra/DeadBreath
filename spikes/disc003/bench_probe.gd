extends Node
## DISC-003 V3 (screenshot) e V5 (frame time). Mede o tempo de parede entre frames.

const WARMUP: int = 120
const MEASURE: int = 600
const SHOT_FRAME: int = 90
const P95_LIMIT_MS: float = 6.9

var mode: String = "shot"
var out_dir: String = ""
var _frame: int = 0
var _last_usec: int = 0
var _frame_ms: PackedFloat64Array = PackedFloat64Array()
var _gpu_ms: PackedFloat64Array = PackedFloat64Array()
var _done: bool = false


func _ready() -> void:
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	print("adapter=%s | vendor=%s | api=%s" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_vendor(), RenderingServer.get_video_adapter_api_version()])
	for m: String in ["get_current_rendering_driver_name", "get_current_rendering_method"]:
		if RenderingServer.has_method(m):
			print("%s=%s" % [m, RenderingServer.call(m)])
	print("window_size=%s | viewport=%s | vsync_mode=%d | max_fps=%d" % [DisplayServer.window_get_size(), get_viewport().get_visible_rect().size, DisplayServer.window_get_vsync_mode(), Engine.max_fps])


func _process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	var now: int = Time.get_ticks_usec()
	if mode == "shot":
		if _frame == SHOT_FRAME:
			_done = true
			_shot()
		return
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam != null:
		cam.rotation.y = sin(_frame * 0.01) * 0.35
	if _frame > WARMUP:
		_frame_ms.append((now - _last_usec) / 1000.0)
		_gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid()))
	_last_usec = now
	if _frame >= WARMUP + MEASURE:
		_done = true
		_report()


func _shot() -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = out_dir.path_join("V3_screenshot.png")
	var err: Error = img.save_png(path)
	var lit: int = 0
	var samples: int = 0
	var lum_sum: float = 0.0
	for y: int in range(0, img.get_height(), 8):
		for x: int in range(0, img.get_width(), 8):
			var c: Color = img.get_pixel(x, y)
			var lum: float = c.get_luminance()
			lum_sum += lum
			samples += 1
			if lum > 0.05:
				lit += 1
	print("V3 screenshot=%s | err=%d | size=%s | mean_lum=%.4f | lit_fraction=%.3f" % [path, err, img.get_size(), lum_sum / samples, float(lit) / samples])
	get_tree().quit(0 if err == OK and lit > 0 else 1)


func _report() -> void:
	var sorted: PackedFloat64Array = _frame_ms.duplicate()
	sorted.sort()
	var n: int = sorted.size()
	var total: float = 0.0
	for v: float in sorted:
		total += v
	var p95: float = sorted[int(ceil(0.95 * n)) - 1]
	var gpu_sorted: PackedFloat64Array = _gpu_ms.duplicate()
	gpu_sorted.sort()
	var gpu_p95: float = gpu_sorted[int(ceil(0.95 * n)) - 1]
	var summary: String = "V5 frames=%d | mean=%.3f ms | p50=%.3f | p95=%.3f | p99=%.3f | max=%.3f | fps_mean=%.1f | gpu_p95=%.3f ms | limit_p95=%.1f | %s" % [
		n, total / n, sorted[n / 2], p95, sorted[int(ceil(0.99 * n)) - 1], sorted[n - 1], 1000.0 * n / total, gpu_p95, P95_LIMIT_MS, "PASS" if p95 <= P95_LIMIT_MS else "FAIL"]
	print(summary)
	var f: FileAccess = FileAccess.open(out_dir.path_join("V5_frametimes_%s.csv" % RenderingServer.call("get_current_rendering_driver_name") if RenderingServer.has_method("get_current_rendering_driver_name") else "V5_frametimes.csv"), FileAccess.WRITE)
	if f != null:
		f.store_line("frame,frame_ms,gpu_ms")
		for i: int in n:
			f.store_line("%d,%.4f,%.4f" % [i, _frame_ms[i], _gpu_ms[i]])
		f.close()
	get_tree().quit(0 if p95 <= P95_LIMIT_MS else 1)

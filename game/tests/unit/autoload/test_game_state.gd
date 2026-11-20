extends TestCase
## Unit: autoload/game_state.gd. Autor: Software Architect (F1-004).

const GameStateScript := preload("res://autoload/game_state.gd")


func test_set_chapter_emits_once_per_change() -> void:
	var gs: GameStateScript = GameStateScript.new()
	var got: Array[StringName] = []
	var listener: Callable = func(chapter_id: StringName) -> void: got.append(chapter_id)
	EventBus.chapter_changed.connect(listener)
	gs.set_chapter(&"ch1_intrusion")
	gs.set_chapter(&"ch1_intrusion")
	gs.set_chapter(&"ch2_no_way_out")
	EventBus.chapter_changed.disconnect(listener)
	assert_eq(gs.chapter_id, &"ch2_no_way_out")
	gs.free()
	var expected: Array[StringName] = [&"ch1_intrusion", &"ch2_no_way_out"]
	assert_eq(got, expected)


func test_production_flag_follows_build_and_argument() -> void:
	var expected: bool = not OS.is_debug_build() or OS.get_cmdline_user_args().has("--production")
	assert_eq(GameState.is_production_build, expected)

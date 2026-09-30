@tool
class_name GameLogic
extends Node

@export_group("Win Condition")

## Should you win the game by collecting coins?
@export var win_by_collecting_coins: bool = false

## How many coins to collect for winning?
## If zero, all the coins must be collected.[br]
## [b]Note:[/b] if you set this to a number bigger than the actual coins,
## the game won't be winnable.
@export_range(0, 100, 1, "or_greater", "prefer_slider") var coins_to_win: int = 0

## Should you win the game by reaching a flag?[br]
## If the option to win by collecting coins is also set, then it will only be
## possible to win by collecting enough coins and then reaching a flag.
@export var win_by_reaching_flag: bool = false

## Win by reaching a specific flag. Otherwise, the player can win by reaching
## any flag placed in the scene.
@export var flag_to_win: Flag = null

## Optional fallback: scene to load after winning if no level matches in _win().
@export_file("*.tscn") var next_level: String = ""

## Seconds to wait after winning before loading the next level.
@export_range(0.0, 10.0, 0.1, "suffix:s") var next_level_delay: float = 3.0

@export_group("Challenges")
## You lose if this time runs out.
## If zero (default), there won't be a time limit to win.
@export_range(0, 60, 0.9, "or_greater", "suffix:s") var time_limit: int = 0

## How many lives does the player have?
@export_range(1, 9) var lives: int = 3:
	set = _set_lives

@export_group("World Properties")

# Keep default the same as ProjectSettings.get_setting("physics/2d/default_gravity")
## This is the gravity of the world. In pixels per second squared.
@export_range(-2000.0, 2000.0, 0.1, "suffix:px/s²") var gravity: float = 980.0

var _is_transitioning: bool = false


func _set_lives(new_lives):
	lives = new_lives
	Global.lives = lives


# Called when the node enters the scene tree for the first time.
func _ready():
	if Engine.is_editor_hint():
		return

	await get_parent().ready
	# Set the gravity strength at runtime:
	PhysicsServer2D.area_set_param(
		get_viewport().find_world_2d().space, PhysicsServer2D.AREA_PARAM_GRAVITY, gravity
	)
	Global.gravity_changed.emit(gravity)
	if win_by_collecting_coins:
		Global.coin_collected.connect(_on_coin_collected)
		if coins_to_win == 0:
			coins_to_win = get_tree().get_node_count_in_group(&"coins")
	if win_by_reaching_flag:
		Global.flag_raised.connect(_on_flag_raised)

	if time_limit > 0:
		Global.setup_timer(time_limit)

	_set_lives(lives)


func _win():
	# Work out the next level based on which scene we're in.
	var current_level := get_tree().current_scene.scene_file_path.get_file().get_basename()
	var target := next_level  # Falls back to the Inspector value if set.

	if current_level == "base_level":
		target = "res://first_level.tscn"
	elif current_level == "first_level":
		target = "res://second_level.tscn"

	# No next level (e.g. the last level): show the normal win ending.
	if target.is_empty():
		Global.game_ended.emit(Global.Endings.WIN)
		return

	# Prevent this from running twice (e.g. coin + flag both triggering it).
	if _is_transitioning:
		return
	_is_transitioning = true

	# The 'true' makes the timer keep running even if the tree gets paused.
	await get_tree().create_timer(next_level_delay, true).timeout

	# Reset coins for the next level (adjust if your Global uses a different name).
	Global.coins = 0

	get_tree().change_scene_to_file(target)


func _on_coin_collected():
	if _check_win_conditions(flag_to_win):
		_win()


func _on_flag_raised(flag: Flag):
	if _check_win_conditions(flag_to_win if flag_to_win else flag):
		_win()
	elif flag_to_win == null or flag == flag_to_win:
		# Put the ending flag back if the player hasn't satisfied conditions.
		flag.flag_position = Flag.FlagPosition.DOWN


func _check_win_conditions(flag: Flag):
	if not win_by_collecting_coins and not win_by_reaching_flag:
		return false

	if win_by_collecting_coins and Global.coins < coins_to_win:
		return false

	if win_by_reaching_flag and flag == null:
		return false

	if win_by_reaching_flag and flag.flag_position == Flag.FlagPosition.DOWN:
		return false

	return true

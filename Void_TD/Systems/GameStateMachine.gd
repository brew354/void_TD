## GameStateMachine.gd — Simple enum-based state machine for GameScene
class_name GameStateMachine

enum State {
	BUILD_PHASE,
	WAVE_IN_PROGRESS,
	WAVE_CLEAR,
	GAME_OVER,
	PAUSED,
}

signal state_changed(new_state: State)

var current: State = State.BUILD_PHASE
var _prior_state: State = State.BUILD_PHASE  # For pause/resume

func transition_to(new_state: State) -> void:
	if new_state == current:
		return
	if new_state == State.PAUSED:
		_prior_state = current
	current = new_state
	state_changed.emit(new_state)

func resume_from_pause() -> void:
	transition_to(_prior_state)

func can_place_tower() -> bool:
	return current == State.BUILD_PHASE or current == State.WAVE_IN_PROGRESS or current == State.WAVE_CLEAR

func can_start_wave() -> bool:
	return current == State.BUILD_PHASE or current == State.WAVE_CLEAR

func can_upgrade_tower() -> bool:
	return current == State.BUILD_PHASE or current == State.WAVE_CLEAR

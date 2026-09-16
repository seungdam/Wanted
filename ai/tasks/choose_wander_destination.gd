@tool
extends BTAction

func _tick(_delta: float) -> Status:
	if not agent.choose_destination():
		return FAILURE
	blackboard.set_var(&"destination", agent.route.back())
	return SUCCESS

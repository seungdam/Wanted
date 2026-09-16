@tool
extends BTAction

func _tick(delta: float) -> Status:
	agent.advance(delta)
	return SUCCESS if agent.route.is_empty() else RUNNING

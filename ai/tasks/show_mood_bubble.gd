@tool
extends BTAction

func _tick(_delta: float) -> Status:
	if agent.has_method("_show_mood_bubble"):
		agent._show_mood_bubble()
	return SUCCESS

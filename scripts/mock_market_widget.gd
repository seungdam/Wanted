class_name MockMarketWidget
extends Control

signal finished

const CODES := ["A", "E", "D"]
var market: MarketCore
var day := 1
var body: VBoxContainer
var message := "가격은 현재 사건 리플레이를 따릅니다."

func configure(value: MarketCore, value_day: int) -> void:
	market = value
	day = value_day

func _ready() -> void:
	assert(market != null, "Configure MockMarketWidget before adding it.")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.08, 0.10, 0.07, 0.42)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-330, -250)
	panel.size = Vector2(660, 500)
	panel.theme = preload("res://assets/ui/themes/cozy_meadow.tres")
	add_child(panel)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	panel.add_child(body)
	_render()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_finish()

func _render() -> void:
	for child in body.get_children():
		child.queue_free()
	var title := Label.new()
	title.text = "모의 거래 · %s" % str(market.active_card.get("title", "시장"))
	title.add_theme_font_size_override("font_size", 24)
	body.add_child(title)
	var balance := Label.new()
	balance.text = "보유 볼트 %s · 포트폴리오 %s" % [GuestSession.format_nut(GuestSession.nut), GuestSession.format_nut(market.portfolio_value())]
	body.add_child(balance)
	for code in CODES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var holding: Dictionary = market.holdings.get(code, {})
		var label := Label.new()
		label.custom_minimum_size.x = 250
		label.text = "%s · %s · 보유 %.2f주" % [code, GuestSession.format_nut(market.current_price(code)), int(holding.get("qty", 0)) / float(MarketCore.SHARE_SCALE)]
		row.add_child(label)
		for is_buy in [true, false]:
			var button := Button.new()
			button.text = "매수 0.01주" if is_buy else "매도 0.01주"
			button.pressed.connect(_trade.bind(code, is_buy))
			row.add_child(button)
		body.add_child(row)
	var status := Label.new()
	status.text = message
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(status)
	var close := Button.new()
	close.text = "닫기"
	close.pressed.connect(_finish)
	body.add_child(close)

func _trade(code: String, is_buy: bool) -> void:
	var result: Dictionary = market.buy(code, MarketCore.SHARE_SCALE, day, "village_tile") if is_buy else market.sell(code, MarketCore.SHARE_SCALE, day, "village_tile")
	message = str(result.get("reason", "%s 완료" % ("매수" if is_buy else "매도")))
	_render()

func _finish() -> void:
	finished.emit()
	queue_free()

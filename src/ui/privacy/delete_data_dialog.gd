class_name DeleteDataDialog
extends RpgDialog
## "Delete my online data" (Options > Privacy; docs/privacy-ops.md "A deletion request"): the
## game can't delete a player on Talo itself (only the dashboard can, and its key never ships in
## the game), so it prepares the request: what will happen, then an email to the privacy contact
## with the device's online ID, its Talo player ID and the pseudonym (Privacy.deletion_request()),
## and turns every online feature off, forgetting that ID (Privacy.forget_online()). The last
## step shows the address and the ID, for a player whose device opened no email.
## Reachable as %Explain, %ConfirmButton, %CancelButton, %DoneText, %CloseButton.

signal finished

const WIDTH := 720.0

## Opens the email app (the tests turn it off: no app opens during a test).
static var opens_email := true


func _init() -> void:
	super._init(TranslationServer.tr("Delete my online data"), WIDTH, 0.82)
	hide()


func open() -> void:
	UiParts.clear(body)
	var request := Privacy.deletion_request()
	var lines := PackedStringArray([tr("This prepares an email asking to delete everything the game sent online: your scores, your pseudonym and your gameplay statistics. Send it, and you get an answer within one month.")])
	lines.append(tr("Then the game turns the online leaderboards and the statistics off and forgets this device's online ID. You can turn them on again later: you will get a new ID."))
	if str(request.id).is_empty():
		lines.append(tr("Nothing was sent from this device yet, as far as it knows."))
	var explain := UiSkin.label("\n\n".join(lines), Fonts.BODY, UiSkin.TEXT, true)
	body.add_child(explain)
	_own(explain, "Explain")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	body.add_child(row)
	var cancel := UiParts.button(tr("Cancel"), close, Vector2(0, 56), Fonts.BODY)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(cancel)
	_own(cancel, "CancelButton")
	var confirm := UiParts.button(tr("Delete my online data"), _confirm, Vector2(0, 56), Fonts.BODY)
	confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(confirm)
	_own(confirm, "ConfirmButton")
	MenuNav.set_first(self, cancel)
	show()


func close() -> void:
	Sfx.play_ui(Sfx.bank.ui_close)
	hide()
	finished.emit()


## Back: closes it (nothing is done before Delete).
func back() -> void:
	close()


## The email opened (when the contact address is set), then everything online off and forgotten.
func _confirm() -> void:
	Sfx.play_ui(Sfx.bank.ui_click)
	var request := Privacy.deletion_request()
	if opens_email and not str(request.mailto).is_empty():
		OS.shell_open(request.mailto)
	Privacy.forget_online()
	UiParts.clear(body)
	var who := str(request.id) if not str(request.id).is_empty() else "-"
	var done := UiSkin.label(tr("Done: nothing is sent any more and this device forgot its online ID. If no email opened, write to {email} with this ID: {id}").format({ "email": request.email, "id": who }), Fonts.BODY, UiSkin.TEXT, true)
	body.add_child(done)
	_own(done, "DoneText")
	var ok := UiParts.button(tr("Close"), close, Vector2(220, 56), Fonts.BODY)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(ok)
	_own(ok, "CloseButton")
	if InputDevice.uses_buttons():
		ok.grab_focus.call_deferred()


func _own(node: Node, node_name: String) -> void:
	node.name = node_name
	node.owner = self
	node.unique_name_in_owner = true

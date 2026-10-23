class_name PrivacyPolicyPanel
extends InfoPanel
## The privacy policy in the game (Options > Privacy, the consent questions, the leaderboards'
## name dialog): the short version's sections from data/online/privacy.tres (PrivacyDef),
## translated, with the contact address filled in, and a button to the full policy online
## (docs/privacy.html, once its address is set: hidden while it is a placeholder).
## Reachable as %Content, %FullPolicyButton, %CloseButton.


func _init() -> void:
	super._init(TranslationServer.tr("Privacy policy"))


func _ready() -> void:
	_build()


func _build() -> void:
	var def := Privacy.def
	for section in def.sections:
		heading(def.fill(tr(section.title)))
		paragraph(def.fill(tr(section.text)), UiSkin.TEXT)
	var link := MenuWindow.button(tr("Read the full policy online"), Fonts.BODY, 52)
	link.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	link.custom_minimum_size.x = 340
	link.visible = not PrivacyDef.is_placeholder(def.policy_url)
	link.pressed.connect(func() -> void:
		Sfx.play_ui(Sfx.bank.ui_click)
		OS.shell_open(def.policy_url))
	content.add_child(link)
	MenuWindow.expose(link, "FullPolicyButton", self)

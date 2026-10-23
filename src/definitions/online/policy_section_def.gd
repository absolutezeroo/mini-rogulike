class_name PolicySectionDef
extends Resource
## One section of the privacy policy as the game shows it (PrivacyDef.sections): a heading and
## its plain text, both English here and translated where shown, with PrivacyDef.fill()'s codes
## ({email}, {controller}...).

@export var title := ""
@export_multiline var text := ""

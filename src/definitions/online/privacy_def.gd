class_name PrivacyDef
extends Resource
## What the game says and decides about the player's data (data/online/privacy.tres, read by the
## Privacy autoload; docs/privacy-ops.md): who is responsible and how to reach them, the policy's
## version, the consent rules (the age asked before the statistics, how long a refusal is kept
## before asking again) and the short policy shown in the game (its sections, translated where
## shown). The same placeholders as docs/privacy.html: until they are filled, the game shows
## them as they are and the "write to us" email cannot be sent (docs/privacy-ops.md says how to
## fill both at once).

## Who is responsible for the data (the "controller": a legal name, or a registered business
## name). "[CONTROLLER_NAME]" in the data until known.
@export var controller_name := ""
## The privacy contact (deletion requests go there). "[CONTACT_EMAIL]" until known.
@export var contact_email := ""
## The public page of the full policy (docs/privacy.html once hosted). "[POLICY_URL]" until known.
@export var policy_url := ""
## The policy's version and date, shown at its end and stored with each consent given.
@export var policy_version := "1.0"
@export var policy_date := "2026-10-23"

@export_group("Consent")
## Raise it when what the statistics collect, why, or who receives them changes: a consent given
## to an older version no longer counts and the player is asked again.
@export var consent_version := 1
## Below this age the statistics are never offered (the strictest age of digital consent in the
## EU; docs/privacy-ops.md). Only "old enough: yes or no" is kept, never an age.
@export_range(13, 18) var age_threshold := 16
## Days a refusal (or no answer) is kept before the question comes back (6 months: the CNIL's
## good practice).
@export_range(1, 3650) var reask_days := 183
## Consents and refusals remembered on the device (proof the choice was asked, GDPR art. 7(1)).
@export_range(1, 100) var history_size := 20

@export_group("Retention (said in the policy; set in Talo's dashboard)")
## Days the statistics' events are kept on Talo (13 months).
@export var event_retention_days := 395
## Days after a player was last seen before Talo deletes it (24 months).
@export var player_purge_days := 730

## The short policy shown in the game, in order (the full one is at policy_url).
@export var sections: Array[PolicySectionDef] = []


## `text` is still a placeholder to fill ("[CONTACT_EMAIL]").
static func is_placeholder(text: String) -> bool:
	return text.is_empty() or (text.begins_with("[") and text.ends_with("]"))


## The placeholders not filled yet (empty: the policy is ready to publish).
func missing() -> PackedStringArray:
	var result := PackedStringArray()
	for field in ["controller_name", "contact_email", "policy_url"]:
		if is_placeholder(str(get(field))):
			result.append(field)
	return result


## `text` (already translated) with its {controller}, {email}, {url}, {version}, {date},
## {age}, {months} and {purge_months} codes filled.
func fill(text: String) -> String:
	return text.format({
		"controller": controller_name,
		"email": contact_email,
		"url": policy_url,
		"version": policy_version,
		"date": policy_date,
		"age": age_threshold,
		"months": roundi(event_retention_days / 30.4),
		"purge_months": roundi(player_purge_days / 30.4),
	})

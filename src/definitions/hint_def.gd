class_name HintDef
extends Resource
## One tutorial hint: a short note at the top of the screen, shown once ever, the first time
## something happens (its `cue`). It may point at a control of the HUD and stay until the
## player does what it teaches (`done_when`). The list lives in TutorialDef; Tutorial shows them.

## Saved in the profile once seen.
@export var id: StringName
## What brings it up (see Tutorial.CUES). Empty: right after the `after` hint is done.
@export var cue: StringName
## Only once this hint was seen (keeps the first steps in order). A cue that comes too early
## waits for it.
@export var after: StringName
## Only if this holds when it would show (see Tutorial.CONDITIONS); dropped otherwise, to come
## back the next time its cue does.
@export var only_if: StringName
@export var title: String
@export_multiline var text: String
## The HUD control it points at (see Hud.hint_target()). Empty: none.
@export var target: StringName
## It stays until the player does this (see Tutorial.ACTIONS). Empty: it goes after `duration`.
@export var done_when: StringName
## Seconds on screen (0: until `done_when`). A tap on it always closes it.
@export var duration := 8.0
## Several waiting: the highest first.
@export var priority := 0

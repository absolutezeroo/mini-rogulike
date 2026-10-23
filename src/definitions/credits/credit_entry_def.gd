class_name CreditEntryDef
extends Resource
## One line of the credits (CreditsDef): what or who, by whom, what it is used for, under which
## licence, where it comes from, and the licence (or credits) file shipped with it. A CC BY work
## must say whether it was changed (`changes`).

## The pack, font, tool or person (a proper name: never translated).
@export var work := ""
## Its makers (a proper name: never translated).
@export var makers := ""
## What it is in the game (translated where shown).
@export var description := ""
## The licence's short name ("CC0 1.0", "MIT", "SIL OFL 1.1"); empty for the game's own makers.
@export var license := ""
## Where it comes from.
@export var url := ""
## The licence or credits file in the project (res://), shipped with the game; empty: none.
@export_file var license_file := ""
## What was changed, if anything (translated where shown).
@export var changes := ""
## Godot itself: the page shows the engine's licence and third-party notices from the engine.
@export var engine_notice := false

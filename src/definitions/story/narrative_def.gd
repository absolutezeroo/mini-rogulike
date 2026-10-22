class_name NarrativeDef
extends Resource
## How the story is told around the fights (content_db.tres > Narrative; data/story/
## narrative.tres): the cinematics before a warden's fight, the fragments on the floors, the
## condition that lets the keeper be named. The chronicles themselves hang on each BossDef
## (`chronicle`). Read by Narrative (the service), BossMeeting and FragmentPlacer.

@export_group("Cinematics")
## A warden met with something new to tell (a chapter, its waking words): Boss stories "Full".
@export var full_cinematic: CinematicDef
## Nothing new, or Boss stories "Short": its name and one line it remembers, about two seconds.
@export var short_cinematic: CinematicDef

@export_group("Fragments")
## Chance for a floor of an act (not its boss's arena) to hold a fragment of the act's warden.
@export_range(0.0, 1.0, 0.01) var fragment_chance: float = 0.35
## Fragments only lie on the floors once these are met (not during the first run: the
## tutorial teaches it).
@export var fragments_open: Array[ProgressCondition] = []
## Logged when one is picked up ("%s" = its title).
@export var fragment_message: String = "A fragment of the past: %s."

@export_group("Deeds")
## Logged when a warden falls the way one of its deeds asks.
@export var deed_message: String = "The Well remembers how %s fell."

@export_group("Reveals")
## Met once the keeper may be named (docs/lore.md section 7: the Nameless Effigy slain, a first
## victory). Every text naming him asks for it (checked by the tests with `reveal_words`).
@export var keeper_reveal: ProgressCondition
## The words only texts gated by `keeper_reveal` may hold, in every language ("Tôma", "Toma").
@export var reveal_words: PackedStringArray = []

@export_group("Dialogue")
## Who keeps vigil at the shrine (the title screen): her figure by the Well, a tap opens her
## words (`shrine_dialogues`).
@export var shrine_speaker: SpeakerDef
## Said at the shrine, one line a tap (the first with something to say).
@export var shrine_dialogues: Array[DialogueDef] = []
## Said on the end screen after a death, one line of each in turn (the tale, then the advice);
## nothing open: the StoryDef's death lines.
@export var death_dialogues: Array[DialogueDef] = []
## The same after a victory (the first, the endings at the bottom of the Well).
@export var victory_dialogues: Array[DialogueDef] = []
## Every dialogue of the game (the codex's Voices lists what they said, by speaker, in this
## order; the tests check them all). The keepers' are hung on their own data too (ShopDef,
## ForgeDef, EncounterDef).
@export var dialogues: Array[DialogueDef] = []


## The death or victory tale, said now (RunFacts: the run's facts). Empty: nothing to say.
func tell_end(facts: RunFacts, rng: RandomNumberGenerator = null) -> Array[Dialogues.Spoken]:
	return Dialogues.say_all(victory_dialogues if facts and facts.won else death_dialogues, facts, rng)

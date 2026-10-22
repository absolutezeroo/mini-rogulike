class_name BalanceGauntlet
extends Node
## (Being written.)

var lab: BalanceLab
var jobs := BalanceJobs.new()
var content: ContentDB
var targets: BalanceTargets
var all_builds: Array[BalanceBuildDef] = []
var builds: Array[BalanceBuildDef] = []
var difficulties: Array[DifficultyDef] = []
var acts: Array[int] = []
var seed_value := 1
var quick := false
var verbose := true


func run() -> BalanceReport:
	var report := BalanceReport.new()
	report.title = "Balance gauntlet"
	return report

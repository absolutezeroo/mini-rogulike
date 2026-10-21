@AGENTS.md

## Claude Code

- Balance work ("too strong", "too weak", a balance pass, after adding content): delegate to the
  `game-balancer` subagent (.claude/agents/). It measures with tools/balance and records the pass.
- Skills in .claude/skills/: `add-content` (new monsters, items, perks, biomes...) and `translate`
  (French texts and the glossary).
- The `game` and `tutorial` suites print a lot: when you only need the verdict, filter the output
  (`... 2>&1 | grep -E 'FAIL|ERROR|checks'`).

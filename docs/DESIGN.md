# The Devil You Owe — design decisions

Everything here was decided or approved by Duff (Nov 19-20, 2026). Anything marked OPEN is not decided.

## Core
- Modern day. You're half demon and you hunt demons for power, like a serial killer.
- Theme: "your own humanity is the final target." Keep it open and not too complex.
- Merged with Duff's scavenger/lair idea (Nov 20): build your own space, serial-killer playstyle, action RPG.
- Camera: TOP-DOWN, in and out of combat. (First person was a different idea, dropped.)
- Feel: "Street Fighter meets Westland Survival", with fighting-game combos ONLY in combat. Exploring, scavenging and crafting stay simple.
- Loop: stalk -> kill -> scavenge the scene -> build the lair -> pick the next target.
- Realm-specific loot; demons you skip get stronger; a corruption meter; moral conflicts; endings decided mostly by how much power you took (choices shape them to an extent).

## Combat (locked)
- Specials combo like a fighting game. Controls are swipes, not quarter-circles.
- Eaten bosses become voices in your head that talk in DIALOGUE BOXES. Each voice gives you its moveset. A voice with a grudge locks its moves until you do its revenge quest.
- Finishers decide loot: a clean kill leaves intact parts for crafting; a brutal kill gives more power.
- Stalking earns the opener: ambush a studied target and the fight starts mid-combo.
- Improvised weapons break as combo enders (big damage), then you scavenge a new one.
- CUT: the combo meter feeding corruption.

## Lair ideas (from the merged concept, approved as direction)
- Trophies as the skill tree: one per kill, limited wall space, placement sets the perk.
- Rooms unlock verbs: workshop = crafting, cold room = stored parts, map room = choose realm / stalk two targets.
- High heat gets the lair raided; defend it with scavenged traps.
- The lair's look tracks your corruption.
- Also floated: your MO is your build (a repeated method stacks a "signature" power but makes you easier to profile); cleanup as scavenging in reverse (each item taken adds heat); a detective or rival with a case board that mirrors your lair. OPEN: who that hunter is.

## Furfur Kemp, the caged demon (locked)
- An immortal demon you captured and keep in the lair as a torture/practice dummy.
- Intro: an early hunt goes wrong, you lose and limp home; the next night he follows you home to finish you; you win ugly and chain him up.
- He mocks you from the cage for the rest of the game.
- Story beat: frustrated after a bad night, you go home and take it out on him.
- Venting after a REAL failure unlocks a combo string; capped at one unlock per real failure (so players can't farm losses).
- He was a partner at Price & Partners; tried to get out of his contract and was hunted. He breaks slowly, leaks lore, reads contract clauses for you (for small mercies), and is the first to hint at the betrayal. Nobody believes him at first, because he's a known liar.
- Hidden ending / achievement: "Killing the Unkillable". You learn how only from what he leaks; doing it costs your training room and your only honest source.

## Samael Price, the lawyer (locked)
- Owns your soul contract. Firm: Price & Partners (every partner is a demon under his contract).
- Catchphrase: "There's always a price to pay." Your line back: "Price is always paid."
- Charming handler early on; sends you targets. Twist: the kills you think pay your debt actually pay his.
- The soul contract is an inventory item; hidden clauses get revealed over time.
- Midgame betrayal reveal: Mom's freedom was never part of the deal; he's holding her.
- Boss fight: he voids your specials ("objection"); you counter with loopholes you dug up earlier.
- Achievement idea: "Paid in Full".

## Mom (locked)
- Mom made the deal to save you when you were dying at birth. That's why you're half demon. You owe your life to the contract that owns you.
- Ideas on the table (not locked): she was a hunter before you, and you find her moves in scavenged notes; her voice hates watching you torture Furfur; Furfur reveals she went to Price willingly to take your debt and Price kept both of you; in a power-heavy ending you can't free her, you become her new owner.
- OPEN: her name.

## Bosses / voices (all five kept)
1. Brother Vesper Lyle, the cult preacher. Voice: preaches, tries to recruit the other voices. Specials: Sermon (stun shout), Flock (shadow followers fight with you), Laying of Hands (healing grab). Grudge: you ate him mid-sermon; quest: kill the demon who took his congregation. Tutorial boss.
2. Gus Malloy, the gambler imp (the funny one). Voice: bets on your fights out loud. Specials: Double or Nothing (coin-flip crit or whiff), Loaded Dice (scatter shot), House Edge (counter). Grudge: you owe him money; quest: rob a demon casino.
3. Rook, the silent brute. Voice: dialogue boxes that just say "..."; the one time he speaks, it matters. Specials: Bulwark (armor through hits), Battering Ram (charge), Quake (ground slam). Grudge: unknown; quest: figure out what he wants.
4. Lady Ines Calder, the duelist. Voice: vain; critiques your form, outfit and lair decor. Specials: Riposte (parry), Flèche (dash-cancel lunge), Thousand Cuts (poke string). Grudge: you beat her ugly; quest: a stylish rematch with her old rival.
5. Mother Hollis, the hag. Voice: smothering, creepy-maternal; clashes with Mom's voice. Specials: Embrace (drain-bite grab), Swarm (insect cloud), Lullaby (sleep). Grudge: you took her "children"; quest: bring one back.

## Realms (locked; one per boss, opened through portals from the lair's map room)
Order: Pews -> Casino -> Quarry and Ballroom (either order) -> Nursery -> Price & Partners.
- The Pews (Vesper, tutorial): rotted megachurch. Zealot swarms, choir demons that buff them. Hazard: collection plates (cash but heat). Loot: candles, stained glass, censer chains.
- The Cellar Casino (Gus): neon demon gambling den. Loan sharks, dealers who shuffle cover. Hazard: slot rooms that spin random buffs/curses. Loot: chips, wire, slot glass, roulette-wheel knuckle duster.
- The Quarry (Rook): silent stone pit. Slow stone brutes. Hazard: rockfalls you can bait enemies under. Loot: rebar, chisels, chain, sledge head.
- The Ballroom (Ines): endless mansion party. Masked duelists, mirror copies of you. Hazard: mirrors you shatter to kill copies (cuts you too). Loot: rapier blades, chandelier crystal, silk cord.
- The Nursery (Hollis): hive-house. Grub swarms, grabbing "nannies". Hazard: the lullaby (stand still too long and you fall asleep mid-fight). Loot: chitin plates, needles, rattle-flail.
- Price & Partners (finale): high-rise law office in hell. Clerks, paralegals, security, all under contract. Hazard: "fine print" floors that void specials in zones. No loot; you're there to collect.

## OPEN (next design topics, in suggested order)
1. ~~Art style lock~~ DONE: LOCKED by Duff Nov 20, ink and blood on real-time 3D (docs/style-guide.md).
   Why struck (Nov 21): it was still listed as open after the lock; style-guide.md, QUEUE.md and BUILD_SPEC.md already had it.
2. The protagonist: name, look, what you do by day.
3. Mom's name and hunter past.
4. The hunter/detective on your tail.
5. Endings (power vs humanity split).
6. Game title.

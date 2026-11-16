# Rune Below

A LÖVE 11.5 dungeon shooter with procedurally generated floors. Collect the runes to unlock the Crown Crypt. When the Hollow King
falls, walk over the golden ladder to descend to a fresh floor. Your vitality
carries over, and each floor has one to three new runes to recover.

The minimap marks your room in cyan, uncollected runes in violet, and the
boss room in red. The cleared boss room turns gold when the ladder opens.

Fading slimes hurt on contact. Spirits teleport beside you and draw a red
strike circle. Star-shaped Sparks rush you and explode on contact. Shoot
Sparks from a distance or dash through them to avoid damage.

## R36S

From the repository root, run `python3 package_r36s.py` to build `RuneBelow-R36S.zip`.
On firmware with current PortMaster installed, copy Rune Below.sh and the
rune-below folder from this ZIP into the SD card's ports folder. Keep the
script beside the folder. Refresh your game list or reboot, then launch
Rune Below from Ports. If launch fails, check rune-below/log.txt.

| R36S | Action |
| --- | --- |
| Left stick | Move |
| Right stick | Aim continuously. Push to the rim in any direction to fire. |
| R1 | Cast a radial spell that clears nearby hostile shots |
| L1 | Dash in the movement direction or toward your aim while standing |
| A | Confirm the highlighted upgrade |
| Start | Begin, pause, resume, or restart after a run |
| Select | Quit from title or pause |

The launcher uses PortMaster's SDL controller mapping and LÖVE 11.5 runtime.

## Desktop

Open rune-below/RuneBelow.love with LÖVE 11.5, or run the RuneBelow
source with `love .` from the repository root.
Use WASD, mouse aim, left click to fire, Shift to dash, right click or E
to cast, Enter to begin, P to pause, and Esc to quit.

## Floor themes

Theme entries live in `floors.lua`. Add an entry with the depth at which it
starts, its colors, and the generator to use for every applicable floor.
A generator returns the room list used by `dungeon.lua`, with the start room
first and the usual reciprocal exits, runes, and boss gate.

## Level ups and upgrades

Defeated enemies grant experience. Level ups pause combat and show three cards:
the top card maps to Up, the left card maps to Left, and the right card maps to
Right. Press A to take the highlighted upgrade. Keyboard arrows and Enter work
on desktop.

The first upgrade pool includes faster fire, heavier rounds, vitality, dash and
spell cooldowns, ricochet, orbiting wisps, a damaging aura, a timed knockback
pulse, health motes, and Grave Calling. Grave Calling can reanimate defeated
non-boss enemies as temporary allies. Health motes and runes are collected by
walking over them.

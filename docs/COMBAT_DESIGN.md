# Combat and movement — prototype specification

## Direction
Side-view 2D dark-fantasy action RPG. Ground combat first; occasional jumps, tree kicks, perches, stealth ambushes. Character growth gradually expands strength, agility, endurance and stability. The origin of supernatural power is intentionally undefined.

## Implemented reusable code (not yet wired to the playable sandbox)
- ActorStats Resource: strength, agility, endurance, stability, mass and weapon mass.
- StaminaComponent: spending, regeneration and cooldown.
- CombatMath: bounded knockback and armor/guard damage calculation.
- PlayerController: horizontal acceleration, friction, jump, dodge, parry window, attack and recoil.
- PerchPoint and KickSurface: reusable environmental interaction definitions.
- VisibilityComponent: elementary detection score based on concealment, light and distance.

## Combat design rules
- Strong attacks produce more recoil and stagger, but not guaranteed one-hit boss kills.
- Bosses have armor, guard, poise and punish windows; use telegraphed attacks and recoverable stagger.
- Low-tier enemies may be overwhelmed by an overleveled player.
- Prefer authored animations and deterministic hit windows to fully simulated ragdoll attacks.
- Superhuman progression changes movement, impact and environment interactions, not only HP numbers.

## Known gaps
These are reusable scripts, not a finished integrated demo. Character scene, input mapping, collision masks, attack animations, boss AI, branch/perch controls, guard/parry resolution and testing in the Godot editor remain to be done.

# Hero gameplay prototype (Godot 4)

The two playable scenes (`scenes/field_prologue.tscn`, `scenes/hero_visual_preview.tscn`) now use `AnimatedSprite2D`, `AttackBox` and `Hurtbox`, with a shared `scripts/actors/hero_controller.gd`.

Controls: A/D or arrows to move; Shift to run; Space/Enter to jump; J to start and chain up to three attacks; Esc returns to the main menu.

The controller supports health, invulnerability after a hit, knockback, death signal, combo sequencing and animation-state selection. Damage delivery requires an enemy Area2D on collision layer 2 implementing `receive_hit(damage: int, impulse: Vector2)`; the prologue currently contains no enemies.

**Art limitation:** All 10 animation names currently use the SAME existing `hero_idle.png` as a one-frame placeholder. This does not constitute actual hand-drawn walk/run/jump/attack animation. The existing sprite has cutout/foot-placement issues. Real, transparent, consistent character frames must be supplied or drawn and then imported into the `SpriteFrames` resources. Do not represent the current project as containing the 8/12-frame sprite sheets shown in the concept mockup.

To verify: pull the branch, open the project in Godot, run F6 on either scene, inspect the Output/Debugger panel. Runtime validation has not been performed here.

# Technical design

The project currently contains a runnable shape-based combat sandbox in `scenes/main.tscn` and modular components prepared for the next iteration.

## Combat components
- `HealthComponent`: reusable health/damage/healing with signals.
- `Hitbox`: melee Area2D damage emitter; activate via animation method tracks.
- `Hurtbox`: Area2D damage receiver linked to a HealthComponent.

For an actual character, add a CharacterBody2D, CollisionShape2D, AnimationPlayer, HealthComponent, and child Hitbox/Hurtbox Area2D nodes with collision shapes. Set collision layers/masks so the attack Area2D sees the target hurtbox, and set owner groups appropriately. Do not use these components as a substitute for physical collision.

## Cinematics
`CutsceneDirector` plays named AnimationPlayer tracks and emits start/finish signals. Animation tracks can animate cameras, character transforms, dialogue triggers, and visual effects.

## Next
Build the first CharacterBody2D player scene, finite state machine (idle/run/attack/dodge/stagger), enemy AI and a level scene. Keep the narrative independent from mechanics until the story outline is ready.

class_name CombatMath
extends RefCounted

# Gameplay-tuned impulse, not a literal rigid-body simulation.
static func knockback(attacker_strength: float, weapon_mass: float, defender_mass: float, defender_stability: float, attack_speed: float, guard_factor: float = 1.0) -> float:
    var impulse := maxf(0.0, attacker_strength) * maxf(0.1, weapon_mass) * maxf(0.1, attack_speed)
    var resistance := maxf(1.0, defender_mass * 0.1 + defender_stability * 2.0)
    return clampf(impulse / resistance * 65.0 * clampf(guard_factor, 0.0, 1.0), 0.0, 900.0)

static func damage(raw_damage: float, guard_multiplier: float, armor: float) -> int:
    return maxi(1, roundi(maxf(0.0, raw_damage) * clampf(guard_multiplier, 0.0, 2.0) * 100.0 / (100.0 + maxf(0.0, armor))))

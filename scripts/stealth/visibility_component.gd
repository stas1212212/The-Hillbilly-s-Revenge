class_name VisibilityComponent
extends Node

@export_range(0.0, 1.0) var concealment := 0.0
@export_range(0.0, 1.0) var movement_noise := 0.0

func detection_score(distance: float, light_level: float) -> float:
    var proximity := clampf(1.0 - distance / 450.0, 0.0, 1.0)
    return clampf(proximity * clampf(light_level, 0.0, 1.0) * (1.0 - concealment) + movement_noise * 0.25, 0.0, 1.0)

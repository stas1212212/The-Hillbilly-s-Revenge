class_name CutsceneDirector
extends Node

signal cutscene_started
signal cutscene_finished

@export var animation_player: AnimationPlayer
var playing := false

func play_cutscene(animation_name: StringName) -> void:
    if playing or animation_player == null:
        return
    if not animation_player.has_animation(animation_name):
        push_warning("Missing cutscene animation: %s" % animation_name)
        return
    playing = true
    cutscene_started.emit()
    animation_player.play(animation_name)
    await animation_player.animation_finished
    playing = false
    cutscene_finished.emit()

extends Node2D


func _on_quit_pressed() -> void:
	pass # Replace with function body.
	get_tree() .quit()



func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://level.tscn")


func _on_video_stream_player_finished() -> void:
	pass # Replace with function body.

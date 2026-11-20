extends Node

const Online = preload("res://scripts/online.gd")

func _ready() -> void:
	var online := Online.new()
	online.name = "Online"
	add_child(online)
	var port := OS.get_environment("PORT").to_int()
	var result := online.serve(port if port > 0 else 10000)
	if result != OK:
		push_error("No se pudo iniciar el servidor: " + error_string(result))
		get_tree().quit(1)

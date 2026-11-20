extends Node

signal connection_status(message: String)
signal avatar_received(peer_id: int, state: Dictionary)
signal avatar_removed(peer_id: int)

const MAX_PLAYERS := 8
const VERSION := 1

var hosting := false
var connected := false
var approved: Dictionary = {}
var last_update: Dictionary = {}

func _ready() -> void:
	multiplayer.peer_disconnected.connect(peer_left)
	multiplayer.connected_to_server.connect(handshake)
	multiplayer.connection_failed.connect(func(): disconnect_game("No se pudo conectar al servidor."))
	multiplayer.server_disconnected.connect(func(): disconnect_game("Se perdió la conexión."))

func serve(port: int) -> Error:
	var socket := WebSocketMultiplayerPeer.new()
	socket.handshake_timeout = 10.0
	var result := socket.create_server(port, "0.0.0.0")
	if result == OK:
		hosting = true
		multiplayer.multiplayer_peer = socket
		print("Ciudad Aurora escuchando WebSocket en el puerto ", port)
		multiplayer.peer_connected.connect(check_handshake)
	return result

func connect_to(url: String) -> void:
	if multiplayer.has_multiplayer_peer():
		disconnect_game("")
	var endpoint := url.strip_edges()
	if endpoint.begins_with("https://"):
		endpoint = "wss://" + endpoint.trim_prefix("https://")
	if not endpoint.begins_with("wss://") and not endpoint.begins_with("ws://"):
		connection_status.emit("Introduce una dirección wss:// válida.")
		return
	var socket := WebSocketMultiplayerPeer.new()
	socket.handshake_timeout = 15.0
	var result := socket.create_client(endpoint)
	if result != OK:
		connection_status.emit("Error de conexión: " + error_string(result))
		return
	multiplayer.multiplayer_peer = socket
	connection_status.emit("Conectando…")

func disconnect_game(message := "Modo sin conexión.") -> void:
	if multiplayer.has_multiplayer_peer():
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	for id in approved.keys():
		avatar_removed.emit(id)
	approved.clear()
	connected = false
	if not message.is_empty():
		connection_status.emit(message)

func handshake() -> void:
	register_player.rpc_id(1, VERSION)

func check_handshake(peer_id: int) -> void:
	await get_tree().create_timer(10.0).timeout
	if multiplayer.get_peers().has(peer_id) and not approved.has(peer_id):
		multiplayer.multiplayer_peer.disconnect_peer(peer_id)

@rpc("any_peer", "reliable")
func register_player(version: int) -> void:
	if not hosting:
		return
	var id := multiplayer.get_remote_sender_id()
	if approved.has(id):
		return
	if version != VERSION or approved.size() >= MAX_PLAYERS:
		rejected.rpc_id(id, "Sala llena o versión incompatible.")
		return
	approved[id] = true
	welcome.rpc_id(id)

@rpc("authority", "reliable")
func welcome() -> void:
	connected = true
	connection_status.emit("En línea · Ciudad Aurora")

@rpc("authority", "reliable")
func rejected(message: String) -> void:
	disconnect_game(message)

func push(position: Vector3, heading: float, vehicle: int, mode: int, floor_number: int, color: Color) -> void:
	if connected:
		submit.rpc_id(1, position, heading, vehicle, mode, floor_number, color)

@rpc("any_peer", "reliable")
func submit(position: Vector3, heading: float, vehicle: int, mode: int, floor_number: int, color: Color) -> void:
	if not hosting:
		return
	var id := multiplayer.get_remote_sender_id()
	if not approved.has(id) or not position.is_finite() or not is_finite(heading) or not Vector3(color.r, color.g, color.b).is_finite() or not is_finite(color.a):
		return
	if absf(position.x) > 725 or absf(position.z) > 725 or position.y < -40 or position.y > 125:
		return
	if vehicle < -1 or vehicle >= 103 or mode < 0 or mode > 2 or floor_number < 0 or floor_number > 40:
		return
	var now := Time.get_ticks_msec()
	if now - int(last_update.get(id, -100)) < 60:
		return
	last_update[id] = now
	for receiver in approved:
		if receiver != id:
			snapshot.rpc_id(receiver, id, position, wrapf(heading, -PI, PI), vehicle, mode, floor_number, color.clamp())

@rpc("authority", "reliable")
func snapshot(id: int, position: Vector3, heading: float, vehicle: int, mode: int, floor_number: int, color: Color) -> void:
	if connected:
		approved[id] = true
		avatar_received.emit(id, {"position": position, "heading": heading, "ride": vehicle, "mode": mode, "floor": floor_number, "color": color})

func peer_left(id: int) -> void:
	if hosting:
		var known := approved.erase(id)
		last_update.erase(id)
		if known:
			for receiver in approved:
				remove_avatar.rpc_id(receiver, id)

@rpc("authority", "reliable")
func remove_avatar(id: int) -> void:
	approved.erase(id)
	avatar_removed.emit(id)

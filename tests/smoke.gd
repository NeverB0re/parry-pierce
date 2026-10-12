extends SceneTree
var main
var n := 0
func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
func _process(_d: float) -> bool:
	n += 1
	if n == 2:
		main.lives = 1
		main.boss.next_t = 0.5
	main.player.invuln = 99.0
	if n > 3:
		main.player.on_platform = false
		main.player.position = Vector2(300, -1200 - (n % 400))
		main.player.vel = Vector2.ZERO
	main._physics_process(1.0 / 60.0)
	if n >= 600:
		print("smoke ok frames=", n, " lives=", main.lives)
		quit()
	return false

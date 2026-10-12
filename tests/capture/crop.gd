extends SceneTree
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var img := Image.load_from_file(args[0])
	var r := Rect2i(int(args[2]), int(args[3]), int(args[4]), int(args[5]))
	var c := img.get_region(r)
	c.resize(c.get_width() * 4, c.get_height() * 4, Image.INTERPOLATE_NEAREST)
	c.save_png(args[1])
	quit()

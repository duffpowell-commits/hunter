extends SceneTree
## Close-up render of the pet fox (docs/renders/fox_pet_*.png). Usage:
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 600x600 --script tools/render_fox.gd -- out.png [--open]
func _initialize():
	await process_frame
	var w := Node3D.new()
	root.add_child(w)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.35, 0.33, 0.36)
	env.environment.ambient_light_color = Color(0.5,0.5,0.5)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	w.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	w.add_child(sun)
	var fox = preload("res://scripts/fox_pet.gd").new()
	w.add_child(fox)
	await process_frame
	var open := OS.get_cmdline_user_args().has("--open")
	fox._set_eye(open)
	fox.model.rotation.y = deg_to_rad(-20)
	var cam := Camera3D.new()
	w.add_child(cam)
	cam.position = Vector3(0.0, 0.75, 1.15)
	cam.look_at(Vector3(0, 0.38, 0))
	cam.make_current()
	for i in 20:
		await process_frame
	var img := root.get_texture().get_image()
	img.save_png(OS.get_cmdline_user_args()[0])
	quit()

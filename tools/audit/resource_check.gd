extends SceneTree
## Проверка фактических типов ресурсов окружения. Только чтение.

func _initialize() -> void:
	var dir := DirAccess.open("res://resources/locations/post_nightmare/environments")
	if dir == null:
		print("NO_DIR")
		quit(1)
		return
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if file.ends_with(".tres") and file.begins_with("env_"):
			var path := "res://resources/locations/post_nightmare/environments/" + file
			var env: Environment = load(path)
			print("ENV ", file, " sky=", env.sky, " bg=", env.background_mode,
				" tonemap=", env.tonemap_mode, " ssao=", env.ssao_enabled,
				" ssil=", env.ssil_enabled, " sdfgi=", env.sdfgi_enabled,
				" glow=", env.glow_enabled, " fog=", env.fog_enabled,
				" volfog=", env.volumetric_fog_enabled)
		file = dir.get_next()
	dir.list_dir_end()
	var sky_mat = load("res://resources/locations/post_nightmare/environments/sky_grey.tres")
	print("SKY_GREY class=", sky_mat.get_class() if sky_mat != null else "null")
	quit(0)

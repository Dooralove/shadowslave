extends CutsceneScript
## B01: призыв Плаща на Чёрном море. Камера — существующий Shots/Sword.

const SHROUD := preload("res://resources/dialogue/post_nightmare/b01_shroud.tres")


func run(ctx: CutsceneContext) -> void:
	await ctx.camera.shot(&"Sword", 0.7)
	ctx.ui.show_title("ПЛАЩ", "Чёрное море", 2.0)
	await ctx.dialogue(SHROUD)

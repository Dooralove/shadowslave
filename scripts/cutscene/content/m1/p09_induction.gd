extends CutsceneScript
## P09: индукция в Sleeper Center. Камера смотрит на дортуар и подиум.

const INDUCTION := preload("res://resources/dialogue/post_nightmare/p09_induction.tres")


func run(ctx: CutsceneContext) -> void:
	await ctx.camera.shot(&"Dormitory", 0.6)
	ctx.ui.show_title("ИНДУКЦИЯ", "Sleeper Center", 2.0)
	await ctx.dialogue(INDUCTION)

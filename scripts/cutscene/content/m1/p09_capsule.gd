extends CutsceneScript
## P09: погружение в капсулу и переход месяца.
## Затемнение и титульная карточка читаются как time-skip, а не как обычный диалог.

const CAPSULE := preload("res://resources/dialogue/post_nightmare/p09_capsule.tres")


func run(ctx: CutsceneContext) -> void:
	await ctx.camera.shot(&"Dormitory", 0.6)
	ctx.ui.show_title("МЕСЯЦ СПУСТЯ", "Академия", 2.0)
	await ctx.dialogue(CAPSULE)
	await ctx.ui.fade_to(1.0, 0.5)
	await ctx.ui.fade_to(0.0, 0.7)

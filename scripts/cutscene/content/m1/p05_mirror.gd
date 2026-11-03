extends CutsceneScript
## P05: взгляд в зеркало. Короткая постановка без движения игрока.

const MIRROR := preload("res://resources/dialogue/post_nightmare/p05_mirror.tres")


func run(ctx: CutsceneContext) -> void:
	await ctx.camera.shot(&"Interrogation", 0.5)
	await ctx.dialogue(MIRROR)

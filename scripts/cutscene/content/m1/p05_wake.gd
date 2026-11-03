extends CutsceneScript
## P05: пробуждение в участке.
## Использует существующий ракурс Shots/Interrogation и канонический диалог A01.
## Управление блокирует CutsceneDirector; флаги завершения — в манифесте.

const WAKE := preload("res://resources/dialogue/post_nightmare/p05_jett_awakening.tres")


func run(ctx: CutsceneContext) -> void:
	await ctx.ui.fade_to(0.85, 0.35)
	await ctx.camera.shot(&"Interrogation", 0.0)
	ctx.ui.show_title("ПОСЛЕ КОШМАРА", "Участок", 2.0)
	await ctx.ui.fade_to(0.0, 0.8)
	await ctx.dialogue(WAKE)

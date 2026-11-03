extends CutsceneScript
## Демонстрационный сценарий: камера -> анимация -> перемещение -> диалог
## -> смена ракурса -> возврат в геймплей.

func run(ctx: CutsceneContext) -> void:
	await ctx.ui.letterbox_on(0.3)

	await ctx.camera.shot(&"ShotA", 0.7)
	ctx.actor(&"sunny").play(&"idle")
	ctx.actor(&"npc").play(&"bob")
	await ctx.wait(0.3)

	await ctx.actor(&"npc").move_to(ctx.marker(&"NpcTarget"), 1.2)
	await ctx.actor(&"npc").face(ctx.marker(&"Focus"), 0.3)

	await ctx.say("Это тестовая кат-сцена. Камера, актёр, анимация и диалог работают.", &"npc", 1.4)

	await ctx.actor(&"sunny").face(ctx.marker(&"Focus"), 0.4)
	await ctx.camera.shot(&"ShotB", 0.8)
	await ctx.actor(&"sunny").move_to(ctx.marker(&"PlayerEnd"), 1.0)
	await ctx.wait(0.4)

	await ctx.camera.player(0.6)
	await ctx.ui.letterbox_off(0.3)

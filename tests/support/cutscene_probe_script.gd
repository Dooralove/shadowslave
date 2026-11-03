extends CutsceneScript
## Минимальный сценарий для GUT-проверки жизненного цикла CutsceneDirector.


func run(ctx: CutsceneContext) -> void:
	await ctx.wait(0.01)
	ctx.flag(&"test_cutscene_ran")

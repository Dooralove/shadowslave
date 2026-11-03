extends CutsceneScript
## Держит кат-сцену активной, чтобы проверить блокировку меню/карты/паузы.


func run(ctx: CutsceneContext) -> void:
	await ctx.wait(1.0)
	ctx.flag(&"test_cutscene_hold_done")

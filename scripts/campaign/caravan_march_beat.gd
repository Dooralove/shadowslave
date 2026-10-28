class_name CaravanMarchBeat
extends Resource
## Один сюжетный отрезок марша S01.
##
## Позиция задаётся в локальных координатах дороги: при пересечении порога
## сценарий один раз показывает последовательность. flag хранится в
## NightmareRunState, поэтому повторный запуск сцены не проигрывает знакомство.

@export var trigger_local_z := -1.0
@export var flag: StringName
@export var sequence: DialogueSequence
## Эта реплика завершает знакомство S01 и открывает прибытие в лагерь.
@export var completes_intro := false
## Короткий удар кнутом: красная вспышка и пометка в HUD.
@export var whip := false

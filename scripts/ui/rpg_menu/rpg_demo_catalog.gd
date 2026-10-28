class_name RpgDemoCatalog
extends Resource
## Отдельный демонстрационный набор для прототипа RPG-меню.
##
## Канонические идентификаторы персонажа берутся из существующего
## StatusSheet, а все предметы, числа и цены ниже — только тестовые данные UI.
## Не подключать к сохранениям, прологу или игровой экономике.

@export var catalog_note := "Демонстрационные данные интерфейса. Не канон."
@export var character_name := "Санни"
@export var status_sheet: StatusSheet
@export var character_note := "Числовые показатели — тестовые. Идентификаторы персонажа взяты из существующего StatusSheet."
@export var demo_stats: Array = []
@export var items: Array = []
@export var merchant_name := ""
@export_multiline var merchant_note := ""
@export var starting_demo_coins := 0
@export var trade_offers: Array = []

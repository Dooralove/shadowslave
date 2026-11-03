class_name AttackData
extends AttackStats
## Расширенные данные атаки для боевой основы.
##
## Наследует существующий AttackStats, поэтому MeleeAttack и старые .tres
## продолжают работать без изменений. Новые атаки описываются этим ресурсом.

enum Kind { LIGHT, HEAVY, UNBLOCKABLE }

@export var attack_name := "Лёгкий удар"
@export var kind: Kind = Kind.LIGHT
## Сколько выносливости стоит начало атаки.
@export var stamina_cost := 8.0
## Сколько выносливости снимает блокированный удар.
@export var guard_damage := 15.0
## Можно ли принять удар блоком.
@export var blockable := true
## Короткая остановка на попадании, с. Пока только данные для будущего hitstop.
@export var hitstop := 0.05

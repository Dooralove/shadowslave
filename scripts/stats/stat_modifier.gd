class_name StatModifier
extends Resource
## Одно изменение характеристики. Используется пассивными баффами/дебаффами
## брони и аксессуаров, чтобы описание предмета не превращалось в набор
## отдельных полей на каждый возможный стат.

enum Operation {
	## Прибавить значение: +12 к броне, -0.1 к скорости.
	ADD,
	## Процент от текущего значения: +10% к запасу выносливости.
	PERCENT,
	## Умножить значение: 0.9 — на 10% медленнее.
	MULTIPLY,
}

@export var stat: StringName = &""
@export var operation: Operation = Operation.ADD
@export var value := 0.0
@export var label := ""
@export_multiline var description := ""


func apply(base: float) -> float:
	match operation:
		Operation.ADD:
			return base + value
		Operation.PERCENT:
			return base * (1.0 + value * 0.01)
		Operation.MULTIPLY:
			return base * value
	return base


## Дебафф — это отрицательный ADD/PERCENT или множитель меньше единицы.
func is_penalty() -> bool:
	match operation:
		Operation.MULTIPLY:
			return value < 1.0
		_:
			return value < 0.0


func is_valid() -> bool:
	return stat != &"" and (operation == Operation.MULTIPLY or value != 0.0)


func describe() -> String:
	if not label.is_empty():
		return label
	var sign := "+" if value >= 0.0 else ""
	match operation:
		Operation.ADD:
			return "%s%s %s" % [sign, str(value), stat]
		Operation.PERCENT:
			return "%s%s%% %s" % [sign, str(value), stat]
		Operation.MULTIPLY:
			return "x%s %s" % [str(value), stat]
	return String(stat)

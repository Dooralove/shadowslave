# Глоссарий: персонажи

Сюда кладутся записи раздела «Персонажи» единого меню. UI читает все `.tres`
из этой папки и показывает `id`, `title` и `text`.

Подходит любой ресурс с этими полями; проще всего — `JournalEntryData`
(`scripts/campaign/journal_entry_data.gd`):

```tres
[gd_resource type="Resource" script_class="JournalEntryData" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/campaign/journal_entry_data.gd" id="1_journal"]

[resource]
script = ExtResource("1_journal")
id = &"character_id"
title = "Имя"
text = "Короткая запись без спойлеров будущих глав."
```

Правила:
- `id` уникален в пределах папки;
- текст не дублирует бестиарий и не раскрывает сюжет раньше сцены;
- записи создаются отдельной контент-сессией, UI их не генерирует.

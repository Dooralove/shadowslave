class_name PostNightmareObjectives
extends Resource
## DEPRECATED: не использовать как источник цели.
##
## M1-сцены выставляют цель через CampaignGuide.set_external_objective, а
## ObjectiveLine читает QuestSystem → CampaignGuide. Ресурс оставлен только
## для обратной совместимости и будет удалён отдельным решением TD.

@export var objectives: Dictionary[StringName, String] = {}


func objective_for_scene(scene_path: String) -> String:
	if scene_path.is_empty():
		return ""
	var key := StringName(scene_path.get_file().get_basename())
	return objectives.get(key, "").strip_edges()

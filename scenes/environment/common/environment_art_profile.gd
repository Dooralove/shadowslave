@tool
class_name EnvironmentArtProfile
extends Resource
## Art-direction recipe for one location.
##
## A profile is data only. EnvironmentArtOverlay applies it to the runtime
## greybox hierarchy after GreyboxLocation has emitted layout_built. Profiles
## never own collision, spawns, portals, markers, gameplay nodes or tide
## controllers.

@export_group("Environment")
@export var environment: Environment
@export var apply_environment := true

@export_group("Materials")
## Resource array of EnvironmentMaterialSwap. Kept untyped at the export
## boundary so .tres files can be authored by tools without global class-cache
## timing issues; every entry is validated in _material_for().
@export var material_swaps: Array = []

@export_group("Visibility")
## Prefixes checked against generated visual mesh names. Hidden nodes are
## always MeshInstance3D/Light3D; collision bodies are never touched.
@export var hide_name_prefixes: PackedStringArray = []
@export var hide_name_contains: PackedStringArray = []
@export var hide_original_lights := false

@export_group("Key Light")
@export var override_key_light := false
@export var key_light_name := "Sun"
@export var key_light_rotation_degrees := Vector3(-38.0, -28.0, 0.0)
@export var key_light_color := Color(1.0, 0.94, 0.86, 1.0)
@export var key_light_energy := 1.6
@export var key_light_shadow := true

@export_group("Water")
@export var water_material: Material
@export var water_name_contains: PackedStringArray = ["Water", "SeaBelow", "BlackWater", "DeepWater"]

@export_group("Post")
## Values below 0 are ignored. Exposure is a linear multiplier (1.0 = neutral).
@export var exposure := -1.0
@export var glow_intensity := -1.0
@export var fog_density := -1.0
@export var fog_light_color := Color(0.0, 0.0, 0.0, 0.0)
@export var fog_light_energy := -1.0

class_name CutsceneTypes
extends RefCounted
## Общие перечисления фреймворка кат-сцен.

enum State {
	IDLE,
	PREPARING,
	PLAYING,
	CLEANING,
	FINISHED,
}

enum Result {
	COMPLETED,
	SKIPPED,
	ABORTED,
	BUSY,
	INVALID,
	ALREADY_COMPLETED,
	BLOCKED,
}

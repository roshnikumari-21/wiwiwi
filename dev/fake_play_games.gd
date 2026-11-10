extends RefCounted
## Fake Play Games clients for tests: they record calls instead of talking to Google.
## Loaded with load() at run time (the plugin classes need the game's autoloads to compile).

class FakeAchievements extends PlayGamesAchievementsClient:
	var calls := []
	func unlock_achievement(id: String) -> void:
		calls.append(["unlock", id])
	func set_achievement_steps(id: String, steps: int) -> void:
		calls.append(["steps", id, steps])

class FakeLeaderboards extends PlayGamesLeaderboardsClient:
	var calls := []
	func submit_score(id: String, score: int) -> void:
		calls.append(["score", id, score])

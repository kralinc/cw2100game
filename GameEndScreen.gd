extends Panel

signal spectate_pressed()

func _ready() -> void:
	visible = false
	%SpectateButton.pressed.connect(_on_spectate_button_pressed)
	%MainMenuButton.pressed.connect(_on_main_menu_button_pressed)
	%PlayButton.pressed.connect(%ReplayTexture.togglePlaying)
	%RestartButton.pressed.connect(%ReplayTexture.rewind)
	%ReplayTexture.playing_changed.connect(_on_replay_playing_changed)
	%ReplayTexture.frame_changed.connect(_on_replay_frame_changed)

# faction can be null if there is no relevant faction to display (e.g. an all-AI game)
func showResult(victory:bool, faction:Faction, canSpectate:bool) -> void:
	%WinStatusLabel.text = "VICTORY" if victory else "DEFEAT"
	%SpectateButton.visible = canSpectate
	%FlagAndTitleContainer.visible = faction != null
	if faction != null:
		%FlagTextureRect.texture = faction.flag
		%CountryNameLabel.text = faction.fullName
	%TurnsLabel.text = "Turns: %d" % Global.turn
	%MapLabel.text = "Map: %s" % Global.mapDir.trim_suffix("/").get_file()
	%ReplayTexture.setup(Global.replayInitialOwnership, Global.replayOwnershipDiffs, Global.factions, Global.replayTileSize)
	visible = true

func _on_replay_playing_changed(playing:bool) -> void:
	%PlayButton.text = "||" if playing else ">"

func _on_replay_frame_changed(frame:int) -> void:
	%TurnCounterLabel.text = "Turn: %d" % frame

func _on_spectate_button_pressed() -> void:
	%ReplayTexture.pause()
	visible = false
	spectate_pressed.emit()

func _on_main_menu_button_pressed() -> void:
	get_tree().change_scene_to_file("res://MainMenu.tscn")

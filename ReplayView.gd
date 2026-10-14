extends TextureRect

# Shows a replay of tile ownership over the course of the game. Ownership is stored as a
# palette index per tile in a small data texture, and replay.gdshader turns that into hexes.

signal playing_changed(playing:bool)
signal frame_changed(frame:int) # frame 0 is the starting map, frame N is the map after turn N

const FRAMES_PER_SECOND = 2.0
const MAX_TEX_WIDTH = 4096 # tiles are stored linearly and wrapped so huge maps don't exceed GPU texture limits
const NO_TILE_INDEX = 0
const NEUTRAL_INDEX = 1

var diffs:Array[Array] = []
var paletteIndices:Dictionary = {} # faction id -> palette index
var mapMin:Vector2i
var mapSize:Vector2i
var texSize:Vector2i
var initialOwnerData:PackedByteArray
var ownerData:PackedByteArray
var ownerImage:Image
var ownerTexture:ImageTexture
var frame:int = 0
var playing:bool = false
var timer:Timer

func _ready() -> void:
	# The shader does all the drawing, the TextureRect just needs something to draw
	texture = ImageTexture.create_from_image(Image.create(1, 1, false, Image.FORMAT_RGBA8))
	material = ShaderMaterial.new()
	material.shader = preload("res://replay.gdshader")
	resized.connect(func(): material.set_shader_parameter("rect_size", size))

	timer = Timer.new()
	timer.wait_time = 1.0 / FRAMES_PER_SECOND
	timer.timeout.connect(stepForward)
	add_child(timer)

func setup(initialOwnership:Dictionary, ownershipDiffs:Array[Array], factions:Dictionary, tileSize:Vector2) -> void:
	pause()
	diffs = ownershipDiffs
	if initialOwnership.is_empty():
		return
	buildPalette(factions)

	var minCell = initialOwnership.keys()[0]
	var maxCell = minCell
	for cell in initialOwnership:
		minCell = minCell.min(cell)
		maxCell = maxCell.max(cell)
	mapMin = minCell
	mapSize = maxCell - minCell + Vector2i.ONE
	var tileCount = mapSize.x * mapSize.y
	texSize.x = mini(tileCount, MAX_TEX_WIDTH)
	texSize.y = ceili(float(tileCount) / texSize.x)

	initialOwnerData = PackedByteArray()
	initialOwnerData.resize(texSize.x * texSize.y * 2)
	initialOwnerData.fill(0) # NO_TILE_INDEX
	for cell in initialOwnership:
		writeOwner(initialOwnerData, cell, initialOwnership[cell])
	ownerData = initialOwnerData.duplicate()
	ownerImage = Image.create_from_data(texSize.x, texSize.y, false, Image.FORMAT_RG8, ownerData)
	ownerTexture = ImageTexture.create_from_image(ownerImage)
	frame = 0
	frame_changed.emit(frame)

	# Bounds of every hex in the same tile-space the shader uses for cell centers
	var worldMin = Vector2(INF, INF)
	var worldMax = Vector2(-INF, -INF)
	for cell in initialOwnership:
		var center = hexCenter(cell, tileSize)
		worldMin = worldMin.min(center - tileSize / 2)
		worldMax = worldMax.max(center + tileSize / 2)

	material.set_shader_parameter("owner_tex", ownerTexture)
	material.set_shader_parameter("tex_width", texSize.x)
	material.set_shader_parameter("map_min", mapMin)
	material.set_shader_parameter("map_size", mapSize)
	material.set_shader_parameter("tile_size", tileSize)
	material.set_shader_parameter("world_min", worldMin)
	material.set_shader_parameter("world_size", worldMax - worldMin)
	material.set_shader_parameter("rect_size", size)

# Must match the cell center formula in replay.gdshader
static func hexCenter(cell:Vector2i, tileSize:Vector2) -> Vector2:
	return Vector2(cell.x * tileSize.x * 0.75, cell.y * tileSize.y + (cell.x & 1) * tileSize.y * 0.5)

func buildPalette(factions:Dictionary) -> void:
	paletteIndices = {0: NEUTRAL_INDEX}
	var colors:Array[Color] = [Color.BLACK, Color.WHITE]
	var factionIds = factions.keys()
	factionIds.sort()
	for factionId in factionIds:
		if factionId == 0:
			continue
		paletteIndices[factionId] = colors.size()
		colors.append(Color(factions[factionId].color, 1.0))

	var paletteImage = Image.create(colors.size(), 1, false, Image.FORMAT_RGBA8)
	for i in colors.size():
		paletteImage.set_pixel(i, 0, colors[i])
	material.set_shader_parameter("palette_tex", ImageTexture.create_from_image(paletteImage))

func writeOwner(data:PackedByteArray, cell:Vector2i, factionId:int) -> void:
	var local = cell - mapMin
	var byteIndex = (local.y * mapSize.x + local.x) * 2
	var paletteIndex:int = paletteIndices.get(factionId, NEUTRAL_INDEX)
	data[byteIndex] = paletteIndex & 0xFF
	data[byteIndex + 1] = (paletteIndex >> 8) & 0xFF

func uploadOwnerData() -> void:
	ownerImage.set_data(texSize.x, texSize.y, false, Image.FORMAT_RG8, ownerData)
	ownerTexture.update(ownerImage)

func lastFrame() -> int:
	return diffs.size()

func stepForward() -> void:
	if ownerImage == null or frame >= lastFrame():
		pause()
		return
	for change in diffs[frame]:
		writeOwner(ownerData, Vector2i(change["x"], change["y"]), change["faction"])
	frame += 1
	uploadOwnerData()
	frame_changed.emit(frame)
	if frame >= lastFrame():
		pause()

func rewind() -> void:
	if ownerImage == null:
		return
	frame = 0
	ownerData = initialOwnerData.duplicate()
	uploadOwnerData()
	frame_changed.emit(frame)

func play() -> void:
	if frame >= lastFrame():
		rewind()
	playing = true
	timer.start()
	playing_changed.emit(true)

func pause() -> void:
	if timer != null:
		timer.stop()
	if playing:
		playing = false
		playing_changed.emit(false)

func togglePlaying() -> void:
	if playing:
		pause()
	else:
		play()

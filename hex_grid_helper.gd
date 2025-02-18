extends Object

class_name HGH

var astar:AStar2D
var mapData:Dictionary
var highestXValue:int
var highestYValue:int


func setMapData(md:Dictionary):
	mapData = md


# Define the direction differences for odd-q hexagonal grid
static var oddq_direction_differences = [
	# even columns
	[
		Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
		Vector2i(-1, -1), Vector2i(-1, 0), Vector2i(0, 1)
	],
	# odd columns
	[
		Vector2i(1, 1), Vector2i(1, 0), Vector2i(0, -1),
		Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)
	]
]

# Function to get the neighbor hex based on the direction
static func oddq_offset_neighbor(hex: Vector2i, direction: int) -> Vector2i:
	var parity = int(hex.x) & 1  # Determine if the column is odd or even
	var diff = oddq_direction_differences[parity][direction]  # Get the direction difference
	return Vector2i(hex.x + diff.x, hex.y + diff.y)  # Return the new hex coordinate
	
func getNeighbors(cell: Vector2i) -> Array:
	var neighbors = []
	for i in range(6):
		if astar.has_point(getAStarCellId(oddq_offset_neighbor(cell, i))):
			neighbors.push_back(oddq_offset_neighbor(cell, i))
	return neighbors
	
func calculateMidpointOfCells(list:Dictionary):
	var sumx = 0
	var sumy = 0
	for item in list:
		sumx += item.x
		sumy += item.y
	var midx = sumx / list.size()
	var midy = sumy / list.size()
	
	return Vector2i(roundi(midx), roundi(midy))
	
func getHighestMapValues():
	var highestY = 0
	var highestX = 0
	for tile in mapData.keys():
		if tile.y > highestY:
			highestY = tile.y
		if tile.x > highestX:
			highestX = tile.x
			
	highestYValue = highestY
	highestXValue = highestX
	
func initMap():
	getHighestMapValues()
	astar = AStar2D.new()
	#Add terrain tiles to map
	for tile in mapData.keys():
		var idx = getAStarCellId(tile)
		astar.add_point(idx, tile, mapData[tile].movementCost)
	#Assign tile neighbors
	for tile in mapData.keys():
		var idx = getAStarCellId(tile)
		
		for neighbor in getNeighbors(tile):
			var nIdx = getAStarCellId(neighbor)
			if (astar.has_point(nIdx)):
				astar.connect_points(idx, nIdx, false)
	
func getPath(from:Vector2i, to:Vector2i, allowPartial:bool):
	var endSpaceHasEnemy = false
	if (mapData.has(to) and mapData[to].unit != null and mapData[to].unit.faction != mapData[from].unit.faction):
		endSpaceHasEnemy = true
		setCellOccupied(to, false)
	var path = astar.get_point_path(getAStarCellId(from), getAStarCellId(to), allowPartial)
	var integerPath = []
	for cell in path:
		integerPath.push_back(Vector2i(int(cell.x), int(cell.y)))
	if (endSpaceHasEnemy):
		setCellOccupied(to, true)
	return integerPath.slice(1) #remove the first tile as we don't want to use it in movement
	
func getAStarCellId(cell:Vector2i)->int:
	var x_shifted = cell.x + 10000
	var y_shifted = cell.y + 10000
	return (x_shifted + y_shifted) * (x_shifted + y_shifted + 1) / 2 + y_shifted

func setCellOccupied(cell:Vector2i, occupied:bool)->void:
	var idx = getAStarCellId(cell)
	if (astar.has_point(idx)):
		astar.set_point_disabled(idx, occupied)

// Draws the whole map as flat-top (odd-q) hexes, coloured by tile owner.
// Each tile's palette index lives in owner_tex as two bytes (R = low, G = high),
// stored linearly and wrapped at tex_width texels per row.
shader_type canvas_item;

uniform sampler2D owner_tex : filter_nearest;
uniform sampler2D palette_tex : filter_nearest;
uniform int tex_width = 1;
uniform ivec2 map_min;      // lowest col, row in the map
uniform ivec2 map_size;     // number of cols, rows
uniform vec2 tile_size = vec2(74.0, 64.0);
uniform vec2 world_min;     // map bounds in tile-space pixels
uniform vec2 world_size = vec2(1.0);
uniform vec2 rect_size = vec2(1.0); // size of the TextureRect, for aspect-correct fitting

void fragment() {
	// Fit the map inside the rect, centered, keeping aspect ratio
	float scale = min(rect_size.x / world_size.x, rect_size.y / world_size.y);
	vec2 offset = (rect_size - world_size * scale) * 0.5;
	vec2 world = (UV * rect_size - offset) / scale + world_min;

	if (any(lessThan(world, world_min)) || any(greaterThan(world, world_min + world_size))) {
		COLOR = vec4(0.0);
	} else {
		// Column centers are 3/4 of a tile apart, odd columns are shifted down half a tile.
		// The point is in whichever of the two nearest columns' hexes has the closest center.
		// Y is scaled so the hexes are regular, which makes "closest center" exact.
		float colSpacing = tile_size.x * 0.75;
		float yScale = (tile_size.x * 0.8660254) / tile_size.y;
		int firstCol = int(floor(world.x / colSpacing));
		ivec2 cell = ivec2(0);
		float bestDist = 1e30;
		for (int i = 0; i < 2; i++) {
			int col = firstCol + i;
			float colOffset = float(col & 1) * tile_size.y * 0.5;
			int row = int(round((world.y - colOffset) / tile_size.y));
			vec2 d = world - vec2(float(col) * colSpacing, float(row) * tile_size.y + colOffset);
			d.y *= yScale;
			float dist = dot(d, d);
			if (dist < bestDist) {
				bestDist = dist;
				cell = ivec2(col, row);
			}
		}

		ivec2 local = cell - map_min;
		int paletteIndex = 0; // no tile
		if (all(greaterThanEqual(local, ivec2(0))) && all(lessThan(local, map_size))) {
			int i = local.y * map_size.x + local.x;
			vec2 rg = texelFetch(owner_tex, ivec2(i % tex_width, i / tex_width), 0).rg;
			paletteIndex = int(round(rg.r * 255.0)) + int(round(rg.g * 255.0)) * 256;
		}
		COLOR = texelFetch(palette_tex, ivec2(paletteIndex, 0), 0);
	}
}

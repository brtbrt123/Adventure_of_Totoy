shader_type canvas_item;
// Turns everything drawn before this node into game-resolution pixel art: each 320x180 "game pixel" averages the
// window pixels under it, then snaps to the nearest colour of the Totoy 36 palette (reserved gold and red excluded).
// Used on the title screen so the painting, the logo and the lettering share the game's pixel look.
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest, repeat_disable;
uniform vec3 palette[36];
uniform int palette_size = 32;
uniform vec2 grid = vec2(320.0, 180.0);

float distance_weighted(vec3 a, vec3 b) {
	float rm = (a.r + b.r) * 0.5;
	vec3 d = a - b;
	return (2.0 + rm) * d.r * d.r + 4.0 * d.g * d.g + (3.0 - rm) * d.b * d.b;
}

void fragment() {
	vec2 screen_size = vec2(textureSize(screen_tex, 0));
	vec2 cell = floor(SCREEN_UV * grid);
	vec2 origin = cell / grid;
	vec2 span = 1.0 / grid;
	vec3 sum = vec3(0.0);
	for (int y = 0; y < 4; y++) {
		for (int x = 0; x < 4; x++) {
			vec2 uv = origin + (vec2(float(x), float(y)) + 0.5) * 0.25 * span;
			sum += textureLod(screen_tex, uv, 0.0).rgb;
		}
	}
	vec3 c = sum / 16.0;
	vec3 best = palette[0];
	float best_d = 1e9;
	for (int i = 0; i < 36; i++) {
		if (i >= palette_size) {
			break;
		}
		float d = distance_weighted(c, palette[i]);
		if (d < best_d) {
			best_d = d;
			best = palette[i];
		}
	}
	COLOR = vec4(best, 1.0);
}

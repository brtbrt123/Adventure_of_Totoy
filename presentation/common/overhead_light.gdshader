shader_type canvas_item;
render_mode unshaded;

uniform vec2 world_size = vec2(571.0, 336.0);
uniform vec3 light_colour = vec3(0.64, 0.77, 1.0);
uniform float shaft_slope = 1.2;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform int lamp_count = 0;
uniform vec4 lamps[32];
uniform vec3 lamp_colour = vec3(1.0, 0.79, 0.52);
uniform float emissive_pass_alpha = 0.99;
uniform float prop_shadow_alpha = 0.30;
uniform float actor_shadow_alpha = 0.20;
uniform bool mixed_lights = false;
uniform vec3 lamp_colours[32];
uniform vec3 lamp_core_colours[32];
uniform vec3 lamp_core_colour = vec3(1.05, 0.98, 0.88);
varying vec2 world_position;
varying vec4 draw_colour;

float hash_point(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float canopy_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash_point(cell), hash_point(cell + vec2(1, 0)), f.x),
		mix(hash_point(cell + vec2(0, 1)), hash_point(cell + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	draw_colour = COLOR;
}

void fragment() {
	// Sprite sampling stays nearest and its alpha stays unchanged. Only the
	// silhouette-shadow pass receives a soft penumbra inside its transparent guard.
	vec2 p = floor(world_position);
	float across = (p.x - shaft_slope * p.y) / max(world_size.x, 1.0);
	float shaft_a = 1.0 - smoothstep(0.035, 0.16, abs(across - 0.12));
	float shaft_b = 1.0 - smoothstep(0.025, 0.13, abs(across - 0.55));
	float shafts = max(shaft_a, shaft_b);
	float above = clamp(1.0 - p.y / max(world_size.y, 1.0), 0.0, 1.0);
	float leaves = canopy_noise(p / 46.0) * 0.55
		+ canopy_noise(p / 18.0 + vec2(7, 3)) * 0.30
		+ canopy_noise(p / 7.0 + vec2(3, 11)) * 0.15;
	float moonlight = smoothstep(0.28, 0.72, leaves + shafts * 0.10);
	float warm_pool = 0.0;
	float warm_halo = 0.0;
	float fixture_core = 0.0;
	vec3 pool_rgb = vec3(0.0);
	vec3 halo_rgb = vec3(0.0);
	vec3 core_rgb = vec3(0.0);
	for (int i = 0; i < 32; i++) {
		if (i >= lamp_count) { break; }
		vec4 lamp = lamps[i];
		vec2 delta = p - lamp.xy;
		bool floor_pool = lamp.w < 0.0;
		if (floor_pool) { delta.y *= 1.7; }
		float distance_to_light = length(delta);
		float falloff = 1.0 - smoothstep(0.0, lamp.z, distance_to_light);
		if (floor_pool) {
			warm_pool += falloff * falloff * abs(lamp.w);
			pool_rgb += lamp_colours[i] * falloff * falloff * abs(lamp.w);
		} else {
			warm_halo += falloff * falloff * lamp.w;
			halo_rgb += lamp_colours[i] * falloff * falloff * lamp.w;
			core_rgb += lamp_core_colours[i] * (1.0 - smoothstep(0.0, 7.0, distance_to_light)) * lamp.w;
			fixture_core += (1.0 - smoothstep(0.0, 7.0, distance_to_light)) * lamp.w;
		}
	}
	bool shadow_pass = max(draw_colour.r, max(draw_colour.g, draw_colour.b)) < 0.001
		&& (abs(draw_colour.a - prop_shadow_alpha) < 0.0001 || abs(draw_colour.a - actor_shadow_alpha) < 0.0001);
	if (abs(draw_colour.a - emissive_pass_alpha) < 0.0001) {
		COLOR = vec4(texture(TEXTURE, UV).rgb * draw_colour.rgb, texture(TEXTURE, UV).a);
	} else if (shadow_pass) {
		float radius = abs(draw_colour.a - prop_shadow_alpha) < 0.0001 ? 2.0 : 0.65;
		vec2 step_uv = TEXTURE_PIXEL_SIZE * radius;
		float mask = texture(TEXTURE, UV).a * 0.28;
		mask += (texture(TEXTURE, UV + vec2(step_uv.x, 0)).a + texture(TEXTURE, UV - vec2(step_uv.x, 0)).a
			+ texture(TEXTURE, UV + vec2(0, step_uv.y)).a + texture(TEXTURE, UV - vec2(0, step_uv.y)).a) * 0.12;
		mask += (texture(TEXTURE, UV + step_uv).a + texture(TEXTURE, UV - step_uv).a
			+ texture(TEXTURE, UV + vec2(step_uv.x, -step_uv.y)).a
			+ texture(TEXTURE, UV + vec2(-step_uv.x, step_uv.y)).a) * 0.06;
		COLOR = vec4(0.035, 0.055, 0.10, mask * draw_colour.a * mix(0.40, 0.65, moonlight));
	} else {
		vec4 base = texture(TEXTURE, UV) * draw_colour;
		float exposure = mix(1.0, 0.48 + moonlight * 0.20 + shafts * 0.07 + above * 0.03, strength);
		vec3 lit = base.rgb * exposure * mix(vec3(1.0), light_colour, strength);
		float warmth = min(1.8, warm_pool * 0.95 + warm_halo * 0.75);
		if (mixed_lights) {
			lit += base.rgb * min(vec3(1.8), pool_rgb * 0.95 + halo_rgb * 0.75) * 0.65;
			lit += min(vec3(0.075), halo_rgb * 0.035);
		} else {
			lit += base.rgb * lamp_colour * warmth * 0.65;
			lit += lamp_colour * min(0.075, warm_halo * 0.035);
		}
		// The painted cream lamp/window/fire cores stay luminous at night.
		float bright_paint = smoothstep(0.55, 0.88, max(base.r, max(base.g, base.b)));
		vec3 fixture_colour = mixed_lights ? core_rgb / max(fixture_core, 0.001) : lamp_core_colour;
		lit = mix(lit, base.rgb * fixture_colour, clamp(fixture_core * bright_paint, 0.0, 0.9));
		COLOR = vec4(clamp(lit, vec3(0.0), vec3(1.0)), base.a);
	}
}

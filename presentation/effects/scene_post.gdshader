// The explore scenes' screen look (owner 2026-11-01): glow on bright things, a colour grade and a vignette, over the world and under
// the HUD (a CanvasLayer between them, presentation/explore/explore_scene.gd). Values come from the scene's look
// (presentation/effects/scene_look.gd, presentation/effects/looks/<scene>.tres).
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float pixel_scale = 3.0; // screen pixels per game pixel

uniform bool grade_enabled = true;
uniform float exposure = 1.0;
uniform float contrast = 1.0;
uniform float saturation = 1.0;
uniform vec3 shadow_tint = vec3(1.0);
uniform vec3 highlight_tint = vec3(1.0);

uniform bool vignette_enabled = true;
uniform float vignette_strength = 0.4;
uniform float vignette_radius = 0.95;
uniform float vignette_softness = 0.6;
uniform vec3 vignette_colour = vec3(0.03, 0.03, 0.07);

uniform bool glow_enabled = true;
uniform float glow_strength = 0.55;
uniform float glow_threshold = 0.62;
uniform float glow_radius = 5.0; // game px
uniform vec3 glow_tint = vec3(1.0);

float brightness(vec3 c) {
	return max(c.r, max(c.g, c.b));
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 c = texture(screen_tex, uv).rgb;
	if (glow_enabled && glow_strength > 0.0) {
		// light spilled by the bright pixels around: three rings of eight taps, nearer rings weigh more
		vec3 spill = vec3(0.0);
		float total = 0.0;
		for (int ring = 1; ring <= 3; ring++) {
			float reach = glow_radius * pixel_scale * float(ring) / 3.0;
			float weight = 1.0 / float(ring);
			for (int k = 0; k < 8; k++) {
				float angle = float(k) * 0.7853982 + float(ring) * 0.39;
				vec3 s = texture(screen_tex, uv + vec2(cos(angle), sin(angle)) * reach * SCREEN_PIXEL_SIZE).rgb;
				spill += s * smoothstep(glow_threshold, glow_threshold + 0.22, brightness(s)) * weight;
				total += weight;
			}
		}
		c += spill / total * glow_strength * glow_tint;
	}
	if (grade_enabled) {
		c *= exposure;
		float luma = dot(c, vec3(0.299, 0.587, 0.114));
		c = mix(vec3(luma), c, saturation);
		c = (c - 0.5) * contrast + 0.5;
		c *= mix(shadow_tint, highlight_tint, smoothstep(0.05, 0.85, luma));
	}
	if (vignette_enabled) {
		vec2 d = uv - 0.5; // follows the screen's shape: the edges darken evenly, the corners most
		float edge = smoothstep(vignette_radius - vignette_softness, vignette_radius, length(d) * 1.414);
		c = mix(c, vignette_colour, edge * vignette_strength);
	}
	COLOR = vec4(clamp(c, vec3(0.0), vec3(1.0)), 1.0);
}

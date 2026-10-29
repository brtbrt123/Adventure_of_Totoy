shader_type canvas_item;
render_mode unshaded, blend_add;

varying vec4 ink;

void vertex() {
	ink = COLOR;
}

void fragment() {
	float centre = texture(TEXTURE, UV).a;
	if (ink.a > 0.9) {
		// Tiny particle cores keep square pixels. The faint larger pass behind them provides the halo.
		COLOR = vec4(ink.rgb, centre * 0.85);
	} else {
		vec2 p = TEXTURE_PIXEL_SIZE;
		float near_mask = 0.0;
		float far_mask = 0.0;
		for (int x = -1; x <= 1; x++) {
			for (int y = -1; y <= 1; y++) {
				vec2 step_uv = vec2(float(x), float(y)) * p;
				near_mask += texture(TEXTURE, clamp(UV + step_uv * 2.0, vec2(0.0), vec2(1.0))).a / 9.0;
				far_mask += texture(TEXTURE, clamp(UV + step_uv * 4.0, vec2(0.0), vec2(1.0))).a / 9.0;
			}
		}
		float halo = (near_mask * 0.7 + far_mask * 0.45) * (1.0 - centre * 0.6);
		COLOR = vec4(ink.rgb, halo * ink.a);
	}
}

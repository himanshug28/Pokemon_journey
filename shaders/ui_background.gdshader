shader_type canvas_item;
render_mode unshaded;

uniform vec3 top_color : source_color = vec3(0.035, 0.08, 0.22);
uniform vec3 bottom_color : source_color = vec3(0.01, 0.02, 0.07);
uniform vec3 accent_a : source_color = vec3(0.10, 0.72, 0.95);
uniform vec3 accent_b : source_color = vec3(1.0, 0.48, 0.18);
uniform vec3 accent_c : source_color = vec3(0.62, 0.35, 1.0);
uniform float speed = 0.10;
uniform float glow_strength = 0.55;
uniform float star_strength = 0.65;
uniform float vignette_strength = 0.7;
uniform float ray_strength = 0.06;
uniform float wave_strength = 0.20;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec2 uv = UV;
	float t = TIME * speed;
	vec3 col = mix(bottom_color, top_color, smoothstep(0.0, 1.0, uv.y));

	// Slow aurora ribbons.
	float n = noise(uv * vec2(3.2, 2.0) + vec2(t * 0.9, -t * 0.35));
	float ribbon = smoothstep(0.58, 0.95, sin((uv.x * 2.2 + uv.y * 1.1 + n * 1.4 + t) * 3.14159) * 0.5 + 0.5);
	col += accent_a * ribbon * glow_strength * 0.20;
	col += accent_c * (1.0 - smoothstep(0.0, 0.7, uv.y)) * wave_strength * 0.13;

	// Warm bloom behind the title area.
	float bloom = smoothstep(0.9, 0.0, distance(uv, vec2(0.22 + sin(t * 0.4) * 0.03, 0.70)));
	col += accent_b * bloom * glow_strength * 0.20;
	float bloom2 = smoothstep(0.8, 0.0, distance(uv, vec2(0.84, 0.35 + cos(t * 0.33) * 0.04)));
	col += accent_c * bloom2 * glow_strength * 0.13;

	// Subtle diagonal light rays.
	float ray = fract((uv.x * 0.7 + uv.y * 1.3) * 6.0 + t * 0.12);
	ray = smoothstep(0.02, 0.0, abs(ray - 0.5) - 0.47);
	col += vec3(0.7, 0.85, 1.0) * ray * ray_strength;

	// Star field with twinkle.
	vec2 grid = uv * vec2(120.0, 68.0);
	vec2 id = floor(grid);
	vec2 local = fract(grid) - 0.5;
	float rnd = hash21(id);
	float star = step(0.985, rnd) * smoothstep(0.55, 0.0, length(local));
	float twinkle = 0.45 + 0.55 * sin(TIME * 2.4 + rnd * 38.0);
	col += vec3(0.82, 0.92, 1.0) * star * twinkle * star_strength;

	// Giant, very faint Poké Ball rings for theme.
	vec2 p = (uv - vec2(0.5, 0.48)) * vec2(1.777, 1.0);
	float r = length(p);
	float ring1 = smoothstep(0.012, 0.0, abs(r - 0.52));
	float ring2 = smoothstep(0.007, 0.0, abs(r - 0.60));
	col += vec3(1.0) * (ring1 + ring2 * 0.6) * 0.028;

	// Vignette and a gentle bottom shadow for UI readability.
	float vig = smoothstep(1.15, 0.25, distance(uv, vec2(0.5)));
	col *= mix(1.0 - vignette_strength * 0.55, 1.0, vig);
	col *= mix(0.82, 1.0, smoothstep(0.0, 0.22, uv.y));
	COLOR = vec4(col, 1.0);
}

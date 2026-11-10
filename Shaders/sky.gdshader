shader_type sky;
// Procedural gradient sky with a real sun disk + glow driven by the scene's
// DirectionalLight3D (LIGHT0_* is populated automatically by Godot each
// frame from whichever DirectionalLight3D has sky contribution enabled).
//
// Sign convention verified empirically in-engine: LIGHT0_DIRECTION already
// points FROM the scene TOWARD the light (not the direction it travels), so
// dot(EYEDIR, LIGHT0_DIRECTION) needs no negation to place the sun glow at
// the correct spot in the dome.

uniform vec3 skyColor : source_color = vec3(0.3, 0.55, 0.95);
uniform vec3 horizonColor : source_color = vec3(0.75, 0.82, 0.9);
uniform vec3 groundColor : source_color = vec3(0.25, 0.24, 0.22);
// NOTE: these thresholds live in dot-product space, not degrees, and that
// space is extremely non-linear near 1.0 -- verified in-engine that the
// first value tried here (0.009) produced a ~15 degree *diameter* solid
// disk (1 - cos(theta) for a small angle theta in radians), which blew
// the sky out to flat white over a third of the screen once tonemapped.
// 0.0008 is close to a real sun's apparent size (~0.5 degree) nudged up
// slightly for visibility as a small, crisp highlight instead.
uniform float sun_disk_size : hint_range(0.0001, 0.01) = 0.0008;
uniform float sun_glow_intensity : hint_range(0.0, 10.0) = 0.9;
uniform float sun_glow_falloff : hint_range(1.0, 1024.0) = 400.0;

void sky() {
	float up = EYEDIR.y;

	// Smooth gradient from the horizon haze band up to the zenith (replaces
	// the previous hard clamp(.., 0.7, 0.9) which left most of the dome a
	// near-flat single color).
	vec3 sky_col;
	if (up >= 0.0) {
		float t = pow(1.0 - clamp(up / 0.16, 0.0, 1.0), 1.1);
		sky_col = mix(skyColor, horizonColor, t);
	} else {
		// Peeking below the horizon line (steep camera angles): fade into a
		// muted ground tone instead of repeating the sky color upside down.
		float t = clamp(-up / 0.25, 0.0, 1.0);
		sky_col = mix(horizonColor, groundColor, t);
	}

	// Sun disk + soft glow/haze, using the real light direction/color so it
	// always matches wherever sun_basis_degrees points each map.
	if (LIGHT0_ENABLED) {
		vec3 light_dir = normalize(LIGHT0_DIRECTION);
		vec3 light_col = LIGHT0_COLOR * LIGHT0_ENERGY;
		float sun_amount = clamp(dot(EYEDIR, light_dir), 0.0, 1.0);

		float disk = smoothstep(1.0 - sun_disk_size, 1.0 - sun_disk_size * 0.35, sun_amount);
		float glow = pow(sun_amount, sun_glow_falloff) * sun_glow_intensity;

		sky_col += light_col * glow;
		sky_col = mix(sky_col, light_col * 1.4, disk);
	}

	COLOR = sky_col;
}

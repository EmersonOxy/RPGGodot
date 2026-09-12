shader_type spatial;
render_mode depth_prepass_alpha;

// Máscara local de oclusão: abre uma "janela" suave ao redor do Player
// somente na geometria que está ENTRE a câmera e ele (paredes, elevações,
// caixas). O script ativa uma instância própria somente no objeto detectado.
// Fora da oclusão, restaura um material opaco nativo.
uniform vec4 albedo_color : source_color = vec4(0.65, 0.69, 0.66, 1.0);
uniform float roughness : hint_range(0.0, 1.0) = 1.0;
uniform vec3 player_position = vec3(0.0, 0.0, 0.0);
uniform float inner_radius = 1.2;
uniform float outer_radius = 2.2;
uniform float min_alpha : hint_range(0.0, 1.0) = 0.25;
uniform float occlusion_strength : hint_range(0.0, 1.0) = 0.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	ALBEDO = albedo_color.rgb;
	ROUGHNESS = roughness;
	vec3 cam = CAMERA_POSITION_WORLD;
	vec3 center = player_position + vec3(0.0, 0.9, 0.0);
	vec3 to_player = center - cam;
	vec3 axis = normalize(to_player);
	if (PROJECTION_MATRIX[3][3] > 0.5) {
		axis = normalize(-INV_VIEW_MATRIX[2].xyz);
	}
	float dist = max(dot(to_player, axis), 0.001);
	vec3 rel = world_pos - center;
	float t = dot(rel, axis);
	float d = length(rel - axis * t);
	float window = 1.0 - smoothstep(inner_radius, outer_radius, d);
	float between = step(-dist, t) * (1.0 - step(-0.05, t));
	// Preserva o piso na altura dos pés. Uma plataforma ACIMA do Player
	// pode abrir o recorte quando realmente estiver encobrindo seu corpo.
	float above_floor = smoothstep(player_position.y + 0.05, player_position.y + 0.25, world_pos.y);
	ALPHA = mix(1.0, min_alpha, window * between * above_floor * occlusion_strength);
}

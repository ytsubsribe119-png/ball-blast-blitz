extends Node2D

enum State { MENU, PLAYING, BOSS_FIGHT, STAGE_CLEAR, GAME_OVER }
var current_state: State = State.MENU

# Menu Selections & Progression (20 Stages & Background Selector)
var selected_cannon: int = 0
var selected_stage: int = 0
var selected_theme: int = 0  # <--- Added background selection (0-4)
var unlocked_stages: int = 20

var cannon_names: Array = ["STANDARD", "TRIPLE SPREAD", "LASER ARRAY", "PLASMA BLAST"]
var theme_names: Array = ["MEADOW", "DESERT", "SNOWY", "RAINY", "VOLCANIC"]

# 20 Unique Monster Names
var boss_names: Array = [
	"GIGA GOLEM", "SAND BEHEMOTH", "ICE TITAN", "STORM HYDRA", "VOLCANO DRAGON",
	"FOREST ANCIENT", "DUST SERPENT", "FROST SPECTRE", "THUNDER LEVIATHAN", "MAGMA DEMON",
	"SHADOW WEAVER", "DUNE RAIDER", "BLIZZARD PHANTOM", "TEMPEST ARCHON", "INFERNO KING",
	"SUN GOD RA", "CRYSTAL GOLEM", "VOID WALKER", "CYCLONE WARLORD", "OMEGA TITAN"
]

# Weapon Types & Levels
enum WeaponType { SINGLE, TRIPLE, LASER, PLASMA, WAVE }
var current_weapon: WeaponType = WeaponType.SINGLE
var weapon_level: int = 1
var is_weapon_locked: bool = false

# Audio Streams
var sfx_laser: AudioStream = preload("res://Bonus/sfx_laser1.ogg") if ResourceLoader.exists("res://Bonus/sfx_laser1.ogg") else null
var sfx_lose: AudioStream = preload("res://Bonus/sfx_lose.ogg") if ResourceLoader.exists("res://Bonus/sfx_lose.ogg") else null
var sfx_shield_down: AudioStream = preload("res://Bonus/sfx_shieldDown.ogg") if ResourceLoader.exists("res://Bonus/sfx_shieldDown.ogg") else null
var sfx_shield_up: AudioStream = preload("res://Bonus/sfx_shieldUp.ogg") if ResourceLoader.exists("res://Bonus/sfx_shieldUp.ogg") else null
var sfx_two_tone: AudioStream = preload("res://Bonus/sfx_twoTone.ogg") if ResourceLoader.exists("res://Bonus/sfx_twoTone.ogg") else null
var sfx_zap: AudioStream = preload("res://Bonus/sfx_zap.ogg") if ResourceLoader.exists("res://Bonus/sfx_zap.ogg") else null

var custom_font: FontFile

# Cannon Controls
var cannon_x: float = 0.0
var wheel_rotation: float = 0.0
var recoil_y: float = 0.0
var barrel_scale: Vector2 = Vector2.ONE
var shoot_timer: float = 0.0
var muzzle_flash_timer: float = 0.0

# Player Health
var lives: int = 3
var respawn_invuln_timer: float = 0.0

# Arrays
var bullets: Array = []
var balls: Array = []
var powerups: Array = []
var weather_particles: Array = []
var clouds: Array = []
var boss_projectiles: Array = []

# Game Timing & Progress
var score: int = 0
var shield_timer: float = 0.0
var max_shield_time: float = 8.0
var stage_timer: float = 0.0
var target_stage_duration: float = 180.0
var ball_spawn_timer: float = 0.0
var boss_warning_timer: float = 0.0
var warning_active: bool = false

# Twister visual variables
var twister_angle: float = 0.0

# Boss Stats
var boss_active: bool = false
var boss_hp: float = 100.0
var boss_max_hp: float = 100.0
var boss_pos: Vector2 = Vector2.ZERO
var boss_vel: Vector2 = Vector2.ZERO
var boss_radius: float = 65.0
var boss_anim_time: float = 0.0
var boss_attack_timer: float = 0.0

func _ready() -> void:
	if ResourceLoader.exists("res://Bonus/kenvector_future.ttf"):
		custom_font = load("res://Bonus/kenvector_future.ttf")

	var screen_size = get_viewport_rect().size
	cannon_x = screen_size.x / 2.0
	_init_clouds(screen_size)
	_init_weather_particles(screen_size)

func _init_clouds(screen: Vector2) -> void:
	clouds.clear()
	# Generate realistic volumetric cloud puffs with varied offsets & opacities
	for i in range(5):
		var puff_list: Array = []
		for p in range(7):
			puff_list.append({
				"offset": Vector2(randf_range(-35.0, 35.0), randf_range(-12.0, 12.0)),
				"radius": randf_range(22.0, 38.0)
			})
		clouds.append({
			"pos": Vector2(randf_range(0, screen.x), randf_range(25, 120)),
			"speed": randf_range(10.0, 25.0),
			"puffs": puff_list,
			"alpha": randf_range(0.6, 0.85)
		})

func _init_weather_particles(screen: Vector2) -> void:
	weather_particles.clear()
	for i in range(70):
		weather_particles.append({
			"pos": Vector2(randf_range(0, screen.x), randf_range(0, screen.y)),
			"vel": Vector2.ZERO,
			"size": randf_range(2.0, 6.0),
			"alpha": randf_range(0.3, 0.9)
		})

func play_sfx(stream: AudioStream, pitch_var: float = 0.1) -> void:
	if not stream: return
	var player = AudioStreamPlayer.new()
	player.stream = stream
	player.pitch_scale = randf_range(1.0 - pitch_var, 1.0 + pitch_var)
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)

func start_game() -> void:
	current_state = State.PLAYING
	score = 0
	lives = 3
	stage_timer = 0.0
	ball_spawn_timer = 0.0
	boss_active = false
	warning_active = false
	boss_warning_timer = 0.0
	is_weapon_locked = false
	balls.clear()
	bullets.clear()
	powerups.clear()
	boss_projectiles.clear()
	shield_timer = 0.0
	respawn_invuln_timer = 0.0
	
	current_weapon = selected_cannon as WeaponType
	weapon_level = 1
	
	play_sfx(sfx_shield_up)
	var screen = get_viewport_rect().size
	
	var initial_hp = 8 + (selected_stage * 3)
	spawn_ball(screen, initial_hp, Vector2(screen.x / 2.0, 100), Vector2(100, -50))

func spawn_ball(screen: Vector2, hp_val: int, pos: Vector2, vel: Vector2) -> void:
	if balls.size() >= 8: return

	var radius_size = clamp(24.0 + (hp_val * 0.35), 28.0, 56.0)
	var is_stone = randf() > 0.5
	
	var crater_list: Array = []
	if is_stone:
		for c in range(randi_range(3, 5)):
			crater_list.append({
				"offset": Vector2(randf_range(-radius_size * 0.5, radius_size * 0.5), randf_range(-radius_size * 0.5, radius_size * 0.5)),
				"size": randf_range(radius_size * 0.15, radius_size * 0.3)
			})

	balls.append({
		"pos": pos,
		"vel": vel,
		"radius": radius_size,
		"hp": hp_val,
		"is_stone": is_stone,
		"craters": crater_list,
		"rot": randf_range(0, TAU),
		"color": Color(0.48, 0.48, 0.52) if is_stone else Color.from_hsv(randf(), 0.85, 0.95)
	})

func trigger_boss_prep_sequence(screen: Vector2) -> void:
	warning_active = true
	boss_warning_timer = 3.0
	
	# Spawn guaranteed fire & shield drops so player can prepare
	for i in range(5):
		powerups.append({
			"pos": Vector2(screen.x * (0.2 + (i * 0.15)), 120),
			"vel": Vector2(0, 180),
			"grounded": false,
			"timer": 7.0,
			"alpha": 1.0,
			"w_type": i % 5,
			"is_life": false,
			"is_shield": (i == 2), # Center powerup is guaranteed shield
			"label": "SHIELD" if (i == 2) else ["TRIPLE", "LASER", "PLASMA", "WAVE", "STANDARD"][i % 5]
		})

func spawn_boss(screen: Vector2) -> void:
	boss_active = true
	current_state = State.BOSS_FIGHT
	boss_max_hp = 300 + (selected_stage * 150)
	boss_hp = boss_max_hp
	boss_pos = Vector2(screen.x / 2.0, 120)
	boss_vel = Vector2(140 + (selected_stage * 15), 0)
	boss_attack_timer = 0.0

func spawn_powerup(pos: Vector2) -> void:
	if randf() < 0.70:
		var is_life = randf() < 0.18
		var is_shield = randf() < 0.28 and not is_life
		var w_type = randi() % 5
		
		powerups.append({
			"pos": pos,
			"vel": Vector2(0, 220),
			"grounded": false,
			"timer": 5.0,
			"alpha": 1.0,
			"w_type": w_type,
			"is_life": is_life,
			"is_shield": is_shield,
			"label": "LIFE +" if is_life else ("SHIELD" if is_shield else ["TRIPLE", "LASER", "PLASMA", "WAVE", "STANDARD"][w_type])
		})

func _input(event: InputEvent) -> void:
	var screen = get_viewport_rect().size

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pos = event.position

		# Lock Button
		if current_state == State.PLAYING or current_state == State.BOSS_FIGHT:
			var lock_btn_rect = Rect2(screen.x - 125, 10, 115, 38)
			if lock_btn_rect.has_point(pos):
				is_weapon_locked = !is_weapon_locked
				play_sfx(sfx_two_tone)
				return

		if current_state == State.MENU:
			# Cannon Selection Buttons
			for i in range(4):
				var btn_rect = Rect2(screen.x * 0.05 + (i * (screen.x * 0.23 + 4)), 150, screen.x * 0.22, 36)
				if btn_rect.has_point(pos):
					selected_cannon = i
					play_sfx(sfx_two_tone)

			# Background Theme Selection Buttons (New UI)
			for i in range(5):
				var btn_rect = Rect2(screen.x * 0.03 + (i * (screen.x * 0.18 + 4)), 220, screen.x * 0.18, 34)
				if btn_rect.has_point(pos):
					selected_theme = i
					play_sfx(sfx_two_tone)

			# Stage Grid Selection (20 Stages: 4 rows x 5 columns)
			for i in range(20):
				var col = i % 5
				var row = i / 5
				var btn_rect = Rect2(screen.x * 0.03 + (col * (screen.x * 0.18 + 4)), 290 + (row * 38), screen.x * 0.18, 32)
				if btn_rect.has_point(pos) and i < unlocked_stages:
					selected_stage = i
					play_sfx(sfx_two_tone)

			# Start Game
			var start_rect = Rect2(screen.x / 2 - 110, 470, 220, 48)
			if start_rect.has_point(pos):
				start_game()

		elif current_state == State.STAGE_CLEAR or current_state == State.GAME_OVER:
			var btn_rect = Rect2(screen.x / 2 - 110, screen.y / 2 + 70, 220, 55)
			if btn_rect.has_point(pos):
				if current_state == State.STAGE_CLEAR:
					if selected_stage < 19:
						selected_stage += 1
						start_game()
					else:
						current_state = State.MENU
				else:
					start_game()

func _process(delta: float) -> void:
	var screen = get_viewport_rect().size
	var ground_y = screen.y - 80.0
	
	twister_angle += delta * 4.0

	_update_clouds(delta, screen)
	_update_weather_particles(delta, screen)

	if current_state == State.PLAYING or current_state == State.BOSS_FIGHT:
		if shield_timer > 0: shield_timer -= delta
		if respawn_invuln_timer > 0: respawn_invuln_timer -= delta
		if muzzle_flash_timer > 0: muzzle_flash_timer -= delta

		# Cannon Controls
		var prev_x = cannon_x
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			var mouse_pos = get_global_mouse_position()
			if mouse_pos.y > 60:
				cannon_x = lerp(cannon_x, mouse_pos.x, delta * 22.0)
				cannon_x = clamp(cannon_x, 45.0, screen.x - 45.0)

		wheel_rotation += (cannon_x - prev_x) * 0.08
		recoil_y = lerp(recoil_y, 0.0, delta * 12.0)
		barrel_scale = lerp(barrel_scale, Vector2.ONE, delta * 10.0)

		# Weapon Firing
		shoot_timer += delta
		var base_rate = 0.12
		if current_weapon == WeaponType.LASER: base_rate = 0.06
		var effective_rate = base_rate * (1.0 - (weapon_level - 1) * 0.18)

		if shoot_timer >= effective_rate:
			shoot_timer = 0.0
			fire_weapon(ground_y)

		# Bullets Logic
		for i in range(bullets.size() - 1, -1, -1):
			var b = bullets[i]
			b.pos += b.vel * delta
			if b.has("wave") and b.wave: b.pos.x += sin(b.pos.y * 0.08) * b.wave_amp
			if b.pos.y < -30 or b.pos.x < -30 or b.pos.x > screen.x + 30: bullets.remove_at(i)

		# Progressive Ball Spawner & Mid-Stage Boss Triggering
		if current_state == State.PLAYING:
			stage_timer += delta
			ball_spawn_timer += delta
			
			var trigger_time = target_stage_duration * (0.5 if selected_stage >= 4 else 1.0)

			# Warning Before Boss Spawns
			if stage_timer >= trigger_time - 3.0 and not warning_active and not boss_active:
				trigger_boss_prep_sequence(screen)

			if warning_active:
				boss_warning_timer -= delta
				if boss_warning_timer <= 0:
					warning_active = false
					balls.clear()
					spawn_boss(screen)

			var spawn_interval = max(3.8 - (selected_stage * 0.1), 2.0)
			if (ball_spawn_timer >= spawn_interval or balls.size() == 0) and balls.size() < 8 and not warning_active:
				ball_spawn_timer = 0.0
				var hp_val = randi_range(6 + int(stage_timer * 0.08), 14 + int(stage_timer * 0.12))
				var vx = randf_range(80, 140) * (-1 if randf() > 0.5 else 1)
				spawn_ball(screen, hp_val, Vector2(randf_range(80, screen.x - 80), 90), Vector2(vx, -40))

		# Power-up Ground Mechanics
		for i in range(powerups.size() - 1, -1, -1):
			var p = powerups[i]
			if not p.grounded:
				p.pos += p.vel * delta
				if p.pos.y >= ground_y - 12.0:
					p.pos.y = ground_y - 12.0
					p.grounded = true
			else:
				p.timer -= delta
				if p.timer <= 1.0: p.alpha = max(0.0, p.timer)
				if p.timer <= 0.0:
					powerups.remove_at(i)
					continue

			if p.pos.distance_to(Vector2(cannon_x, ground_y - 25)) < 48.0:
				play_sfx(sfx_shield_up)
				if p.is_life: lives += 1
				elif p.is_shield: shield_timer = max_shield_time
				else:
					if not is_weapon_locked:
						var picked = p.w_type as WeaponType
						if current_weapon == picked: weapon_level = min(weapon_level + 1, 3)
						else:
							current_weapon = picked
							weapon_level = 1

				powerups.remove_at(i)

		# Boss Monster Behavior
		if boss_active:
			boss_anim_time += delta * 3.0
			boss_pos += boss_vel * delta
			if boss_pos.x - boss_radius < 10 or boss_pos.x + boss_radius > screen.x - 10:
				boss_vel.x = -boss_vel.x

			boss_attack_timer += delta
			var attack_cooldown = max(2.2 - (selected_stage * 0.08), 0.8)
			if boss_attack_timer >= attack_cooldown:
				boss_attack_timer = 0.0
				_execute_boss_attack(screen, ground_y)

			var cannon_body_pos = Vector2(cannon_x, ground_y - 25)
			if boss_pos.distance_to(cannon_body_pos) < boss_radius + 28.0 and respawn_invuln_timer <= 0:
				_handle_player_hit()

			for j in range(bullets.size() - 1, -1, -1):
				if bullets[j].pos.distance_to(boss_pos) < boss_radius + bullets[j].radius:
					boss_hp -= bullets[j].dmg
					score += 20
					bullets.remove_at(j)
					play_sfx(sfx_zap, 0.2)

					if boss_hp <= 0:
						boss_active = false
						boss_projectiles.clear()
						score += 1500 + (selected_stage * 100)
						play_sfx(sfx_shield_down)
						if selected_stage + 1 >= unlocked_stages and unlocked_stages < 20:
							unlocked_stages = selected_stage + 2
						current_state = State.STAGE_CLEAR
						break

		# Boss Projectiles
		for i in range(boss_projectiles.size() - 1, -1, -1):
			var bp = boss_projectiles[i]
			bp.pos += bp.vel * delta
			if bp.pos.y > ground_y or bp.pos.x < 0 or bp.pos.x > screen.x:
				boss_projectiles.remove_at(i)
				continue

			var cannon_body_pos = Vector2(cannon_x, ground_y - 25)
			if bp.pos.distance_to(cannon_body_pos) < bp.radius + 20.0 and respawn_invuln_timer <= 0:
				_handle_player_hit()
				boss_projectiles.remove_at(i)

		# Ball Mechanics
		for i in range(balls.size() - 1, -1, -1):
			var b = balls[i]
			b.vel.y += 520.0 * delta
			b.pos += b.vel * delta

			if b.pos.x - b.radius < 0:
				b.pos.x = b.radius
				b.vel.x = abs(b.vel.x)
			elif b.pos.x + b.radius > screen.x:
				b.pos.x = screen.x - b.radius
				b.vel.x = -abs(b.vel.x)

			if b.pos.y + b.radius > ground_y:
				b.pos.y = ground_y - b.radius
				b.vel.y = -max(abs(b.vel.y) * 0.95, 380.0 + (b.radius * 2.5))

			var cannon_body_pos = Vector2(cannon_x, ground_y - 25)
			if b.pos.distance_to(cannon_body_pos) < b.radius + 28.0 and respawn_invuln_timer <= 0:
				_handle_player_hit()

			for j in range(bullets.size() - 1, -1, -1):
				if bullets[j].pos.distance_to(b.pos) < b.radius + bullets[j].radius:
					b.hp -= bullets[j].dmg
					score += 10
					bullets.remove_at(j)
					play_sfx(sfx_zap, 0.15)

					if b.hp <= 0:
						spawn_powerup(b.pos)
						if b.radius > 32.0 and balls.size() < 7:
							var next_hp = max(1, int(b.hp / 2.0))
							spawn_ball(screen, next_hp, b.pos + Vector2(-15, -10), Vector2(-120, -280))
							spawn_ball(screen, next_hp, b.pos + Vector2(15, -10), Vector2(120, -280))

						balls.remove_at(i)
						break

	queue_redraw()

func _execute_boss_attack(screen: Vector2, ground_y: float) -> void:
	var mode = selected_theme
	var speed_mult = 1.0 + (selected_stage * 0.05)

	if mode == 0: # Meadow / Golem attacks
		for i in range(3):
			boss_projectiles.append({"pos": Vector2(randf_range(50, screen.x - 50), 0), "vel": Vector2(0, 300 * speed_mult), "radius": 16.0, "color": Color.SADDLE_BROWN})
	elif mode == 1: # Desert / Sand attacks
		for a in [-0.4, -0.2, 0.0, 0.2, 0.4]:
			boss_projectiles.append({"pos": boss_pos, "vel": Vector2.DOWN.rotated(a) * 340 * speed_mult, "radius": 14.0, "color": Color.GOLD})
	elif mode == 2: # Ice attacks
		for i in range(4):
			boss_projectiles.append({"pos": Vector2(cannon_x + randf_range(-160, 160), -20), "vel": Vector2(0, 440 * speed_mult), "radius": 12.0, "color": Color.CYAN})
	elif mode == 3: # Storm / Hydra attacks
		var dir = (Vector2(cannon_x, ground_y - 20) - boss_pos).normalized()
		boss_projectiles.append({"pos": boss_pos, "vel": dir * 500 * speed_mult, "radius": 16.0, "color": Color.MAGENTA})
	elif mode == 4: # Magma attacks
		for a in [-0.5, -0.25, 0.0, 0.25, 0.5]:
			boss_projectiles.append({"pos": boss_pos, "vel": Vector2.DOWN.rotated(a) * 380 * speed_mult, "radius": 15.0, "color": Color.ORANGE_RED})

func _handle_player_hit() -> void:
	if shield_timer > 0:
		shield_timer = 0.0
		play_sfx(sfx_shield_down)
		return

	lives -= 1
	play_sfx(sfx_lose)

	if lives <= 0:
		current_state = State.GAME_OVER
	else:
		if not is_weapon_locked:
			current_weapon = WeaponType.SINGLE
			weapon_level = 1
		respawn_invuln_timer = 2.5

func fire_weapon(ground_y: float) -> void:
	recoil_y = 12.0
	barrel_scale = Vector2(1.22, 0.82)
	muzzle_flash_timer = 0.05
	play_sfx(sfx_laser, 0.08)

	var tip = Vector2(cannon_x, ground_y - 95.0 + recoil_y)

	if current_weapon == WeaponType.SINGLE:
		bullets.append({"pos": tip, "vel": Vector2(0, -1350.0), "dmg": weapon_level, "color": Color.GOLD, "radius": 7.0 + weapon_level})
	elif current_weapon == WeaponType.TRIPLE:
		var angles = [-0.15, 0.0, 0.15] if weapon_level == 1 else ([-0.28, 0.0, 0.28] if weapon_level == 2 else [-0.4, -0.2, 0.0, 0.2, 0.4])
		for a in angles: bullets.append({"pos": tip, "vel": Vector2.UP.rotated(a) * 1300.0, "dmg": weapon_level, "color": Color.LIME_GREEN, "radius": 6.0 + weapon_level})
	elif current_weapon == WeaponType.LASER:
		bullets.append({"pos": tip + Vector2(-10, 0), "vel": Vector2(0, -1700.0), "dmg": weapon_level, "color": Color.CYAN, "radius": 5.0 + weapon_level})
		bullets.append({"pos": tip + Vector2(10, 0), "vel": Vector2(0, -1700.0), "dmg": weapon_level, "color": Color.CYAN, "radius": 5.0 + weapon_level})
	elif current_weapon == WeaponType.PLASMA:
		bullets.append({"pos": tip, "vel": Vector2(0, -1000.0), "dmg": 2 * weapon_level, "color": Color.ORANGE, "radius": 12.0 + (weapon_level * 4.0)})
	elif current_weapon == WeaponType.WAVE:
		bullets.append({"pos": tip, "vel": Vector2(0, -1250.0), "dmg": weapon_level, "color": Color.MAGENTA, "radius": 8.0 + weapon_level, "wave": true, "wave_amp": 8.0 * weapon_level})

func _update_clouds(delta: float, screen: Vector2) -> void:
	for c in clouds:
		c.pos.x += c.speed * delta
		if c.pos.x > screen.x + 120: 
			c.pos.x = -120 
			c.pos.y = randf_range(25, 120)

func _update_weather_particles(delta: float, screen: Vector2) -> void:
	var theme = selected_theme
	for p in weather_particles:
		if theme == 0: # Meadow dust & leaves
			p.vel = Vector2(160, randf_range(-10, 20))
		elif theme == 1: # Desert Sandstorm
			p.vel = Vector2(-350, randf_range(-40, 40))
		elif theme == 2: # Snow Blizzard
			p.vel = Vector2(randf_range(-60, 60), 160)
		elif theme == 3: # Heavy Rain
			p.vel = Vector2(-120, 950)
		elif theme == 4: # Volcanic Embers
			p.vel = Vector2(randf_range(-50, 50), -160)
		
		p.pos += p.vel * delta
		if p.pos.y > screen.y or p.pos.x > screen.x or p.pos.x < 0 or p.pos.y < 0:
			p.pos = Vector2(randf_range(0, screen.x), screen.y if theme == 4 else 0)

func _draw() -> void:
	var screen = get_viewport_rect().size
	var ground_y = screen.y - 80.0
	var active_font = custom_font if custom_font else ThemeDB.fallback_font

	_draw_rich_background(screen, ground_y)
	_draw_weather_effects(screen, ground_y)

	if current_state == State.MENU:
		draw_rect(Rect2(0, 0, screen.x, screen.y), Color(0, 0, 0, 0.65))
		draw_string(active_font, Vector2(screen.x / 2 - 170, 60), "BALL BLAST BLITZ", HORIZONTAL_ALIGNMENT_CENTER, -1, 26, Color.GOLD)

		# 1. Weapon Selector
		draw_string(active_font, Vector2(screen.x / 2 - 100, 135), "1. CHOOSE WEAPON", HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color.WHITE)
		for i in range(4):
			var x_pos = screen.x * 0.05 + (i * (screen.x * 0.23 + 4))
			draw_rect(Rect2(x_pos, 150, screen.x * 0.22, 36), Color(0.2, 0.8, 0.4) if selected_cannon == i else Color(0.2, 0.2, 0.2))
			draw_string(active_font, Vector2(x_pos + 1, 172), cannon_names[i], HORIZONTAL_ALIGNMENT_CENTER, -1, 8, Color.WHITE)

		# 2. Background Theme Selector (Player Choice)
		draw_string(active_font, Vector2(screen.x / 2 - 100, 205), "2. CHOOSE BACKGROUND", HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color.WHITE)
		for i in range(5):
			var x_pos = screen.x * 0.03 + (i * (screen.x * 0.18 + 4))
			draw_rect(Rect2(x_pos, 220, screen.x * 0.18, 34), Color(0.9, 0.6, 0.1) if selected_theme == i else Color(0.25, 0.25, 0.28))
			draw_string(active_font, Vector2(x_pos + 1, 241), theme_names[i], HORIZONTAL_ALIGNMENT_CENTER, -1, 8, Color.WHITE)

		# 3. Stage Grid Selector
		draw_string(active_font, Vector2(screen.x / 2 - 100, 275), "3. SELECT STAGE (1-20)", HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color.WHITE)
		for i in range(20):
			var unlocked = i < unlocked_stages
			var col = i % 5
			var row = i / 5
			var x_pos = screen.x * 0.03 + (col * (screen.x * 0.18 + 4))
			var y_pos = 290 + (row * 38)
			
			draw_rect(Rect2(x_pos, y_pos, screen.x * 0.18, 32), Color(0.2, 0.6, 1.0) if selected_stage == i else (Color(0.25, 0.3, 0.35) if unlocked else Color(0.12, 0.12, 0.12)))
			draw_string(active_font, Vector2(x_pos + 1, y_pos + 20), "ST " + str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, -1, 9, Color.GOLD if selected_stage == i else Color.WHITE)

		draw_rect(Rect2(screen.x / 2 - 110, 470, 220, 48), Color(0.15, 0.85, 0.3))
		draw_string(active_font, Vector2(screen.x / 2 - 75, 501), "START GAME", HORIZONTAL_ALIGNMENT_CENTER, -1, 18, Color.WHITE)

	elif current_state == State.PLAYING or current_state == State.BOSS_FIGHT:
		for b in bullets:
			draw_line(b.pos, b.pos + Vector2(0, 20), b.color * Color(1, 1, 1, 0.6), b.radius * 1.5)
			draw_circle(b.pos, b.radius, b.color)

		for bp in boss_projectiles:
			draw_circle(bp.pos, bp.radius, bp.color)

		for p in powerups:
			var alpha_col = Color(1, 1, 1, p.alpha)
			var base_col = Color.RED if p.is_life else (Color.CYAN if p.is_shield else Color.GOLD)
			draw_circle(p.pos, 16.0, base_col * alpha_col)
			draw_circle(p.pos, 13.0, Color(0.1, 0.1, 0.1, p.alpha))
			draw_string(active_font, p.pos + Vector2(-22, -22), p.label, HORIZONTAL_ALIGNMENT_CENTER, -1, 9, Color.WHITE * alpha_col)

		for b in balls:
			_draw_realistic_ball(b, active_font)

		if boss_active:
			_draw_boss_monster(active_font)
			_draw_boss_health_bar(screen, active_font)

		if warning_active:
			draw_string(active_font, Vector2(screen.x / 2 - 180, 160), "WARNING! MONSTER APPROACHING!", HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color.RED)

		if respawn_invuln_timer <= 0 or int(Engine.get_process_frames() / 4) % 2 == 0:
			_draw_cannon_cart(ground_y)

		_draw_top_hud(screen, active_font)

	elif current_state == State.STAGE_CLEAR:
		draw_rect(Rect2(0, 0, screen.x, screen.y), Color(0, 0, 0, 0.8))
		draw_string(active_font, Vector2(screen.x / 2 - 170, screen.y / 2 - 60), "STAGE CLEAR!", HORIZONTAL_ALIGNMENT_CENTER, -1, 32, Color.GOLD)
		draw_string(active_font, Vector2(screen.x / 2 - 100, screen.y / 2 - 10), "SCORE: " + str(score), HORIZONTAL_ALIGNMENT_CENTER, -1, 18, Color.WHITE)

		var btn_rect = Rect2(screen.x / 2 - 110, screen.y / 2 + 70, 220, 55)
		draw_rect(btn_rect, Color(0.15, 0.75, 0.3))
		draw_string(active_font, Vector2(screen.x / 2 - 80, screen.y / 2 + 105), "NEXT STAGE", HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color.WHITE)

	elif current_state == State.GAME_OVER:
		draw_rect(Rect2(0, 0, screen.x, screen.y), Color(0, 0, 0, 0.85))
		draw_string(active_font, Vector2(screen.x / 2 - 120, screen.y / 2 - 40), "GAME OVER", HORIZONTAL_ALIGNMENT_CENTER, -1, 28, Color.RED)
		draw_string(active_font, Vector2(screen.x / 2 - 80, screen.y / 2), "SCORE: " + str(score), HORIZONTAL_ALIGNMENT_CENTER, -1, 18, Color.WHITE)
		var btn_rect = Rect2(screen.x / 2 - 110, screen.y / 2 + 70, 220, 55)
		draw_rect(btn_rect, Color(0.85, 0.25, 0.2))
		draw_string(active_font, Vector2(screen.x / 2 - 70, screen.y / 2 + 105), "TRY AGAIN", HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color.WHITE)

func _draw_realistic_ball(b: Dictionary, active_font: FontFile) -> void:
	var pos = b.pos
	var r = b.radius

	if b.is_stone:
		draw_circle(pos, r, Color(0.2, 0.21, 0.24))
		draw_circle(pos + Vector2(-r * 0.15, -r * 0.15), r * 0.88, Color(0.4, 0.42, 0.46))
		draw_circle(pos + Vector2(-r * 0.3, -r * 0.3), r * 0.65, Color(0.6, 0.63, 0.68))
		if b.has("craters"):
			for c in b.craters:
				draw_circle(pos + c.offset, c.size, Color(0.2, 0.22, 0.25))
	else:
		var main_col: Color = b.color
		draw_circle(pos, r, main_col.darkened(0.6))
		draw_circle(pos, r * 0.92, main_col)
		draw_circle(pos + Vector2(-r * 0.22, -r * 0.22), r * 0.75, main_col.lightened(0.25))

	draw_string(active_font, pos - Vector2(12, -6), str(b.hp), HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color.WHITE)

func _draw_boss_monster(active_font: FontFile) -> void:
	var pulse = sin(boss_anim_time) * 5.0
	var r = boss_radius + pulse
	var stage_type = selected_theme

	var boss_colors = [
		Color.DARK_GREEN, Color.SANDY_BROWN, Color.LIGHT_BLUE, Color.DARK_SLATE_BLUE, Color.DARK_RED
	]
	var base_col = boss_colors[stage_type].lightened((selected_stage / 5) * 0.1)

	draw_circle(boss_pos, r + 8.0, Color(1.0, 0.2, 0.2, 0.35))
	draw_circle(boss_pos, r, base_col)

	# Dynamic Eyes & Spikes based on stage progression
	draw_circle(boss_pos + Vector2(-20, -12), 12.0, Color.YELLOW if selected_stage >= 10 else Color.RED)
	draw_circle(boss_pos + Vector2(20, -12), 12.0, Color.YELLOW if selected_stage >= 10 else Color.RED)
	draw_circle(boss_pos + Vector2(0, 18), 16.0, Color.BLACK)

func _draw_boss_health_bar(screen: Vector2, active_font: FontFile) -> void:
	var bar_w = 320.0
	var bar_h = 18.0
	var pos = Vector2((screen.x - bar_w) / 2.0, 68)

	draw_rect(Rect2(pos.x - 4, pos.y - 4, bar_w + 8, bar_h + 8), Color(0, 0, 0, 0.7))
	var fill_w = bar_w * (float(boss_hp) / float(boss_max_hp))
	draw_rect(Rect2(pos, Vector2(fill_w, bar_h)), Color.RED)
	draw_string(active_font, pos + Vector2(bar_w / 2.0 - 65, 14), boss_names[selected_stage], HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color.WHITE)

func _draw_rich_background(screen: Vector2, ground_y: float) -> void:
	var theme = selected_theme  # Uses player-selected theme
	var sky_col = Color(0.62, 0.88, 0.98) if theme == 0 else (Color(0.98, 0.8, 0.5) if theme == 1 else (Color(0.8, 0.9, 0.98) if theme == 2 else (Color(0.2, 0.25, 0.35) if theme == 3 else Color(0.18, 0.08, 0.08))))
	draw_rect(Rect2(0, 0, screen.x, ground_y), sky_col)

	# Desert Tornado Effect
	if theme == 1:
		_draw_sandstorm_twister(screen, ground_y)

	var h_points: PackedVector2Array = [
		Vector2(0, ground_y), Vector2(0, ground_y - 120), Vector2(screen.x * 0.35, ground_y - 180),
		Vector2(screen.x * 0.7, ground_y - 100), Vector2(screen.x, ground_y - 140), Vector2(screen.x, ground_y)
	]
	var g_color = Color(0.22, 0.65, 0.32) if theme == 0 else (Color(0.85, 0.65, 0.25) if theme == 1 else (Color(0.85, 0.95, 1.0) if theme == 2 else (Color(0.3, 0.35, 0.35) if theme == 3 else Color(0.25, 0.08, 0.08))))
	draw_polygon(h_points, [g_color])

	# Realistic Volumetric Clouds Drawing Pass
	for c in clouds:
		_draw_cloud_shape(c)

	draw_rect(Rect2(0, ground_y, screen.x, screen.y - ground_y), g_color.darkened(0.15))

func _draw_cloud_shape(c: Dictionary) -> void:
	# 1. Soft Shadow Pass (Darkened Underside)
	for p in c.puffs:
		var shadow_pos = c.pos + p.offset + Vector2(0, 8)
		draw_circle(shadow_pos, p.radius * 1.08, Color(0.35, 0.4, 0.48, c.alpha * 0.25))

	# 2. Main Body Puff Pass (Soft White Base)
	for p in c.puffs:
		var puff_pos = c.pos + p.offset
		draw_circle(puff_pos, p.radius, Color(0.92, 0.94, 0.97, c.alpha))

	# 3. Top Sun Highlights Pass (3D Volume Depth)
	for p in c.puffs:
		var highlight_pos = c.pos + p.offset + Vector2(-p.radius * 0.25, -p.radius * 0.25)
		draw_circle(highlight_pos, p.radius * 0.65, Color(1.0, 1.0, 1.0, c.alpha * 0.8))

func _draw_sandstorm_twister(screen: Vector2, ground_y: float) -> void:
	var twister_center = Vector2(screen.x * 0.75, ground_y - 160)
	for i in range(12):
		var y_off = -140 + (i * 22)
		var width = 12.0 + (i * 7.0)
		var x_shift = sin(twister_angle + (i * 0.4)) * 25.0
		draw_line(twister_center + Vector2(-width + x_shift, y_off), twister_center + Vector2(width + x_shift, y_off), Color(0.82, 0.65, 0.35, 0.45), 8.0)

func _draw_weather_effects(screen: Vector2, ground_y: float) -> void:
	var theme = selected_theme
	for p in weather_particles:
		if theme == 0: draw_circle(p.pos, p.size, Color(0.3, 0.8, 0.2, p.alpha))
		elif theme == 1: draw_circle(p.pos, p.size * 1.5, Color(0.9, 0.75, 0.4, p.alpha))
		elif theme == 2: draw_circle(p.pos, p.size, Color(1, 1, 1, p.alpha))
		elif theme == 3: draw_line(p.pos, p.pos + Vector2(-3, 22), Color(0.6, 0.8, 1.0, 0.7), 2.5)
		elif theme == 4: draw_circle(p.pos, p.size, Color(1.0, 0.35, 0.1, p.alpha))

func _draw_top_hud(screen: Vector2, active_font: FontFile) -> void:
	draw_rect(Rect2(10, 10, screen.x - 140, 48), Color(0, 0, 0, 0.5))

	var w_names = ["STANDARD", "TRIPLE", "LASER", "PLASMA", "WAVE"]
	draw_string(active_font, Vector2(20, 32), w_names[current_weapon] + " L" + str(weapon_level), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.GOLD)
	draw_string(active_font, Vector2(20, 48), "STAGE " + str(selected_stage + 1) + "/20", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.WHITE)

	if current_state == State.PLAYING:
		var prog = clamp(stage_timer / target_stage_duration, 0.0, 1.0)
		draw_rect(Rect2(screen.x * 0.28, 24, screen.x * 0.18, 12), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(screen.x * 0.28, 24, (screen.x * 0.18) * prog, 12), Color.LIME_GREEN)

	draw_string(active_font, Vector2(screen.x * 0.48, 38), "LIVES:" + str(lives), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.LIGHT_CORAL)

	# Lock Button
	var lock_rect = Rect2(screen.x - 125, 10, 115, 38)
	var lock_bg = Color(0.8, 0.2, 0.2, 0.45) if is_weapon_locked else Color(0.1, 0.1, 0.1, 0.35)
	draw_rect(lock_rect, lock_bg)
	draw_rect(lock_rect, Color(1, 1, 1, 0.4), false, 2.0)
	var lock_text = "LOCK: ON" if is_weapon_locked else "LOCK: OFF"
	draw_string(active_font, Vector2(screen.x - 120, 34), lock_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color.GREEN_YELLOW if is_weapon_locked else Color.WHITE)

func _draw_cannon_cart(ground_y: float) -> void:
	var base_pos = Vector2(cannon_x, ground_y)
	draw_rect(Rect2(base_pos.x - 32, base_pos.y - 22, 64, 14), Color(0.4, 0.22, 0.1))

	var barrel_pivot = base_pos + Vector2(0, -18)
	var b_w = 34.0 * barrel_scale.x
	var b_h = 65.0 * barrel_scale.y
	draw_rect(Rect2(barrel_pivot.x - b_w / 2.0, barrel_pivot.y - b_h + recoil_y, b_w, b_h), Color(0.25, 0.27, 0.32))

	if muzzle_flash_timer > 0:
		draw_circle(Vector2(barrel_pivot.x, barrel_pivot.y - b_h - 10.0 + recoil_y), 24.0, Color.GOLD)

	_draw_wagon_wheel(base_pos + Vector2(-28, -14), wheel_rotation)
	_draw_wagon_wheel(base_pos + Vector2(28, -14), wheel_rotation)

	if shield_timer > 0:
		draw_arc(base_pos + Vector2(0, -25), 46.0, 0, TAU, 32, Color.CYAN, 4.0)

func _draw_wagon_wheel(pos: Vector2, rot: float) -> void:
	draw_circle(pos, 18.0, Color(0.15, 0.15, 0.18))
	draw_circle(pos, 14.0, Color(0.5, 0.28, 0.12))
	for i in range(4):
		var offset = Vector2.RIGHT.rotated(rot + (i * PI / 4.0)) * 14.0
		draw_line(pos - offset, pos + offset, Color(0.2, 0.1, 0.05), 3.0)

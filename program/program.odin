package program

import "core:fmt"
import "core:math"
import rand "core:math/rand"
import os "core:os"
import "core:slice"
import "core:strconv"
import "core:strings"
import "core:time"

// NOTE: c/libc.system() conflicts with raylib, so I use this small library instead
when ODIN_OS == .Windows {
	foreign import launch_lib "../launch/launch.lib"
	foreign launch_lib {
		launch :: proc(_: cstring) ---
	}
} else {
	launch :: proc(_: cstring) {
	}
}

Habit :: struct {
	done:        [days_per_month]bool,
	skip:        [days_per_month]bool,
	name:        string,
	description: string,
	purpose:     string,
	cmd:         string,
}
habits: [dynamic]Habit
frame: int

days_per_month :: 31
today: int
saved_write_time: os.File_Time
file_name: string

// stores the names and descriptions of the habits, think of it as an arena
// in practice, it stores the complete text of the habits file
data: []byte

current_habit: int = -1

timer: f32 = 0

theme_editor := false
theme_editor_default_width :: 250
theme_editor_width: f32 = theme_editor_default_width
theme_editor_selected_color := -1
theme_editor_selected_color_hsv: [4]f32
theme_editor_editing_sv: bool = false
theme_editor_editing_hue: bool = false
theme_editor_editing_alpha: bool = false

text_width :: 10
grid_width :: days_per_month
total_width :: text_width + grid_width

text_start :: 0
grid_start :: text_start + text_width

Particle :: struct {
	pos:         [2]f32,
	speed:       [2]f32,
	opacity:     f32,
	size:        f32,
	color:       [4]u8,
	decay_speed: f32,
}
particles: [1000]Particle

color_names: []string = {"background", "text", "checkbox", "not_done"}
colors: [dynamic]^[4]u8 = {}
color_background := [4]u8{4, 20, 30, 255}
color_text := [4]u8{232, 182, 182, 255}
color_checkbox: [4]u8 = {56, 156, 155, 255}
color_not_done := [4]u8{161, 17, 17, 255}

st: ^State

@(export)
setup :: proc(state: ^State) {
	st = state
	this_year: int
	this_month: time.Month
	this_year, this_month, today = time.date(time.now())
	file_name = fmt.aprintf("%d-%2.d.txt", this_year, int(this_month))
	when ODIN_DEBUG {
		emit_particles({0, 0})
		// theme_editor = true
	}
	colors = {&color_background, &color_text, &color_checkbox, &color_not_done}
	load_colors()
}

@(export)
draw :: proc() {
	free_all(context.temp_allocator)

	load()
	theme_editor_width = theme_editor_default_width if theme_editor else 0
	effective_window_dims: [2]f32 = st.window_dims - {theme_editor_width, 0}

	st.clear_color = color_background
	unit := effective_window_dims.x / total_width
	mouse_x := st.mouse.x
	mouse_y := st.mouse.y
	effective_window_dims.y = unit * (lenf(habits) + 2)

	st.window_dims.y = effective_window_dims.y

	st.hand_cursor = false
	for &h, hi in habits {
		y := f32(hi + 0) * unit

		text_hovered := point_inside_quad(st.mouse, {unit * text_start, y}, {unit * text_width, unit})
		color := brighten_color(color_text, 0.2) if text_hovered else color_text

		name_background_color := color_background

		// cover not done habits with red overlay
		if (h.done[today - 1] == false && h.skip[today - 1] == false) {
			name_background_color = color_not_done
			if current_habit != -1 && hi != current_habit {
				name_background_color = desat_color(name_background_color, 0.4)
			}
		}

		if hi % 2 == 0 {
			name_background_color = mix_colors(name_background_color, color_background, 0.2)
		}

		draw_quad({0, y}, {unit * text_width, unit}, name_background_color)

		text_size := unit / 1.1
		draw_text(h.name, {grid_start * unit - unit / 10, y}, text_size, color, .right)
		if text_hovered && len(h.cmd) > 0 {
			st.hand_cursor = true
		}
		// underline habits that has command
		if len(h.cmd) > 0 {
			spaces: f32 = 0
			for c in h.name {
				if c == ' ' {
					spaces += 1
				} else {
					break
				}
			}
			underline_y := y + unit - unit / 4
			length := (lenf(h.name) - spaces) / 2 * text_size
			start_x := grid_start * unit - length - unit / 10
			draw_quad({start_x, underline_y}, {length, unit / 15}, color_text)
		}

		// the grid checkboxes for this habit
		for day in 0 ..< days_per_month {
			if h.skip[day] do continue
			c1 := color_checkbox
			// there is something weird here, a jump when changing hue
			c2 := desat_color(color_not_done, 0.5)

			// dim other days
			if day != today - 1 {
				c1 = desat_color(mix_colors(c1, color_background))
				c2 = desat_color(mix_colors(c2, color_background))
			}

			if hi % 2 == 0 {
				c1 = mix_colors(c1, color_background, 0.2)
				c2 = mix_colors(c2, color_background, 0.2)
			}

			if checkbox({unit * f32(grid_start + day), y}, {unit, unit}, &h.done[day], {0, 0, 0, 0}, c1, c2) {
				save()

				if h.done[day] do emit_particles(st.mouse)

				if day == today - 1 {
					if hi == current_habit {
						timer = 0
						current_habit = -1
					}
					all_done := true
					for hh in habits {
						if hh.skip[today - 1] do continue
						all_done &= hh.done[today - 1]
					}
					if all_done do emit_particles2(effective_window_dims / 2)
				}
			}
		}
		// shortcut to toggle today
		if text_hovered && st.mouse_right_pressed && h.skip[today - 1] == false {
			h.done[today - 1] = !h.done[today - 1]

			save()

			if h.done[today - 1] {
				emit_particles({unit * (.5 + f32(grid_start + today - 1)), y + unit / 2})
			}

			if hi == current_habit {
				timer = 0
				current_habit = -1
			}

			all_done := true
			for hh in habits do all_done &= hh.done[today - 1]
			if all_done do emit_particles2(effective_window_dims / 2)
		}

		// launch on click
		if text_hovered && st.mouse_left_pressed {
			current_habit = hi
			timer = 0
			if len(h.cmd) > 0 {
				launch(cstr(h.cmd))
			}
		}
	}

	// hovered column
	if mouse_x > unit * grid_start && mouse_x < effective_window_dims.x && mouse_y < unit * lenf(habits) {
		hovered_mouse_x := math.floor(mouse_x / unit) * unit
		c := color_checkbox
		c.a = 40
		draw_quad({hovered_mouse_x, 0}, {unit, unit * lenf(habits)}, c)
	}

	description_index := current_habit

	// hovered row
	if mouse_y < unit * lenf(habits) && mouse_x < effective_window_dims.x {
		hovered_mouse_y := math.floor(mouse_y / unit) * unit
		c := color_checkbox
		c.a = 40
		draw_quad({0, hovered_mouse_y}, {unit * total_width, unit}, c)
		index := int(hovered_mouse_y / unit)
		description_index = index
	}

	{ 	// remaining
		done_today: f32 = 0
		all: f32 = 0
		for h in habits {
			if h.done[today - 1] do done_today += 1
			if h.skip[today - 1] == false do all += 1
		}
		remaining_text_size := unit * 2

		remaining := fmt.tprintf("%v/%v", done_today, all)
		draw_text(remaining, {remaining_text_size / 5, effective_window_dims.y - remaining_text_size}, remaining_text_size, color_text)
	}

	{ 	// description and purpose
		text_size := unit
		description: string
		purpose: string
		if description_index != -1 {
			description = habits[description_index].description
			purpose = habits[description_index].purpose
			if len(description) == 0 {
				description = "no description"
			}
			if len(purpose) == 0 {
				purpose = "no purpose"
			}
		} else {
			description = "click a habit"
			purpose = "to start the timer"
		}
		draw_text(description, {effective_window_dims.x / 2, effective_window_dims.y - 2 * text_size}, text_size, color_text, .center)
		draw_text(purpose, {effective_window_dims.x / 2, effective_window_dims.y - 1.1 * text_size}, text_size, color_text, .center)
	}

	{ 	// current habit
		name: string
		color: [4]u8
		if current_habit == -1 {
			name = "other"
			color = color_text
			// draw_quad({0, 0}, st.window_dims, {200, 0, 0, 100})
		} else {
			name = habits[current_habit].name
			color = color_text
		}

		text_size := unit
		minutes := math.floor(timer / 60)
		seconds := timer - minutes * 60
		millis := int((timer - math.floor(timer)) * 100)

		timer_text := fmt.tprintf("%2.0f:%2.0f.%2.0d", minutes, seconds, millis)
		draw_text(name, {effective_window_dims.x - unit / 10, effective_window_dims.y - 2 * text_size}, text_size, color, .right)
		draw_text(timer_text, {effective_window_dims.x - unit / 10, effective_window_dims.y - text_size}, text_size, color_text, .right)
		timer += st.dt
	}


	if theme_editor {
		pos: [2]f32 = {effective_window_dims.x, 0}
		dims: [2]f32 = {300, effective_window_dims.y}
		w := theme_editor_width

		draw_quad({pos.x, 0}, {w, dims.y}, {130, 100, 100, 255})

		y: f32 = 10
		hovered := -1
		if theme_editor_selected_color == -1 {
			theme_editor_selected_color = 0
			cc := colors[theme_editor_selected_color]
			theme_editor_selected_color_hsv = RGBToHSVA(cc^)
		}

		for name, i in color_names {
			if mouse_x > pos.x && mouse_y > y && mouse_y < y + 22 {
				hovered = i
				if st.mouse_left_pressed {
					theme_editor_selected_color = hovered
					cc := colors[theme_editor_selected_color]
					theme_editor_selected_color_hsv = RGBToHSVA(cc^)
					save_colors()
				}
			}
			if theme_editor_selected_color == i {
				draw_quad({pos.x, y}, {dims.x, 22}, {20, 20, 20, 255})
			}
			if hovered == i {
				draw_quad({pos.x, y}, {dims.x, 22}, {40, 40, 40, 255})
			}
			draw_quad({pos.x + 7 - 1, y + 2 - 1}, {18, 18}, {200, 200, 200, 255})
			draw_quad({pos.x + 7, y + 2}, {16, 16}, colors[i]^)
			draw_text(name, {pos.x + 30, y}, 20, {255, 255, 255, 255})
			y += 22
		}
		y += 10

		padding: f32 = 5

		// current color
		current_color_quad_pos: [2]f32 = {pos.x + padding, y}
		current_color_quad_dim: [2]f32 = {40, 40}
		text_pos: [2]f32 = current_color_quad_pos + {current_color_quad_dim.x + padding, current_color_quad_dim.y / 3}
		draw_quad(current_color_quad_pos, current_color_quad_dim, colors[theme_editor_selected_color]^)
		text_size: f32 = 16
		white: [4]u8 = {255, 255, 255, 255}
		draw_text("sat", text_pos + {0, 0}, text_size, white)
		draw_text("desat", text_pos + {35, 0}, text_size, white)
		draw_text("light", text_pos + {85, 0}, text_size, white)
		draw_text("dark", text_pos + {135, 0}, text_size, white)
		y += current_color_quad_dim.y + 2 * padding

		// pallete
		sv_dim: [2]f32 = {200, 200}
		sv_pos: [2]f32 = {pos.x + padding, y}
		q_dim: [2]f32 = sv_dim / 100
		h_pos: [2]f32 = sv_pos + {sv_dim.x + padding, 0}
		h_dim: [2]f32 = {15, 200}
		v_pos: [2]f32 = h_pos + {h_dim.x + padding, 0}
		v_dim: [2]f32 = {15, 200}

		if point_inside_quad(st.mouse, sv_pos, sv_dim) {
			if st.mouse_left_pressed do theme_editor_editing_sv = true
		}
		if point_inside_quad(st.mouse, h_pos, h_dim) {
			if st.mouse_left_pressed do theme_editor_editing_hue = true
		}
		if point_inside_quad(st.mouse, v_pos, v_dim) {
			if st.mouse_left_pressed do theme_editor_editing_alpha = true
		}

		if st.mouse_left_released {
			if theme_editor_editing_sv || theme_editor_editing_hue || theme_editor_editing_alpha {
				save_colors()
			}

			theme_editor_editing_sv = false
			theme_editor_editing_hue = false
			theme_editor_editing_alpha = false
		}

		if theme_editor_editing_sv {
			val_s := (st.mouse.x - sv_pos.x) / sv_dim.x
			val_v := 1 - (st.mouse.y - sv_pos.y) / sv_dim.y

			val_v = math.clamp(val_v, 0, 1)
			val_s = math.clamp(val_s, 0, 1)

			theme_editor_selected_color_hsv.g = val_s
			theme_editor_selected_color_hsv.b = val_v
			colors[theme_editor_selected_color]^ = HSVAToRGB(theme_editor_selected_color_hsv)
		}
		if theme_editor_editing_hue {
			val := (st.mouse.y - h_pos.y) / h_dim.y
			val = math.clamp(val, 0, 1)
			theme_editor_selected_color_hsv.r = val
			colors[theme_editor_selected_color]^ = HSVAToRGB(theme_editor_selected_color_hsv)
		}
		if theme_editor_editing_alpha {
			val := 1 - (st.mouse.y - v_pos.y) / v_dim.y
			val = math.clamp(val, 0, 1)
			theme_editor_selected_color_hsv.a = val
			colors[theme_editor_selected_color]^ = HSVAToRGB(theme_editor_selected_color_hsv)
		}

		for i in 0 ..< 100 {
			for j in 0 ..< 100 {
				q_pos := sv_pos + {f32(i) * sv_dim.x / 100, f32(j) * sv_dim.y / 100}
				hue := theme_editor_selected_color_hsv.r
				draw_quad(q_pos, q_dim, HSVAToRGB({hue, f32(i) / 100, 1 - (f32(j) / 100), 1}))
			}
		}
		for i in 0 ..< 100 {
			draw_quad(h_pos + {0, f32(i) * 2}, {h_dim.x, 2}, HSVAToRGB({f32(i) / 100, 1, 1, 1}))
		}
		for i in 0 ..< 100 {
			draw_quad(v_pos + {0, f32(i) * 2}, {v_dim.x, 2}, HSVAToRGB({1, 0, 1 - (f32(i) / 100), 1}))
		}

		if theme_editor_selected_color != -1 {
			circle_color: [4]u8 = {255, 255, 255, 255}
			circle_inner_color: [4]u8 = {100, 100, 100, 255}
			draw_circle(
				sv_pos + {theme_editor_selected_color_hsv.y * sv_dim.x, (1 - theme_editor_selected_color_hsv.z) * sv_dim.y},
				5,
				circle_color,
			)
			draw_circle(h_pos + {h_dim.x / 2, theme_editor_selected_color_hsv.x * h_dim.y}, 5, circle_color)
			draw_circle(v_pos + {v_dim.x / 2, (1 - theme_editor_selected_color_hsv.w) * h_dim.y}, 5, circle_color)

			draw_circle(
				sv_pos + {theme_editor_selected_color_hsv.y * sv_dim.x, (1 - theme_editor_selected_color_hsv.z) * sv_dim.y},
				2,
				circle_inner_color,
			)
			draw_circle(h_pos + {h_dim.x / 2, theme_editor_selected_color_hsv.x * h_dim.y}, 2, circle_inner_color)
			draw_circle(v_pos + {v_dim.x / 2, (1 - theme_editor_selected_color_hsv.w) * h_dim.y}, 2, circle_inner_color)
		}
	}

	if st.t_pressed {
		st.window_dims.x += -theme_editor_default_width if theme_editor else theme_editor_default_width
		theme_editor = !theme_editor
	}

	if st.e_pressed {
		launch(cstr(fmt.tprintf("START %v", file_name)))
	}

	frame += 1
	if frame > 120 {
		frame = 0
		// emit_particles({500, 200})
	}

	simulate_particles()
	draw_particles()
}

invert_color :: proc(c: [4]u8) -> [4]u8 {
	hsv := RGBToHSVA(c)
	hsv.z = 1 - hsv.z
	return HSVAToRGB(hsv)
}

sat_color :: proc(c: [4]u8, v: f32 = 0.1) -> [4]u8 {
	hsv := RGBToHSVA(c)
	hsv.y = math.clamp(hsv.y * (1 + v), 0, 1)
	return HSVAToRGB(hsv)
}

desat_color :: proc(c: [4]u8, v: f32 = 0.1) -> [4]u8 {
	hsv := RGBToHSVA(c)
	hsv.y = math.clamp(hsv.y * (1 - v), 0, 1)
	return HSVAToRGB(hsv)
}

brighten_color :: proc(c: [4]u8, v: f32 = 0.1) -> [4]u8 {
	hsv := RGBToHSVA(c)
	hsv.z = math.clamp(hsv.z * (1 + v), 0, 1)
	return HSVAToRGB(hsv)
}

darken_color :: proc(c: [4]u8, v: f32 = 0.1) -> [4]u8 {
	hsv := RGBToHSVA(c)
	hsv.z = math.clamp(hsv.z * (1 - v), 0, 1)
	return HSVAToRGB(hsv)
}

mix_colors :: proc(c1: [4]u8, c2: [4]u8, f: f32 = 0.5) -> [4]u8 {
	cf1: [4]f32 = {f32(c1.r), f32(c1.g), f32(c1.b), f32(c1.a)}
	cf2: [4]f32 = {f32(c2.r), f32(c2.g), f32(c2.b), f32(c2.a)}

	return {u8(math.lerp(cf1.r, cf2.r, f)), u8(math.lerp(cf1.g, cf2.g, f)), u8(math.lerp(cf1.b, cf2.b, f)), u8(math.lerp(cf1.a, cf2.a, f))}
}

point_inside_quad :: proc(p: [2]f32, tl: [2]f32, dims: [2]f32) -> bool {
	return p.x > tl.x && p.x < tl.x + dims.x && p.y > tl.y && p.y < tl.y + dims.y
}

checkbox :: proc(pos: [2]f32, dims: [2]f32, v: ^bool, c0, c1, c2: [4]u8) -> bool {
	padding :: 2

	hovered := point_inside_quad(st.mouse, pos, dims)
	done := v^

	inner_rectangle_color := c1 if done else c2
	if hovered do inner_rectangle_color = brighten_color(inner_rectangle_color, 0.3)

	draw_quad(pos, dims, c0)
	draw_quad(pos + padding, dims - 2 * padding, inner_rectangle_color)

	if hovered && (st.mouse_left_pressed || st.mouse_right_pressed) {
		v^ = !v^
		return true
	}

	return false
}

load :: proc() {
	if os.is_file(file_name) == false { 	// create file if it doesn't exist
		if len(habits) == 0 {
			delete(data)
			data = slice.clone(#load("../data/tutorial.txt"))
			parse(data) // create tutorial
		}
		save()
	}

	last_write_time, last_write_err := os.last_write_time_by_name(file_name)

	if last_write_err != os.ERROR_NONE || saved_write_time == last_write_time {return}

	saved_write_time = last_write_time
	loaded: bool
	delete(data)
	data, loaded = os.read_entire_file(file_name)
	if loaded == false {panic("failed to load the file")}
	parse(data)
}

parse :: proc(data: []byte) {
	clear_dynamic_array(&habits)
	it := string(data)
	for line in strings.split_lines_iterator(&it) {
		h: Habit
		res, _ := strings.split(line, ";", context.temp_allocator)
		if len(res) < 5 {
			fmt.println("invalid habit. Found", len(res), "sections instead of 5")
			continue
		}

		if len(res[0]) != 31 {
			fmt.println("Invalid habit. Found", len(res[0]), "day markers sections instead of 31")
			continue
		}

		for c, i in res[0] {
			h.done[i] = c == 'x'
			h.skip[i] = c == '-'
		}
		h.name = res[1]
		h.description = res[2]
		h.purpose = res[3]
		h.cmd = res[4]
		append(&habits, h)
	}
}

save :: proc() {
	builder := strings.builder_make_none(context.temp_allocator)

	for h in habits {
		for d, i in h.done {
			if h.skip[i] {
				strings.write_byte(&builder, '-')
			} else {
				strings.write_byte(&builder, 'x' if d else '.')
			}
		}
		strings.write_byte(&builder, ';')
		strings.write_string(&builder, h.name)
		strings.write_byte(&builder, ';')
		strings.write_string(&builder, fmt.tprintf("%s", h.description))
		strings.write_byte(&builder, ';')
		strings.write_string(&builder, fmt.tprintf("%s", h.purpose))
		strings.write_byte(&builder, ';')
		strings.write_string(&builder, fmt.tprintf("%s", h.cmd))
		strings.write_byte(&builder, '\n')
	}

	written := os.write_entire_file(file_name, transmute([]u8)strings.to_string(builder))
	if written == false {panic("failed to save the file")}

	saved_write_time, _ = os.last_write_time_by_name(file_name)
}

cstr :: proc(s: string) -> cstring {
	return strings.clone_to_cstring(s, context.temp_allocator)
}

draw_text :: proc(s: string, pos: [2]f32, size: f32, color: [4]u8, alignment: Text_Alignment = .left) {
	append(&st.text, Text{s, pos, size, color, alignment})
}

draw_quad :: proc(pos: [2]f32, dims: [2]f32, color: [4]u8) {
	append(&st.quads, Quad{pos, dims, color})
}

draw_circle :: proc(pos: [2]f32, radius: f32, color: [4]u8) {
	append(&st.circles, Circle{pos, radius, color})
}

emit_particles :: proc(pos: [2]f32) {
	for &p, i in particles {
		if i > 80 {break}
		// p.pos = {rand.float32_range(0, 900), rand.float32_range(0, 500)}
		// p.pos = {rand.float32_range(pos.x - 5, pos.x + 5), rand.float32_range(pos.y - 5, pos.y + 5)}
		p.pos = {rand.float32_range(pos.x - 2, pos.x + 2), rand.float32_range(pos.y - 2, pos.y + 2)}
		speed: f32 = 600
		p.speed = {rand.float32_range(-speed, speed) * 2, rand.float32_range(-speed, speed)}
		p.opacity = 255
		p.decay_speed = 200
		p.size = rand.float32_range(2, 10)
		p.color = {u8(rand.uint32()), u8(rand.uint32()), u8(rand.uint32()), 255}
	}
}
emit_particles2 :: proc(pos: [2]f32) {
	for &p, i in particles {
		if i > 300 {break}
		// p.pos = {rand.float32_range(0, 900), rand.float32_range(0, 500)}
		// p.pos = {rand.float32_range(pos.x - 5, pos.x + 5), rand.float32_range(pos.y - 5, pos.y + 5)}
		p.pos = {rand.float32_range(pos.x - 2, pos.x + 2), rand.float32_range(pos.y - 2, pos.y + 2)}
		speed: f32 = 300
		p.speed = {rand.float32_range(-speed, speed) * 2, rand.float32_range(-speed, speed)}
		p.opacity = 255
		p.decay_speed = 50
		p.size = rand.float32_range(2, 10)
		p.color = {u8(rand.uint32()), u8(rand.uint32()), u8(rand.uint32()), 255}
	}
}

simulate_particles :: proc() {
	for &p in particles {
		p.pos += st.dt * p.speed
		p.opacity -= st.dt * p.decay_speed
		if p.opacity < 0 {p.opacity = 0}
	}
}

draw_particles :: proc() {
	for p in particles {
		draw_circle(p.pos, p.size, {p.color[0], p.color[1], p.color[2], u8(p.opacity)})
	}
}

lenf :: proc(a: $T) -> f32 {
	return f32(len(a))
}

save_colors :: proc() {
	builder := strings.builder_make_none(context.temp_allocator)

	for i in 0 ..< len(color_names) {
		strings.write_string(&builder, color_names[i])
		strings.write_byte(&builder, ' ')
		strings.write_uint(&builder, uint(colors[i][0]))
		strings.write_byte(&builder, ' ')
		strings.write_uint(&builder, uint(colors[i][1]))
		strings.write_byte(&builder, ' ')
		strings.write_uint(&builder, uint(colors[i][2]))
		strings.write_byte(&builder, ' ')
		strings.write_uint(&builder, uint(colors[i][3]))
		strings.write_byte(&builder, '\n')
	}

	written := os.write_entire_file("colors.hex", transmute([]u8)strings.to_string(builder))
	if written == false {panic("failed to save the file")}
}

load_colors :: proc() {
	color_data, loaded := os.read_entire_file("colors.hex", context.temp_allocator)
	if loaded == false do return
	fmt.println("loading colors")

	it := string(color_data)
	for line in strings.split_lines_iterator(&it) {
		if len(line) == 0 do continue
		res, _ := strings.split(line, " ", context.temp_allocator)

		name: string = res[0]
		r: u8 = u8(strconv.atoi(res[1]))
		g: u8 = u8(strconv.atoi(res[2]))
		b: u8 = u8(strconv.atoi(res[3]))
		a: u8 = u8(strconv.atoi(res[4]))

		color: [4]u8 = {r, g, b, a}

		for n, i in color_names {
			if n == name {
				colors[i]^ = color
				break
			}
		}
	}
}

RGBToHSVA :: proc(rgb_in: [4]u8) -> [4]f32 {
	r: f32 = f32(rgb_in[0]) / 255
	g: f32 = f32(rgb_in[1]) / 255
	b: f32 = f32(rgb_in[2]) / 255
	a: f32 = f32(rgb_in[3]) / 255

	max := math.max(math.max(r, g), b)
	min := math.min(math.min(r, g), b)
	delta := max - min

	h: f32
	if (delta == 0) {
		h = 0
	} else if (r == max) {
		h = 60 * ((g - b) / delta + 0)
	} else if (g == max) {
		h = 60 * ((b - r) / delta + 2)
	} else if (b == max) {
		h = 60 * ((r - g) / delta + 4)
	}

	h = math.abs(math.mod(h, 360))
	h /= 360

	v := max

	s: f32 = 0
	if (v != 0) do s = delta / v

	return {h, s, v, a}
}

HSVAToRGB :: proc(hsv: [4]f32) -> [4]u8 {
	c := hsv[1] * hsv[2]
	hd := hsv[0] * 6

	x: f32 = c * (1 - math.abs(math.mod(hd, 2) - 1))

	m := hsv[2] - c
	c += m
	x += m
	a := hsv[3]

	rgba: [4]f32
	if (hd <= 1) {
		rgba = {c, x, m, a}
	} else if (hd <= 2) {
		rgba = {x, c, m, a}
	} else if (hd <= 3) {
		rgba = {m, c, x, a}
	} else if (hd <= 4) {
		rgba = {m, x, c, a}
	} else if (hd <= 5) {
		rgba = {x, m, c, a}
	} else if (hd <= 6) {
		rgba = {c, m, x, a}
	}

	return {u8(rgba.x * 255), u8(rgba.y * 255), u8(rgba.z * 255), u8(rgba.a * 255)}
}

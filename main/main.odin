package main

import "../program"
import "core:dynlib"
import "core:fmt"
import "core:os"
import "core:os/os2"
import "core:strings"
import ray "vendor:raylib"

API :: struct {
	setup: proc(state: ^program.State),
	draw:  proc(),
}

api: API
api_load_time: os.File_Time
font: ray.Font
st: program.State
old_st: program.State

// foreign import launch_lib "../launch/launch.lib"
// foreign launch_lib {
// launch :: proc(_: cstring) ---
// }

load :: proc() -> bool {
	dll_name :: "program"
	dll_ext :: ".dll"
	full_name :: dll_name + dll_ext

	if os.is_file(full_name) == false {
		fmt.println(full_name, "doesn't exit")
		return false
	}

	last_write_time, last_write_err := os.last_write_time_by_name(full_name)
	if last_write_err != os.ERROR_NONE || api_load_time == last_write_time do return false
	new_name := fmt.tprintf("{}_{}{}", dll_name, last_write_time, dll_ext)
	api_load_time = last_write_time

	// command := fmt.ctprintf("copy {} {}", full_name, new_name)
	// fmt.println(command)
	// launch(command)
	copy_error := os2.copy_file(new_name, full_name)
	// NOTE: This returns an error even if the copy is successful
	// if copy_error != nil {
	// fmt.printfln("failed to copy {} to {}. Reason: {}.", full_name, new_name, copy_error)
	// return false
	// }
	_, ok := dynlib.initialize_symbols(&api, new_name)

	if !ok {
		fmt.printfln("failed to load {}: {}", dynlib.last_error())
		return false
	}
	return true
}

main :: proc() {
	{ 	//ui_init()
		ray.SetTraceLogLevel(.WARNING)
		window_config := ray.ConfigFlags{.MSAA_4X_HINT, .WINDOW_RESIZABLE}
		// window_config += {.WINDOW_UNDECORATED}
		// window_config += {.WINDOW_UNFOCUSED}

		ray.SetConfigFlags(window_config)
		ray.InitWindow(1000, 500, "Dima")
		ray.SetTargetFPS(60)
		ray.SetExitKey(.Q)

		fantasque := #load("../data/fantasque/FantasqueSansMono-Regular.ttf")
		font = ray.LoadFontFromMemory(".ttf", &fantasque[0], i32(len(fantasque)), 100, nil, 0)
		ray.GenTextureMipmaps(&font.texture)
		ray.SetTextureFilter(font.texture, .BILINEAR)
		st.quads = make([dynamic]program.Quad, 0, 1000)
		st.text = make([dynamic]program.Text, 0, 1000)
	}

	when ODIN_DEBUG == false {
		program.setup(&st)
	}

	for ray.WindowShouldClose() == false {
		free_all(context.temp_allocator)

		{ 	// ui_clear
			old_st = st
			clear_dynamic_array(&st.quads)
			clear_dynamic_array(&st.circles)
			clear_dynamic_array(&st.text)
			st.window_dims = {f32(ray.GetScreenWidth()), f32(ray.GetScreenHeight())}
			st.mouse = ray.GetMousePosition()
			st.mouse_left_released = ray.IsMouseButtonReleased(.LEFT)
			st.mouse_left_pressed = ray.IsMouseButtonPressed(.LEFT)
			st.mouse_right_released = ray.IsMouseButtonReleased(.RIGHT)
			st.mouse_right_pressed = ray.IsMouseButtonPressed(.RIGHT)
			st.dt = ray.GetFrameTime()
			st.e_pressed = ray.IsKeyPressed(.E)
			st.t_pressed = ray.IsKeyPressed(.T)
			st.b_pressed = ray.IsKeyPressed(.B)
		}

		when ODIN_DEBUG {
			loaded := load()
			if loaded do api.setup(&st)
			api.draw()
		} else {
			program.draw()
		}

		{ 	//draw
			if old_st.hand_cursor != st.hand_cursor {
				if st.hand_cursor {
					ray.SetMouseCursor(.POINTING_HAND)
				} else {
					ray.SetMouseCursor(.DEFAULT)
				}
			}

			if old_st.window_dims != st.window_dims {
				ray.SetWindowSize(i32(st.window_dims.x), i32(st.window_dims.y))
			}

			ray.BeginDrawing();defer ray.EndDrawing()
			ray.ClearBackground(st.clear_color.rgba)

			for q in st.quads {
				ray.DrawRectangleV(q.pos, q.dims, q.color.xyzw)
			}
			for c in st.circles {
				ray.DrawCircleV(c.pos, c.radius, c.color.xyzw)
			}
			for t in st.text {
				s := strings.clone_to_cstring(t.s, context.temp_allocator)
				text_width := ray.MeasureTextEx(font, s, t.size, 0).x
				x := t.pos.x
				if t.algnment == .center {
					x -= text_width / 2
				}
				if t.algnment == .right {
					x -= text_width
				}
				ray.DrawTextEx(font, s, {x, t.pos.y}, t.size, 0, t.color.xyzw)
			}
		}
	}
}

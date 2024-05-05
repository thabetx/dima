package program

// The main program must be recompiled if this file is changed
State :: struct {
	quads:                [dynamic]Quad,
	text:                 [dynamic]Text,
	circles:              [dynamic]Circle,
	clear_color:          [4]u8,
	window_dims:          [2]f32,
	mouse:                [2]f32,
	mouse_left_pressed:   bool,
	mouse_left_released:  bool,
	mouse_right_pressed:  bool,
	mouse_right_released: bool,
	dt:                   f32,
	e_pressed:            bool,
	t_pressed:            bool,
	b_pressed:            bool,
	hand_cursor:          bool,
}

Quad :: struct {
	pos:   [2]f32,
	dims:  [2]f32,
	color: [4]u8,
}

Text_Alignment :: enum {
	left,
	center,
	right,
}

Text :: struct {
	s:        string,
	pos:      [2]f32,
	size:     f32,
	color:    [4]u8,
	algnment: Text_Alignment,
}

Circle :: struct {
	pos:    [2]f32,
	radius: f32,
	color:  [4]u8,
}

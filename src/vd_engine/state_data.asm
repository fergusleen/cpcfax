; Engine state and buffer storage
vd_cursor_x:    defb 0
vd_cursor_y:    defb 0
vd_cursor_on:   defb 0
vd_esc_state:   defb 0
vd_iac_state:   defb 0
vd_cur_fg:      defb 0
vd_cur_bg:      defb 0
vd_cur_flags:   defb 0
vd_hold_graphics: defb 0
vd_held_char:   defb 0
vd_held_attr:   defb 0
vd_held_flags:  defb 0
vd_held_mosaic: defb 0
vd_write_mosaic_override: defb 0
vd_write_char_tmp: defb 0
vd_next_fg:     defb 0
vd_next_flags:  defb 0
vd_esc_row_tmp: defb 0
vd_force_row_valid: defb 0
vd_force_row_y: defb 0
vd_dirty_any:  defb 0
vd_last_write_x: defb 0
vd_last_write_y: defb 0
vd_last_write_valid: defb 0

esc_first_counts:   defs 256
esc_second_counts:  defs 256

vd_buffer:      defs VD_BUF_SIZE
vd_attr:        defs VD_BUF_SIZE
vd_mosaic:      defs VD_BUF_SIZE
vd_flags:       defs VD_BUF_SIZE
vd_dirty_rows:  defs VD_HEIGHT

vd_colour_ink_map:
                ; Viewdata colours map to pens 0..7 (black..white).
                db 0,1,2,3,4,5,6,7
	; colourMap[0] = color.NRGBA{R: 0, G: 0, B: 0, A: 255}       // Black
	; colourMap[1] = color.NRGBA{R: 255, G: 0, B: 0, A: 255}     // Red
	; colourMap[2] = color.NRGBA{R: 0, G: 255, B: 0, A: 255}     // Green
	; colourMap[3] = color.NRGBA{R: 255, G: 255, B: 0, A: 255}   // Yellow
	; colourMap[4] = color.NRGBA{R: 0, G: 0, B: 255, A: 255}     // Blue
	; colourMap[5] = color.NRGBA{R: 255, G: 0, B: 255, A: 255}   // Magenta
	; colourMap[6] = color.NRGBA{R: 0, G: 255, B: 255, A: 255}   // Cyam
	; colourMap[7] = color.NRGBA{R: 255, G: 255, B: 255, A: 255} // White

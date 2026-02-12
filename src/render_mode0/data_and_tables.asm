; ------------------------------------------------------------
; Mode 0 Tables & Variables
; ------------------------------------------------------------

mode0_left:
                db $00,$80,$20,$A0,$08,$88,$28,$A8,$02,$82,$22,$A2,$0A,$8A,$2A,$AA
mode0_right:
                db $00,$40,$10,$50,$04,$44,$14,$54,$01,$41,$11,$51,$05,$45,$15,$55

mode0_cols:    db 0
mode0_col:     db 0
mode0_row:     db 0
mode0_scanline: db 0
mode0_scanlines_left: db 0
mode0_ch:      db 0
mode0_mosaic:  db 0
mode0_noncontig: db 0
mode0_glyph:   db 0
mode0_fg:      db 0
mode0_bg:      db 0
mode0_tmp:     db 0
mode0_cell_char: db 0
mode0_cell_attr: db 0
mode0_cell_flags: db 0
mode0_cell_mosaic: db 0
mode0_row_dh_upper: db 0
mode0_row_dh_lower: db 0
mode0_dh_active: db 0
mode0_dh_lower_half: db 0
mode0_render_xor: db 0
mode0_lut_ready: db 0
mode0_lf:      db 0
mode0_lb:      db 0
mode0_rf:      db 0
mode0_rb:      db 0
mode0_cursor_prev_x: db 0
mode0_cursor_prev_y: db 0
mode0_cursor_prev_valid: db 0
render_scan_row: db 0
render_scan_col: db 0
render_key_hook_ptr: dw 0
render_flush_hook_ptr: dw 0
render_recv_hook_ptr: dw 0
mode0_attr_base_ptr: dw 0
render_cache_dh_curr: db 0
render_cache_dh_prev: db 0
render_ptr_flags: dw 0

vd_dirty_min:   ds 24
vd_dirty_max:   ds 24

mode0_attrglyph_lut: defs 8192

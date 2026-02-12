vd_write_cell:
                ld      (vd_write_char_tmp),a
                ld      a,(vd_cursor_x)
                ld      (vd_last_write_x),a
                ld      a,(vd_cursor_y)
                ld      (vd_last_write_y),a
                ld      a,1
                ld      (vd_last_write_valid),a
                ld      a,(vd_cursor_y)
                ld      l,a
                ld      h,0
                add     hl,hl
                add     hl,hl
                add     hl,hl
                ld      d,h
                ld      e,l
                add     hl,hl
                add     hl,hl
                add     hl,de
                ld      a,(vd_cursor_x)
                ld      e,a
                ld      d,0
                add     hl,de
                push    hl
                ld      de,vd_buffer
                add     hl,de
                ld      a,(vd_write_char_tmp)
                ld      (hl),a
                pop     hl
                push    hl
                ld      de,vd_attr
                add     hl,de
                ld      a,b
                ld      (hl),a
                pop     hl
                ld      de,vd_flags
                add     hl,de
                ld      a,c
                or      FLAG_DIRTY
                ld      (hl),a
                ld      a,1
                ld      (vd_dirty_any),a
                call    vd_mark_row_dirty

                ; If override set, write mosaic pattern for this cell.
                ld      a,(vd_write_mosaic_override)
                or      a
                jr      z,.vd_wc_no_mosaic_override
                push    hl
                ld      de,VD_BUF_SIZE
                or      a
                sbc     hl,de            ; hl = vd_mosaic + index (flags - VD_BUF_SIZE)
                ld      (hl),a
                pop     hl
                xor     a
                ld      (vd_write_mosaic_override),a
.vd_wc_no_mosaic_override:

                ld      a,(vd_cursor_x)
                inc     a
                cp      VD_WIDTH
                jr      c,.vd_write_set
                xor     a
                ld      (vd_cursor_x),a
                call    vd_newline
                ret
.vd_write_set:
                ld      (vd_cursor_x),a
                ret

vd_handle_esc_control:
                call    vd_row_start_defaults_if_col0
                ld      a,b
                cp      ALPHA_RED
                jr      c,.vd_esc_misc
                cp      ALPHA_WHITE+1
                jr      nc,.vd_esc_mosaic
                sub     ALPHA_BLACK
                ld      l,a
                ld      h,0
                ld      de,vd_colour_ink_map
                add     hl,de
                ld      a,(hl)
                ld      (vd_next_fg),a
                ld      a,(vd_cur_flags)
                and     ~(FLAG_GRAPHICS|FLAG_CONCEAL)
                ld      (vd_next_flags),a
                call    vd_write_control_prev
                jp      .vd_apply_next

.vd_esc_mosaic:
                ld      a,b
                cp      MOSAIC_RED
                jr      c,.vd_esc_misc
                cp      MOSAIC_WHITE+1
                jr      nc,.vd_esc_misc
                sub     MOSAIC_BLACK
                ld      l,a
                ld      h,0
                ld      de,vd_colour_ink_map
                add     hl,de
                ld      a,(hl)
                ld      (vd_next_fg),a
                ld      a,(vd_cur_flags)
                and     ~(FLAG_CONCEAL)
                or      FLAG_GRAPHICS
                ld      (vd_next_flags),a
                call    vd_write_control_prev
                jp      .vd_apply_next

.vd_esc_misc:
                ld      a,b
                cp      BLACK_BACKGROUND
                jp      z,.vd_black_bg
                cp      NEW_BACKGROUND
                jp      z,.vd_new_bg
                cp      CONCEAL
                jp      z,.vd_conceal
                cp      FLASH
                jp      z,.vd_flash
                cp      STEADY
                jp      z,.vd_steady
                cp      CONTIGUOUS_GRAPHICS
                jp      z,.vd_contig
                cp      SEPARATED_GRAPHICS
                jp      z,.vd_sep
                cp      DOUBLE_HEIGHT
                jp      z,.vd_double
                cp      NORMAL_HEIGHT
                jp      z,.vd_normal
                cp      HOLD_GRAPHICS
                jp      z,.vd_hold
                cp      RELEASE_GRAPHICS
                jp      z,.vd_release
                cp      'E'
                jp      z,.vd_do_clear
                cp      'H'
                jp      z,.vd_do_home
                ; Unknown ESC control: still consume one control cell so
                ; cursor/layout stay in sync with stream (display.go behavior).
                call    vd_write_control_prev
                ret

.vd_black_bg:
                ld      a,0
                ld      (vd_cur_bg),a
                call    vd_apply_bg_to_eol_current
                call    vd_write_control_current
                ret

.vd_new_bg:
                ld      a,(vd_cur_fg)
                ld      (vd_cur_bg),a
                call    vd_apply_bg_to_eol_current
                call    vd_write_control_current
                ret

.vd_conceal:
                ld      a,(vd_cur_flags)
                or      FLAG_CONCEAL
                ld      (vd_cur_flags),a
                call    vd_write_control_current
                ret

.vd_flash:
                ; Render path does not support per-cell flash. Treat FLASH as STEADY.
                jp      .vd_steady

.vd_steady:
                ld      a,(vd_cur_fg)
                ld      (vd_next_fg),a
                ld      a,(vd_cur_flags)
                and     ~FLAG_FLASH
                ld      (vd_next_flags),a
                call    vd_write_control_prev
                jp      .vd_apply_next

.vd_contig:
                ld      a,(vd_cur_fg)
                ld      (vd_next_fg),a
                ld      a,(vd_cur_flags)
                and     ~FLAG_NONCONTIG
                ld      (vd_next_flags),a
                call    vd_write_control_prev
                jp      .vd_apply_next

.vd_sep:
                ld      a,(vd_cur_fg)
                ld      (vd_next_fg),a
                ld      a,(vd_cur_flags)
                or      FLAG_NONCONTIG
                ld      (vd_next_flags),a
                call    vd_write_control_prev
                jp      .vd_apply_next

.vd_double:
                ld      a,(vd_cur_fg)
                ld      (vd_next_fg),a
                ld      a,(vd_cur_flags)
                or      FLAG_DOUBLE
                ld      (vd_next_flags),a
                call    vd_write_control_prev
                jp      .vd_apply_next

.vd_normal:
                ld      a,(vd_cur_fg)
                ld      (vd_next_fg),a
                ld      a,(vd_cur_flags)
                and     ~FLAG_DOUBLE
                ld      (vd_next_flags),a
                call    vd_write_control_prev
                jr      .vd_apply_next

.vd_hold:
                ld      a,(vd_hold_graphics)
                or      a
                jr      z,.vd_hold_blank
                call    vd_write_control_hold
                jr      .vd_hold_set
.vd_hold_blank:
                call    vd_write_control_prev
.vd_hold_set:
                ld      a,1
                ld      (vd_hold_graphics),a
                ret

.vd_release:
                call    vd_write_control_hold
                xor     a
                ld      (vd_hold_graphics),a
                ret

.vd_do_clear:
                xor     a
                ld      (vd_esc_state),a
                call    VD_Init
                call    Mode0_ClearScreen
                ret

.vd_do_home:
                xor     a
                ld      (vd_cursor_x),a
                ld      (vd_cursor_y),a
                ld      (vd_esc_state),a
                ret

.vd_apply_next:
                ld      a,(vd_next_fg)
                ld      (vd_cur_fg),a
                ld      a,(vd_next_flags)
                ld      (vd_cur_flags),a
                ret

vd_write_control_prev:
                ld      a,(vd_hold_graphics)
                or      a
                jr      z,.vd_wcp_space
                ld      a,(vd_cur_flags)
                and     FLAG_GRAPHICS
                jr      z,.vd_wcp_space
                ld      a,(vd_held_char)
                or      a
                jr      z,.vd_wcp_space
                ld      a,(vd_held_attr)
                ld      b,a
                ld      a,(vd_held_flags)
                ld      c,a
                ld      a,(vd_held_mosaic)
                ld      (vd_write_mosaic_override),a
                ld      a,(vd_held_char)
                call    vd_write_cell
                ret
.vd_wcp_space:
                call    vd_make_attr
                ld      b,a
                ld      a,(vd_cur_flags)
                ld      c,a
                xor     a
                ld      (vd_write_mosaic_override),a
                ld      a,' '
                call    vd_write_cell
                ret

vd_write_control_current:
                ld      a,(vd_hold_graphics)
                or      a
                jr      z,.vd_wcc_space
                ld      a,(vd_cur_flags)
                and     FLAG_GRAPHICS
                jr      z,.vd_wcc_space
                ld      a,(vd_held_char)
                or      a
                jr      z,.vd_wcc_space
                ld      a,(vd_held_attr)
                ld      b,a
                ld      a,(vd_held_flags)
                ld      c,a
                ld      a,(vd_held_mosaic)
                ld      (vd_write_mosaic_override),a
                ld      a,(vd_held_char)
                call    vd_write_cell
                ret
.vd_wcc_space:
                call    vd_make_attr
                ld      b,a
                ld      a,(vd_cur_flags)
                ld      c,a
                xor     a
                ld      (vd_write_mosaic_override),a
                ld      a,' '
                call    vd_write_cell
                ret

vd_write_control_hold:
                ld      a,(vd_hold_graphics)
                or      a
                jp      z,vd_write_control_prev
                ld      a,(vd_held_char)
                or      a
                jp      z,vd_write_control_prev
                ld      a,(vd_held_attr)
                ld      b,a
                ld      a,(vd_held_flags)
                ld      c,a
                ld      a,(vd_held_mosaic)
                ld      (vd_write_mosaic_override),a
                ld      a,(vd_held_char)
                call    vd_write_cell
                ret

; Apply current background from cursor position to end-of-row.
; This matches display.go setAttributes() behavior for background controls,
; where the background continues through the rest of the line.
vd_apply_bg_to_eol_current:
                ; b = background nibble in high 4 bits
                ld      a,(vd_cur_bg)
                and     $0F
                add     a,a
                add     a,a
                add     a,a
                add     a,a
                ld      b,a

                ; c = remaining cells in row (including current column)
                ld      a,VD_WIDTH
                ld      d,a
                ld      a,(vd_cursor_x)
                sub     d
                neg
                ret     z
                ld      c,a

                ; hl = linear index (row*40 + col)
                ld      a,(vd_cursor_y)
                ld      l,a
                ld      h,0
                add     hl,hl
                add     hl,hl
                add     hl,hl
                ld      d,h
                ld      e,l
                add     hl,hl
                add     hl,hl
                add     hl,de
                ld      a,(vd_cursor_x)
                ld      e,a
                ld      d,0
                add     hl,de

                ; de = vd_attr + index
                push    hl
                ld      de,vd_attr
                add     hl,de
                ex      de,hl
                pop     hl

                ; hl = vd_flags + index
                push    de
                ld      de,vd_flags
                add     hl,de
                pop     de

.vd_bg_eol_loop:
                ld      a,(de)
                and     $0F
                or      b
                ld      (de),a
                ld      a,(hl)
                or      FLAG_DIRTY
                ld      (hl),a
                inc     de
                inc     hl
                dec     c
                jr      nz,.vd_bg_eol_loop

                ld      a,1
                ld      (vd_dirty_any),a
                call    vd_mark_row_dirty
                ld      (vd_force_row_valid),a
                ld      a,(vd_cursor_y)
                ld      (vd_force_row_y),a
                ret

vd_us_cursor_row:
                ld      a,b
                sub     32
                ld      a,$FF
                ld      (vd_esc_row_tmp),a
                jr      c,.vd_us_row_set_state
                cp      VD_HEIGHT
                jr      c,.vd_us_row_ok
                jr      nz,.vd_us_row_set_state
                dec     a
.vd_us_row_ok:
                ld      (vd_esc_row_tmp),a
.vd_us_row_set_state:
                ld      a,9
                ld      (vd_esc_state),a
                ret

vd_us_cursor_col:
                ld      a,b
                sub     32
                jr      c,.vd_us_cursor_done
                cp      VD_WIDTH
                jr      c,.vd_us_col_ok
                jr      nz,.vd_us_cursor_done
                dec     a
.vd_us_col_ok:
                ld      c,a
                ld      a,(vd_esc_row_tmp)
                cp      $FF
                jr      z,.vd_us_cursor_done
                ld      (vd_cursor_y),a
                ld      a,c
                ld      (vd_cursor_x),a
.vd_us_cursor_done:
                xor     a
                ld      (vd_esc_state),a
                ret

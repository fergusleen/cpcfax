vd_put_char:
                ld      c,a
                ld      a,c
                and     $7F
                ld      c,a
                xor     a
                ld      b,a

                ; HOLD behaviour: if graphics+hold active and char is space, substitute held mosaic
                ld      a,(vd_cur_flags)
                and     FLAG_GRAPHICS
                jr      z,.vd_put_normal_char
                ld      a,(vd_hold_graphics)
                or      a
                jr      z,.vd_put_normal_char
                ld      a,c
                cp      $20
                jr      nz,.vd_put_normal_char
                ld      a,(vd_held_mosaic)
                or      a
                jr      z,.vd_put_normal_char
                ld      b,1
.vd_put_normal_char:

                ; HL = cell index (row*40 + col)
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

                ; HL -> vd_buffer[index]
                push    hl
                ld      de,vd_buffer
                add     hl,de

                ; If in graphics mode, store char in vd_buffer and store pattern in vd_mosaic.
                ld      a,(vd_cur_flags)
                and     FLAG_GRAPHICS
                jr      z,.vd_put_alpha_store

                ld      a,b
                or      a
                jr      z,.vd_put_mosaic_check

                ; HOLD-substituted space => write held mosaic pattern
                ld      a,(vd_held_mosaic)
                and     $20
                jr      z,.vd_hold_char_low
                ; pattern bit5 set => char in 0x60..0x7F (bit6 set, bit5 clear)
                ld      a,(vd_held_mosaic)
                and     $1F
                or      $40
                ld      (hl),a
                jr      .vd_hold_char_done
.vd_hold_char_low:
                ; pattern bit5 clear => char in 0x20..0x3F (bit5 set)
                ld      a,(vd_held_mosaic)
                and     $1F
                or      $20
                ld      (hl),a
.vd_hold_char_done:
                push    hl
                ld      de,vd_mosaic - vd_buffer
                add     hl,de
                ld      a,(vd_held_mosaic)
                ld      (hl),a
                pop     hl
                jr      .vd_put_mosaic_done

.vd_put_mosaic_check:
                ld      a,c
                ld      (hl),a
                cp      $21
                jr      c,.vd_put_mosaic_store
                cp      $40
                jr      c,.vd_put_mosaic_set
                cp      $60
                jr      c,.vd_put_alpha_store
                cp      $80
                jr      c,.vd_put_mosaic_set
                jr      .vd_put_alpha_store

.vd_put_mosaic_store:
                ; mosaic-space or non-pattern => store zero pattern
                jr      .vd_put_mosaic_zero

.vd_put_mosaic_set:
                ; store actual mosaic char + extracted 6-bit pattern
                ld      a,c
                ld      (hl),a
                ld      a,c
                and     $1F
                ld      b,a
                ld      a,c
                and     $40
                rrca
                ld      d,a
                ld      a,b
                or      d
                ld      b,a
                push    hl
                ld      de,vd_mosaic - vd_buffer
                add     hl,de
                ld      (hl),b
                pop     hl
                jr      .vd_put_mosaic_done

.vd_put_mosaic_zero:
                push    hl
                ld      de,vd_mosaic - vd_buffer
                add     hl,de
                xor     a
                ld      (hl),a
                pop     hl
                jr      .vd_put_mosaic_done

.vd_put_alpha_store:
                ; alpha store into vd_buffer, clear vd_mosaic
                ld      a,c
                ld      (hl),a
                push    hl
                ld      de,vd_mosaic - vd_buffer
                add     hl,de
                xor     a
                ld      (hl),a
                pop     hl

.vd_put_mosaic_done:
                pop     hl

                ; attr
                push    hl
                ld      de,vd_attr
                add     hl,de
                call    vd_make_attr
                ld      (hl),a
                pop     hl

                ; flags
                ld      de,vd_flags
                add     hl,de
                ld      a,(vd_cur_flags)
                ld      b,a
                ; Hold-substituted spaces use held mosaic separation state.
                ld      a,b
                and     FLAG_GRAPHICS
                jr      z,.vd_flags_sep_ready
                ld      a,(vd_hold_graphics)
                or      a
                jr      z,.vd_flags_sep_ready
                ld      a,c
                cp      $20
                jr      nz,.vd_flags_sep_ready
                ld      a,(vd_held_mosaic)
                or      a
                jr      z,.vd_flags_sep_ready
                ld      a,b
                and     ~FLAG_NONCONTIG
                ld      d,a
                ld      a,(vd_held_flags)
                and     FLAG_NONCONTIG
                or      d
                ld      b,a
.vd_flags_sep_ready:
                and     FLAG_GRAPHICS
                jr      z,.vd_store_flags
                ld      a,c
                cp      $40
                jr      c,.vd_store_flags
                cp      $60
                jr      nc,.vd_store_flags
                ; alpha range in graphics mode -> store without graphics flag
                ld      a,b
                and     $FE
                or      FLAG_DIRTY
                ld      (hl),a
                jr      .vd_flags_done
.vd_store_flags:
                ld      a,b
                or      FLAG_DIRTY
                ld      (hl),a
.vd_flags_done:
                ld      a,1
                ld      (vd_dirty_any),a
                call    vd_mark_row_dirty

                ; Update held mosaic only for real mosaic patterns
                ld      a,(vd_cur_flags)
                and     FLAG_GRAPHICS
                jr      z,.vd_put_no_hold
                ld      a,c
                cp      $21
                jr      c,.vd_put_no_hold
                cp      $40
                jr      c,.vd_put_hold_update
                cp      $60
                jr      c,.vd_put_no_hold
                cp      $80
                jr      c,.vd_put_hold_update
                jr      .vd_put_no_hold

.vd_put_hold_update:
                ld      a,c
                ld      (vd_held_char),a
                ld      a,c
                and     $1F
                ld      b,a
                ld      a,c
                and     $40
                rrca
                ld      d,a
                ld      a,b
                or      d
                ld      (vd_held_mosaic),a
                call    vd_make_attr
                ld      (vd_held_attr),a
                ld      a,(vd_cur_flags)
                ld      (vd_held_flags),a

.vd_put_no_hold:
                ld      a,(vd_cursor_x)
                inc     a
                cp      VD_WIDTH
                jr      c,.vd_put_set
                xor     a
                ld      (vd_cursor_x),a
                call    vd_newline
                ret
.vd_put_set:
                ld      (vd_cursor_x),a
                ret

vd_newline:
                ld      a,(vd_cursor_y)
                cp      VD_HEIGHT-1
                ret     nc
                inc     a
                ld      (vd_cursor_y),a
                call    vd_reset_row_state
                ret

vd_reset_row_state:
                ld      a,7
                ld      (vd_cur_fg),a
                xor     a
                ld      (vd_cur_bg),a
                ld      (vd_cur_flags),a
                ld      (vd_hold_graphics),a
                ld      (vd_held_char),a
                ld      (vd_held_mosaic),a
                call    vd_make_attr
                ld      (vd_held_attr),a
                xor     a
                ld      (vd_held_flags),a
                ret

vd_row_start_defaults_if_col0:
                ld      a,(vd_cursor_x)
                or      a
                ret     nz
                jp      vd_reset_row_state

vd_mark_row_dirty:
                push    bc
                ld      a,(vd_cursor_y)
                ld      b,a
                ld      a,(vd_cursor_x)
                ld      c,a
                ; Call the new logic in render_mode0.asm that updates min/max
                call    Render_MarkCellDirty 
                pop     bc
                ret

vd_make_attr:
                ld      a,(vd_cur_bg)
                and     $0F
                add     a,a
                add     a,a
                add     a,a
                add     a,a
                ld      e,a
                ld      a,(vd_cur_fg)
                and     $0F
                or      e
                ret


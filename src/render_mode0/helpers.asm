; ------------------------------------------------------------
; MODE 0 helpers 
; ------------------------------------------------------------

ForceScreenC000_Offset0:
                ld      hl,0
                call    SCR_SET_OFFSET
                ld      a,$C0
                call    SCR_SET_BASE
                ret

Mode0_ClearScreen:
                xor     a
                call    SCR_SET_MODE
                call    ForceScreenC000_Offset0
                call    SetPalette
                ; Invalidate cursor position on clear so it redraws
                xor     a
                ld      (mode0_cursor_prev_valid),a
                ; Reset the dirty column tracking bounds
                call    Mode0_ResetDirtyBounds
                ret

Mode0_InitPages:
                call    ForceScreenC000_Offset0
                xor     a
                ld      (mode0_render_xor),a
                ld      (render_scan_row),a
                ld      (render_scan_col),a
                call    Mode0_ResetDirtyBounds
                ret

Mode0_ResetDirtyBounds:
                ld      b, 24           ; VD_HEIGHT
                ld      hl, vd_dirty_min
                ld      de, vd_dirty_max
.m0rdb_loop:    ld      (hl), 39        ; Min starts at right edge
                ex      de, hl
                ld      (hl), 0         ; Max starts at left edge
                ex      de, hl
                inc     hl
                inc     de
                djnz    .m0rdb_loop
                ret

Mode0_FlipPages:
                ld      a,(mode0_render_xor)
                or      a
                jr      z,.display_c000
                ld      a,$80
                jr      .set_base
.display_c000:
                ld      a,$C0
.set_base:
                call    SCR_SET_BASE
                ld      a,(mode0_render_xor)
                xor     $40
                ld      (mode0_render_xor),a
                ret

Mode0_BuildGlyphAttrLUT:
                ld      ix,mode0_attrglyph_lut
                ld      b,0                   ; attr
.attr_loop:
                ld      a,b
                and     $0F
                ld      (mode0_fg),a          ; fg
                ld      a,b
                rrca
                rrca
                rrca
                rrca
                and     $0F
                ld      (mode0_bg),a          ; bg

                ld      a,(mode0_fg)
                ld      l,a
                ld      h,0
                ld      de,mode0_left
                add     hl,de
                ld      a,(hl)
                ld      (mode0_lf),a
                ld      a,(mode0_bg)
                ld      l,a
                ld      h,0
                ld      de,mode0_left
                add     hl,de
                ld      a,(hl)
                ld      (mode0_lb),a
                ld      a,(mode0_fg)
                ld      l,a
                ld      h,0
                ld      de,mode0_right
                add     hl,de
                ld      a,(hl)
                ld      (mode0_rf),a
                ld      a,(mode0_bg)
                ld      l,a
                ld      h,0
                ld      de,mode0_right
                add     hl,de
                ld      a,(hl)
                ld      (mode0_rb),a

                ld      c,0                   ; glyph
.glyph_loop:
                ld      a,c
                bit     3,a
                jr      z,.p0_bg
                ld      a,(mode0_lf)
                jr      .p0_done
.p0_bg:
                ld      a,(mode0_lb)
.p0_done:
                ld      (mode0_tmp),a

                ld      a,c
                bit     2,a
                jr      z,.p1_bg
                ld      a,(mode0_rf)
                jr      .p1_done
.p1_bg:
                ld      a,(mode0_rb)
.p1_done:
                ld      e,a
                ld      a,(mode0_tmp)
                or      e
                ld      (ix+0),a
                inc     ix

                ld      a,c
                bit     1,a
                jr      z,.p2_bg
                ld      a,(mode0_lf)
                jr      .p2_done
.p2_bg:
                ld      a,(mode0_lb)
.p2_done:
                ld      (mode0_tmp),a

                ld      a,c
                bit     0,a
                jr      z,.p3_bg
                ld      a,(mode0_rf)
                jr      .p3_done
.p3_bg:
                ld      a,(mode0_rb)
.p3_done:
                ld      e,a
                ld      a,(mode0_tmp)
                or      e
                ld      (ix+0),a
                inc     ix

                inc     c
                ld      a,c
                cp      16
                jr      nz,.glyph_loop

                inc     b
                jp      nz,.attr_loop

                ld      a,1
                ld      (mode0_lut_ready),a
                ret

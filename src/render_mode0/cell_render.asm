; ------------------------------------------------------------
; Sub-Cell Rendering
; ------------------------------------------------------------

Renderer_RenderCellPaired:
                push    bc
                call    RenderCell_Mode0
                pop     bc
                push    bc
                ld      a,b
                call    Mode0_RowHasDouble_Cached 
                pop     bc
                or      a
                jr      z,.rrcp_prev
                ld      a,b
                cp      VD_HEIGHT-1
                ret     nc
                inc     b
                jp      RenderCell_Mode0
.rrcp_prev:
                ld      a,b
                or      a
                ret     z
                dec     a
                push    bc
                call    Mode0_RowHasDouble_Cached
                pop     bc
                or      a
                ret     z
                dec     b
                jp      RenderCell_Mode0

Mode0_RowHasDouble_Cached:
                push    bc
                ld      b,a     ; requested row
                ld      a,(render_scan_row)
                cp      b
                jr      z,.m0rhdc_curr
                dec     a
                cp      b
                jr      z,.m0rhdc_prev
                ld      a,b
                pop     bc
                jp      Mode0_RowHasDouble
.m0rhdc_curr:
                ld      a,(render_cache_dh_curr)
                pop     bc
                ret
.m0rhdc_prev:
                ld      a,(render_cache_dh_prev)
                pop     bc
                ret

; ------------------------------------------------------------
; Character Cell Rendering
; ------------------------------------------------------------

RenderCell_Mode0:
                ld      a,(mode0_lut_ready)
                or      a
                call    z,Mode0_BuildGlyphAttrLUT

                ld      a,b
                ld      (mode0_row),a
                ld      a,c
                ld      (mode0_col),a

                ld      a,(render_scan_row)
                cp      b
                jr      nz,.rc_pair_context

                ld      a,(render_cache_dh_curr)
                ld      (mode0_row_dh_upper),a
                ld      a,(render_cache_dh_prev)
                ld      (mode0_row_dh_lower),a
                jr      .rc_context_done

.rc_pair_context:
                ld      a,(render_cache_dh_curr)
                ld      (mode0_row_dh_lower),a
                xor     a
                ld      (mode0_row_dh_upper),a 

.rc_context_done:
                ld      a,(mode0_row)
                ld      b,a
                ld      a,(mode0_row_dh_lower)
                or      a
                ld      a,b
                jr      z,.rc_src_row_ready
                dec     a
.rc_src_row_ready:
                ld      l,a
                ld      h,0
                add     hl,hl
                add     hl,hl
                add     hl,hl
                ld      de,hl
                add     hl,hl
                add     hl,hl
                add     hl,de
                ld      a,(mode0_col)
                ld      e,a
                ld      d,0
                add     hl,de

                push    hl
                ld      de,vd_buffer
                add     hl,de
                ld      a,(hl)
                ld      (mode0_cell_char),a
                pop     hl

                push    hl
                ld      de,vd_attr
                add     hl,de
                ld      a,(hl)
                ld      (mode0_cell_attr),a
                pop     hl

                push    hl
                ld      de,vd_mosaic
                add     hl,de
                ld      a,(hl)
                ld      (mode0_cell_mosaic),a
                pop     hl

                ld      de,vd_flags
                add     hl,de
                ld      a,(hl)
                ld      (mode0_cell_flags),a

                xor     a
                ld      (mode0_scanline),a
                ld      a,8
                ld      (mode0_scanlines_left),a

                ld      a,(mode0_cell_attr)
                ld      l,a
                ld      h,0
                add     hl,hl   ; *2
                add     hl,hl   ; *4
                add     hl,hl   ; *8
                add     hl,hl   ; *16
                add     hl,hl   ; *32
                ld      bc,mode0_attrglyph_lut
                add     hl,bc
                ld      (mode0_attr_base_ptr),hl

.rc_scanline_loop:
                ld      a,(mode0_scanlines_left)
                or      a
                ret     z
                dec     a
                ld      (mode0_scanlines_left),a

                ld      a,(mode0_row)
                add     a,a
                add     a,a
                add     a,a
                ld      b,a
                ld      a,(mode0_scanline)
                add     a,b
                ld      l,a
                ld      h,0
                add     hl,hl
                ld      de,screen_lut_mode0
                add     hl,de
                ld      e,(hl)
                inc     hl
                ld      d,(hl)
                ld      a,(mode0_render_xor)
                xor     d
                ld      d,a

                ld      a,(mode0_col)
                add     a,a
                ld      c,a
                ld      b,0
                ex      de,hl
                add     hl,bc
                ex      de,hl

                xor     a
                ld      (mode0_dh_active),a
                ld      (mode0_dh_lower_half),a
                ld      a,(mode0_row_dh_lower)
                or      a
                jr      z,.rc_dh_upper_check
                ld      a,(mode0_cell_flags)
                and     FLAG_DOUBLE
                jr      nz,.rc_dh_lower_cell
                xor     a
                ld      (mode0_glyph),a
                jp      .rc_glyph_ready
.rc_dh_lower_cell:
                ld      a,1
                ld      (mode0_dh_active),a
                ld      (mode0_dh_lower_half),a
                jr      .rc_glyph_conceal_check
.rc_dh_upper_check:
                ld      a,(mode0_cell_flags)
                and     FLAG_DOUBLE
                jr      z,.rc_glyph_conceal_check
                ld      a,1
                ld      (mode0_dh_active),a
.rc_glyph_conceal_check:
                ld      a,(mode0_cell_flags)
                and     FLAG_NONCONTIG
                ld      (mode0_noncontig),a
                ld      a,(mode0_cell_flags)
                and     FLAG_CONCEAL
                jr      z,.rc_glyph_pick
                xor     a
                ld      (mode0_glyph),a
                jp      .rc_glyph_ready

.rc_glyph_pick:
                ld      a,(mode0_cell_flags)
                and     FLAG_GRAPHICS
                jr      z,.rc_glyph_alpha
                ld      a,(mode0_cell_char)
                and     $7F
                cp      $40
                jr      c,.rc_glyph_graphics_do
                cp      $60
                jr      c,.rc_glyph_alpha_from_char
.rc_glyph_graphics_do:
                ld      a,(mode0_cell_mosaic)
                ld      (mode0_mosaic),a
                jr      .rc_glyph_mosaic
.rc_glyph_alpha_from_char:
                ld      a,(mode0_cell_char)
                and     $7F
                ld      (mode0_ch),a
                jr      .rc_glyph_alpha_ch

.rc_glyph_alpha:
                ld      a,(mode0_cell_char)
                and     $7F
                ld      (mode0_ch),a
.rc_glyph_alpha_ch:
                ld      a,(mode0_ch)
                cp      32
                jr      c,.rc_glyph_space
                cp      127
                jr      nc,.rc_glyph_space
                sub     32
                ld      l,a
                ld      h,0
                add     hl,hl
                add     hl,hl
                add     hl,hl
                ld      bc,Font4x8
                add     hl,bc
                ld      a,(mode0_scanline)
                ld      c,a
                ld      a,(mode0_dh_active)
                or      a
                jr      z,.rc_glyph_alpha_scan_ready
                ld      a,(mode0_scanline)
                srl     a
                ld      c,a
                ld      a,(mode0_dh_lower_half)
                or      a
                jr      z,.rc_glyph_alpha_scan_ready
                ld      a,c
                add     a,4
                ld      c,a
.rc_glyph_alpha_scan_ready:
                ld      b,0
                add     hl,bc
                ld      a,(hl)
                ld      (mode0_glyph),a
                jp      .rc_glyph_ready
.rc_glyph_space:
                xor     a
                ld      (mode0_glyph),a
                jp      .rc_glyph_ready

.rc_glyph_mosaic:
                ld      a,(mode0_dh_active)
                or      a
                jr      z,.rc_glyph_mosaic_scan
                ld      a,(mode0_mosaic)
                ld      b,a
                ld      a,(mode0_dh_lower_half)
                or      a
                ld      a,b
                jr      z,.rc_glyph_mosaic_upper
                call    Mode0_MosaicDHLower
                jr      .rc_glyph_mosaic_store
.rc_glyph_mosaic_upper:
                call    Mode0_MosaicDHUpper
.rc_glyph_mosaic_store:
                ld      (mode0_mosaic),a
.rc_glyph_mosaic_scan:
                call    Mode0_MosaicNibble
                ld      (mode0_glyph),a

.rc_glyph_ready:
                ld      a,(mode0_row)
                ld      b,a
                ld      a,(vd_cursor_y)
                cp      b
                jr      nz,.rc_cursor_done
                ld      a,(mode0_col)
                ld      b,a
                ld      a,(vd_cursor_x)
                cp      b
                jr      nz,.rc_cursor_done
                
                ld      a,(mode0_scanline)
                cp      6
                jr      c,.rc_cursor_done

                ld      a,(mode0_glyph)
                xor     $FF
                ld      (mode0_glyph),a

.rc_cursor_done:
                ld      hl,(mode0_attr_base_ptr)
                ld      a,(mode0_glyph)
                add     a,a
                ld      c,a
                ld      b,0
                add     hl,bc
                
                ld      a,(hl)
                ld      (de),a
                inc     de
                inc     hl
                ld      a,(hl)
                ld      (de),a

                ld      a,(mode0_scanline)
                inc     a
                ld      (mode0_scanline),a
                jp      .rc_scanline_loop

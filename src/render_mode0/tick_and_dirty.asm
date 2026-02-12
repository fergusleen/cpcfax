; ------------------------------------------------------------
; Non-blocking Incremental Renderer
; Scans only within dirty bounds (min/max) for the current row.
; ------------------------------------------------------------
Render_Tick:
                ld      a,(mode0_lut_ready)
                or      a
                call    z,Mode0_BuildGlyphAttrLUT

                call    Render_UpdateCursorDirty

                ld      a,(render_scan_row)
                cp      24                  ; VD_HEIGHT
                jr      c,.rt_check_row
                xor     a
                ld      (render_scan_row),a
                ret                         ; A=0 (Idle)

.rt_check_row:
                ld      hl,vd_dirty_rows
                ld      e,a
                ld      d,0
                add     hl,de
                ld      a,(hl)
                or      a
                jr      nz,.rt_process_row

                call    .rt_next_row
                jr      Render_Tick         ; Recurse to find work

.rt_process_row:
                ; Start scan at the cached min_col for this row
                ld      a,(render_scan_row)
                ld      l,a
                ld      h,0
                ld      de,vd_dirty_min
                add     hl,de
                ld      a,(hl)
                ld      (render_scan_col),a

                call    Render_PrepareRowContext

                ; Adjust flags pointer to the starting min_col
                ld      hl,(render_ptr_flags)
                ld      a,(render_scan_col)
                ld      e,a
                ld      d,0
                add     hl,de
                ld      (render_ptr_flags),hl

.rt_cell_loop:
                ld      hl,(render_ptr_flags)
                bit     FLAG_DIRTY_BIT,(hl)
                jr      z,.rt_skip_cell

                ; --- FOUND DIRTY CELL ---
                ld      a,(render_scan_row)
                ld      b,a
                ld      a,(render_scan_col)
                ld      c,a
                
                push    hl
                call    Renderer_RenderCellPaired
                pop     hl

                res     FLAG_DIRTY_BIT,(hl)
                
                call    .rt_next_col
                ld      a,1                 ; Return Busy
                ret

.rt_skip_cell:
                call    .rt_next_col
                
                ; Check if we have passed the max_col for this row
                ld      a,(render_scan_row)
                ld      l,a
                ld      h,0
                ld      de,vd_dirty_max
                add     hl,de
                ld      e,(hl)              ; E = max_col
                ld      a,(render_scan_col)
                cp      e
                jr      z,.rt_cell_loop     ; On the last dirty cell
                jr      nc,.rt_row_finished ; Past last dirty cell
                
                jr      .rt_cell_loop

.rt_row_finished:
                ; Reset row dirty flags and bounds for the next pass
                ld      a,(render_scan_row)
                ld      l,a
                ld      h,0
                push    hl
                ld      de,vd_dirty_rows
                add     hl,de
                ld      (hl),0
                pop     hl
                push    hl
                ld      de,vd_dirty_min
                add     hl,de
                ld      (hl), 39
                pop     hl
                ld      de,vd_dirty_max
                add     hl,de
                ld      (hl), 0

                call    .rt_next_row
                ld      a,1                 ; Yield
                ret

.rt_next_row:
                ld      hl,render_scan_row
                inc     (hl)
                xor     a
                ld      (render_scan_col),a
                ret

.rt_next_col:
                ld      hl,(render_ptr_flags)
                inc     hl
                ld      (render_ptr_flags),hl

                ld      hl,render_scan_col
                inc     (hl)
                ret

; ------------------------------------------------------------
; Row Context Preparation
; ------------------------------------------------------------

Render_PrepareRowContext:
                ld      a,(render_scan_row)
                call    Mode0_RowHasDouble
                ld      (render_cache_dh_curr),a

                ld      a,(render_scan_row)
                or      a
                jr      z,.rpr_noprev
                dec     a
                call    Mode0_RowHasDouble
                jr      .rpr_saveprev
.rpr_noprev:    xor     a
.rpr_saveprev:  ld      (render_cache_dh_prev),a

                ld      a,(render_scan_row)
                ld      l,a
                ld      h,0
                add     hl,hl   ; *2
                add     hl,hl   ; *4
                add     hl,hl   ; *8
                ld      d,h
                ld      e,l
                add     hl,hl   ; *16
                add     hl,hl   ; *32
                add     hl,de   ; *40
                ld      de,vd_flags
                add     hl,de
                ld      (render_ptr_flags),hl
                ret

; ------------------------------------------------------------
; Cursor Tracking
; ------------------------------------------------------------

Render_UpdateCursorDirty:
                ld      a,(mode0_cursor_prev_valid)
                or      a
                jr      z,.rucd_init

                ld      a,(vd_cursor_y)
                ld      hl,mode0_cursor_prev_y
                cp      (hl)
                jr      nz,.rucd_changed

                ld      a,(vd_cursor_x)
                ld      hl,mode0_cursor_prev_x
                cp      (hl)
                ret     z   ; No change

.rucd_changed:
                ld      a,(mode0_cursor_prev_y)
                ld      b,a
                ld      a,(mode0_cursor_prev_x)
                ld      c,a
                call    Render_MarkCellDirty

                ld      a,(vd_cursor_y)
                ld      b,a
                ld      a,(vd_cursor_x)
                ld      c,a
                call    Render_MarkCellDirty

                ld      a,(vd_cursor_y)
                ld      (mode0_cursor_prev_y),a
                ld      a,(vd_cursor_x)
                ld      (mode0_cursor_prev_x),a
                ret

.rucd_init:
                ld      a,1
                ld      (mode0_cursor_prev_valid),a
                ld      a,(vd_cursor_y)
                ld      (mode0_cursor_prev_y),a
                ld      a,(vd_cursor_x)
                ld      (mode0_cursor_prev_x),a
                ld      b,a 
                ld      a,(vd_cursor_y) 
                ld      c,b
                ld      b,a
                jp      Render_MarkCellDirty

; ------------------------------------------------------------
; Helper: Mark cell B (row), C (col) as dirty
; Tracks min/max column bounds to speed up Render_Tick.
; ------------------------------------------------------------

Render_MarkCellDirty:
                ; 1. Set Row Dirty flag
                ld      hl,vd_dirty_rows
                ld      e,b
                ld      d,0
                add     hl,de
                ld      (hl),1

                ; 2. Update Min Column Bound
                ld      hl,vd_dirty_min
                add     hl,de           ; DE is row offset
                ld      a,c
                cp      (hl)            ; Compare current with min
                jr      nc,.rmcd_check_max
                ld      (hl),a          ; Update new min

.rmcd_check_max:
                ; 3. Update Max Column Bound
                ld      hl,vd_dirty_max
                add     hl,de
                ld      a,c
                cp      (hl)            ; Compare current with max
                jr      c,.rmcd_set_flag
                ld      (hl),a          ; Update new max

.rmcd_set_flag:
                ; 4. Set Cell Flag Dirty
                ld      l,b
                ld      h,0
                add     hl,hl   ; *2
                add     hl,hl   ; *4
                add     hl,hl   ; *8
                ld      d,h
                ld      e,l
                add     hl,hl   ; *16
                add     hl,hl   ; *32
                add     hl,de   ; *40
                ld      e,c
                ld      d,0
                add     hl,de
                ld      de,vd_flags
                add     hl,de
                set     FLAG_DIRTY_BIT,(hl)
                ret

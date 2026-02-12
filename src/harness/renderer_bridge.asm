; ------------------------------------------------------------
; Set CPC inks to match Viewdata colours (vd_colour_ink_map).
; INK 0..7 -> CPC ink numbers
; ------------------------------------------------------------
SetPalette:
                ; set border to black
                xor     a
                ld      b,a
                call    SCR_SET_BORDER


                ; pens 0..7 for Viewdata colours (no flash)
                ld      hl,palette_inks
                ld      d,8
                ld      e,0                   ; start at pen 0
.sp_loop:
                ld      a,e                   ; pen index
                ld      b,(hl)                ; ink index (first colour)
                ld      c,b                   ; second colour = same (no flash)
                push    hl
                push    de
                call    SCR_SET_INK           ; A=pen, B/C=ink
                pop     de
                pop     hl
                inc     hl
                inc     e
                dec     d
                jr      nz,.sp_loop
                ret

Renderer_Init:
                xor     a
                call    SCR_SET_MODE            ; MODE 0
                call    Mode0_InitPages
                call    SetPalette
                call    Sound_Init
                call    Mode0_ClearScreen
                call    VD_Init
                ld      hl,Render_M4KeyHook
                ld      (render_key_hook_ptr),hl
                ld      hl,Render_M4FlushHook
                ld      (render_flush_hook_ptr),hl
                ld      hl,Render_M4RecvHook
                ld      (render_recv_hook_ptr),hl
                xor     a
                ld      (render_key_deferred_valid),a
                ld      hl,0
                ld      (recv_pending_count),hl
                ld      (recv_pending_ptr),hl
                xor     a
                ld      (mode0_cursor_prev_valid),a
                ret

Renderer_FeedByte:
                ld      c,a
                ld      a,c
                call    VD_FeedByte
                ret

palette_inks:
                db 0,6,2,17,18,24,20,26


; ------------------------------
; feed_vector (unchanged)
; ------------------------------
feed_vector:
                ld      a,b
                or      c
                ret     z
.fv_loop:
                ld      a,(hl)
                inc     hl
                push    bc
                push    hl
                call    TR_FeedByte
                jr      c,.fv_skip
                call    Renderer_FeedByte
.fv_skip:
                pop     hl
                pop     bc
                dec     bc
                ld      a,b
                or      c
                jr      nz,.fv_loop
                ret

TR_FeedByte:
                ld      b,a
                ld      a,(tr_skip_count)
                or      a
                jr      z,.tr_check_iac
                dec     a
                ld      (tr_skip_count),a
                scf
                ret
.tr_check_iac:
                ld      a,b
                cp      $FF
                jr      nz,.tr_keep
                ld      a,2
                ld      (tr_skip_count),a
                scf
                ret
.tr_keep:
                ld      a,b
                or      a
                and     a
                ret

tr_skip_count:  db 0
sock_status_ptr: dw 0

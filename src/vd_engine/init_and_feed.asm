; Initializes buffer and cursor
VD_Init:
                xor     a
                ld      (vd_cursor_x),a
                ld      (vd_cursor_y),a
                ld      (vd_esc_state),a
                ld      (vd_iac_state),a
                ld      (vd_last_write_valid),a
                ld      (vd_force_row_valid),a
                ld      (vd_force_row_y),a
                ld      (vd_dirty_any),a
                call    vd_reset_row_state
                ld      a,1
                ld      (vd_cursor_on),a
                ld      (vd_dirty_any),a

                call    Mode0_ResetDirtyBounds
                ld      hl,vd_buffer
                ld      bc,VD_BUF_SIZE
                ld      d,' '
.vd_clear_loop:
                ld      a,d
                ld      (hl),a
                inc     hl
                dec     bc
                ld      a,b
                or      c
                jr      nz,.vd_clear_loop

                ld      hl,vd_attr
                ld      bc,VD_BUF_SIZE
                call    vd_make_attr
                ld      d,a
.vd_clear_attr_loop:
                ld      a,d
                ld      (hl),a
                inc     hl
                dec     bc
                ld      a,b
                or      c
                jr      nz,.vd_clear_attr_loop

                ld      hl,vd_mosaic
                ld      bc,VD_BUF_SIZE
                xor     a
                ld      d,a
.vd_clear_mosaic_loop:
                ld      a,d
                ld      (hl),a
                inc     hl
                dec     bc
                ld      a,b
                or      c
                jr      nz,.vd_clear_mosaic_loop

                ld      hl,vd_flags
                ld      bc,VD_BUF_SIZE
                ld      a,FLAG_DIRTY
                ld      d,a
.vd_clear_flags_loop:
                ld      a,d
                ld      (hl),a
                inc     hl
                dec     bc
                ld      a,b
                or      c
                jr      nz,.vd_clear_flags_loop

                ld      hl,vd_dirty_rows
                ld      b,VD_HEIGHT
                ld      a,1
.vd_clear_dirty_rows:
                ld      (hl),a
                inc     hl
                djnz    .vd_clear_dirty_rows
                ret

; Clear ESC stats counters (useful before feeding a capture).
VD_ResetEscCounts:
                ld      hl,esc_first_counts
                ld      bc,512
                xor     a
.vd_clear_esc_counts:
                ld      (hl),a
                inc     hl
                dec     bc
                ld      a,b
                or      c
                jr      nz,.vd_clear_esc_counts
                ret

; Feed one byte in A. Consumes IAC filter and ESC sequences.
VD_FeedByte:
                ; Keep the raw byte for telnet/IAC handling, then strip parity
                ; only for viewdata/control decoding.
                ld      c,a
                ld      b,a
                ld      a,(vd_iac_state)
                or      a
                jr      z,.vd_prepare_data
                cp      1
                jr      z,.vd_iac_cmd
                cp      2
                jr      z,.vd_iac_skip_opt
                cp      3
                jr      z,.vd_iac_sb
                jr      .vd_iac_sb_ff

.vd_iac_cmd:
                ld      a,b
                cp      $FA
                jr      z,.vd_iac_sb_start
                cp      $FB
                jr      z,.vd_iac_need_opt
                cp      $FC
                jr      z,.vd_iac_need_opt
                cp      $FD
                jr      z,.vd_iac_need_opt
                cp      $FE
                jr      z,.vd_iac_need_opt
                ; Single-byte IAC command (or escaped IAC): consume command only.
                xor     a
                ld      (vd_iac_state),a
                ret

.vd_iac_need_opt:
                ld      a,2
                ld      (vd_iac_state),a
                ret

.vd_iac_sb_start:
                ld      a,3
                ld      (vd_iac_state),a
                ret

.vd_iac_skip_opt:
                xor     a
                ld      (vd_iac_state),a
                ret

.vd_iac_sb:
                ld      a,b
                cp      $FF
                ret     nz
                ld      a,4
                ld      (vd_iac_state),a
                ret

.vd_iac_sb_ff:
                ld      a,b
                cp      $F0
                jr      z,.vd_iac_sb_end
                cp      $FF
                jr      z,.vd_iac_sb_ff_stay
                ld      a,3
                ld      (vd_iac_state),a
                ret

.vd_iac_sb_ff_stay:
                ret

.vd_iac_sb_end:
                xor     a
                ld      (vd_iac_state),a
                ret

.vd_prepare_data:
                ; Telnet IAC must take precedence over display ESC state.
                ; If an IAC arrives while ESC parsing is in-flight, swallow it
                ; into the IAC state machine instead of treating it as display data.
                ld      a,c
                cp      $FF
                jr      nz,.vd_prepare_strip
                ld      a,1
                ld      (vd_iac_state),a
                ret
.vd_prepare_strip:
                ; Keep escaped path Viewdata-focused: no CSI/OSC handling.
                ld      a,c
                and     $7F
                ld      b,a

.vd_check_esc_state:
                ld      a,(vd_esc_state)
                or      a
                jp      z,.vd_check_iac
                cp      1
                jp      z,.vd_esc_expect_attr
                cp      6
                jp      z,.vd_esc_cursor_row
                cp      7
                jp      z,.vd_esc_cursor_col
                cp      8
                jp      z,vd_us_cursor_row
                cp      9
                jp      z,vd_us_cursor_col
                ld      a,b
                call    vd_handle_esc_control
                xor     a
                ld      (vd_esc_state),a
                ret

.vd_esc_expect_attr:
                ld      a,b
                cp      '='
                jp      z,.vd_esc_cursor_start
                call    vd_handle_esc_control
                xor     a
                ld      (vd_esc_state),a
                ret

.vd_esc_cursor_start:
                ld      a,6
                ld      (vd_esc_state),a
                ret

.vd_esc_cursor_row:
                ld      a,b
                ld      (vd_esc_row_tmp),a
                ld      a,7
                ld      (vd_esc_state),a
                ret

.vd_esc_cursor_col:
                ld      a,(vd_esc_row_tmp)
                sub     32
                jr      c,.vd_esc_cursor_done
                cp      VD_HEIGHT
                jr      c,.vd_esc_row_ok
                jr      nz,.vd_esc_cursor_done
                dec     a
.vd_esc_row_ok:
                ld      (vd_cursor_y),a
                ld      a,b
                sub     32
                jr      c,.vd_esc_cursor_done
                cp      VD_WIDTH
                jr      c,.vd_esc_col_ok
                jr      nz,.vd_esc_cursor_done
                dec     a
.vd_esc_col_ok:
                ld      (vd_cursor_x),a
.vd_esc_cursor_done:
                xor     a
                ld      (vd_esc_state),a
                ret

.vd_esc_newbg_start:
                ld      a,3
                ld      (vd_esc_state),a
                ret

.vd_esc_newbg_pending:
                ld      a,b
                cp      '0'
                jr      c,.vd_newbg_check_semi
                cp      '9'+1
                jr      c,.vd_newbg_to_osc
.vd_newbg_check_semi:
                cp      ';'
                jr      z,.vd_newbg_to_osc
                ; Treat as native Viewdata NEW_BACKGROUND control, then
                ; reprocess current byte as normal input.
                ld      a,(vd_cur_fg)
                ld      (vd_cur_bg),a
                call    vd_write_control_current
                xor     a
                ld      (vd_esc_state),a
                jp      .vd_check_iac
.vd_newbg_to_osc:
                ld      a,4
                ld      (vd_esc_state),a
                ret

.vd_esc_osc:
                ld      a,b
                cp      $07
                jr      z,.vd_esc_osc_end
                cp      $1B
                jr      z,.vd_esc_osc_got_esc
                ret
.vd_esc_osc_got_esc:
                ld      a,5
                ld      (vd_esc_state),a
                ret
.vd_esc_osc_end:
                xor     a
                ld      (vd_esc_state),a
                ret

.vd_esc_osc_esc:
                ld      a,b
                cp      '\'
                jr      z,.vd_esc_osc_end2
                cp      $07
                jr      z,.vd_esc_osc_end2
                ld      a,4
                ld      (vd_esc_state),a
                ret
.vd_esc_osc_end2:
                xor     a
                ld      (vd_esc_state),a
                ret

.vd_esc_csi_start:
                ld      a,2
                ld      (vd_esc_state),a
                ret

.vd_esc_csi:
                ld      a,b
                cp      $40
                jr      c,.vd_esc_csi_keep
                cp      $7F
                jr      nc,.vd_esc_csi_keep
                xor     a
                ld      (vd_esc_state),a
                ret
.vd_esc_csi_keep:
                ret

.vd_check_iac:
                ld      a,c
                cp      $FF
                jr      nz,.vd_check_esc
                ld      a,1
                ld      (vd_iac_state),a
                ret

.vd_esc_clear:
                xor     a
                ld      (vd_esc_state),a
                jp      VD_Init

.vd_esc_home:
                xor     a
                ld      (vd_cursor_x),a
                ld      (vd_cursor_y),a
                ld      (vd_esc_state),a
                ret

.vd_check_esc:
                ld      a,c
                cp      $1B
                jr      nz,.vd_check_ctrl
                ld      a,1
                ld      (vd_esc_state),a
                ret

.vd_check_ctrl:
                ld      a,c
                cp      $0C
                jr      nz,.vd_check_cr
                call    VD_Init
                call    Mode0_ClearScreen
                ret

.vd_check_cr:
                cp      $0D
                jr      nz,.vd_check_lf
                xor     a
                ld      (vd_cursor_x),a
                ret

.vd_check_lf:
                cp      $0A
                jr      nz,.vd_check_vt
                call    vd_newline
                ret

.vd_check_vt:
                cp      $0B
                jr      nz,.vd_check_bs
                ld      a,(vd_cursor_y)
                or      a
                jr      nz,.vd_vt_up_dec
                ld      a,VD_HEIGHT-1
                ld      (vd_cursor_y),a
                ret
.vd_vt_up_dec:
                dec     a
                ld      (vd_cursor_y),a
                ret

.vd_check_bs:
                cp      $08
                jr      nz,.vd_check_tab
                ld      a,(vd_cursor_x)
                or      a
                jr      z,.vd_bs_wrap_prev
                dec     a
                ld      (vd_cursor_x),a
                ret
.vd_bs_wrap_prev:
                ld      a,VD_WIDTH-1
                ld      (vd_cursor_x),a
                ld      a,(vd_cursor_y)
                or      a
                jr      nz,.vd_bs_prev_dec
                ld      a,VD_HEIGHT-1
                ld      (vd_cursor_y),a
                ret
.vd_bs_prev_dec:
                dec     a
                ld      (vd_cursor_y),a
                ret

.vd_check_tab:
                cp      $09
                jr      nz,.vd_check_home
                ld      a,(vd_cursor_x)
                inc     a
                cp      VD_WIDTH
                jr      c,.vd_tab_set
                xor     a
                ld      (vd_cursor_x),a
                call    vd_newline
                ret
.vd_tab_set:
                ld      (vd_cursor_x),a
                ret

.vd_check_home:
                cp      $1E
                jr      nz,.vd_check_cursor_ctrl
                xor     a
                ld      (vd_cursor_x),a
                ld      (vd_cursor_y),a
                ret

.vd_check_cursor_ctrl:
                cp      $1F              ; US: row/col absolute cursor address
                jr      nz,.vd_check_cursor_onoff
                ld      a,8
                ld      (vd_esc_state),a
                ret
.vd_check_cursor_onoff:
                cp      $11              ; CURON
                jr      z,.vd_cur_on
                cp      $14              ; CUROFF
                jr      z,.vd_cur_off
                ld      a,b              ; parity-stripped fallback
                cp      $11
                jr      z,.vd_cur_on
                cp      $14
                jr      z,.vd_cur_off
                ld      a,c              ; continue normal printable path
                jr      .vd_check_printable
.vd_cur_on:
                ld      a,1
                ld      (vd_cursor_on),a
                ld      (vd_dirty_any),a
                ret
.vd_cur_off:
                ld      a,1
                ld      (vd_cursor_on),a
                ld      (vd_dirty_any),a
                ret

.vd_check_printable:
                cp      $20
                ret     c
                cp      $80
                jr      c,.vd_check_printable_ascii
                cp      $A0
                ret     c
.vd_check_printable_ascii:
                ; Accept 0x7F (used for full-block mosaics on some pages).
                cp      $80
                ret     nc
                call    vd_row_start_defaults_if_col0
                ld      a,b
                call    vd_put_char
                ret

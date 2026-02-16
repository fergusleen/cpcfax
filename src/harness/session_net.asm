dnslookup:  ld      hl,(0xFF02) ; get response buffer address
            push    hl
            pop     iy
            
            ld      hl,(0xFF06) ; get sock info
            push    hl
            pop     ix      ; ix ptr to current socket status
            

            ld      hl,cmdlookup
            call    sendcmd
            ld      a,(iy+3)
            cp      1
            jr      z,wait_lookup
            ld      a,1
            ret
            
wait_lookup:
            ld  a,(ix+0)
            cp  5           ; ip lookup in progress
            jr  z, wait_lookup
            ret
            
            
            ; actual telnet session
            ; M4 rom should be mapped as upper rom.
            
telnet_session: 
            ld      hl,(0xFF02) ; get response buffer address
            push    hl
            pop     iy
            
            ; get a socket
            
            ld      hl,cmdsocket
            call    sendcmd
            ld      a,(iy+3)
            cp      255
            ret     z
            
            ; store socket in predefined packets
            
            ld      (csocket),a
            ld      (clsocket),a
            ld      (rsocket),a
            ld      (sendsock),a
            
            
            ; multiply by 16 and add to socket status buffer
            
            sla     a
            sla     a
            sla     a
            sla     a
            
            ld      hl,(0xFF06) ; get sock info
            ld      e,a
            ld      d,0
            add     hl,de   ; sockinfo + (socket*4)
            push    hl
            pop     ix      ; ix ptr to current socket status
            ld      (sock_status_ptr),hl
            
            ; connect to server
            
            ld      hl,cmdconnect
            call    sendcmd
            ld      a,(iy+3)
            cp      255
            jp      z,exit_close
wait_connect:
            ld      a,(ix)          ; get socket status  (0 ==IDLE (OK), 1 == connect in progress, 2 == send in progress)
            cp      1               ; connect in progress?
            jr      z,wait_connect
            cp      0
            jr      z,connect_ok
            call    disp_error  
            jp      exit_close
connect_ok: ld      hl,msgconnect
            call    disptextz
            call    send_telnet_init
            call    Renderer_Init
            call    txq_reset
            
            ; [NEW] Reset IAC State Machine
            xor     a
            ld      (harness_iac_state),a
        
mainloop:   
            ; 1. Flush any queued output bytes
            call    try_flush_pending_tx
            
            ; 2. Poll for one byte of input (non-blocking)
            ld      bc,1
            call    recv_noblock
            
            ; 3. Poll keyboard
            call    km_read_char
            jr      nc,.ml_render_slice
            
            ; 3b. Handle Key
            cp      0xFC            ; ESC?
            jp      z, exit_close   
            call    queue_key_for_send
            
            ; 4. Cooperative Multitasking: Render one dirty cell (or scan for one)
.ml_render_slice:
            call    Sound_Tick
            call    Render_Tick
            jp      mainloop

queue_key_for_send:
            call    normalize_outgoing_key
            push    af
            call    Sound_QueueKeyEvent
            pop     af
            jp      txq_enqueue_with_retry


.q_single:
            jp      txq_enqueue_with_retry

Render_M4KeyHook:
            ld      b,a
            call    queue_key_for_send
            jr      c,.rm4k_defer
            call    try_flush_pending_tx
            xor     a
            ld      (render_key_deferred_valid),a
            ret
.rm4k_defer:
            ld      a,b
            ld      (render_key_deferred),a
            ld      a,1
            ld      (render_key_deferred_valid),a
            ret

Render_M4FlushHook:
            call    try_flush_pending_tx
            ret

Render_M4RecvHook:
            call    recv_noblock
            ret

Sound_QueueKeyEvent:
            ld      a,(snd_key_level)
            cp      SND_KEY_PEAK
            ret     nc
            ld      a,SND_KEY_PEAK
            ld      (snd_key_level),a
            ret

Sound_Tick:
            ld      a,(snd_tick_div)
            inc     a
            and     SND_TICK_MASK
            ld      (snd_tick_div),a
            ret     nz

            ld      a,(snd_key_level)
            or      a
            jr      z,.st_key_done
            dec     a
            ld      (snd_key_level),a
.st_key_done:
            ld      a,(snd_key_level)
            ld      b,a
            cp      16
            jr      c,.st_vol_ok
            ld      a,15
.st_vol_ok:
            ld      b,a
            ld      a,(snd_last_vol)
            cp      b
            ret     z
            ld      a,b
            ld      (snd_last_vol),a
            ld      c,a
            ld      a,8
            call    MC_SOUND_REGISTER
            ret

Sound_Init:
            xor     a
            ld      (snd_key_level),a
            ld      (snd_tick_div),a
            ld      a,0xFF
            ld      (snd_last_vol),a

            ld      a,6
            ld      c,SND_NOISE_PER
            call    MC_SOUND_REGISTER
            ld      a,7
            ld      c,SND_MIXER_A
            call    MC_SOUND_REGISTER
            xor     a
            ld      c,a
            ld      a,8
            call    MC_SOUND_REGISTER
            ld      a,9
            call    MC_SOUND_REGISTER
            ld      a,10
            call    MC_SOUND_REGISTER
            ret

normalize_outgoing_key:
            and     0x7F
            cp      0x7F
            ret     nz
            ld      a,0x08
            ret

txq_enqueue_with_retry:
            call    txq_push_a
            ret     nc
            call    try_flush_pending_tx
            call    txq_push_a
            ret

try_flush_pending_tx:
            ld      hl,(sock_status_ptr)
            ld      a,(hl)
            cp      2           ; send in progress?
            ret     z
            cp      3
            jr      z,.tft_err
            cp      240
            jr      nc,.tft_err
            call    txq_pop_a
            ret     c
            ld      hl,sendtext
            ld      (hl),a
            ld      a,6
            ld      (cmdsend),a
            ld      a,1
            ld      (sendsize),a
            xor     a
            ld      (sendsize+1),a
            ld      hl,cmdsend
            call    sendcmd
            ret
.tft_err:
            call    disp_error
            jp      exit_close

txq_reset:
            xor     a
            ld      (txq_head),a
            ld      (txq_tail),a
            ret

txq_push_a:
            ld      b,a
            ld      a,(txq_tail)
            ld      e,a             ; old tail
            inc     a
            and     TXQ_MASK
            ld      c,a             ; next tail
            ld      a,(txq_head)
            cp      c
            jr      z,.txq_full
            ld      d,0
            ld      hl,txq_buf
            add     hl,de
            ld      a,b
            ld      (hl),a
            ld      a,c
            ld      (txq_tail),a
            or      a               ; CY=0
            ret
.txq_full:
            scf
            ret

txq_pop_a:
            ld      a,(txq_head)
            ld      e,a
            ld      a,(txq_tail)
            cp      e
            jr      z,.txq_empty
            ld      d,0
            ld      hl,txq_buf
            add     hl,de
            ld      a,(hl)
            ld      b,a
            inc     e
            ld      a,e
            and     TXQ_MASK
            ld      (txq_head),a
            ld      a,b
            or      a               ; CY=0
            ret
.txq_empty:
            scf
            ret

wait_send_ready_or_close:
            call    socket_wait_send_ready
            ret     nc
            call    disp_error
            jp      exit_close

socket_wait_send_ready:
.sws_wait:  ld      a,(ix)
            cp      2           ; send in progress?
            jr      z,.sws_wait
            cp      0
            ret     z
            cp      3
            jr      z,.sws_fail
            cp      240
            jr      nc,.sws_fail
            or      a
            ret
.sws_fail:  scf
            ret

                ; call when CMD (0xFF) detected, read next two bytes of command
                ; IY = socket structure ptr
send_telnet_init:
                ; IAC DO SUPPRESS-GO-AHEAD (FF FD 03) => full speed
            call    wait_send_ready_or_close

            ld      a,8
            ld      (cmdsend),a
            ld      hl,sendsize
            ld      (hl),3
            inc     hl
            ld      (hl),0
            inc     hl
            ld      (hl),0xFF       ; IAC
            inc     hl
            ld      (hl),0xFD       ; DO
            inc     hl
            ld      (hl),0x03       ; SUPPRESS-GO-AHEAD
            ld      hl,cmdsend
            call    sendcmd
            ret

            ; Helper to send IAC negotiation reply
            ; B = CMD (e.g. WONT/DONT/WILL/DO)
            ; C = OPTION
reply_iac_cmd:
            push    af
            push    bc
            push    de
            push    hl
            push    ix
            push    iy
            
            call    wait_send_ready_or_close
            
            ld      a,8             ; Packet Length (Header + 3 bytes payload)
            ld      (cmdsend),a
            ld      hl,sendsize
            ld      (hl),3          ; Data Size
            inc     hl
            ld      (hl),0
            
            ld      hl,sendtext
            ld      (hl),0xFF       ; IAC
            inc     hl
            ld      (hl),b          ; Command
            inc     hl
            ld      (hl),c          ; Option Code
            
            ld      hl,cmdsend
            call    sendcmd
            
            pop     iy
            pop     ix
            pop     hl
            pop     de
            pop     bc
            pop     af
            ret

; In: B = Received Command (DO/DONT/WILL/WONT)
; In: C = Option Code
perform_negotiation:
            ; Check Option Code
            ld      a,c
            cp      0x01        ; ECHO
            jr      z,.pn_accept
            cp      0x03        ; SUPPRESS GO AHEAD
            jr      z,.pn_accept
            jr      .pn_refuse

.pn_accept:
            ; If DO (253) -> Reply WILL (251)
            ; If WILL (251) -> Reply DO (253)
            ld      a,b
            cp      253
            jr      z,.pn_send_will
            cp      251
            jr      z,.pn_send_do
            ; Else (DONT/WONT) just ignore or confirm? 
            ; Usually if they say DONT, we say WONT.
            cp      254
            jr      z,.pn_send_wont
            cp      252
            jr      z,.pn_send_dont
            ret

.pn_refuse:
            ; If DO -> WONT
            ; If WILL -> DONT
            ld      a,b
            cp      253
            jr      z,.pn_send_wont
            cp      251
            jr      z,.pn_send_dont
            ret

.pn_send_will:
            ld      b,251
            jp      reply_iac_cmd
.pn_send_do:
            ld      b,253
            jp      reply_iac_cmd
.pn_send_wont:
            ld      b,252
            jp      reply_iac_cmd
.pn_send_dont:
            ld      b,254
            jp      reply_iac_cmd


recv_noblock:
            push    af
            push    bc
            push    de
            push    hl

            ld      hl,(recv_pending_count)
            ld      a,h
            or      l
            jr      nz,.rn_consume_one

            ld      bc,RX_RECV_CHUNK
            call    recv
            cp      0xFF
            jp      z, exit_close   
            cp      3
            jp      z, exit_close
            ld      a,b
            or      c
            jp      z,.rn_done

            ; Check byte for IAC handling (Byte-by-Byte state machine)
            ; Copy to safe buffer first
            push    bc          ; Save length
            push    iy
            pop     hl
            ld      de,6
            add     hl,de       ; HL = Source (M4 Buffer + 6)
            ld      de,net_recv_buf
            ldir                ; Copy BC bytes to safe buffer
            pop     bc          ; Restore length

            ld      (recv_pending_count),bc
            ld      hl,net_recv_buf
            ld      (recv_pending_ptr),hl

.rn_consume_one:
            ld      hl,(recv_pending_ptr)
            ld      a,(hl)
            
            ; --- IAC STATE MACHINE ---
            push    hl
            ld      hl,harness_iac_state
            ld      b,(hl)
            ld      c,a     ; Current Byte
            
            ld      a,b     ; State
            or      a
            jr      z,.iac_st_0_normal
            cp      1
            jr      z,.iac_st_1_gotiac
            cp      2
            jr      z,.iac_st_2_gotcmd
            jr      .iac_reset ; Error, reset

.iac_st_0_normal:
            ld      a,c
            cp      0xFF
            jr      nz,.iac_pass_through
            ; Found IAC
            ld      a,1
            ld      (harness_iac_state),a
            jr      .iac_consume_byte

.iac_st_1_gotiac:
            ld      a,c
            cp      0xFF
            jr      z,.iac_literal_ff   ; Double FF = Literal FF
            cp      250
            jr      c,.iac_reset        ; Simple commands (SE, NOP) or invalid? Ignore for now.
            ; Complex commands (DO/DONT/WILL/WONT are 251-254)
            ld      (harness_iac_cmd),a ; Save Command
            ld      a,2
            ld      (harness_iac_state),a
            jr      .iac_consume_byte
.iac_literal_ff:
            xor     a
            ld      (harness_iac_state),a
            ld      a,0xFF
            jr      .iac_pass_through

.iac_st_2_gotcmd:
            ; C is the Option Code
            push    bc
            ld      a,(harness_iac_cmd)
            ld      b,a
            ; C is already option
            call    perform_negotiation
            pop     bc
            xor     a
            ld      (harness_iac_state),a
            jr      .iac_consume_byte

.iac_reset:
            xor     a
            ld      (harness_iac_state),a
            jr      .iac_consume_byte

.iac_consume_byte:
            ; Don't pass to renderer
            pop     hl
            jr      .rn_next_byte

.iac_pass_through:
            pop     hl
            ld      a,c
            push    ix
            push    iy
            call    Renderer_FeedByte
            pop     iy
            pop     ix
            ; Fall through to next byte

.rn_next_byte:
            ld      hl,(recv_pending_ptr)
            inc     hl
            ld      (recv_pending_ptr),hl
            ld      bc,(recv_pending_count)
            dec     bc
            ld      (recv_pending_count),bc
            ld      a,b
            or      c
            jr      nz,.rn_consume_one

.rn_done:
            pop     hl
            pop     de
            pop     bc
            pop     af
            ret

drain_rx_pending:
            push    af
            push    bc
            push    de
            push    hl
            push    ix
            push    iy
            xor     a
            ld      (recv_pending_count),a
            ld      (recv_pending_count+1),a
            ld      e,8
.drain_loop:
            ld      bc,64
            call    recv
            cp      0xFF
            jr      z,.drain_done
            cp      3
            jr      z,.drain_done
            ld      a,b
            or      c
            jr      z,.drain_done
            dec     e
            jr      nz,.drain_loop
.drain_done:
            pop     iy
            pop     ix
            pop     hl
            pop     de
            pop     bc
            pop     af
            ret
            

exit_close:
            push    af
            ld      hl,cmdclose
            call    sendcmd
            pop     af
            call    disp_error
            ld      sp, $BFF0
            jp      loop_ip
            
            ; recv tcp data
            ; in
            ; bc = receive size
            ; out
            ; a = receive status
            ; bc = received size 

            
recv:       ; connection still active
            ld      hl,(sock_status_ptr)
            ld      a,(hl)          ; 
            cp      3               ; socket status  (3 == remote closed connection)
            ret     z
            ; check if anything in buffer ?
            ld      de,2
            add     hl,de
            ld      a,(hl)
            cp      0
            jr      nz,recv_cont
            inc     hl
            ld      a,(hl)
            cp      0
            jr      nz,recv_cont
            ld      bc,0
            ld      a,1 
            ret
recv_cont:          
            ; set receive size
            ld      a,c
            ld      (rsize),a
            ld      a,b
            ld      (rsize+1),a
            
            ld      hl,cmdrecv
            call    sendcmd
            
            ld      a,(iy+3)
            cp      0               ; all good ?
            jr      z,recv_ok
            ld      bc,0
            ret

recv_ok:            
            ld      c,(iy+4)
            ld      b,(iy+5)
            ret
            
            
            ;
            ; Find M4 ROM location
            ;
                
find_m4_rom:
            ld      iy,m4_rom_name  ; rom identification line
            ld      d,127       ; start looking for from (counting downwards)
            
romloop:    push    de
            ld      c,d
            call    kl_rom_select       ; system/interrupt friendly
            ld      a,(0xC000)
            cp      1
            jr      nz, not_this_rom
            ld      hl,(0xC004) ; get rsxcommand_table
            push    iy
            pop     de
cmp_loop:
            ld      a,(de)
            xor     (hl)            ; hl points at rom name
            jr      z, match_char
not_this_rom:
            pop     de
            dec     d
            jr      nz, romloop
            ld      a,255       ; not found!
            ret
            
match_char:
            ld      a,(de)
            inc     hl
            inc     de
            and     0x80
            jr      z,cmp_loop
            
            ; rom found, store the rom number
            
            pop     de          ;  rom number
            ld      a,d
            ld      (m4_rom_num),a
            ret
            
            ;
            ; Send command to M4
            ; HL = packet to send
            ;
sendcmd:
            push    hl
            ld      a,(m4_rom_num)
            ld      c,a
            call    kl_rom_select
            ld      iy,(0xFF02)
            pop     hl
            ld      bc,0xFE00
            ld      d,(hl)
            inc     d
sendloop:   inc     b
            outi
            dec     d
            jr      nz,sendloop
            ld      bc,0xFC00
            out     (c),c
            ret

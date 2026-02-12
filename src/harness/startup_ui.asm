start:      di
            ld      sp,$BFF0
            ei
            ld      a,2
            call    scr_reset       ; set mode 1
            call    setup_startup_palette
            
            ; find rom M4 rom number
            
            ld      a,(m4_rom_num)
            cp      0xFF
            call    z,find_m4_rom   
            cp      0xFF
            jr      nz, found_m4
            
            ld      hl,msgnom4
            call    disptextz
            jp      exit
            
found_m4:   ld      hl,(0xFF00) ; get version
            
            ; compare version
            
            ld      de,0x110        ; v1.1.0 lowest version required
            ld      a,h
            xor     d
            jp      m,cmpgte2
            sbc     hl,de
            jr      nc,cmpgte3
cmpgte1:    ld      hl,msgverfail
            call    disptextz
            jp      exit
cmpgte2:    bit     7,d
            jr      z,cmpgte1
cmpgte3:

            ; ask for server / ip
loop_ip:
            call    draw_startup_screen
            call    choose_profile
            cp      0xFC
            jp      z, exit
            call    apply_profile_preset
            call    get_server
            cp      0
            jr      nz, loop_ip
            
            call    show_connecting_status
            call    telnet_session
            jr      loop_ip
            
exit:
            jp      km_wait_key

print_lownib:           
            and     0xF         ; keep lower nibble
            add     48          ; 0 + x = neric ascii
            jp      txt_output

setup_startup_palette:
            ld      a,1
            ld      b,26
            ld      c,26
            call    scr_set_ink
            ld      a,2
            ld      b,20
            ld      c,20
            call    scr_set_ink
            ld      a,3
            ld      b,17
            ld      c,17
            call    scr_set_ink
            xor     a
            call    txt_set_paper
            ld      a,1
            call    txt_set_pen
            ret

draw_startup_screen:
            ld      a,1
            call    scr_reset
            call    setup_startup_palette

            ld      a,3
            call    txt_set_pen
            ld      h,1
            ld      l,1
            call    txt_set_cursor
            ld      hl,ui_line_border
            call    disptextz
            ld      h,1
            ld      l,25
            call    txt_set_cursor
            ld      hl,ui_line_border
            call    disptextz

            ld      a,1
            call    txt_set_pen
            ld      b,2
.dss_fill:
            ld      a,2
            call    txt_set_pen
            ld      h,5
            ld      l,3
            call    txt_set_cursor
            ld      hl,ui_title
            call    disptextz

            ld      a,3
            call    txt_set_pen
            ld      h,8
            ld      l,5
            call    txt_set_cursor
            ld      hl,ui_profiles
            call    disptextz

            ld      a,1
            call    txt_set_pen
            ld      h,4
            ld      l,7
            call    txt_set_cursor
            ld      hl,ui_opt1
            call    disptextz
            ld      h,4
            ld      l,8
            call    txt_set_cursor
            ld      hl,ui_opt2
            call    disptextz
            ld      h,4
            ld      l,9
            call    txt_set_cursor
            ld      hl,ui_opt3a
            call    disptextz
            ; ld        h,4
            ; ld        l,10
            ; call  txt_set_cursor
            ; ld        hl,ui_opt3b
            ; call  disptextz
            ld      h,4
            ld      l,11
            call    txt_set_cursor
            ld      hl,ui_opt4
            call    disptextz

            ld      a,2
            call    txt_set_pen
            ld      h,4
            ld      l,13
            call    txt_set_cursor
            ld      hl,ui_hostline
            call    disptextz
            ; ld        h,4
            ; ld        l,14
            ; call  txt_set_cursor
            ; ld        hl,ui_hint
            ; call  disptextz

            ld      a,3
            call    txt_set_pen
            ld      h,4
            ld      l,16
            call    txt_set_cursor
            ld      hl,msg_profile_prompt
            call    disptextz

            ld      a,2
            call    txt_set_pen
            ld      h,11
            ld      l,24
            call    txt_set_cursor
            ld      hl,ui_footer
            call    disptextz
            ret

choose_profile:
.cp_wait:
            call    km_read_char
            jr      nc,.cp_wait
            cp      0xFC
            ret     z
            cp      '1'
            jr      c,.cp_wait
            cp      '5'
            jr      nc,.cp_wait
            call    txt_output
            ret

apply_profile_preset:
            cp      '1'
            jr      z,.app_amshole
            cp      '2'
            jr      z,.app_telstar
            cp      '3'
            jr      z,.app_tet
            ld      hl,preset_other
            jr      .app_copy
.app_amshole:
            ld      hl,preset_amshole
            jr      .app_copy
.app_telstar:
            ld      hl,preset_telstar
            jr      .app_copy
.app_tet:
            ld      hl,preset_tetrachloromethane
.app_copy:
            ld      de,buf
.app_copy_loop:
            ld      a,(hl)
            ld      (de),a
            inc     hl
            inc     de
            or      a
            jr      nz,.app_copy_loop
            ret

show_connecting_status:
            ld      a,1
            call    txt_set_pen
            ld      h,4
            ld      l,18
            call    txt_set_cursor
            ld      hl,msg_status_clear
            call    disptextz
            ld      h,4
            ld      l,18
            call    txt_set_cursor
            ld      hl,msgconnecting_ui
            call    disptextz
            ld      hl,ip_addr
            call    disp_ip
            ld      hl,msgport_ui
            call    disptextz
            ld      hl,(port)
            call    disp_port
            ret
            
get_server: 
            ld      h,14
            ld      l,13
            call    txt_set_cursor
            ld      hl,buf
            call    get_textinput
            
            ;cp     0xFC            ; ESC?
            ;ret        z
            xor     a
            cp      c
            jr      z, get_server
        
            ; check if any none neric chars
            
            ld      b,c
            ld      hl,buf
check_neric:
            ld      a,(hl)
            cp      59              ; bigger than ':' ?
            jr      nc,dolookup
            inc     hl
            djnz    check_neric
            jp      convert_ip
            
            ; make dns lookup
dolookup:   
            ; copy name to packet
            
            ld      hl,buf
            ld      de,lookup_name
            ld      b,0
copydns:    ld      a,(hl)
            cp      58
            jr      z,copydns_done
            cp      0
            jr      z,copydns_done
            ld      a,b
            ldi
            inc     a
            ld      b,a
            jr      copydns
copydns_done:
            push    hl
            xor     a
            ld      (de),a      ; terminate with zero
            
            ld      hl,cmdlookup
            inc     b           
            inc     b
            inc     b
            ld      (hl),b      ; set  size
            
            ; disp servername
            
            ld      hl,msgresolve
            call    disptextz
            ld      hl,lookup_name
            call    disptextz
            
            ; do the lookup
            call    dnslookup
            pop     hl
            cp      0
            jr      z, lookup_ok
            
            ld      hl,msgfail
            call    disptextz
            ld      a,1
                

        
            ret
            
lookup_ok:  push    hl          ; contains port "offset"
            ld      hl,msgok
            call    disptextz
            
            ; copy IP from socket 0 info
            ld      hl,(0xFF06)
            ld      de,4
            add     hl,de
            ld      de,ip_addr
            ldi
            ldi
            ldi
            ldi
            pop     hl
            jr      check_port
            ; convert ascii IP to binary, no checking for non decimal chars format must be x.x.x.x
convert_ip:         
            ld      hl,buf  
            call    ascii2dec
            ld      (ip_addr+3),a
            call    ascii2dec
            ld      (ip_addr+2),a
            call    ascii2dec
            ld      (ip_addr+1),a
            call    ascii2dec
            ld      (ip_addr),a
            dec     hl
check_port: ld      a,(hl)
            cp      0x3A        ; any ':' for port number ?
            jr      nz, no_port
            
            push    hl
            pop     ix
            call    port2dec
            
            jr      got_port
            
no_port:    ld      hl,23
got_port:   
            ld      (port),hl
            xor     a
            ret

            

msgconnclosed:  db  10,13,"Remote closed connection....",10,13,0
msgsenderror:   db  10,13,"ERROR: ",0
msgconnect:     db  10,13,"Connected.",10,13,0
msgnom4:        db  "No M4 board found, bad luck :/",10,13,0
msgverfail:     db  ", you need v1.1.0 or higher.",10,13,0
msgok:          db  ", OK.",10,13,0
msgresolve:     db  10,13, "Resolving: ",0
msgfail:        db  ", failed!", 10, 13, 0
msguserabort:   db  10,13,"User aborted (ESC)", 10, 13,0
msg_profile_prompt:
                db  "Select profile [1-4]: ",0
msgconnecting_ui:
                db  "Connecting to ",0
msgport_ui:     db  " : ",0
msg_status_clear:
                db  "                                    ",0

ui_line_border: db  "########################################",0
ui_line_blank:  db  0xe0,"                                      ",0xe0,0
ui_title:       db  "CPCFAX -M4 Viewdata Client",0
ui_profiles:    db  "Connection Profiles",0
ui_opt1:        db  "1. AMSHOLE ",0
ui_opt2:        db  "2. TELSTAR ",0
ui_opt3a:       db  "3. TETRACHLOROMETHANE",0
ui_opt3b:       db  "   (fish.ccl4.org)",0
ui_opt4:        db  "4. Other",0
ui_hostline:    db  "Host/IP: [                     ]",0
ui_hint:        db  "Press ENTER after editing host:port",0
ui_footer:      db  "kolleykibber - 2026",0

preset_amshole:
                db  "52.215.38.123:6512",0
preset_telstar:
                db  "glasstty.com:6502",0
preset_tetrachloromethane:
                db  "fish.ccl4.org",0
preset_other:   db  0
cmdsocket:      db  5
                dw  C_NETSOCKET
                db  0x0,0x0,0x6     ; domain, type, protocol (TCP/IP)

cmdconnect:     db  9   
                dw  C_NETCONNECT
csocket:        db  0
ip_addr:        db  0,0,0,0     ; ip addr
port:           dw  23      ; port

cmdsend:        db  0           ; we can ignore value of this byte (part of early design)   
                dw  C_NETSEND
sendsock:       db  0
sendsize:       dw  0           ; size
sendtext:       ds  255
txq_head:       db  0
txq_tail:       db  0
txq_buf:        ds  TXQ_SIZE
            
cmdclose:       db  0x03
                dw  C_NETCLOSE
clsocket:       db  0x0

cmdlookup:      db  16
                dw  C_NETHOSTIP
lookup_name:    ds  128

cmdrecv:        db  5
                dw  C_NETRECV   ; recv
rsocket:        db  0x0         ; socket
rsize:          dw  2048        ; size
            
m4_rom_name:    db "M4 BOAR",0xC4       ; D | 0x80
m4_rom_num: db  0xFF
curPos:         dw  0
isEscapeCode:   db  0
EscapeCount:    db  0
EscapeBuf:      ds  255
buf:            ds  255
render_key_deferred: db 0
render_key_deferred_valid: db 0
snd_key_level: db 0
snd_tick_div: db 0
snd_last_vol: db 0
recv_pending_count: dw 0
recv_pending_ptr: dw 0
harness_iac_state: db 0
harness_iac_cmd: db 0
net_recv_buf:   ds 64

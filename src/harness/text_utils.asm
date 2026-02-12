            ; display text
            ; HL = text
            ; BC = length

disptext:   xor     a
            cp      c
            jr      nz, not_dispend
            cp      b
            ret     z
not_dispend:
            ld      a,(hl)
            push    bc
            call    txt_output
            pop     bc
            inc     hl
            dec     bc
            jr      disptext

            ; display text zero terminated
            ; HL = text
disptextz:  ld      a,(hl)
            or      a
            ret     z
            call    txt_output
            inc     hl
            jr      disptextz

            ;
            ; Display error code in ascii (hex)
            ;
    
            ; a = error code
disp_error:
            cp      3
            jr      nz, not_rc3
            ld      hl,msgconnclosed
            jp      disptextz
not_rc3:    cp      0xFC
            jr      nz,notuser
            ld      hl,msguserabort
            jp      start
            jp      disptextz

notuser:
            push    af
            ld      hl,msgsenderror
            ld      bc,9
            call    disptext
            pop     bc
            ld      a,b
            srl     a
            srl     a
            srl     a
            srl     a
            add     a,0x90
            daa
            adc     a,0x40
            daa
            call    txt_output
            ld      a,b
            and     0x0f
            add     a,0x90
            daa
            adc     a,0x40
            daa
            call    txt_output
            ld      a,10
            call    txt_output
            ld      a,13
            call    txt_output
            ret
disphex:    ld      b,a
            srl     a
            srl     a
            srl     a
            srl     a
            add     a,0x90
            daa
            adc     a,0x40
            daa
            call    txt_output
            ld      a,b
            and     0x0f
            add     a,0x90
            daa
            adc     a,0x40
            daa
            call    txt_output
            ld      a,32
            call    txt_output
            ret

            ;
            ; Get input text line.
            ;
            ; in
            ; hl = dest buf
            ; return
            ; bc = out size
get_textinput:      
            ld  bc,0
            call    txt_cur_on  
.ti_prefill:
            ld      a,(hl)
            or      a
            jr      z,inputloop
            push    hl
            push    bc
            call    txt_output
            pop     bc
            pop     hl
            inc     hl
            inc     bc
            jr      .ti_prefill
inputloop:
            
re:         call    mc_wait_flyback
            call    km_read_char
            jr      nc,re

            cp      0x7F
            jr      nz, not_delkey
            ld      a,c
            cp      0
            jr      z, inputloop
            push    hl
            push    bc
            call    txt_get_cursor
            dec     h
            push    hl
            call    txt_set_cursor
            ld      a,32
            call    txt_output
            pop     hl
            call    txt_set_cursor
            pop     bc
            pop     hl
            dec     hl
            dec     bc
            jr      inputloop
not_delkey: 
            cp      13
            jr      z, terminate
            cp      0xFC
            ret     z
            cp      32
            jr      c, inputloop
            cp      0x7e
            jr      nc, inputloop
            ld      (hl),a
            inc     hl
            inc     bc
            push    hl
            push    bc
            call    txt_output
            call    txt_get_cursor
            ;push   hl
            ;ld     a,32
            ;call   txt_output
            ;pop    hl
            call    txt_set_cursor
            pop     bc
            pop     hl
            jp      inputloop
terminate:  ld      (hl),0
            ret

            
            ;
            ; Get input text line, accept only neric and .
            ;
            ; in
            ; hl = dest buf
            ; return
            ; bc = out size
get_textinput_ip:       
            ld  bc,0
            call    txt_cur_on  
inputloop2:
            
re2:        call    mc_wait_flyback
            call    km_read_char
            jr      nc,re2

            cp      0x7F
            jr      nz, not_delkey2
            ld      a,c
            cp      0
            jr      z, inputloop2
            push    hl
            push    bc
            call    txt_get_cursor
            dec h
            push    hl
            call    txt_set_cursor
            ld      a,32
            call    txt_output
            pop hl
            call    txt_set_cursor
            pop     bc
            pop     hl
            dec     hl
            dec     bc
            jr      inputloop2
not_delkey2:    
            cp      13
            jr      z, enterkey2
            cp      0xFC
            ret     z
            cp      46              ; less than '.'
            jr      c, inputloop2
            cp      59              ; bigger than ':' ?
            jr      nc, inputloop2
            
            
            ld      (hl),a
            inc     hl
            inc     bc
            push    hl
            push    bc
            call    txt_output
            call    txt_get_cursor
            ;push   hl
            ;ld     a,32
            ;call   txt_output
            ;pop    hl
            call    txt_set_cursor
            pop     bc
            pop     hl
            jp      inputloop2
enterkey2:  ld      (hl),0
            ret
            
            
crlf:       ld      a,10
            call    txt_output
            ld      a,13
            jp      txt_output

            
            ; HL = point to IP addr
            
disp_ip:    ld      bc,3
            add     hl,bc
            ld      b,3
disp_ip_loop:
            push    hl
            push    bc
            call    dispdec
            pop     bc
            pop     hl
            dec     hl
            ld      a,0x2e
            call    txt_output
            djnz    disp_ip_loop
            
            jp      dispdec ; last digit
            
            
dispdec:    ld      e,0
            ld      a,(hl)
            ld      l,a
            ld      h,0
            ld      bc,-100
            call    n1
            cp      '0'
            jr      nz,notlead0
            ld      e,1
notlead0:   call    nz,txt_output
            ld      c,-10
            call    n1
            cp      '0'
            jr      z, lead0_2
            call    txt_output
lead0_2_cont:   
            ld      c,b
            call    n1
            jp      txt_output
            
n1:         ld      a,'0'-1
n2:         inc     a
            add     hl,bc
            jr      c,n2
            sbc     hl,bc
            ret
lead0_2:
            ld      d,a
            xor     a
            cp      e
            ld      a,d
            call    z,txt_output
            jr      lead0_2_cont
                        
            ; ix = points to :portnumber
            ; hl = return 16 bit number
            
port2dec:
count_digits:
            inc     ix
            ld      a,(ix)
            cp      0
            jr      nz,count_digits
            dec     ix
            ld      a,(ix)
            cp      0x3A
            ret     z
            sub     48
            ld      l,a         ; *1
            ld      h,0
            
            
            dec     ix
            ld      a,(ix)
            cp      0x3A
            ret     z
            sub     48

            push    hl
            ld      e,a
            ld      d,0
            ld      bc,10
            call    mul16       ; *10
            pop     de
            add     hl,de       
            dec     ix
            ld      a,(ix)
            cp      0x3A
            ret     z
            sub     48
            
            push    hl
            ld      e,a
            ld      d,0
            ld      bc,100
            call    mul16       ; *100
            pop     de
            add     hl,de       
            dec     ix
            ld      a,(ix)
            cp      0x3A
            ret     z
            sub     48
            
            push    hl
            ld      e,a
            ld      d,0
            ld      bc,1000
            call    mul16       ; *1000
            pop     de
            add     hl,de       
            dec     ix
            ld      a,(ix)
            cp      0x3A
            ret     z
            sub     48
            
            push    hl
            ld      e,a
            ld      d,0
            ld      bc,10000
            call    mul16       ; *10000
            pop     de
            add     hl,de       
            ret
                        
ascii2dec:  ld      d,0
loop2e:     ld      a,(hl)
            cp      0
            jr      z,found2e
            cp      0x3A        ; ':' port seperator ?
            jr      z,found2e
            
            cp      0x2e
            jr      z,found2e
            ; convert to decimal
            cp      0x41    ; a ?
            jr      nc,less_than_a
            sub     0x30    ; - '0'
            jr      next_dec
less_than_a:    
            sub     0x37    ; - ('A'-10)
next_dec:       
            ld      (hl),a
            inc     hl
            inc     d
            dec     bc
            xor     a
            cp      c
            ret     z
            jr      loop2e
found2e:
            push    hl
            call    dec2bin
            pop     hl
            inc     hl
            ret
dec2bin:    dec     hl
            ld      a,(hl)
            dec     hl
            dec     d
            ret     z
            ld      b,(hl)
            inc     b
            dec     b
            jr      z,skipmul10
mul10:      add     10
            djnz    mul10
skipmul10:  dec     d
            ret     z
            dec     hl
            ld      b,(hl)
            inc     b
            dec     b
            ret     z
mul100:     add     100
            djnz    mul100
            ret
            
            ; BC*DE

mul16:      ld  hl,0
            ld  a,16
mul16Loop:  add hl,hl
            rl  e
            rl  d
            jp  nc,nomul16
            add hl,bc
            jp  nc,nomul16
            inc de
nomul16:
            dec a
            jp  nz,mul16Loop
            ret
escape_val: cp      2
            jr      nz, has_value
            xor     a
            ret
has_value:  ld      d,0
            sub     2
            ld      e,a
dec_loop2:
            ld      a,(hl)
            cp      0x41    ; a ?
            jr      nc,less_than_a2
            sub     0x30    ; - '0'
            jr      next_dec2
less_than_a2:   
            sub     0x37    ; - ('A'-10)
next_dec2:  inc hl
            cp  0
            jr  nz, do_mul
            dec e
            jr  nz, dec_loop2
            ld  a,d
            ret
do_mul:     ld  b,a
            ld  a,e
            cp  3
            jr  nz, not_3digits
            xor a
a_mul100:       add 100
            djnz    a_mul100
            ld  d,a
            dec e
            jr  nz, dec_loop2
            ret
not_3digits:        cp  2
            jr  nz, not_2digits
            xor a
a_mul10:        add 10
            djnz    a_mul10
            add d           
            ld  d,a
            dec e
            jr  nz, dec_loop2
            ret
            ld  a,d
not_2digits:    ld  a,b
            add d
            ret         
            
disp_port:
            ld      bc,-10000
            call    n16_1
            cp      48
            jr      nz,not16_lead0
            ld      bc,-1000
            call    n16_1
            cp      48
            jr      nz,not16_lead1
            ld      bc,-100
            call    n16_1
            cp      48
            jr      nz,not16_lead2
            ld      bc,-10
            call    n16_1
            cp      48
            jr      nz, not16_lead3
            jr      not16_lead4
    
not16_lead0:
            call    txt_output
            ld      bc,-1000
            call    n16_1
not16_lead1:
            call    txt_output
            ld      bc,-100
            call    n16_1
not16_lead2:
            call    txt_output
            ld      c,-10
            call    n16_1
not16_lead3:
            call    txt_output
not16_lead4:
            ld      c,b
            call    n16_1
            call    txt_output
            ret
n16_1:
            ld      a,'0'-1
n16_2:
            inc     a
            add     hl,bc
            jr      c,n16_2
            sbc     hl,bc

            ;ld     (de),a
            ;inc    de
            
            ret         

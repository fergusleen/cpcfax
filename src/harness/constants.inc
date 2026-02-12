DATAPORT        equ 0xFE00
ACKPORT         equ 0xFC00          

; m4 commands used
C_NETSOCKET     equ 0x4331
C_NETCONNECT    equ 0x4332
C_NETCLOSE      equ 0x4333
C_NETSEND       equ 0x4334
C_NETRECV       equ 0x4335
C_NETHOSTIP     equ 0x4336

; firmware functions used
km_read_char    equ 0xBB09
km_wait_key     equ 0xBB18
txt_output      equ 0xBB5A
txt_set_column  equ 0xBB6F
txt_set_row     equ 0xBB72
txt_set_cursor  equ 0xBB75
txt_get_cursor  equ 0xBB78
txt_cur_on      equ 0xBB81
txt_set_pen     equ 0xBB90
txt_set_paper   equ 0xBB96
scr_reset       equ 0xBC0E
scr_set_ink     equ 0xBC32
scr_set_border  equ 0xBC38
mc_wait_flyback equ 0xBD19
kl_rom_select   equ 0xb90f

SCR_SET_MODE    EQU $BC0E
SCR_SET_INK     EQU $BC32
SCR_SET_BORDER  EQU $BC38
KM_WAIT_KEY     EQU $BB18
KM_READ_CHAR    EQU $BB09
MC_SOUND_REGISTER EQU $BD34

; telnet negotiation codes
DO              equ 0xfd
WONT            equ 0xfc
WILL            equ 0xfb
DONT            equ 0xfe
CMD             equ 0xff
CMD_ECHO        equ 1
CMD_WINDOW_SIZE equ 31
TXQ_SIZE        equ 32
TXQ_MASK        equ (TXQ_SIZE-1)
RX_RECV_CHUNK   equ 32
SND_TICK_MASK   equ 0x00
SND_KEY_PEAK    equ 4
SND_NOISE_PER   equ 0x03
SND_MIXER_A     equ 0x37

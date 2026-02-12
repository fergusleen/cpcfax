; CPCFAX - M4 Viewdata Client
; Jan 2026 - https://github.com/fergusleen/cpcfax


            INCLUDE "vd_engine.inc"

            org 0x1000
; nolist

            INCLUDE "harness/constants.inc"
            INCLUDE "harness/startup_ui.asm"
            INCLUDE "harness/session_net.asm"
            INCLUDE "harness/text_utils.asm"
            INCLUDE "harness/data.asm"
            INCLUDE "harness/renderer_bridge.asm"

            INCLUDE "render_mode0.asm"
            INCLUDE "vd_engine.asm"

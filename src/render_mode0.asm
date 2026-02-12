; -----------------------------------------------------------------------------
; render_mode0.asm
; Optimized Mode 0 Renderer for Amstrad CPC Viewdata
; -----------------------------------------------------------------------------

                INCLUDE "render_mode0/constants.inc"
                INCLUDE "render_mode0/helpers.asm"
                INCLUDE "render_mode0/tick_and_dirty.asm"
                INCLUDE "render_mode0/cell_render.asm"
                INCLUDE "render_mode0/mosaic_helpers.asm"
                INCLUDE "render_mode0/data_and_tables.asm"
                INCLUDE "screen_lut_mode0.inc"
                INCLUDE "font4x8.inc"

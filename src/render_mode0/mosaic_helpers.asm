; ------------------------------------------------------------
; Logic-based Mosaic Helpers
; ------------------------------------------------------------

Mode0_MosaicNibble:
                push    de
                ld      a,(mode0_noncontig)
                or      a
                jr      z,.m0mn_contig_band

                ld      a,(mode0_scanline)
                cp      2
                jr      c,.m0mn_top_sep
                cp      3
                jr      c,.m0mn_gap
                cp      5
                jr      c,.m0mn_mid_sep
                cp      6
                jr      c,.m0mn_gap
                jr      .m0mn_bot_sep

.m0mn_contig_band:
                ld      a,(mode0_scanline)
                cp      2
                jr      c,.m0mn_top_contig
                cp      5
                jr      c,.m0mn_mid_contig
                jr      .m0mn_bot_contig

.m0mn_top_contig:
                ld      b,$01
                ld      c,$02
                ld      d,$0C
                ld      e,$03
                jr      .m0mn_build
.m0mn_mid_contig:
                ld      b,$04
                ld      c,$08
                ld      d,$0C
                ld      e,$03
                jr      .m0mn_build
.m0mn_bot_contig:
                ld      b,$10
                ld      c,$20
                ld      d,$0C
                ld      e,$03
                jr      .m0mn_build

.m0mn_top_sep:
                ld      b,$01
                ld      c,$02
                ld      d,$08
                ld      e,$02
                jr      .m0mn_build
.m0mn_mid_sep:
                ld      b,$04
                ld      c,$08
                ld      d,$08
                ld      e,$02
                jr      .m0mn_build
.m0mn_bot_sep:
                ld      b,$10
                ld      c,$20
                ld      d,$08
                ld      e,$02
                jr      .m0mn_build

.m0mn_gap:
                xor     a
                pop     de
                ret

.m0mn_build:
                ld      a,(mode0_mosaic)
                and     b
                jr      z,.m0mn_left_off
                ld      a,d
                jr      .m0mn_left_done
.m0mn_left_off:
                xor     a
.m0mn_left_done:
                ld      (mode0_tmp),a
                ld      a,(mode0_mosaic)
                and     c
                jr      z,.m0mn_right_off
                ld      a,e
                jr      .m0mn_right_done
.m0mn_right_off:
                xor     a
.m0mn_right_done:
                ld      b,a
                ld      a,(mode0_tmp)
                or      b
                pop     de
                ret

Mode0_RowHasDouble:
                ld      l,a
                ld      h,0
                add     hl,hl
                add     hl,hl
                add     hl,hl
                ld      de,hl
                add     hl,hl
                add     hl,hl
                add     hl,de
                ld      de,vd_flags
                add     hl,de
                ld      b,40          ; VD_WIDTH
.m0rhd_loop:
                ld      a,(hl)
                and     FLAG_DOUBLE
                jr      nz,.m0rhd_yes
                inc     hl
                djnz    .m0rhd_loop
                xor     a
                ret
.m0rhd_yes:
                ld      a,1
                ret

Mode0_MosaicDHUpper:
                ld      b,a
                xor     a
                bit     0,b
                jr      z,.m0mdhu_b1
                set     0,a
                set     2,a
.m0mdhu_b1:
                bit     1,b
                jr      z,.m0mdhu_b2
                set     1,a
                set     3,a
.m0mdhu_b2:
                bit     2,b
                jr      z,.m0mdhu_b3
                set     4,a
.m0mdhu_b3:
                bit     3,b
                ret     z
                set     5,a
                ret

Mode0_MosaicDHLower:
                ld      b,a
                xor     a
                bit     5,b
                jr      z,.m0mdhl_b4
                set     5,a
                set     3,a
.m0mdhl_b4:
                bit     4,b
                jr      z,.m0mdhl_b3
                set     4,a
                set     2,a
.m0mdhl_b3:
                bit     3,b
                jr      z,.m0mdhl_b2
                set     1,a
.m0mdhl_b2:
                bit     2,b
                ret     z
                set     0,a
                ret

; A very minimalistic TOS ROM replacement, used for testing without real TOS
;
; All exception pointers are set to "unhandled_error", all interrupt pointers are set to "rte",
; except VBL at $70 which will update a counter at $462 (similar to real TOS)
; SR will be set to $0300 to allow VBL interrupt and its counter
;
; In case an SCU is detected at $FF8E01 - $FF8E0D (on MegaSTE / TT), we enable
; interrupts for hsync, vsync, scc and mfp as normal TOS does (if not, "stop $2300" won't work anymore)
;
; Assemble faketos.s as a binary only using vasm, and include it in faketosData.c
;   vasmm68k_mot -nosym -devpac -showopt -o fakeTos.bin -Fbin faketos.s


	org	$e00000

TEST_PRG_BASEPAGE equ $1000

rom_header:
	bra.s	start			; Branch to 0xe00030
	dc.w	$0001			; TOS version
	dc.l	start			; Reset PC value
	dc.l	rom_header		; Pointer to ROM header
	dc.l	TEST_PRG_BASEPAGE	; End of OS BSS
	dc.l	start			; Reserved
	dc.l	$0			; Unused (GEM's MUPB)
	dc.l	$03032018		; Fake date
	dc.w	$0001			; PAL flag
	dc.w	$4c63			; Fake DOS date
	dc.l	$00000880		; Fake pointer 1 (mem pool)
	dc.l	$00000870		; Fake pointer 2 (key shift)
	dc.l	$00000800		; Addr of basepage var
	dc.l	$0			; Reserved
start:
	move	#$2700,sr
	reset
	move.b	#5,$ffff8001.w		; Fake memory config
	lea	$20000,sp		; Set up SSP

	;-- Config SCU interrupts on MegaSTE / TT
	bsr	config_scu

	;-- Set all exception vectors to "unhandled_error"
	lea	unhandled_error(pc),a1
	movea.w	#8,a0			; Start with bus error handler
	movea.w	#$1bc,a2
	bsr.s	range_set_pointer

	;-- Set all possible interrupt vectors to "rte"
	lea	rte_only(pc),a1
	movea.w	#$64,a0			; level 1-7 interrupts (hbl, vbl,...)
	movea.w	#$7c,a2
	bsr.s	range_set_pointer

	movea.w	#$100,a0		; mfp and scc interrupts
	movea.w	#$1bc,a2
	bsr.s	range_set_pointer

	;-- Set a minimal VBL interrupt to update a fake TOS VBL counter at $462
	lea	vbl_mini(pc),a1
	move.l	a1,$70.w		; Minimal VBL
	clr.l	$462			; clear fake TOS vbl counter

	lea	$fffffa00.w,a0
	move.b	#$48,17(a0)		; Configure MFP vector base

	lea	$fffffc00.w,a0
	move.b	#3,(a0)			; Reset ACIA
	move.b	#$16,(a0)		; Configure ACIA

	lea	$fa0000,a0
	cmp.l	#$abcdef42,(a0)		; Cartridge enabled?
	bne.s	no_sys_init
	dc.w	$a			; Call SYSINIT_OPCODE to init trap #1
no_sys_init:

	moveq	#0,d0
	movea.l	d0,a0
	movea.l	d0,a1
	move	#$0300,sr		; Go to user mode, allow VBL interrupt
	lea	$18000,sp		; Set up USP
	pea	TEST_PRG_BASEPAGE.w
	pea	rom_header(pc)
	jmp	TEST_PRG_BASEPAGE+$100.w


range_set_pointer:
	move.l	a1,(a0)+
	cmp.l	a2,a0
	ble.s	range_set_pointer
	rts


unhandled_err_txt:
	dc.b	"ERROR: Unhandled exception!",13,10,0
	even

unhandled_error:
	pea	unhandled_err_txt(pc)
	move.w  #9,-(sp)
	trap    #1		; Cconws
	addq.l  #6,sp

	move.w	#1,-(sp)
	move.w	#76,-(sp)
	trap	#1		; Pterm

rte_only:
	rte

vbl_mini:
	addq.l	#1,$462			; TOS vbl counter
	rte


;-- Check if the SCU is present (only on MegaSTE and TT)
;-- If writing to $FF8E01 and $FF8E0D doesn't cause a bus error, then we have an SCU
;-- If so, we enable the following interrupts in SCU's sys_mask and vme_mask :
;--   hsync (level 2), vsync (level 4), scc (level 5) and mfp (level 6)
;-- This is similar to what normal TOS does on boot
config_scu:
	move.l	$8.w,a0			; save bus error handler
	move.l	a7,a6			; save A7/SSP in case of bus error changing the stack
	lea	config_scu_error(pc),a1
	move.l	a1,$8.w
	move.b	#$14,$ffff8e01.w	; enable hsync and vsync
	move.b	#$60,$ffff8e0d.w	; enable scc and mfp

config_scu_error:
	move.l	a0,$8.w			; restore bus error handler
	move.l	a6,a7			; restore A7/SSP
	rts

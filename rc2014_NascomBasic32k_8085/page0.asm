;==============================================================================
; Contents of this file are copyright Phillip Stevens
;
; You have permission to use this for NON COMMERCIAL USE ONLY
; If you wish to use it elsewhere, please include an acknowledgement to myself.
;
; https://github.com/feilipu/
;
; https://feilipu.me/
;

;==============================================================================
;
; REQUIRES
;

INCLUDE         "rc2014.inc"

;==============================================================================
;
; 8085 INTERRUPT ORIGINATING VECTOR TABLE
;
SECTION         vector_rst

EXTERN          INIT

;------------------------------------------------------------------------------
; RST 00 - RESET / TRAP
;               ALIGN    0x0000         ; ORG     0000H
                JP      INIT            ; Initialize Hardware and go

;------------------------------------------------------------------------------
; RST 08
                ALIGN   0x0008          ; ORG     0008H
                JP      VECTOR_BASE-VECTOR_PROTO+RST_08_LBL

;------------------------------------------------------------------------------
; RST 10
                ALIGN   0x0010          ; ORG     0010H
                JP      VECTOR_BASE-VECTOR_PROTO+RST_10_LBL

;------------------------------------------------------------------------------
; RST 18
                ALIGN   0x0018          ; ORG     0018H
                JP      VECTOR_BASE-VECTOR_PROTO+RST_18_LBL

;------------------------------------------------------------------------------
; RST 20
                ALIGN   0x0020          ; ORG     0020H
                JP      VECTOR_BASE-VECTOR_PROTO+RST_20_LBL

;------------------------------------------------------------------------------
; TRAP
                ALIGN   0x0024          ; ORG     0024H
                JP      VECTOR_BASE-VECTOR_PROTO+TRAP_LBL

;------------------------------------------------------------------------------
; RST 28
                ALIGN   0x0028          ; ORG     0028H
                JP      VECTOR_BASE-VECTOR_PROTO+RST_28_LBL

;------------------------------------------------------------------------------
; IRQ 5.5
                ALIGN   0x002C          ; ORG     002CH
                JP      VECTOR_BASE-VECTOR_PROTO+IRQ_55_LBL

;------------------------------------------------------------------------------
; RST 30
                ALIGN   0x0030          ; ORG     0030H
                JP      VECTOR_BASE-VECTOR_PROTO+RST_30_LBL

;------------------------------------------------------------------------------
; IRQ 6.5
                ALIGN   0x0034          ; ORG     0034H
                JP      VECTOR_BASE-VECTOR_PROTO+IRQ_65_LBL

;------------------------------------------------------------------------------
; RST 38

                ALIGN   0x0038          ; ORG     0038H
                JP      VECTOR_BASE-VECTOR_PROTO+RST_38_LBL

;------------------------------------------------------------------------------
; IRQ 7.5
                ALIGN   0x003C          ; ORG     003CH
                JP      VECTOR_BASE-VECTOR_PROTO+IRQ_75_LBL

;------------------------------------------------------------------------------
; RST 40 - OVERFLOW
                ALIGN   0x0040          ; ORG     0040H
                JP      VECTOR_BASE-VECTOR_PROTO+RST_40_LBL

;==============================================================================
;
; 8085 INTERRUPT VECTOR TABLE PROTOTYPE
;
; WILL BE DUPLICATED DURING INIT TO:
;
;               ORG     VECTOR_BASE

SECTION         vector_table_prototype

EXTERN          RST_00, RST_08, RST_10, RST_18
EXTERN          RST_20, RST_28, RST_30, RST_38

EXTERN          TRAP, IRQ_55, IRQ_65, IRQ_75, RST_40

.RST_00_LBL
                JP      RST_00
                NOP
.RST_08_LBL
                JP      RST_08
                NOP
.RST_10_LBL
                JP      RST_10
                NOP
.RST_18_LBL
                LD      A,(serRxBufUsed)    ; this is called each token,
                RET                         ; so optimise it to here
.RST_20_LBL
                JP      RST_20
                NOP
.TRAP_LBL
                JP      TRAP
                NOP
.RST_28_LBL
                JP      RST_28
                NOP
.IRQ_55_LBL
                JP      IRQ_55
                NOP
.RST_30_LBL
                JP      RST_30
                NOP
.IRQ_65_LBL
                JP      IRQ_65
                NOP
.RST_38_LBL
                JP      RST_38
                NOP
.IRQ_75_LBL
                JP      IRQ_75
                NOP
.RST_40_LBL
                JP      RST_40
                NOP

;------------------------------------------------------------------------------
; NULL RETURN INSTRUCTIONS

SECTION         vector_null_ret

PUBLIC          NULL_INT, NULL_RET

.NULL_INT
                EI
.NULL_RET
                RET

;==============================================================================


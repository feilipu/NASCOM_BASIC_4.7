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
; Z180_VECTOR_BASE  .EQU   RAM vector address for Z180 Vectors
;
;
; #include          "d:/yaz180.h"   ; OR
; #include          "d:/rc2014.h"

;==============================================================================
;
; Z180 INTERRUPT VECTOR TABLE PROTOTYPE [ Originating at $0070 ]
;
; WILL BE DUPLICATED DURING INIT TO
;
;               .ORG    Z180_VECTOR_BASE

;------------------------------------------------------------------------------
; INT1
                .ORG    Z180_VECTOR_PROTO
VECTOR_INT1_LBL:
                EI
                RET

;------------------------------------------------------------------------------
; INT2
                .ORG    Z180_VECTOR_PROTO+$02
VECTOR_INT2_LBL:
                EI
                RET

;------------------------------------------------------------------------------
; PRT0
                .ORG    Z180_VECTOR_PROTO+$04
VECTOR_PRT0_LBL:
                EI
                RET

;------------------------------------------------------------------------------
; PRT1
                .ORG    Z180_VECTOR_PROTO+$06
VECTOR_PRT1_LBL:
                EI
                RET

;------------------------------------------------------------------------------
; DMA0
                .ORG    Z180_VECTOR_PROTO+$08
VECTOR_DMA0_LBL:
                EI
                RET

;------------------------------------------------------------------------------
; DMA1
                .ORG    Z180_VECTOR_PROTO+$0A
VECTOR_DMA1_LBL:
                EI
                RET

;------------------------------------------------------------------------------
; CSIO
                .ORG    Z180_VECTOR_PROTO+$0C
VECTOR_CSIO_LBL:
                EI
                RET

;------------------------------------------------------------------------------
; ASCI0
                .ORG    Z180_VECTOR_PROTO+$0E
VECTOR_ASCI0_LBL:
                JP      INT_ASCI0

;------------------------------------------------------------------------------
; ASCI1                
                .ORG    Z180_VECTOR_PROTO+$10
VECTOR_ASCI1_LBL:
;                EI
;                RET

;==============================================================================
;
                .END
;
;==============================================================================



; Processor: AT89C52
; Compiler:  Keil A51
;====================================================================
$NOMOD51

            ORG 0000H
            LJMP START

; ====================== BIT DEFINITIONS ==============================
MODBUS_VAR_COIL_INPUT     DATA 28H
MODBUS_VAR_COIL           DATA 2CH
MODBUS_FLAG               DATA 20H

BTN_STATE_MODBUS          BIT MODBUS_VAR_COIL_INPUT.0
BTN_STATE_MAX_MODBUS      BIT MODBUS_VAR_COIL_INPUT.1
SERISRFLG                 BIT MODBUS_FLAG.0
CARRY_BKP                 BIT 21H.0

; ====================== CONSTANTS ====================================
MODBUS_SLAVE_ID           EQU 1
SERIAL_BUF_START_ADDR     EQU 40H
SERIAL_BUF_SIZE           EQU 0FH
CRC_L                     DATA 50H
CRC_H                     DATA 51H
CRC_MASK_LSB              EQU 001H
CRC_MASK_MSB              EQU 0A0H

COM_CTRL                  EQU P3.2
BTN                       EQU P2.0
BTN_LED                   EQU P2.1

; ====================== ISR ==========================================
            ORG 0023H
            LCALL SERIAL_ISR
            RETI

; ====================== MAIN CODE ====================================
START:
            MOV R0, #SERIAL_BUF_START_ADDR
            SETB EA
            SETB ES
            MOV SCON, #0D0H
            MOV RCAP2H, #0FFH
            MOV RCAP2L, #0DCH
            MOV T2CON, #030H
            SETB TR2

MAIN_LOOP:
            CLR SERISRFLG
            MOV R0, #SERIAL_BUF_START_ADDR
            MOV R2, #0
            CLR COM_CTRL

POLL_LOOP:
            MOV A, #1
            LCALL SOFTDELAY
            JB BTN, BTN_RELEASED
            SETB BTN_STATE_MODBUS
            JB BTN_STATE_MAX_MODBUS, CHECK_SERIAL
            INC 31H
            MOV A, 31H
            CJNE A, #250, CHECK_SERIAL
            MOV 31H, #0
            INC 32H
            MOV A, 32H
            CJNE A, #20, CHECK_SERIAL
            SETB BTN_STATE_MAX_MODBUS
            SETB BTN_LED
            MOV 33H, #0
            MOV 34H, #0
            SJMP CHECK_SERIAL

BTN_RELEASED:
            CLR BTN_STATE_MODBUS
            JNB BTN_STATE_MAX_MODBUS, SKIP_TIMER
            INC 33H
            MOV A, 33H
            CJNE A, #250, SKIP_TIMER
            MOV 33H, #0
            INC 34H
            MOV A, 34H
            CJNE A, #20, SKIP_TIMER
            CLR BTN_STATE_MAX_MODBUS
            CLR BTN_LED
            MOV 31H, #0
            MOV 32H, #0
            MOV 33H, #0
            MOV 34H, #0

SKIP_TIMER:
CHECK_SERIAL:
            JNB SERISRFLG, POLL_LOOP

WAIT_RX:
            CLR SERISRFLG
            MOV A, #3
            LCALL SOFTDELAY
            JB SERISRFLG, WAIT_RX
            MOV R0, #SERIAL_BUF_START_ADDR

            MOV A, @R0
            CJNE A, #MODBUS_SLAVE_ID, MAIN_LOOP
            MOV A, R2
            CLR C
            SUBB A, #2
            MOV R2, A
            LCALL CRC_CALC
            MOV A, @R0
            CJNE A, CRC_L, MAIN_LOOP
            INC R0
            MOV A, @R0
            CJNE A, CRC_H, MAIN_LOOP

            MOV R0, #SERIAL_BUF_START_ADDR
            INC R0
            MOV A, @R0
            CJNE A, #02H, MAIN_LOOP
            INC R0
            MOV A, @R0
            CJNE A, #0H, MAIN_LOOP
            INC R0
            MOV A, @R0
            CLR C
            SUBB A, #2
            JNC MAIN_LOOP
            INC R0
            MOV A, @R0
            CJNE A, #0H, MAIN_LOOP
            INC R0
            MOV A, @R0
            CLR C
            SUBB A, #3
            JNC MAIN_LOOP

            MOV R2, #4
            MOV R0, #SERIAL_BUF_START_ADDR
            MOV @R0, #MODBUS_SLAVE_ID
            INC R0
            MOV @R0, #02H
            INC R0
            MOV @R0, #01H
            INC R0
            CLR A
            MOV C, BTN_STATE_MAX_MODBUS
            RLC A
            MOV C, BTN_STATE_MODBUS
            RLC A
            MOV @R0, A
            MOV R0, #SERIAL_BUF_START_ADDR
            LJMP MODBUS_REPLY

; ====================== CRC, REPLY, SERIAL ISR ========================

MODBUS_REPLY:
            MOV A, #20
            LCALL SOFTDELAY
            LCALL CRC_CALC
            MOV @R0, CRC_L
            INC R0
            MOV @R0, CRC_H
            MOV A, R2
            ADD A, #2
            MOV R2, A
            MOV R0, #SERIAL_BUF_START_ADDR
            CLR SERISRFLG
            SETB COM_CTRL
            MOV SBUF, @R0
WAIT_TX:
            JNB SERISRFLG, WAIT_TX
            SJMP MAIN_LOOP

SERIAL_ISR:
            MOV 36H, A
            MOV CARRY_BKP, C
            JB TI, SERIAL_TX
            MOV A, SBUF
            CLR RI
            CJNE R2, #SERIAL_BUF_SIZE, STORE_SER
            RET
STORE_SER:
            MOV @R0, A
            INC R0
            INC R2
            SETB SERISRFLG
            SJMP RESTORE_ISR
SERIAL_TX:
            CLR TI
            DJNZ R2, NEXT_TX
            SETB SERISRFLG
            RET
NEXT_TX:
            INC R0
            MOV SBUF, @R0
RESTORE_ISR:
            MOV A, 36H
            MOV C, CARRY_BKP
            RET

CRC_CALC:
            MOV A, R2
            MOV R4, A
            MOV CRC_L, #0FFH
            MOV CRC_H, #0FFH
CRC_BYTE:
            MOV A, @R0
            XRL A, CRC_L
            MOV CRC_L, A
            MOV R5, #8
CRC_BIT:
            MOV A, CRC_H
            CLR C
            RRC A
            MOV CRC_H, A
            MOV A, CRC_L
            RRC A
            MOV CRC_L, A
            JNC SKIP_XOR
            MOV A, CRC_L
            XRL A, #CRC_MASK_LSB
            MOV CRC_L, A
            MOV A, CRC_H
            XRL A, #CRC_MASK_MSB
            MOV CRC_H, A
SKIP_XOR:
            DJNZ R5, CRC_BIT
            INC R0
            DJNZ R4, CRC_BYTE
            RET

SOFTDELAY:
            MOV 30H, #2
            DJNZ 30H, $
            DJNZ 30H, $
            DEC A
            CJNE A, #0, SOFTDELAY
            RET

            END
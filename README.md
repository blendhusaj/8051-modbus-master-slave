# 8051 MODBUS Master/Slave (A51 Assembly)

MODBUS-style communication on 8051, written in Keil A51 assembly. One master talks to three slaves at 9600 baud and uses CRC. UART RX/TX is handled in the serial interrupt with a small RAM buffer.

## How the project is supposed to work

- This project uses Modbus RTU framing over an RS-485 style half-duplex link (UART + transceiver).
- The master polls slave 1 (button status), slave 2 (ADC0804 reading), then writes a PWM value to slave 3 (lamp intensity).
- Each slave receives all frames on the bus, but only the addressed slave replies.

Keil projects are in `Keil/`:
- `Keil/Master/` (master firmware)
- `Keil/Slave_1/`, `Keil/Slave_2/`, `Keil/Slave_3/` (slave firmwares)

Optional simulation files are in `Proteus/`.

If you want images on GitHub, add screenshots to `docs/images/` and link them in the README. A good set is:
- `docs/images/proteus-topology.png` (overall bus + nodes)
- `docs/images/slave1-button.png` (button wiring / coils)
- `docs/images/slave2-adc0804.png` (ADC0804 + pot wiring)
- `docs/images/slave3-pwm.png` (PWM lamp wiring)

## Requirements (what you need)

- Keil µVision (8051 toolchain) to build the `.hex`
- 8051 MCU(s): one for master + one for each slave (or use Proteus)
- A way to connect them on a bus (UART + RS-485 transceivers such as MAX487/MAX485)
- A programmer/debugger for your specific 8051 part

## Protocol notes (what is implemented)

- Modbus RTU-like packet: slave id, function code, address, length/data, CRC16 (2 bytes)
- Function codes used:
  - 0x02 Read Input Status (coils)
  - 0x04 Read Input Registers
  - 0x06 Write Holding Register
- If a slave receives an unsupported function/address, it replies with an exception (function | 0x80 + exception code).

## Node roles (what each slave does)

- Slave 1: reads a button on P2.0 and exposes two input coils:
  - coil 0: current button state
  - coil 1: “max” state if the button is held low long enough (about 7 seconds)
- Slave 2: reads ADC0804 and exposes one input register:
  - input register 0: ADC value from the pot/ADC0804
- Slave 3: controls lamp/LED intensity using PWM on P3.3:
  - holding register 0: PWM duty (0..255)
  - a local/master select input on P3.7 allows local control (DIP switches) or master control

## Build: generate the `.hex` in Keil

1. Open the project you want to build:
   - Master: `Keil/Master/main.uvproj`
   - Slave 1: `Keil/Slave_1/main.uvproj`
   - Slave 2: `Keil/Slave_2/main.uvproj`
   - Slave 3: `Keil/Slave_3/main.uvproj`
2. In Keil µVision press Build (F7).
3. The output `.hex` is generated under the project’s `Objects/` folder (e.g. `Keil/Master/Objects/main.hex`).

There are also ready-made hex files under `Share File/`:
- `Share File/MASTER.hex`
- `Share File/SLAVE1.hex`
- `Share File/SLAVE2.hex`
- `Share File/SLAVE3.hex`

## Flash: load the `.hex` on each MCU

Flash the corresponding `.hex` onto each board:

- Master MCU → `MASTER.hex` (or `Keil/Master/Objects/main.hex`)
- Slave 1 MCU → `SLAVE1.hex` (or `Keil/Slave_1/Objects/main.hex`)
- Slave 2 MCU → `SLAVE2.hex` (or `Keil/Slave_2/Objects/main.hex`)
- Slave 3 MCU → `SLAVE3.hex` (or `Keil/Slave_3/Objects/main.hex`)

The exact flashing tool depends on your 8051 device (some require an external programmer, others support ISP). Use whatever programmer/software matches your MCU and load the `.hex`.

For Proteus, load the hex by opening the MCU properties and setting “Program File” to the right `.hex` for each node.

## Notes

- UART is configured for 9600 baud (Timer 2).
- Half-duplex bus: only one node transmits at a time. Direction control is required on RS-485 transceivers (DE/RE).

## Code snippets

Serial interrupt stores received bytes into a small RAM buffer and sets a flag for the main loop to process:

```asm
; UART serial interrupt (RX/TX)
ORG 23H
LCALL SERIAL_ISR
RETI

SERIAL_ISR:
  MOV 34H, A        ; backup ACC
  MOV 20H.1, C      ; backup C
  JB  TI, SERIAL_ISR_TX
  MOV A, SBUF       ; RX byte
  CLR RI
  SETB 20H.0        ; SERISRFLG
  MOV @R0, A
  INC R0
  INC R2            ; TOTAL_SER_BYTES
  ; ...
```

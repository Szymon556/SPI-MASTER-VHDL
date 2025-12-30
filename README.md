
## SPI Master Controller – VHDL

This project implements a fully configurable SPI Master controller written in VHDL and intended for FPGA-based systems.

The design supports standard SPI modes (CPOL/CPHA), programmable clock divider, and byte-oriented data transfers. The module is suitable for integration with microcontrollers, sensors, ADCs, DACs and other SPI-compatible peripherals.

The project was developed with a focus on clean RTL structure, synthesizability, and easy integration into larger SoC designs.
### Key features
- SPI Master implementation in pure VHDL
- Support for CPOL and CPHA (SPI modes 0–3)
- Programmable SPI clock divider
- Byte-based data transmission
- Synchronous FSM-based control logic
- FPGA-friendly, fully synthesizable design
### TODO
- Currently implemented SPI mode: Mode 0 (CPOL=0, CPHA=0)
- Additional SPI modes (1–3) can be added with minor extensions to the control FSM and clock generation logic

  
The current implementation focuses on a clean and extendable architecture rather than full feature coverage.

Interrupts are a mechanism that many micro-controllers employ to interrupt the normal execution of a CPU to handle some event. These events can be in many forms: 

- **Hardware interrupt**: these come from other hardware devices on the system e.g. an IO device or timer 
- **Software interrupts**: these are interrupts thrown by software through the `int` instruction
- **Exceptions**: These are interrupts the CPU throws e.g. when you divide by zero, or try to access memory you're not allowed. 

There are two major pieces of hardware that enable us to configure how interrupts are handled in x86:

- [[IDT - interrupt descriptor table]]: a table that contains pointers to functions that handle certain kinds of interrupt. These interrupts are referenced with a "interrupt vector" which is essentially just an integer index into this table, for example, `0x1` is the divide by zero error handler. 
- The programmable interrupt controller (PIC): Handles incoming interrupts configuring priority, masking and other features to decide which interrupt handles is best placed to handle the interrupt (if any). 

When booting into an x86 system, the PIC will be running in a legacy mode, which emulates the old 8259 PIC from single core machines. To facilitate multi-processing, we must switch to the far more complex [[APIC - Advanced Programmable Interrupt Controller]] mode. This includes a bus to facilitate sending and distributing interrupts between multiple cores. 
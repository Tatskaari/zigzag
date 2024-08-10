PICs enable us to configure how interrupts should be distributed to the CPU to be handled i.e. by masking interrupts, setting priority, and buffering them. The APIC is a more advanced PIC that was introduced with multi-core systems. It facilitates two major functions for the CPU: 

- APICs receive interrupts from various internal (i.e. the IO pins on the CPU) and external sources (i.e. from externally connected IO devices), and forwards these to the processors core for handling. 
- In multi-processor systems, APICs handle sending inter-core interrupts. This can be used to distribute interrupts between cores, e.g. to schedule tasks between cores. This is how you'd implement a scheduler.  

APICs have memory mapped registers that allow us to configure how this works e.g. by adding function pointers in tables that can handle various interrupts, or by masking out certain kinds of interrupts altogether. 

## APICs and the IDT vectors 

The APIC is responsible for translating interrupt signals to vectors that reference entries in your IDT. How this happens depends on the kind of interrupt. 

For interrupts that originate locally from within the CPU (e.g. timers or IO devices connected directly to the CPU interrupt pins), this is done via the local vector table (LVT). This table has a number of entries for each kind of local interrupt. 

For interrupts that originate from other CPUs or from external hardware devices connected through the IO APIC, the vector is included in the inter-process interrupt (IPI) message. This message includes an destination identifier that decides which local APICs should receive the interrupt message. 

The IO APIC has a redirect table that configures the vector and the local APIC to send the message to for interrupts from externally connected hardware.  Both this and the LVT can be configured through memory mapped registers using `mov`. 
## Overview

The local APIC is described in chapter 10 of the intel software delivery manual. There's a good overview of how all this works there. The IO APIC isn't technically part of the CPU, so this is documented in its own data sheet. See the the references section below. 

There are two protocols for how the local APIC handles interrupts:

- For local interrupts sources, something called the local interrupt vector (LVT) table is used. This translate the interrupt type into a vector to look up int he IDT. 
- For external interrupt sources, inter-process interrupt (IPI) messages are used. These essentially contain the interrupt vector (referencing the IDT) and a target CPU. This is how the io-apic and other processors send interrupts to each-other.  

These are used for different purposes and are configured differently, but ultimately serve the purpose of turning an interrupt event into a vector that can be distributed to a handler via the IDT to be handled by a specific CPU core. 

The first step either way is to get the address of the io and local APICs so we can start configuring them. The APIC addresses should already be mapped on boot. We just need to get these addresses, and configure the APICs:

- Get the IO-APIC address from the Multiple APIC Description Table (MADT) entry in the Root System Descriptor Table (RSDT) 
- Get the local APIC address for the current CPU core through the read model specific register (MSR) op code, `rdmsr`. This is a special x86 instruction that can be used to read a bunch of information about the current CPU including the address of the local APIC. 
- Disable the legacy PIC by masking out all interrupts
- Enable the local APIC by setting the spurious interrupt register to a vector to handle erroneous interrupts in your IDT.

Once we have these, we can configure the LVT for the local APIC and the redirect table for the IO APIC to configure how interrupts are translated into vectors in our IDT. This is done through memory mapped registers. 

## Local and IO APIC overview

The APIC has two key kinds:

- IO-APIC: Forwards interrupts from IO devices to the local APIC for each core using a redirect table
- Forwards interrupts that arrive from local sources, as well as on the APIC bus to handlers by looking up vectors in the IDT  

Interrupts can arrive from a number of sources e.g. io devices that are directly connected to the CPU interrupt pins, or from external interrupts that are received over the APIC bus from the IO APIC. Local interrupts are things like thermal sensors, performance monitoring and timers. External IO devices like keyboards and PCI devices go via the io-apic. 

Upon receiving an interrupt, the local APIC will look up how to handle that interrupt through the local vector table (LVT), which must be configured through the memory mapped registers mentioned above.

![[figure-10-1-apics-single-cpu.png]]

# Local APIC configuration 
In table 10-1, you can see the following key registers that allow us to set up the local apic: 

| Name                      | Register | Description                                                                                                                                                                                                                                   |
| ------------------------- | -------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Spurious interrupt vector | 0xF0     | Must be set to an entry in the IDT. This handles spurious interrupts, which mean the interrupt was invalid or unexpected. Basically, this should never be called unless hardware is miss-configured, but setting this enables the local APIC. |
| TODO LVT registers        |          |                                                                                                                                                                                                                                               |
|                           |          |                                                                                                                                                                                                                                               |

### Configuring the LVT

![[IVT registers layout.png]]
# IO APIC configuration 

> The IOAPIC registers are accessed by an indirect addressing scheme using two registers (IOREGSEL and IOWIN) that are located in the CPU's memory space (memory address specified by the APICBASE Register located in the PIIX3). These two registers are re-locateable (via the APICBASE Register) as shown in Table 3.1. In the IOAPIC only the IOREGSEL and IOWIN Registers are directly accesable in the memory address space.

The key bit of configuration for the IO apic is the relocation table. This is how we determine how a hardware interrupt that arrives on the IO APIC interrupt pins is converted into a IPI message i.e. how we determine what core the interrupt should be forwarded to. 

![[IOAPIC registers.png]]

The redirection table register is how we configure how the IO APIC handles interrupt signals: 

>There are 24 I/O Redirection Table entry registers. Each register is a dedicated entry for each interrupt input signal.

Each table entry has the following format:

![[redtbl format.png]]

The ACPI ID here should be the ID of the local ACPI of the processor that is running the driver for the IO device.  

# References

- IO APIC: https://www.intel.com/content/dam/www/public/us/en/documents/manuals/64-ia-32-architectures-software-developer-vol-3a-part-1-manual.pdf
- Local APIC and overview: Chapter 10 of the intel software developers manual
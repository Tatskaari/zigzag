Qemu has a wide range of tools that can be really useful in a pinch

# System monitor
The qemu system monitor is a really useful command line to inspect a huge amount of information about the system. It can be accessed via `ctr-alt-2`.

So far, I have found this useful to:
- view PCI devices with `info pci`
- view apic info with `info lapic`
- view all devices connected with `info qtree`

There's a lot more here.

# Debug logging
Qemu can be set up to print a huge amount of information from the command line. The main flag to configure this is `-d`. Passing `-d int` can be really useful to diagnose exceptions. This will print the CPU state every time an interrupt happens which will give you the program counter and exception code when the CPU e.g. hit a general protection fault.   

# Tracing
There's -trace, which can trace various things like lapic events, but I haven't figured out how to use it effectively yet. 
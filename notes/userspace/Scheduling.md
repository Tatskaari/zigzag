Scheduling allows the system to implement multitasking. If multi-processing is enabled, this also allows tasks to execute in parallel but this isn't strictly necessary. Scheduling is required to implement a userspace, because we need to be able to schedule different userspace processes. By starting the scheduler, we pass off execution to the initial process, and from this point on, the kernel is not executing, except through syscalls and periodic interrupts. 

## Overview

To get scheduling working, we need to save and restore the CPU context of each thread. This consists of saving the registers in a CPU context structure that we store against each thread. This structure must end in the iret frame, that is:

1. rip: the instruction pointer register that contains the memory address of the line of asm the thread was executing 
2. cs: the code selector that references a segment in the gdt to set permissions for this thread. In long mode, this controls the ring it executes in. 
3. rflags: cpu flags. The most important part of this is the interrupt enable bit, but it also stores things like the carry flags, and integer overflow. 
4. rsp: the stack pointer register: stores the address of the current head of the stack. 
5. ss: The stack segment selector: similar to the code segment and refers to a gdt entry, but controls permissions for the stack, rather than the code. 

To restore the cpu to this state, we push these onto the stack and call `iret`:
```zig
const ctx = self.findCurrentThread().ctx;  
asm volatile (  
    \\ push %[ss]  
    \\ push %[rsp]    \\ push %[rflags]    \\ push %[cs]    \\ push %[rip]    \\ iretq    :  
    : [rip] "r" (ctx.rip),  
      [cs] "r" (ctx.cs),  
      [rflags] "r" (ctx.rflags),  
      [rsp] "r" (ctx.rsp),  
      [ss] "r" (ctx.ss),  
    : "memory"  
);
```

The scheduler should keep the currently executing thread in a variable, so we can update it's context when the interrupt fires. The scheduler can schedule a different thread like so: 

1. Have some kind of timer that triggers periodically (lapic)
2. When the interrupt fires, push the current CPU state to the stack and call the interrupt handler
3. Update the CPU state for the currently executing thread
6. Find another thread to execute
7. Write the new CPU context to the stack
8. Restore the other registers state before we exit (iret only deals with the 5 registers above)
9. Call iret which will now return us to the new CPU context

To start the scheduler, we must then:

1. Create a new thread with a new stack and page table, making sure we set the right segment selectors, stack pointers etc. in the context. 
2. Set the currently executing thread in the scheduler
3. Start the interrupt timer. 
4. use iret to pass execution off to the current thread. 

From this point on, the kernel is no longer running. The only way the kernel gets to run code is through syscalls and the above periodic interrupt. 


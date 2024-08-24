Scheduling allows the system to implement multitasking. If multi-processing is enabled, this also allows tasks to execute in parallel but this isn't strictly necessary. Scheduling is required to implement a userspace, because we need to be able to schedule different userspace processes

## Overview

To get scheduling working:
1. Have some kind of timer that triggers periodically 
2. Use the interrupt stack frame to find the thread that was executing 
3. Save push the other general purpose registers to the stack 
4. When the timer interrupt fires, save the current CPU state to the thread
5. Find another thread to execute
6. Load it's CPU state

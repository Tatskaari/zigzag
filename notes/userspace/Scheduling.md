Scheduling allows the system to implement multitasking. If multi-processing is enabled, this also allows tasks to execute in parallel but this isn't strictly necessary. Scheduling is required to implement a userspace, because we need to be able to schedule different userspace processes

We need a way to manage tasks through [[TSS - Task State Segment]]. 
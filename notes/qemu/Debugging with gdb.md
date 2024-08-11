Qemu can be started with `-s -S`, and this will start a gdb debug server on `:1234`. You can use `gdb path/to/kernel.elf` and run `target :1234` to connect gdb to the terminal. 

This allows you to inspect memory, op code, cpu registers, while stepping through execution, which can be invaluable when trying to figure out what's going wrong with your kernel. 

# CLion setup

First we should set up `make run` command or similar to start gdb. This command should spin up the qemu VM as a background process. This is important otherwise CLion will wait for the process to die before attaching the debugger. 

Additionally, we can only have one debug session at a time, so this command should ideally find the existing qemu process(es) and nuke them:

```
.PHONY: gdb  
gdb: $(IMAGE_NAME).iso  
    (pgrep -f -x "qemu-system-x86_64.*" | xargs kill -9); qemu-system-x86_64 -s -S ... &
```

Once we have that set up, the setup steps are as follow:
1. Create new run configuration of type "remote debug"
2. Set the binary to the path of your kernel binary, and the target to `:1234`
3. Add a "before launch" task to run a remote tool
4. Create a new remote tool to run the above command

If your paths are all messed up because your build system builds "out of source" i.e. it copies source files to a temporary directory to avoid having build artifacts in your repo root, you may need to add a path mapping from your build directory to the repo source directory:

`/home/{usr}/my_kernel_project/build-dir => /home/{usr}/my_kernel_project`

This is mostly relevant to bazel/buck/please build systems.

![[run config.png]]
See the full config png for more detail. 
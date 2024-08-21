The OS should provide an abstraction over the underlying fliesystem. There are a number of syscalls that are typically presented to userspace applications to implement this:

- mount/unmount: mount a device to a directory 
- open/close: create and release a file descriptor for a given file
- read/write: read or write data from a file descriptor 
- mkdir/rmdir: create and delete directories
- link/unlink: create and delete hard links 
- raname: move files and directories 
- chmod/chown: change permissions and ownership on files 
- stat: gets information about a file
- [getdents](https://man7.org/linux/man-pages/man2/getdents64.2.html): gets directory entries  
- sync: flush filesystem buffers (should be done by close)
- [mknod](https://man7.org/linux/man-pages/man2/mknod.2.html): creates a filesystem node (file, device, special file, or named pipe)

The operating system keeps track of mounts using a mount table, and can dispatch these requests to the underlying block device/filesystem as appropriate. 

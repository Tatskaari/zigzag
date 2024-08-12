The kernel must provide an adequate execution environment to enable a shell program like bash to run. The kernel often provides a tty interface that allows programs to write charters and controls codes to files such as `/dev/tty1`, and the kernel will handle sending these out to (usually) serial. 

There are also pty devices, which are usually allocated on demand and represent psudo-teletypes. These are usually handled by some user-space program. For example, when you ssh into a machine, the tty commands are sent to the SSH deamon, not a serial port. 

Terminal emulator like xterm present a pty device to programs like bash, which then provide a command line interface to end users. The ANSI control codes allow precise control of the cursor to make visual applications like vim possible. 

# ANSI control codes
There are ANSI standards for the different control characters that the terminal must handle:

https://en.wikipedia.org/wiki/ASCII#Control_characters

These could be handled by a user space program, if that program is presented with a way to render the text to a buffer.  
# Termios

termios is the newer (now already a few decades old) Unix API for terminal I/O. The anatomy of a program performing serial I/O with the help of termios is as follows:

- Open serial device with standard Unix system call **open**(2)
- Configure communication parameters and other interface properties (line discipline, etc.) with the help of specific termios functions and data structures.
- Use standard Unix system calls **read**(2) and **write**(2) for reading from, and writing to the serial interface. Related system calls like **readv**(2) and **writev**(2) can be used, too. Multiple I/O techniques, like blocking, non-blocking, asynchronous I/O (**select**(2) or **poll**(2), or signal-driven I/O (`SIGIO` signal)) are also possible. The selection of the I/O technique is an important part of the application's design. The serial I/O needs to work well with other kinds of I/O performed by the application, like networking, and must not waste CPU cycles.
- Close device with the standard Unix system call **close**(2) when done.


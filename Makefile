# Important Directories
BOOTDIR   = boot
KERNELDIR = kernel
DRIVERDIR = drivers
LIBCDIR   = libc

# Kernel source and include directories
KERNELINCLUDESDIR := $(KERNELDIR)/includes
KERNELSRCDIR      := $(KERNELDIR)/src

# Driver source and include directories
DRIVERINCLUDESDIR := $(DRIVERDIR)/includes
DRIVERSRCDIR      := $(DRIVERDIR)/src

# Libc source and include directories
LIBCINCLUDESDIR := $(LIBCDIR)/includes
LIBCSRCDIR      := $(LIBCDIR)/src

# Boot related code
BOOTFILE    := $(BOOTDIR)/boot.asm
BOOTBIN     := $(BOOTFILE:%.asm=%.bin)
BOOTASFILES := $(wildcard $(BOOTDIR)/*.asm)
BOOTASFILES += $(wildcard $(BOOTDIR)/*/*.asm)
BINFILES    := $(BOOTASFILES:%.asm=%.bin)
DISKSPACE   := diskspace.bin

# Kernel related code
KERNEL    := $(KERNELDIR)/kernel_entry.asm
KERNELO   := $(KERNEL:%.asm=%.o)

# Kernel related source files
KERNELSRCFILES := $(wildcard $(KERNELDIR)/*.c)
KERNELSRCFILES += $(wildcard $(KERNELSRCDIR)/*.c)
KERNELSRCFILES += $(wildcard $(KERNELSRCDIR)/*/*.c)
KERNELOBJFILES := $(KERNELSRCFILES:%.c=%.o)

# Driver related source files
DRIVERSRCFILES := $(wildcard $(DRIVERDIR)/*.c)
DRIVERSRCFILES += $(wildcard $(DRIVERSRCDIR)/*.c)
DRIVERSRCFILES += $(wildcard $(DRIVERSRCDIR)/*/*.c)
DRIVEROBJFILES := $(DRIVERSRCFILES:%.c=%.o)

# Driver related assembly source files
DRIVERASMSRCFILES := $(wildcard $(DRIVERDIR)/*.asm)
DRIVERASMSRCFILES += $(wildcard $(DRIVERSRCDIR)/*.asm)
DRIVERASMSRCFILES += $(wildcard $(DRIVERSRCDIR)/*/*.asm)
DRIVERASMOBJFILES := $(DRIVERASMSRCFILES:%.asm=%.o)

# Libc related sourced files
LIBCSRCFILES := $(wildcard $(LIBCDIR)/*.c)
LIBCSRCFILES += $(wildcard $(LIBCSRCDIR)/*.c)
LIBCSRCFILES += $(wildcard $(LIBCSRCDIR)/*/*.c)
LIBCOBJFILES := $(LIBCSRCFILES:%.c=%.o)

# Header files
HEADERS := $(wildcard $(LIBCINCLUDESDIR)/*.h)
HEADERS += $(wildcard $(LIBCINCLUDESDIR)/*/*.h)
HEADERS += $(wildcard $(KERNELINCLUDESDIR)/*.h)
HEADERS += $(wildcard $(DRIVERINCLUDESDIR)/*.h)
HEADERS += $(wildcard $(KERNELINCLUDESDIR)/*/*.h)
HEADERS += $(wildcard $(DRIVERINCLUDESDIR)/*/*.h)

# The image file that contains all os related code.
IMAGE = kernel_image

# The kernel file that contains all the linked code.
LINKFILE = link.bin

# File to write the disassembled version of the kernel to.
KDIS = kernel.dis

# Flags let us assemble to flat binary
AS       = nasm
ASFLAGS  = -f bin -I$(BOOTDIR)/
# For assembly files that are linked in to create a binary
FASFLAGS = -f elf

# C code is in the 2011 C standard. Must be 32 bit to be compatible
CC     = gcc
STD    = c11
CFLAGS = -std=$(STD) -m32 -Wall -Werror -Wpedantic -ffreestanding \
         -I$(KERNELINCLUDESDIR) -I$(DRIVERINCLUDESDIR) -I$(LIBCINCLUDESDIR)

# The linker w'll use. --entry main so it knows where our start point is (main
# function).
LD      = ld
LDFLAGS = -m elf_i386 --oformat binary --entry main -Ttext 0x1000

# The flags ensure it knows what kind of disk image it's getting.
EMU      = qemu-system-i386
EMUFLAGS = -drive file=$(IMAGE),index=0,media=disk,format=raw

# The -f options suppresses warnings if a file is not present
RM = rm -f

# No target specified, so just create the OS image.
default: $(IMAGE)

# Compilation of our boot sector
$(BOOTBIN): $(BOOTFILE) $(BOOTASFILES)
	$(AS) $(ASFLAGS) $< -o $@

# Just runs emu with our disk image
run: $(IMAGE)
	$(EMU) $(EMUFLAGS)

# Sticks our component binaries together to create our disk image
$(IMAGE): $(BOOTBIN) $(LINKFILE) $(DISKSPACE)
	cat $^ > $@

# Just out extra space padding for our disk image to give breathing room
$(DISKSPACE): $(BOOTDIR)/nullbytes.asm
	$(AS) $(ASFLAGS) $< -o $@

# It's very important that the dependencies are in this order so they are stuck
# together properly (entry before kernel)
$(LINKFILE): $(DRIVEROBJFILES) $(LIBCOBJFILES) $(KERNELOBJFILES)
$(LINKFILE): $(KERNELO) $(DRIVERASMOBJFILES)
	$(LD) $(LDFLAGS) -o $@ $^

# Compile C src files into their respective obj file.
%.o: %.c $(HEADERS)
	$(CC) $(CFLAGS) -c $< -o $@

# Assemble asm src files into their respective obj file.
%.o: %.asm
	$(AS) $< $(FASFLAGS) -o $@

# Disassemble our kernel - might be useful for debugging .
disassemble: $(LINKFILE)
	ndisasm -b 32 $< > $(KDIS)

# Remove all but source files
clean:
	$(RM) $(DRIVEROBJFILES) $(DRIVERASMOBJFILES) $(KERNELOBJFILES) $(KDIS)
	$(RM) $(LIBCOBJFILES) $(DISKSPACE) $(KERNELO) $(IMAGE) $(LINKFILE)
	$(RM) $(BOOTBIN)

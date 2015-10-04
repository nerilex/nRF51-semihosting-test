
#
# Toolchain setup
#
TOOLCHAIN_PATH   = 
TOOLCHAIN_PREFIX = arm-none-eabi
AS      = $(TOOLCHAIN_PATH)$(TOOLCHAIN_PREFIX)-as
CC      = $(TOOLCHAIN_PATH)$(TOOLCHAIN_PREFIX)-gcc
LD      = $(TOOLCHAIN_PATH)$(TOOLCHAIN_PREFIX)-ld
OBJCOPY = $(TOOLCHAIN_PATH)$(TOOLCHAIN_PREFIX)-objcopy
OBJDUMP = $(TOOLCHAIN_PATH)$(TOOLCHAIN_PREFIX)-objdump
SIZE    = $(TOOLCHAIN_PATH)$(TOOLCHAIN_PREFIX)-size
GDB     = $(TOOLCHAIN_PATH)$(TOOLCHAIN_PREFIX)-gdb
OPENOCD = openocd
OPENOCD_CFG = openocd.cfg

#
# Project setup
#
SRCS = gcc_startup_nrf51.s system_nrf51.c nrf_delay.c main.c
OBJS = gcc_startup_nrf51.o system_nrf51.o nrf_delay.o main.o
OUTPUT_NAME = main

#
# Compiler and Linker setup
#
LINKER_SCRIPT = nrf51_xxaa.ld

CFLAGS += -std=gnu99 -Wall -g -mcpu=cortex-m0 -mthumb -mabi=aapcs -mfloat-abi=soft
# keep every function in separate section. This will allow linker to dump unused functions
CFLAGS += -ffunction-sections -fdata-sections -fno-strict-aliasing
CFLAGS += --short-enums

LDFLAGS += -L /usr/lib/gcc/arm-none-eabi/4.9/armv6-m/ -L /usr/lib/arm-none-eabi/newlib/armv6-m/
LDFLAGS += -T $(LINKER_SCRIPT)
LDFLAGS += -Wl,-Map,"$(OUTPUT_NAME).map"
LDFLAGS += --specs=rdimon.specs -Wl,--start-group -lgcc -lc -lc -lm -lrdimon -Wl,--end-group

HEX = $(OUTPUT_NAME).hex
ELF = $(OUTPUT_NAME).elf
BIN = $(OUTPUT_NAME).bin

#
# Makefile build targets
#
clean:
	rm -f main *.o *.out *.bin *.elf *.hex *.map

all: $(OBJS) $(HEX)

%.o: %.c %s
	$(CC) $(CFLAGS) -c $< -o $@

$(ELF): $(OBJS)
	$(CC) $(CFLAGS) $(LDFLAGS) $(OBJS) -o $(ELF)
	$(SIZE) $(ELF)

$(HEX): $(ELF)
	$(OBJCOPY) -Oihex $(ELF) $(HEX)

$(BIN): $(ELF)
	$(OBJCOPY) -Obinary $(ELF) $(BIN)

START_ADDRESS = 0 #$($(OBJDUMP) -h $(ELF) -j .text | grep .text | awk '{print $$4}')

erase:
	$(OPENOCD) -f $(OPENOCD_CFG) -c "init; reset halt; nrf51 mass_erase; shutdown;"

flash: $(BIN)
	$(OPENOCD) -f $(OPENOCD_CFG) -c "init; reset halt; program $(BIN) $(START_ADDRESS) verify; shutdown;"

pinreset:
	# mww: write word to memory
	# das funktioniert so nicht, falsche Adresse:
	#$(OPENOCD) -f $(OPENOCD_CFG) -c "init; reset halt; sleep 1; mww phys 0x4001e504 2; mww 0x40000544 1; reset; shutdown;"

debug:
	$(OPENOCD) -f $(OPENOCD_CFG)
	
gdb:
	echo "target remote localhost:3333    \n\
          monitor reset halt              \n\
          monitor arm semihosting enable  \n\
          file $(ELF)                     \n\
          load                            \n\
          b _start                        \n\
          monitor reset                   \n\
          continue                        \n\
          set interactive-mode on" | $(GDB)

run:
	$(OPENOCD) -f $(OPENOCD_CFG) -f openocd-run.cfg

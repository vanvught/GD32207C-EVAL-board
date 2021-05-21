
PREFIX ?= arm-none-eabi-

CC	 = $(PREFIX)gcc
CPP	 = $(PREFIX)g++
AS	 = $(CC)
LD	 = $(PREFIX)ld
AR	 = $(PREFIX)ar

FAMILY=gd32f20x

# Output 
TARGET = $(FAMILY).bin
LIST = $(FAMILY).list
MAP = $(FAMILY).map
BUILD=build_gd32/

# Input
SOURCE = ./
FIRMWARE_DIR = ./../gd32-firmware-template/
LINKER = $(FIRMWARE_DIR)gd32f20x_flash.ld

LIBS+=GD32F207C_EVAL gd32f2xx c
	
DEFINES:=$(addprefix -D,$(DEFINES))

# The variable for the firmware include directories
INCDIRS+=../include $(INCDIR)
INCDIRS+=$(wildcard ./include) $(wildcard ./*/include) $(wildcard ./*/*/include) $(wildcard ./*/*/*/include)
INCDIRS+=../lib-gd32f2xx/GD32F20x_standard_peripheral/Include
INCDIRS+=../lib-gd32f2xx/CMSIS
INCDIRS+=../lib-gd32f2xx/CMSIS/GD/GD32F20x/Include
INCDIRS+=../lib-gd32f2xx/Utilities
INCDIRS+=../GD32F207C_EVAL/include
INCDIRS:=$(addprefix -I,$(INCDIRS))

# The variable for the libraries include directory
LIBINCDIRS:=$(addprefix -I../lib-,$(LIBS))
LIBINCDIRS+=$(addsuffix /include, $(LIBINCDIRS))

# The variables for the ld -L flag
LIBGD32=$(addprefix -L../lib-,$(LIBS))
LIBGD32:=$(addsuffix /lib_gd32, $(LIBGD32))

# The variable for the ld -l flag 
LDLIBS:=$(addprefix -l,$(LIBS))

# The variables for the dependency check 
LIBDEP=$(addprefix ../lib-,$(LIBS))

$(info [${LIBDEP}])


COPS=-DBARE_METAL -DGD32 -DGD32F20x -DGD32F20X_CL $(DEFINES) $(MAKE_FLAGS) $(INCLUDES)
COPS+=$(INCDIRS) $(LIBINCDIRS) $(addprefix -I,$(EXTRA_INCLUDES))
COPS+=-Os -mcpu=cortex-m3 -mthumb
COPS+=-nostartfiles -ffreestanding -nostdlib

PLATFORM_LIBGCC+= -L $(shell dirname `$(CC) $(COPS) -print-libgcc-file-name`)

$(info $$PLATFORM_LIBGCC [${PLATFORM_LIBGCC}])

C_OBJECTS=$(foreach sdir,$(SRCDIR),$(patsubst $(sdir)/%.c,$(BUILD)$(sdir)/%.o,$(wildcard $(sdir)/*.c)))
C_OBJECTS+=$(foreach sdir,$(SRCDIR),$(patsubst $(sdir)/%.cpp,$(BUILD)$(sdir)/%.o,$(wildcard $(sdir)/*.cpp)))
ASM_OBJECTS=$(foreach sdir,$(SRCDIR),$(patsubst $(sdir)/%.S,$(BUILD)$(sdir)/%.o,$(wildcard $(sdir)/*.S)))

BUILD_DIRS:=$(addprefix $(BUILD),$(SRCDIR))

OBJECTS:=$(ASM_OBJECTS) $(C_OBJECTS)

define compile-objects
$(BUILD)$1/%.o: $(SOURCE)$1/%.cpp
	$(CPP) $(COPS) $(CPPOPS) -c $$< -o $$@	

$(BUILD)$1/%.o: $(SOURCE)$1/%.c
	$(CC) $(COPS) -c $$< -o $$@
	
$(BUILD)$1/%.o: $(SOURCE)$1/%.S
	$(CC) $(COPS) -D__ASSEMBLY__ -c $$< -o $$@
endef


all : builddirs $(TARGET)
	
.PHONY: clean builddirs

builddirs:
	mkdir -p $(BUILD_DIRS)

.PHONY:  clean

clean: $(LIBDEP)
	rm -rf $(BUILD)
	rm -f $(TARGET)
	rm -f $(MAP)
	rm -f $(LIST)

#
# Libraries
#

.PHONY: libdep $(LIBDEP)

lisdep: $(LIBDEP)

$(LIBDEP):
	$(MAKE) -f Makefile $(MAKECMDGOALS) 'MAKE_FLAGS=$(DEFINES)' -C $@ 

# Build uImage

$(BUILD_DIRS) :
	mkdir -p $(BUILD_DIRS)

$(BUILD)startup_gd32f20x_cl.o : $(FIRMWARE_DIR)/startup_$(FAMILY)_cl.S
	$(AS) $(COPS) -D__ASSEMBLY__ -c $(FIRMWARE_DIR)/startup_$(FAMILY)_cl.S -o $(BUILD)startup_$(FAMILY)_cl.o
	
$(BUILD)main.elf: Makefile $(LINKER) $(BUILD)startup_gd32f20x_cl.o $(OBJECTS) $(LIBDEP)
	$(LD) $(BUILD)startup_gd32f20x_cl.o $(OBJECTS) -Map $(MAP) -T $(LINKER) -o $(BUILD)main.elf $(LIBGD32) $(LDLIBS) $(PLATFORM_LIBGCC) -lgcc 
	$(PREFIX)objdump -D $(BUILD)main.elf | $(PREFIX)c++filt > $(LIST)
	$(PREFIX)size -A -x $(BUILD)main.elf

$(TARGET) : $(BUILD)main.elf 
	$(PREFIX)objcopy $(BUILD)main.elf -O binary $(TARGET)	
	
$(foreach bdir,$(SRCDIR),$(eval $(call compile-objects,$(bdir))))
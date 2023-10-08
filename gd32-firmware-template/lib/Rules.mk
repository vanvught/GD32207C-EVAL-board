PREFIX ?= arm-none-eabi-

CC	= $(PREFIX)gcc
CPP	= $(PREFIX)g++
AS	= $(CC)
LD	= $(PREFIX)ld
AR	= $(PREFIX)ar

SRCDIR = src src/gd32 $(EXTRA_SRCDIR)

INCLUDES:= -I./include -I../include $(addprefix -I,$(EXTRA_INCLUDES))
INCLUDES+=-I../lib-gd32f2xx/CMSIS
INCLUDES+=-I../lib-gd32f2xx/CMSIS/GD/GD32F20x/Include
INCLUDES+=-I../lib-gd32f2xx/GD32F20x_standard_peripheral/Include
INCLUDES+=-I../lib-gd32f2xx/Utilities
INCLUDES+=-I../gd32-firmware-template/template

COPS=-DBARE_METAL -DGD32 -DGD32F20x -DGD32F20X_CL $(DEFINES) $(MAKE_FLAGS) $(INCLUDES)
COPS+=-Os -mcpu=cortex-m3 -mthumb
COPS+=-nostartfiles -ffreestanding -nostdlib

CPPOPS=-std=c++11 -Wnon-virtual-dtor -fno-rtti -fno-exceptions -fno-unwind-tables

CURR_DIR:=$(notdir $(patsubst %/,%,$(CURDIR)))
LIB_NAME:=$(patsubst lib-%,%,$(CURR_DIR))

BUILD = build_gd32/
BUILD_DIRS:=$(addprefix build_gd32/,$(SRCDIR))
$(info $$BUILD_DIRS [${BUILD_DIRS}])

C_OBJECTS=$(foreach sdir,$(SRCDIR),$(patsubst $(sdir)/%.c,$(BUILD)$(sdir)/%.o,$(wildcard $(sdir)/*.c)))
CPP_OBJECTS=$(foreach sdir,$(SRCDIR),$(patsubst $(sdir)/%.cpp,$(BUILD)$(sdir)/%.o,$(wildcard $(sdir)/*.cpp)))
ASM_OBJECTS=$(foreach sdir,$(SRCDIR),$(patsubst $(sdir)/%.S,$(BUILD)$(sdir)/%.o,$(wildcard $(sdir)/*.S)))

EXTRA_C_OBJECTS=$(patsubst %.c,$(BUILD)%.o,$(EXTRA_C_SOURCE_FILES))
EXTRA_C_DIRECTORIES=$(shell dirname $(EXTRA_C_SOURCE_FILES))
EXTRA_BUILD_DIRS:=$(addsuffix $(EXTRA_C_DIRECTORIES), $(BUILD))

OBJECTS:=$(strip $(ASM_OBJECTS) $(C_OBJECTS) $(CPP_OBJECTS) $(EXTRA_C_OBJECTS))

$(info $$OBJECTS [${OBJECTS}])

TARGET=lib_gd32/lib$(LIB_NAME).a 
$(info $$TARGET [${TARGET}])

LIST = lib.list

define compile-objects
$(BUILD)$1/%.o: $1/%.c
	$(CC) $(COPS) -c $$< -o $$@
	
$(BUILD)$1/%.o: $1/%.cpp
	$(CPP) $(COPS) $(CPPOPS)  -c $$< -o $$@
	
$(BUILD)$1/%.o: $1/%.S
	$(CC) $(COPS) -D__ASSEMBLY__ -c $$< -o $$@	
endef

all : builddirs $(TARGET)

.PHONY: clean builddirs

builddirs:
	mkdir -p $(BUILD_DIRS)
	mkdir -p $(EXTRA_BUILD_DIRS)
	mkdir -p lib_gd32

clean:
	rm -rf build_gd32
	rm -rf lib_gd32
	
$(BUILD)%.o: %.c
	$(CC) $(COPS) -c $< -o $@
	
$(BUILD_DIRS) :	
	mkdir -p $(BUILD_DIRS)
	mkdir -p lib_gd32
	
$(TARGET): Makefile $(OBJECTS)
	$(AR) -r $(TARGET) $(OBJECTS)
	$(PREFIX)objdump -d $(TARGET) | $(PREFIX)c++filt > lib_gd32/$(LIST)
	
$(foreach bdir,$(SRCDIR),$(eval $(call compile-objects,$(bdir))))
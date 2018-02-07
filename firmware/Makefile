

TOOLCHAIN_PREFIX = /opt/riscv32i/bin/riscv32-unknown-elf-

BUILD_DIR = build
OBJ_DIR = $(BUILD_DIR)/obj
LINKER_SCRIPT = pico_zedboard.ld

TEST_DIR = tests
TEST_SRCS = $(wildcard $(TEST_DIR)/*.S)
TEST_OBJS = $(addprefix $(OBJ_DIR)/,$(addsuffix .o,$(basename $(TEST_SRCS))))

TESTBENCH_SRCS_DIR = testbench
TESTBENCH_SRCS = \
	$(wildcard $(TESTBENCH_SRCS_DIR)/*.c) \
	$(wildcard $(TESTBENCH_SRCS_DIR)/*.S)

TESTBENCH_OBJS = \
	$(OBJ_DIR)/testbench/start.o \
	$(OBJ_DIR)/testbench/print.o \
	$(OBJ_DIR)/testbench/sieve.o \
	$(OBJ_DIR)/testbench/multest.o \
	$(OBJ_DIR)/testbench/stats.o \
	$(OBJ_DIR)/testbench/irq.o

GCC_WARNS  = -Werror -Wall -Wextra -Wshadow -Wundef -Wpointer-arith -Wcast-qual -Wcast-align -Wwrite-strings
GCC_WARNS += -Wredundant-decls -Wstrict-prototypes -Wmissing-prototypes -pedantic # -Wconversion


OBJS = $(TEST_OBJS) $(TESTBENCH_OBJS)
OBJ_DIRS = $(sort $(dir $(OBJS)))

.PHONY: default
default:
	@echo 'Default target, doing nothing'
	@echo ' '

.PHONY: clean
clean:
	rm -rf $(OBJ_DIR)

$(OBJS): | $(OBJ_DIRS)

$(BUILD_DIR):
	mkdir -p $@

$(OBJ_DIRS): | $(BUILD_DIR)
	mkdir -p $@

.PHONY: firmware-testbench
firmware-testbench: $(BUILD_DIR)/pico-testbench.elf
firmware-testbench: $(BUILD_DIR)/pico-testbench.bin
firmware-testbench: $(BUILD_DIR)/pico-testbench.hex
firmware-testbench: $(BUILD_DIR)/pico-testbench.disassembly

$(BUILD_DIR)/pico-testbench.disassembly: $(BUILD_DIR)/pico-testbench.elf
	$(TOOLCHAIN_PREFIX)objdump -xdsS $< > $@

$(BUILD_DIR)/pico-testbench.hex: $(BUILD_DIR)/pico-testbench.bin makehex.py
	python3 makehex.py $< 16384 > $@
	
$(BUILD_DIR)/pico-testbench.bin: $(BUILD_DIR)/pico-testbench.elf
	$(TOOLCHAIN_PREFIX)objcopy -O binary $< $@

$(BUILD_DIR)/pico-testbench.elf: $(TESTBENCH_OBJS) $(TEST_OBJS) $(LINKER_SCRIPT) | $(BUILD_DIR)
	$(TOOLCHAIN_PREFIX)gcc -Os -ffreestanding -nostdlib \
		-Wl,-Bstatic,-T,$(LINKER_SCRIPT),-Map,$(addsuffix .map,$(basename $@)),--strip-debug \
		-o $@ $(TESTBENCH_OBJS) $(TEST_OBJS) -lgcc

$(OBJ_DIR)/testbench/start.o: testbench/start.S | $(OBJ_DIRS)
	$(TOOLCHAIN_PREFIX)gcc -c -march=rv32im -o $@ $<

$(OBJ_DIR)/testbench/%.o: testbench/%.c | $(OBJ_DIRS)
	$(TOOLCHAIN_PREFIX)gcc -c -march=rv32i -Os --std=c99 -Wall -Wextra -pedantic \
		-ffreestanding -nostdlib -o $@ $<

$(OBJ_DIR)/$(TEST_DIR)/%.o: $(TEST_DIR)/%.S $(TEST_DIR)/riscv_test.h $(TEST_DIR)/test_macros.h | $(OBJ_DIRS)
	$(TOOLCHAIN_PREFIX)gcc -c -march=rv32im -o $@ \
		-DTEST_FUNC_NAME=$(notdir $(basename $<)) \
		-DTEST_FUNC_TXT='"$(notdir $(basename $<))"' \
		-DTEST_FUNC_RET=$(notdir $(basename $<))_ret $<

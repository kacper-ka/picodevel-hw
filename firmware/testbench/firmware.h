// This is free and unencumbered software released into the public domain.
//
// Anyone is free to copy, modify, publish, use, compile, sell, or
// distribute this software, either in source code form or as a compiled
// binary, for any purpose, commercial or non-commercial, and by any
// means.

#ifndef FIRMWARE_H
#define FIRMWARE_H

#include <stdint.h>
#include <stdbool.h>
#include "../custom_ops.h"

typedef uint32_t u32;
typedef uint16_t u16;
typedef uint8_t u8;
typedef int32_t i32;
typedef int16_t i16;
typedef int8_t i8;

// irq.c
uint32_t *irq(uint32_t *regs, uint32_t irqs);

// print.c
void print_chr(char ch);
void print_str(const char *p);
void print_dec(unsigned int val);
void print_hex(unsigned int val, int digits);

// sieve.c
void sieve(void);

// multest.c
uint32_t hard_mul(uint32_t a, uint32_t b);
uint32_t hard_mulh(uint32_t a, uint32_t b);
uint32_t hard_mulhsu(uint32_t a, uint32_t b);
uint32_t hard_mulhu(uint32_t a, uint32_t b);
void multest(void);

// stats.c
void stats(void);



#endif

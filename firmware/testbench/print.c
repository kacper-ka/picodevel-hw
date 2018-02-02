// This is free and unencumbered software released into the public domain.
//
// Anyone is free to copy, modify, publish, use, compile, sell, or
// distribute this software, either in source code form or as a compiled
// binary, for any purpose, commercial or non-commercial, and by any
// means.

#include "firmware.h"

#define UART_BASE_ADDR  0xE0000000

#define UART_REG_SR     44
#define UART_REG_FIFO   48
#define UART_SR_TXFULL  0x10


void print_chr(char ch)
{
	register u32 sr;
    do
    {
        sr = *((volatile u32*) (UART_BASE_ADDR + UART_REG_SR));
    } while ((sr & UART_SR_TXFULL) != 0);
    *((volatile u8*) (UART_BASE_ADDR + UART_REG_FIFO)) = ch;
}

void print_str(const char *p)
{
	while (*p != 0)
		print_chr(*p++);
}

void print_dec(unsigned int val)
{
	char buffer[10];
	char *p = buffer;
	while (val || p == buffer) {
		*(p++) = val % 10;
		val = val / 10;
	}
	while (p != buffer) {
		print_chr('0' + *(--p));
	}
}

void print_hex(unsigned int val, int digits)
{
	for (int i = (4*digits)-4; i >= 0; i -= 4)
    {
        char c = "0123456789ABCDEF"[(val >> i) % 16];
        print_chr(c);
    }
}


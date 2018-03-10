
#ifndef __CUSTOM_OPS_H__
#define __CUSTOM_OPS_H__ 1


#include <stdint.h>

__attribute__((always_inline)) static inline uint32_t __get_COREID(void)
{
    register uint32_t a0 __asm__("a0");
    __asm__ volatile (".word 0x0200052B" : "=r" (a0));
    return a0;
}

__attribute__((always_inline)) static inline void __EXIT(void)
{
    __asm__ volatile (".word 0x0400002B");
}

__attribute__((always_inline)) static inline void __EBREAK(void)
{
    __asm__ volatile ("ebreak");
}

__attribute__((always_inline)) static inline uint32_t __FORK(void)
{
    register uint32_t a0 __asm__("a0");
    __asm__ volatile (".word 0x0000452B" : "=r" (a0));
    return a0;
}

__attribute__((always_inline)) static inline void __JOIN(void)
{
    __asm__ volatile (".word 0x0000502B");
}

extern uint32_t __CORES_COUNT__;

#endif

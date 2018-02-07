
#ifndef __CUSTOM_OPS_H__
#define __CUSTOM_OPS_H__ 1

__attribute__((always_inline)) static inline uint32_t __get_COREID(void)
{
    register uint32_t a0 __asm__("a0");
    __asm__ volatile (".word 0x0200052B" : : : "a0");
    return a0;
}

__attribute__((always_inline,noreturn)) static inline void __EXIT(void)
{
    __asm__ volatile (".word 0x0400002B");
    for(;;);
}

#endif

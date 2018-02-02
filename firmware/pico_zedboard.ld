




MEMORY
{
    /* program memory */
    m_prog      (rwx)   : ORIGIN = 0x00000000, LENGTH = 64k
    /* private memory for each core, up to 3 cores */
    m_private   (rw)    : ORIGIN = 0xFF000000, LENGTH = 16k
    /* shared memory */
    m_shared    (rw)    : ORIGIN = 0x10100000, LENGTH = 128M
}

OUTPUT_FORMAT("elf32-littleriscv", "elf32-littleriscv", "elf32-littleriscv")
OUTPUT_ARCH(riscv)
/* ENTRY(start) */

SECTIONS
{
    /*--------------------------------------------------------------------*/
    /* Code and read-only segment                                         */
    /*--------------------------------------------------------------------*/

    /* Begining of code and text segment */
    . = ORIGIN(m_prog);
    _ftext = .;
    PROVIDE( eprol = . );
    
    /* text: Program code section */
    .text : 
    {
        *(.text)
        *(.text.*)
        *(.gnu.linkonce.t.*)
    } > m_prog

    /* init: Code to execute before main (called by crt0.S) */
    .init : 
    {
        KEEP( *(.init) )
    } > m_prog
    
    /* fini: Code to execute after main (called by crt0.S) */
    .fini : 
    {
        KEEP( *(.fini) )
    } > m_prog
    
    /* rodata: Read-only data */
    .rodata : 
    {
        *(.rdata)
        *(.rodata)
        *(.rodata.*)
        *(.gnu.linkonce.r.*)
    } > m_prog
    
    /* End of code and read-only segment */
    PROVIDE( etext = . );
    _etext = .;
    
    /*--------------------------------------------------------------------*/
    /* Global constructor/destructor segement                             */
    /*--------------------------------------------------------------------*/

    .preinit_array     :
    {
        PROVIDE_HIDDEN (__preinit_array_start = .);
        KEEP (*(.preinit_array))
        PROVIDE_HIDDEN (__preinit_array_end = .);
    } > m_prog
    
    .init_array     :
    {
        PROVIDE_HIDDEN (__init_array_start = .);
        KEEP (*(SORT(.init_array.*)))
        KEEP (*(.init_array ))
        PROVIDE_HIDDEN (__init_array_end = .);
    } > m_prog
    
    .fini_array     :
    {
        PROVIDE_HIDDEN (__fini_array_start = .);
        KEEP (*(SORT(.fini_array.*)))
        KEEP (*(.fini_array ))
        PROVIDE_HIDDEN (__fini_array_end = .);
    } > m_prog

    /*--------------------------------------------------------------------*/
    /* Other misc gcc segments (this was in idt32.ld)                     */
    /*--------------------------------------------------------------------*/
    /* I am not quite sure about these sections but it seems they are for
        C++ exception handling. I think .jcr is for "Java Class
        Registration" but it seems to end up in C++ binaries as well. */
    
    .eh_frame_hdr     : { *(.eh_frame_hdr)     } > m_prog
    .eh_frame         : { KEEP( *(.eh_frame) ) } > m_prog
    .gcc_except_table : { *(.gcc_except_table) } > m_prog
    .jcr              : { KEEP (*(.jcr))       } > m_prog

    /*--------------------------------------------------------------------*/
    /* Initialized data segment                                           */
    /*--------------------------------------------------------------------*/
    
    /* Start of initialized data segment */
    . = ORIGIN(m_private);
    _fdata = .;

    /* data: Writable data */
    .data : AT(_etext)
    {
        *(.data)
        *(.data.*)
        *(.gnu.linkonce.d.*)
        . = ALIGN(8);
        *(.sdata)
        *(.sdata.*)
        *(.srodata.*)
        *(.gnu.linkonce.s.*)
    } > m_private

    /* End of initialized data segment */
    PROVIDE( edata = . );
    _edata = .;

    /*--------------------------------------------------------------------*/
    /* Uninitialized data segment                                         */
    /*--------------------------------------------------------------------*/
    
    /* Start of uninitialized data segment */

    . = ALIGN(8);
    
    _fbss = .;
    .bss (NOLOAD) :
    {
        *(.sbss)
        *(.sbss.*)
        *(.gnu.linkonce.sb.*)
        . = ALIGN(8);
        *(.bss)
        *(.bss.*)
        *(.gnu.linkonce.b.*)
        *(COMMON)
    } > m_private
    
    PROVIDE( ebss = . );
    _ebss = .;
    
    . = ORIGIN(m_private) + LENGTH(m_private);
    PROVIDE( estack = . );
    _estack = .;
    
    /*--------------------------------------------------------------------*/
    /* Shared data and heap segment                                       */
    /*--------------------------------------------------------------------*/
    
    . = ORIGIN(m_shared);
    PROVIDE( sshared = . );
    _sshared = .;
    
    .shared (NOLOAD) :
    {
        *(.shared)
        *(.shared.*)
    } > m_shared
    
    . = ALIGN(4);
    PROVIDE( eshared = . );
    _eshared = .;
    
    . = ALIGN(8);
    PROVIDE( sheap = . );
    _sheap = .;
    
    .heap (NOLOAD) :
    {
        KEEP(*(.heap))
        KEEP(*(.heap.*))
    } > m_shared
    
    . = ORIGIN(m_shared) + LENGTH(m_shared);
    PROVIDE( eheap = . );
    _eheap = .;
  
}

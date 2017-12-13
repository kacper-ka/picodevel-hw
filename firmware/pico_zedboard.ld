




MEMORY
{
    m_ocm   (rwx)   : ORIGIN = 0x00000000, LENGTH = 48k
}

SECTIONS
{
    .memory :
    {
        . = 0x00000000;
        *(.text.reset_vec);
        *(.text);
        *(*);
        end = .;
    } > m_ocm
}

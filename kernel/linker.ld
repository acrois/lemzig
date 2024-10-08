/* Tell the linker that we want an x86_64 ELF64 output file */
OUTPUT_FORMAT(elf64-x86-64)
OUTPUT_ARCH(i386:x86-64)

/* We want the symbol _start to be our entry point */
ENTRY(_start)

SECTIONS
{
    /* We want to be placed in the topmost 2GiB of the address space, for optimisations */
    /* and because that is what the Limine spec mandates. */
    /* Any address in this region will do, but often 0xffffffff80000000 is chosen as */
    /* that is the beginning of the region. */
    /* Additionally, leave space for the ELF headers by adding SIZEOF_HEADERS to the */
    /* base load address. */
    . = 0xffffffff80000000 + SIZEOF_HEADERS;

    .rodata ALIGN(CONSTANT(MAXPAGESIZE)) : {
        *(.rodata .rodata.*)
    }

    .text ALIGN(CONSTANT(MAXPAGESIZE)) : {
        *(.text .text.*)
    }

    .data ALIGN(CONSTANT(MAXPAGESIZE)) : {
        *(.data .data.*)

        /* Place the sections that contain the Limine requests as part of the .data */
        /* output section. */
        KEEP(*(.requests_start_marker))
        KEEP(*(.requests))
        KEEP(*(.requests_end_marker))
    }

    /* Dynamic section for relocations and other PIE related information. */
    .dynamic : {
        *(.dynamic)
    }

    /* NOTE: .bss needs to be the last thing mapped to the data PHDR, otherwise lots of */
    /* unnecessary zeros will be written to the binary. */
    /* If you need, for example, .init_array and .fini_array, those should be placed */
    /* above this. */
    .bss ALIGN(CONSTANT(MAXPAGESIZE)) : {
        *(.bss .bss.*)
        *(COMMON)
    }

    /* Discard the program interpreter section since we do not need one. This is */
    /* more or less equivalent to the --no-dynamic-linker linker flag, except that it */
    /* works with ld.gold. */
    /DISCARD/ : {
        *(.interp)
    }
}

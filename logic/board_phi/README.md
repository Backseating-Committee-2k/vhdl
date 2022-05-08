# PCIe based bss2k system on Per Vices Phi

## Device Interface

The device appears as a PCIe device with VID 1172 (Altera) and PID 1337.
There are two BARs.

### BAR 0/1

BAR 0/1 is 2 MB in size, at offsets 0 and 1 MB there are
two 32 bit RGBA framebuffers for text mode emulation.

### BAR 2

BAR 2 is 256 bytes and implements the following registers:

| Offset | Type        | Description                     |
| 0      | uint64\_t   | status word                     |
| 8      | uint64\_t   | control word                    |
| 16     | uint64\_t   | interrupt status                |
| 24     | uint64\_t   | interrupt mask                  |
| 128    | 8 x void *  | mapping of bss2k to host memory |

### Status Word

| Bits   | Description   |
| 0      | running       |
| 1      | mapping error |

#### Running

While the CPU is running, this bit is `1`, otherwise it is `0`.

#### Mapping error

When this bit is set, the host memory mapping seems to be incorrect, either
because the pages are not on 2 MB boundaries, or one of the mappings is a
NULL pointer. The CPU cannot be started then for safety reasons.

### Control Word

| Bits   | Description |
| 0      | reset       |

#### Reset

This controls the reset line of the CPU, a value of `0` lets the CPU run
normally, a value of `1` keeps it in reset.

### Interrupt Status

| Bits   | Description |
| 0      | halted      |

#### Halted

This bit is set when the CPU stops.

### Interrupt Mask

| Bits   | Description |
| 0      | halted      |

#### Halted

When this bit is set, an interrupt is triggered when the CPU stops. If the
CPU is already stopped when this bit is set, no interrupt occurs, to avoid
race conditions with very short programs.

### Mapping

The mapping area consists of 8 pointers (64 bits) into host DMA memory.
Each sets up a mapping for 2 MB of memory, and should point to a 2 MB
hugepage that is locked (or at least 2 MB of contiguous memory at a 2 MB
boundary).

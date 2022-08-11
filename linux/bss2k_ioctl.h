#pragma once

#include <asm/ioctl.h>

/* ioctls */

#define BSS2K_MAGIC (2*'K')

/* reset entire system */
#define BSS2K_IOC_RESET			_IO(BSS2K_MAGIC, 0)

/* start CPU */
#define BSS2K_IOC_START_CPU		_IO(BSS2K_MAGIC, 1)

/* read card registers */
#define BSS2K_IOC_READ_STATUS		_IOR(BSS2K_MAGIC, 0, unsigned long long)
#define BSS2K_IOC_READ_CONTROL		_IOR(BSS2K_MAGIC, 1, unsigned long long)
#define BSS2K_IOC_READ_INTSTS		_IOR(BSS2K_MAGIC, 2, unsigned long long)
#define BSS2K_IOC_READ_INTMASK		_IOR(BSS2K_MAGIC, 3, unsigned long long)

/* export DMA buffer */
#define BSS2K_IOC_GET_TEXTMODE_TEXTURE	_IOR(BSS2K_MAGIC, 64, int)

/* write card registers */
#define BSS2K_IOC_WRITE_CONTROL 	_IOW(BSS2K_MAGIC, 1, unsigned long long)
#define BSS2K_IOC_WRITE_INTMASK		_IOW(BSS2K_MAGIC, 3, unsigned long long)

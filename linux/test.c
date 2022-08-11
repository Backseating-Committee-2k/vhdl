#include <unistd.h>

#include <sys/fcntl.h>
#include <sys/ioctl.h>

#include <stdio.h>
#include <stdint.h>
#include <inttypes.h>

#include "bss2k_ioctl.h"

int main(int argc, char **argv)
{
	int fd = open("/dev/bss2k-0", O_RDWR);
	if(fd == -1)
	{
		perror("cannot open device");
		return 1;
	}

	int rc;

	uint64_t status;

	rc = ioctl(fd, BSS2K_IOC_READ_STATUS, &status);
	if(rc == -1)
	{
		perror("ioctl failed");
		return 1;
	}

	printf("%" PRIu64 "\n", status);

	rc = ioctl(fd, BSS2K_IOC_RESET);
	if(rc == -1)
	{
		perror("ioctl failed");
		return 1;
	}

	int prog_fd = open("../roms/hello_world.backseat", O_RDONLY);
	if(prog_fd == -1)
	{
		perror("cannot open program");
		return 1;
	}

	unsigned char buffer[2048];
	ssize_t size = read(prog_fd, buffer, sizeof buffer);
	if(size < 0)
	{
		perror("read program failed");
		return 1;
	}

	off_t off = lseek(fd, 0x1d3748, SEEK_SET);
	if(off != 0x1d3748)
	{
		perror("seek failed");
		return 1;
	}

	ssize_t wrsize = write(fd, buffer, size);
	if(wrsize != size)
	{
		perror("write failed");
		return 1;
	}

	rc = ioctl(fd, BSS2K_IOC_START_CPU);
	if(rc == -1)
	{
		perror("ioctl failed");
		return 1;
	}

	rc = ioctl(fd, BSS2K_IOC_READ_STATUS, &status);
	if(rc == -1)
	{
		perror("ioctl failed");
		return 1;
	}

	printf("%" PRIu64 "\n", status);

	usleep(10000);

	uint64_t control = 1ULL;

	rc = ioctl(fd, BSS2K_IOC_WRITE_CONTROL, &control);
	if(rc == -1)
	{
		perror("ioctl failed");
		return 1;
	}

	rc = ioctl(fd, BSS2K_IOC_READ_CONTROL, &control);
	if(rc == -1)
	{
		perror("ioctl failed");
		return 1;
	}

	printf("%" PRIu64 "\n", control);

	control = 3ULL;

	rc = ioctl(fd, BSS2K_IOC_WRITE_CONTROL, &control);
	if(rc == -1)
	{
		perror("ioctl failed");
		return 1;
	}

	rc = ioctl(fd, BSS2K_IOC_READ_CONTROL, &control);
	if(rc == -1)
	{
		perror("ioctl failed");
		return 1;
	}

	printf("%" PRIu64 "\n", control);

	control = 1ULL;

	rc = ioctl(fd, BSS2K_IOC_WRITE_CONTROL, &control);
	if(rc == -1)
	{
		perror("ioctl failed");
		return 1;
	}

	rc = ioctl(fd, BSS2K_IOC_READ_CONTROL, &control);
	if(rc == -1)
	{
		perror("ioctl failed");
		return 1;
	}

	printf("%" PRIu64 "\n", control);

	/*
	int texture_fd = -1;

	rc = ioctl(fd, BSS2K_IOC_GET_TEXTMODE_TEXTURE, &texture_fd);
	if(rc == -1)
	{
		perror("ioctl failed");
		return 1;
	}

	printf("%d\n", texture_fd);
	 */

	close(fd);

	return 0;
}

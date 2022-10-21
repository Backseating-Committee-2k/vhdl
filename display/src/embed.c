#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include <unistd.h>
#include <errno.h>

int main(int argc, char **argv)
{
	size_t const buffer_size = 1024;

	unsigned char buffer[buffer_size];

	size_t total = 0;

	if(argc != 3)
	{
		fprintf(stderr, "Usage: %s input output\n", argv[0]);
		exit(1);
	}

	FILE *in = fopen(argv[1], "rb");
	if(!in)
	{
		fprintf(stderr, "Cannot open %s for reading: %s\n", argv[1], strerror(errno));
		exit(1);
	}

	FILE *out = fopen(argv[2], "w");
	if(!out)
	{
		fprintf(stderr, "Cannot open %s for writing: %s\n", argv[2], strerror(errno));
		exit(1);
	}

	for(;;)
	{
		size_t const num_read = fread(buffer, 1, buffer_size, in);
		if(num_read == 0)
		{
			if(ferror(in))
				exit(1);
			if(feof(in))
				break;
		}

		size_t const count = (size_t)num_read;

		for(size_t i = 0; i < count; ++i, ++total)
		{
			fprintf(out, "0x%02x, ", buffer[i]);
			if((total & 0xf) == 0xf)
				fprintf(out, "\n");
		}
	}
	fprintf(out, "\n");

	fclose(in);
	fclose(out);

	exit(0);
}

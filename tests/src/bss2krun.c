#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include <bss2k_ioctl.h>

#if HAVE_CURSES_H && HAVE_TERM_H && HAVE_LIBTINFO
#include <curses.h>
#include <term.h>
#endif

#include <sys/types.h>
#include <sys/time.h>
#include <sys/select.h>
#include <sys/ioctl.h>

#include <fcntl.h>
#include <unistd.h>

#include <string.h>

#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <stdint.h>

static bool parse_bool(char const *const value)
{
	if(!strcmp(value, "yes"))
		return true;
	else
		return false;
}

struct options
{
	bool color_tests;
	bool expect_failure;
	bool enable_hard_errors;

	char const *test_name;
	char const *log_file;
	char const *trs_file;
};

static bool handle_option(
		char const *const opt,
		size_t const opt_len,
		char const *const optval,
		struct options *options)
{
	switch(opt_len)
	{
	case 10:
		if(!strncmp(opt, "--log-file", 10))
			options->log_file = optval;
		else if(!strncmp(opt, "--trs-file", 10))
			options->trs_file = optval;
		else
			return false;
		return true;
	case 11:
		if(!strncmp(opt, "--test-name", 11))
			options->test_name = optval;
		else
			return false;
		return true;
	case 13:
		if(!strncmp(opt, "--color-tests", 13))
			options->color_tests = parse_bool(optval);
		else
			return false;
		return true;
	case 16:
		if(!strncmp(opt, "--expect-failure", 16))
			options->expect_failure = parse_bool(optval);
		else
			return false;
		return true;
	case 20:
		if(!strncmp(opt, "--enable-hard-errors", 20))
			options->enable_hard_errors = parse_bool(optval);
		else
			return false;
		return true;
	}
	return false;
}

enum result
{
	PASS,
	XFAIL,
	SKIP,
	FAIL,
	XPASS,
	ERROR
};

enum result run_program(int prog_fd, int dev_fd)
{
	int rc;

	rc = ioctl(dev_fd, BSS2K_IOC_RESET);
	if(rc == -1)
		return ERROR;

	/* TODO: magic value */
	off_t const start_address = 0x1d1fd8;

	off_t const address = lseek(dev_fd, start_address, SEEK_SET);

	if(address != start_address)
		return ERROR;

	for(;;)
	{
		unsigned char buffer[256];
		ssize_t const read_count = read(prog_fd, buffer, sizeof buffer);
		if(read_count < 0)
			return ERROR;
		if(read_count == 0)
			break;
		if((size_t)read_count > sizeof buffer)
			return ERROR;
		ssize_t const write_count = write(dev_fd, buffer, read_count);
		if(write_count != read_count)
			return ERROR;
	}

	rc = ioctl(dev_fd, BSS2K_IOC_START_CPU);
	if(rc == -1)
		return ERROR;

	struct timeval now;
	rc = gettimeofday(&now, NULL);
	if(rc == -1)
		return ERROR;

	struct timeval const end =
	{
		/* one second timeout */
		now.tv_sec + 1,
		now.tv_usec
	};

	for(;;)
	{
		struct timeval timeout;

		if(now.tv_sec > end.tv_sec)
		{
			return FAIL;
		}
		else if(now.tv_sec == end.tv_sec)
		{
			if(now.tv_usec > end.tv_usec)
				return FAIL;
			timeout.tv_sec = 0;
			timeout.tv_usec = end.tv_usec - now.tv_usec;
		}
		else if(now.tv_usec > end.tv_usec)
		{
			timeout.tv_sec = end.tv_sec - 1 - now.tv_sec;
			timeout.tv_usec = end.tv_usec + 1000000 - now.tv_usec;
		}
		else
		{
			timeout.tv_sec = end.tv_sec - now.tv_sec;
			timeout.tv_usec = end.tv_usec - now.tv_usec;
		}

		fd_set readfds;

		FD_ZERO(&readfds);
		FD_SET(dev_fd, &readfds);

		rc = select(dev_fd + 1, &readfds, NULL, NULL, &timeout);
		if(rc == -1)
			return ERROR;
		if(rc == 0)
			return FAIL;

		uint64_t status;

		rc = ioctl(dev_fd, BSS2K_IOC_READ_STATUS, &status);
		if(rc == -1)
			return ERROR;

		/* TODO: magic value */
		if(!(status & (uint64_t)1))
		{
			if(status & (uint64_t)4)
				return FAIL;
			return PASS;
		}
	}
}

int main(int argc, char **argv)
{
	struct options options =
	{
		false, false, false,
		NULL, NULL, NULL
	};

	char **test_argv = NULL;
	int test_argc = 0;

	bool expect_options = true;

	for(int i = 1; i < argc; ++i)
	{
		char const *const arg = argv[i];

		if(expect_options)
		{
			char const *const equals = strchr(arg, '=');
			if(equals && handle_option(arg, equals - arg, equals + 1, &options))
				continue;

			size_t const arg_len = strlen(arg);

			if(arg_len > 0 && arg[0] == '-')
			{
				if(arg_len == 2 && arg[1] == '-')
				{
					expect_options = false;
					continue;
				}

				bool const have_another_arg = (i + 1 < argc);

				if(have_another_arg && handle_option(arg, arg_len, argv[i+1], &options))
				{
					++i;
					continue;
				}

				/* option, but not handled yet */
				fprintf(stderr, "Invalid option: \"%s\"\n", arg);
				return 1;
			}
		}

		/* have a file name, rest are args to the test */
		test_argv = argv + i;
		test_argc = argc - i;
		break;
	}

	if(!options.test_name)
	{
		fprintf(stderr, "Missing --test-name option\n");
		return 1;
	}

	if(!options.log_file)
	{
		fprintf(stderr, "Missing --log-file option\n");
		return 1;
	}

	if(!options.trs_file)
	{
		fprintf(stderr, "Missing --trs-file option\n");
		return 1;
	}

	int const log_fd = open(options.log_file, O_WRONLY|O_CREAT, 0666);
	if(log_fd == -1)
	{
		perror("Cannot open log file");
		return 1;
	}

	int const trs_fd = open(options.trs_file, O_WRONLY|O_CREAT, 0666);
	if(trs_fd == -1)
	{
		perror("Cannot open trs file");
		close(log_fd);
		return 1;
	}

	char *normal = NULL;
	char *bold = NULL;
	char *red = NULL;
	char *yellow = NULL;
	char *green = NULL;

#if HAVE_CURSES_H && HAVE_TERM_H && HAVE_LIBTINFO
	if(options.color_tests)
	{
		int err_setupterm;
		/*int const rc_setupterm = */ setupterm(NULL, STDOUT_FILENO, &err_setupterm);

		if(cur_term)
		{
			normal = strdup(tiparm(exit_attribute_mode));
			bold = strdup(tiparm(enter_bold_mode));
			red = strdup(tiparm(set_a_foreground, COLOR_RED));
			yellow = strdup(tiparm(set_a_foreground, COLOR_YELLOW));
			green = strdup(tiparm(set_a_foreground, COLOR_GREEN));
		}
	}
#endif

	enum result result = PASS;

	char const *message = NULL;

	if(!test_argc)
	{
		result = ERROR;
		message = "Missing test program";
	}
	else if(test_argc > 1)
	{
		result = ERROR;
		message = "Test program arguments not supported";
	}
	else
	{
		int const dev_fd = open("/dev/bss2k-0", O_RDWR|O_EXCL);
		if(dev_fd == -1)
		{
			result = SKIP;
			message = "Device unavailable";
		}
		else
		{
			int const prog_fd = open(test_argv[0], O_RDONLY);
			if(prog_fd == -1)
			{
				result = ERROR;
				message = "Cannot open program";
			}
			else
			{
				result = run_program(prog_fd, dev_fd);

				close(prog_fd);
			}

			ioctl(dev_fd, BSS2K_IOC_RESET);
			close(dev_fd);
		}
	}

	if(options.expect_failure)
		/* translate */
		switch(result)
		{
		case PASS:	result = XPASS;		break;
		case FAIL:	result = XFAIL;		break;
		default:						break;
		}

	char const *result_str;

	switch(result)
	{
	case PASS:	result_str = "PASS";	break;
	case XFAIL:	result_str = "XFAIL";	break;
	case SKIP:	result_str = "SKIP";	break;
	case FAIL:	result_str = "FAIL";	break;
	case XPASS:	result_str = "XPASS";	break;
	default:
	case ERROR:	result_str = "ERROR";	break;
	}

	char const *result_attr;
	char const *result_color;

	switch(result)
	{
	case PASS:	result_attr = normal;	result_color = green;	break;
	case XFAIL:	result_attr = bold;	result_color = green;	break;
	case SKIP:	result_attr = normal;	result_color = yellow;	break;
	case FAIL:	result_attr = normal;	result_color = red;	break;
	case XPASS:	result_attr = bold;	result_color = red;	break;
	default:
	case ERROR:	result_attr = bold;	result_color = red;	break;
	}

	if(!result_color)
		result_color = "";
	if(!result_attr)
		result_attr = "";

	bool const print_message = !! message;

	if(print_message)
		printf("%s%s%s: %s (%s)%s\n", result_attr, result_color, result_str, options.test_name, message, normal);
	else
		printf("%s%s%s: %s%s\n", result_attr, result_color, result_str, options.test_name, normal);

	if(print_message)
		dprintf(log_fd, "%s: %s (%s)\n", result_str, options.test_name, message);
	else
		dprintf(log_fd, "%s: %s\n", result_str, options.test_name);

	dprintf(trs_fd,
			":test-result: %s\n"
			":global-test-result: %s\n"
			":recheck: no\n"
			":copy-in-global-log: no\n",
			result_str,
			result_str);

	free(green);
	free(yellow);
	free(red);
	free(bold);
	free(normal);

	close(trs_fd);
	close(log_fd);

	return 0;
}

library ieee;
use ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL;

package bss2k is
	constant address_width : integer := 24;
	constant instruction_size : integer := 64;
	constant word_size : integer := 32;
	constant byte_size : integer := 8;

	subtype address is std_logic_vector(address_width - 1 downto 0);
	subtype instruction is std_logic_vector(instruction_size - 1 downto 0);
	subtype word is std_logic_vector(word_size - 1 downto 0);
	subtype reg is std_logic_vector(7 downto 0);

	function to_word(a : address) return word;
	function to_address(w : word) return address;

	-- text mode
	constant terminal_width : integer := 80;
	constant terminal_height : integer := 25;

	-- graphics mode
	constant framebuffer_width : integer := 480;
	constant framebuffer_height : integer := 360;

	-- size calculations
	constant terminal_buffer_size : integer :=
		(terminal_width * terminal_height);
	constant framebuffer_size : integer :=
		(framebuffer_width * framebuffer_height) * 4;	-- RGBA

	constant stack_size : integer := 512 * 1024;

	-- address calculations
	constant terminal_buffer_start : address := x"000000";
	constant terminal_cursor_pointer : address :=
		address(unsigned(terminal_buffer_start) + terminal_buffer_size);
	constant terminal_cursor_mode : address :=
		address(unsigned(terminal_cursor_pointer) + word_size / byte_size);
	constant first_framebuffer_start : address :=
		address(unsigned(terminal_cursor_mode) + word_size / byte_size);
	constant second_framebuffer_start : address :=
		address(unsigned(first_framebuffer_start) + framebuffer_size);
	constant stack_start : address :=
		address(unsigned(second_framebuffer_start) + framebuffer_size);
	constant entry_point : address :=
		address(unsigned(stack_start) + stack_size);
end package;

package body bss2k is
	function to_word(a : address) return word is
		variable ret : word;
	begin
		ret := (others => '0');
		ret(address'range) := a;
		return ret;
	end function;

	function to_address(w : word) return address is
	begin
		return w(address'range);
	end function;
end package body;

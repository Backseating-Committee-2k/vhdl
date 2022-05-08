library ieee;
use ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL;

package bss2k is
	constant address_width : integer := 24;
	constant instruction_size : integer := 64;
	constant word_size : integer := 32;

	subtype address is std_logic_vector(address_width - 1 downto 0);
	subtype instruction is std_logic_vector(instruction_size - 1 downto 0);
	subtype word is std_logic_vector(word_size - 1 downto 0);
end package;

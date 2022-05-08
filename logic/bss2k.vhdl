library ieee;
use ieee.std_logic_1164.ALL;

package bss2k is
	constant address_width : integer := 24;

	subtype address is std_logic_vector(address_width - 1 downto 0);
end package;

library ieee;
use ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL;

entity registers is
	port(
		clock : in std_logic;
		address_a : in std_logic_vector (7 downto 0);
		address_b : in std_logic_vector (7 downto 0);
		data_a : in std_logic_vector (31 downto 0);
		data_b : in std_logic_vector (31 downto 0);
		wren_a : in std_logic;
		wren_b : in std_logic;
		q_a : out std_logic_vector (31 downto 0);
		q_b : out std_logic_vector (31 downto 0)
	);
end entity;

architecture sim of registers is
	constant address_width : integer := 8;
	constant word_width : integer := 32;

	subtype address is std_logic_vector(address_width - 1 downto 0);
	subtype word is std_logic_vector(word_width - 1 downto 0);

	subtype index is integer range 0 to 2 ** address_width - 1;

	type storage_type is array(index) of word;
	signal storage : storage_type;
begin
	q_a <= storage(to_integer(unsigned(address_a)));
	q_b <= storage(to_integer(unsigned(address_b)));

	process(clock) is
	begin
		if(rising_edge(clock)) then
			if(wren_a = '1') then
				storage(to_integer(unsigned(address_a))) <= data_a;
			end if;
			if(wren_b = '1') then
				storage(to_integer(unsigned(address_b))) <= data_b;
			end if;
		end if;
	end process;
end architecture;

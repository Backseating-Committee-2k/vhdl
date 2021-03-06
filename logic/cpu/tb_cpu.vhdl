library ieee;
use ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL;

use work.bss2k.ALL;

library std;
use std.env.finish;

entity tb_cpu is
begin
end entity;

architecture sim of tb_cpu is
	component cpu is
		port(
			-- async reset
			reset : in std_logic;

			-- clock
			clk : in std_logic;

			-- instruction bus (Avalon-MM)
			i_addr : out address;
			i_rddata : in instruction;
			i_rdreq : out std_logic;
			i_waitrequest : in std_logic;

			-- data bus (Avalon-MM)
			d_addr : out address;
			d_rddata : in word;
			d_rdreq : out std_logic;
			d_wrdata : out word;
			d_wrreq : out std_logic;
			d_waitrequest : in std_logic;

			-- status
			halted : out std_logic
		);
	end component;

	signal reset : std_logic;
	signal clk : std_logic := '0';

	signal i_addr : address;
	signal i_rddata : instruction;
	signal i_rdreq : std_logic;
	signal i_waitrequest : std_logic;

	signal d_addr : address;
	signal d_rddata : word;
	signal d_rdreq : std_logic;
	signal d_wrdata : word;
	signal d_wrreq : std_logic;
	signal d_waitrequest : std_logic;

	signal halted : std_logic;

	constant rom_size : integer := 256;
	constant rom_start : integer := to_integer(unsigned(entry_point));
	constant rom_end : integer := rom_start + rom_size - 1;

	type insn_mem is array(rom_start to rom_end) of instruction;
	signal i : insn_mem;

	type data_mem is array(16#0000# to 16#ffff#) of word;
	signal d : data_mem;
begin
	-- reset gen
	reset <= '1', '0' after 1 us;

	-- clk gen
	clk <= not clk after 100 ns;

	-- sim timeout
	process is
	begin
		wait for 60 us;
		report "sim timeout" severity error;
		finish;
	end process;

	-- normal exit
	process is
	begin
		wait until halted = '1';
		wait for 400 ns;
		finish;
	end process;

	-- stimuli
	process is
		type insn_file_type is file of character;
		file rom : insn_file_type;
		variable fstatus : file_open_status;
		variable t : character;
		variable a : instruction;
		variable x : integer;
	begin
		file_open(fstatus, rom, "../roms/hello_world.backseat", read_mode);
		x := i'low;
		while not endfile(rom) loop
			a := (others => '0');
			for y in 0 to 7 loop
				read(rom, t);
				a := a(55 downto 0) & std_logic_vector(to_unsigned(character'pos(t), 8));
			end loop;
			i(x) <= a;
			-- increment by eight, because instructions are 64 bit
			x := x + 8;
		end loop;
		wait;
	end process;

	-- instruction bus
	i_rddata <= i(to_integer(unsigned(i_addr))) when i_rdreq = '1' else (others => 'U');
	i_waitrequest <= '0';

	-- data bus
	d_rddata <= d(to_integer(unsigned(d_addr))) when d_rdreq = '1' else (others => 'U');
	d(to_integer(unsigned(d_addr))) <= d_wrdata when rising_edge(clk) and d_wrreq = '1';
	d_waitrequest <= '0';

	-- dut
	dut : cpu
		port map(
			reset => reset,
			clk => clk,
			i_addr => i_addr,
			i_rddata => i_rddata,
			i_rdreq => i_rdreq,
			i_waitrequest => i_waitrequest,
			d_addr => d_addr,
			d_rddata => d_rddata,
			d_rdreq => d_rdreq,
			d_wrdata => d_wrdata,
			d_wrreq => d_wrreq,
			d_waitrequest => d_waitrequest,
			halted => halted
	);
end architecture;

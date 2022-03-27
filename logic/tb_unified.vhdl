library ieee;
use ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL;

library std;
use std.env.finish;

entity tb_unified is
begin
end entity;

architecture sim of tb_unified is
	signal reset : std_logic;
	signal clk : std_logic := '0';

	constant address_width : integer := 32;
	constant word_width : integer := 32;

	subtype address is std_logic_vector(address_width - 1 downto 0);
	subtype insn is std_logic_vector(63 downto 0);
	subtype word is std_logic_vector(word_width - 1 downto 0);

	signal i_addr : address;
	signal i_rddata : insn;
	signal i_rdreq : std_logic;
	signal i_waitrequest : std_logic;

	signal d_addr : address;
	signal d_rddata : word;
	signal d_rdreq : std_logic;
	signal d_wrdata : word;
	signal d_wrreq : std_logic;
	signal d_waitrequest : std_logic;

	signal halted : std_logic;
	signal addr : address;
	signal rddata : word;
	signal rdreq : std_logic;
	signal wrdata : word;
	signal wrreq : std_logic;
	signal waitrequest : std_logic;

	type mem is array(16#0000# to 16#00ff#) of word;
	signal m : mem := (others => (others => 'Z'));
begin
	-- reset gen
	reset <= '1', '0' after 1 us;

	-- clk gen
	clk <= not clk after 100 ns;

	-- sim timeout
	process is
	begin
		wait for 40 us;
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
		variable a : word;
		variable x : integer;
	begin
		file_open(fstatus, rom, "hello_world.backseat", read_mode);
		x := 0;
		while not endfile(rom) loop
			a := (others => '0');
			for y in 0 to 3 loop
				read(rom, t);
				a := a(23 downto 0) & std_logic_vector(to_unsigned(character'pos(t), 8));
				report integer'image(x) & " " & to_string(a) severity note;
			end loop;
			m(x) <= a;
			-- increment by four, because we're writing words
			x := x + 4;
		end loop;
		report "read " & integer'image(x) & " bytes." severity note;
		wait;
	end process;

	-- memory bus
	rddata <= m(to_integer(unsigned(addr))) when rdreq = '1' else (others => 'U');
	m(to_integer(unsigned(addr))) <= wrdata when rising_edge(clk) and wrreq = '1';
	waitrequest <= '0';

	-- dut cpu
	dut_cpu : entity work.cpu
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

	-- dut arbiter
	dut_arbiter : entity work.mem_arbiter
		port map(
			reset => reset,
			clk => clk,
			comb_addr => addr,
			comb_rdreq => rdreq,
			comb_rddata => rddata,
			comb_wrreq => wrreq,
			comb_wrdata => wrdata,
			comb_waitrequest => waitrequest,
			i_addr => i_addr,
			i_rdreq => i_rdreq,
			i_rddata => i_rddata,
			i_waitrequest => i_waitrequest,
			d_addr => d_addr,
			d_rdreq => d_rdreq,
			d_rddata => d_rddata,
			d_wrreq => d_wrreq,
			d_wrdata => d_wrdata,
			d_waitrequest => d_waitrequest
	);
end architecture;

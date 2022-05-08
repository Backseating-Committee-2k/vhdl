library ieee;
use ieee.std_logic_1164.ALL;

library std;
use std.env.finish;

entity tb_mem_arbiter is
begin
end entity;

architecture sim of tb_mem_arbiter is
	-- async
	signal reset : std_logic;

	-- clock
	signal clk : std_logic := '0';

	-- combined (Avalon-MM)
	signal comb_addr : std_logic_vector(23 downto 0);
	signal comb_rdreq : std_logic;
	signal comb_rddata : std_logic_vector(31 downto 0);
	signal comb_wrreq : std_logic;
	signal comb_wrdata : std_logic_vector(31 downto 0);
	signal comb_waitrequest : std_logic;

	-- insn bus (Avalon-MM)
	signal i_addr : std_logic_vector(23 downto 0);
	signal i_rdreq : std_logic;
	signal i_rddata : std_logic_vector(63 downto 0);
	signal i_waitrequest : std_logic;

	-- data bus (Avalon-MM)
	signal d_addr : std_logic_vector(23 downto 0);
	signal d_rdreq : std_logic;
	signal d_rddata : std_logic_vector(31 downto 0);
	signal d_wrreq : std_logic;
	signal d_wrdata : std_logic_vector(31 downto 0);
	signal d_waitrequest : std_logic;
begin
	reset <= '1', '0' after 1 us;

	clk <= not clk after 100 ns;

	timeout : process is
	begin
		wait for 100 us;
		report "sim timeout" severity error;
		finish;
	end process;

	stimuli : process is
		procedure tick is
		begin
			wait until rising_edge(clk);
		end procedure;
	begin
		i_rdreq <= '0';
		d_rdreq <= '0';
		d_wrreq <= '0';
		wait until reset = '0';
		tick;
		i_rdreq <= '1';
		i_addr <= x"000000";
		tick;
		while i_waitrequest = '1' loop
			tick;
		end loop;
		i_rdreq <= '0';
		d_rdreq <= '1';
		d_addr <= x"123456";
		tick;
		while d_waitrequest = '1' loop
			tick;
		end loop;
		d_rdreq <= '0';
		d_wrreq <= '1';
		d_addr <= x"654321";
		d_wrdata <= x"2468ace0";
		tick;
		while d_waitrequest = '1' loop
			tick;
		end loop;


		finish;
	end process;

	memory : process(reset, clk) is
		type state is (idle, read, write);
		variable s : state;
	begin
		if(reset = '1') then
			s := idle;
		elsif(rising_edge(clk)) then
			case s is
				when idle =>
					if(comb_rdreq = '1') then
						comb_waitrequest <= '1';
						s := read;
					elsif(comb_wrreq = '1') then
						comb_waitrequest <= '1';
						s := write;
					end if;
				when read =>
					comb_rddata <= x"00" & comb_addr;
					comb_waitrequest <= '0';
					s := idle;
				when write =>
					comb_waitrequest <= '0';
					s := idle;
			end case;
		end if;
	end process;

	dut : entity work.mem_arbiter
		port map(
			-- async
			reset => reset,

			-- clock
			clk => clk,

			-- combined (Avalon-MM)
			comb_addr => comb_addr,
			comb_rdreq => comb_rdreq,
			comb_rddata => comb_rddata,
			comb_wrreq => comb_wrreq,
			comb_wrdata => comb_wrdata,
			comb_waitrequest => comb_waitrequest,

			-- insn bus (Avalon-MM)
			i_addr => i_addr,
			i_rdreq => i_rdreq,
			i_rddata => i_rddata,
			i_waitrequest => i_waitrequest,

			-- data bus (Avalon-MM)
			d_addr => d_addr,
			d_rdreq => d_rdreq,
			d_rddata => d_rddata,
			d_wrreq => d_wrreq,
			d_wrdata => d_wrdata,
			d_waitrequest => d_waitrequest
		);
end architecture;

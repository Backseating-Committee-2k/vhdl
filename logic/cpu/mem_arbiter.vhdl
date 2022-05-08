library ieee;
use ieee.std_logic_1164.ALL;

use work.bss2k.ALL;

entity mem_arbiter is
	port(
		-- async
		reset : in std_logic;

		-- clock
		clk : in std_logic;

		-- combined (Avalon-MM)
		comb_addr : out address;
		comb_rdreq : out std_logic;
		comb_rddata : in std_logic_vector(31 downto 0);
		comb_wrreq : out std_logic;
		comb_wrdata : out std_logic_vector(31 downto 0);
		comb_waitrequest : in std_logic;

		-- insn bus (Avalon-MM)
		i_addr : in address;
		i_rdreq : in std_logic;
		i_rddata : out instruction;
		i_waitrequest : out std_logic;

		-- data bus (Avalon-MM)
		d_addr : in address;
		d_rdreq : in std_logic;
		d_rddata : out std_logic_vector(31 downto 0);
		d_wrreq : in std_logic;
		d_wrdata : in std_logic_vector(31 downto 0);
		d_waitrequest : out std_logic
	);
end entity;

architecture rtl of mem_arbiter is
	type state is (data, insn1, insn2);
	signal s : state;

	signal i_buffer : std_logic_vector(31 downto 0);
begin
	with s select comb_addr <=
		i_addr when insn1,
		i_addr xor x"000004" when insn2,
		d_addr when data;
	with s select comb_rdreq <=
		i_rdreq when insn1|insn2,
		d_rdreq when data;
	with s select comb_wrreq <=
		'0' when insn1|insn2,
		d_wrreq when data;

	comb_wrdata <= d_wrdata;
	i_rddata(31 downto 0) <= comb_rddata;
	i_rddata(63 downto 32) <= i_buffer;
	d_rddata <= comb_rddata;

	with s select i_waitrequest <=
		'1' when insn1|data,
		comb_waitrequest when insn2;
	with s select d_waitrequest <=
		'1' when insn1|insn2,
		comb_waitrequest when data;

	i_buffer <= comb_rddata when s = insn1 and rising_edge(clk);

	process(reset, clk) is
	begin
		if(reset = '1') then
			s <= data;
		elsif(rising_edge(clk)) then
			case s is
				when data =>
					if(i_rdreq = '1' and d_rdreq = '0' and d_wrreq = '0') then
						s <= insn1;
					end if;
				when insn1 =>
					if(comb_waitrequest = '0') then
						s <= insn2;
					end if;
				when insn2 =>
					if(comb_waitrequest = '0') then
						s <= data;
					end if;
			end case;
		end if;
	end process;
end architecture;

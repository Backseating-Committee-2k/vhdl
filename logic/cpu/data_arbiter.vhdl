library ieee;
use ieee.std_logic_1164.ALL;

entity data_arbiter is
	generic(
		address_width : integer range 1 to 32 := 32
	);
	port(
		-- combined data bus (Avalon-MM)
		comb_addr : out std_logic_vector(address_width - 1 downto 0);
		comb_rdreq : out std_logic;
		comb_rddata : in std_logic_vector(31 downto 0);
		comb_wrreq : out std_logic;
		comb_wrdata : out std_logic_vector(31 downto 0);
		comb_waitrequest : in std_logic;

		-- load bus (Avalon-MM, read only)
		load_addr : in std_logic_vector(address_width - 1 downto 0);
		load_rdreq : in std_logic;
		load_rddata : out std_logic_vector(31 downto 0);
		load_waitrequest : out std_logic;

		-- store bus (Avalon-MM, write only)
		store_addr : in std_logic_vector(address_width - 1 downto 0);
		store_wrreq : in std_logic;
		store_wrdata: in std_logic_vector(31 downto 0);
		store_waitrequest : out std_logic
	);
end entity;

architecture rtl of data_arbiter is
	type path is (idle, load, store);
	signal active : path;
begin
	-- TODO waiting load should not be interrupted by store
	active <= store when store_wrreq = '1' and active /= load else
		  load when load_rdreq = '1' else
		  idle;

	with active select comb_addr <=
		load_addr when load,
		store_addr when store,
		(others => 'U') when idle;

	with active select comb_rdreq <=
		load_rdreq when load,
		'0' when store|idle;
	load_rddata <= comb_rddata;
	with active select load_waitrequest <=
		comb_waitrequest when load,
		load_rdreq when store|idle;

	with active select comb_wrreq <=
		store_wrreq when store,
		'0' when load|idle;
	comb_wrdata <= store_wrdata;
	with active select store_waitrequest <=
		comb_waitrequest when store,
		store_wrreq when load|idle;
end architecture;

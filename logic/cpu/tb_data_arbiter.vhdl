library ieee;
use ieee.std_logic_1164.ALL;
use ieee.numeric_std.std_match;

library std;
use std.env.finish;

entity tb_data_arbiter is
begin
end entity;

architecture sim of tb_data_arbiter is
	constant address_width : integer := 32;

	-- combined data bus (Avalon-MM)
	signal comb_addr : std_logic_vector(address_width - 1 downto 0);
	signal comb_rdreq : std_logic;
	signal comb_rddata : std_logic_vector(31 downto 0);
	signal comb_wrreq : std_logic;
	signal comb_wrdata : std_logic_vector(31 downto 0);
	signal comb_waitrequest : std_logic;

	-- load bus (Avalon-MM, read only)
	signal load_addr : std_logic_vector(address_width - 1 downto 0);
	signal load_rdreq : std_logic;
	signal load_rddata : std_logic_vector(31 downto 0);
	signal load_waitrequest : std_logic;

	-- store bus (Avalon-MM, write only)
	signal store_addr : std_logic_vector(address_width - 1 downto 0);
	signal store_wrreq : std_logic;
	signal store_wrdata : std_logic_vector(31 downto 0);
	signal store_waitrequest : std_logic;
begin
	process is
		type testcase is record
			-- combined data bus (Avalon-MM)
			comb_addr : std_logic_vector(address_width - 1 downto 0);
			comb_rdreq : std_logic;
			comb_rddata : std_logic_vector(31 downto 0);
			comb_wrreq : std_logic;
			comb_wrdata : std_logic_vector(31 downto 0);
			comb_waitrequest : std_logic;

			-- load bus (Avalon-MM, read only)
			load_addr : std_logic_vector(address_width - 1 downto 0);
			load_rdreq : std_logic;
			load_rddata : std_logic_vector(31 downto 0);
			load_waitrequest : std_logic;

			-- store bus (Avalon-MM, write only)
			store_addr : std_logic_vector(address_width - 1 downto 0);
			store_wrreq : std_logic;
			store_wrdata : std_logic_vector(31 downto 0);
			store_waitrequest : std_logic;
		end record;
		type testcases is array(1 to 7) of testcase;

		constant tests : testcases :=
			(
				-- idle
				1 => (
					(others => '-'), '0', (others => 'U'), '0', (others => '-'), '0',
					(others => 'U'), '0', (others => '-'), '0',
					(others => 'U'), '0', (others => 'U'), '0'
				),
				-- read request
				2 => (
					x"12345678", '1', x"87654321", '0', (others => '-'), '0',
					x"12345678", '1', x"87654321", '0',
					(others => 'U'), '0', (others => 'U'), '0'
				),
				-- write request
				3 => (
					x"23456789", '0', (others => 'U'), '1', x"98765432", '0',
					(others => 'U'), '0', (others => '-'), '0',
					x"23456789", '1', x"98765432", '0'
				),
				-- simultaneous read and write (write wins)
				4 => (
					x"23456789", '0', (others => 'U'), '1', x"98765432", '0',
					x"12345678", '1', (others => '-'), '1',
					x"23456789", '1', x"98765432", '0'
				),
				-- load with waitrequest, store in second cycle
				5 => (
					x"12345678", '1', (others => 'U'), '0', (others => '-'), '1',
					x"12345678", '1', (others => '-'), '1',
					(others => 'U'), '0', (others => 'U'), '0'
				),
				6 => (
					x"12345678", '1', x"87654321", '0', (others => '-'), '0',
					x"12345678", '1', x"87654321", '0',
					x"23456789", '1', x"98765432", '1'
				),
				7 => (
					x"23456789", '0', (others => 'U'), '1', x"98765432", '0',
					(others => 'U'), '0', (others => '-'), '0',
					x"23456789", '1', x"98765432", '0'
				)
			);
	begin
		for i in testcases'range loop
			comb_rddata <= tests(i).comb_rddata;
			comb_waitrequest <= tests(i).comb_waitrequest;
			load_addr <= tests(i).load_addr;
			load_rdreq <= tests(i).load_rdreq;
			store_addr <= tests(i).store_addr;
			store_wrreq <= tests(i).store_wrreq;
			store_wrdata <= tests(i).store_wrdata;

			wait for 10 ns;

			assert std_match(comb_addr, tests(i).comb_addr) report "comb_addr is " & to_string(comb_addr) & ", should be " & to_string(tests(i).comb_addr) severity error;
			assert std_match(comb_rdreq, tests(i).comb_rdreq) report "comb_rdreq is " & to_string(comb_rdreq) & ", should be " & to_string(tests(i).comb_rdreq) severity error;
			assert std_match(comb_wrreq, tests(i).comb_wrreq) report "comb_wrreq is " & to_string(comb_wrreq) & ", should be " & to_string(tests(i).comb_wrreq) severity error;
			assert std_match(comb_wrdata, tests(i).comb_wrdata) report "comb_wrdata is " & to_string(comb_wrdata) & ", should be " & to_string(tests(i).comb_wrdata) severity error;
			assert std_match(load_rddata, tests(i).load_rddata) report "load_rddata is " & to_string(load_rddata) & ", should be " & to_string(tests(i).load_rddata) severity error;
			assert std_match(load_waitrequest, tests(i).load_waitrequest) report "load_waitrequest is " & to_string(load_waitrequest) & ", should be " & to_string(tests(i).load_waitrequest) severity error;
			assert std_match(store_waitrequest, tests(i).store_waitrequest) report "store_waitrequest is " & to_string(store_waitrequest) & ", should be " & to_string(tests(i).store_waitrequest) severity error;

			wait for 10 ns;
		end loop;

		wait for 10 ns;

		finish;
	end process;

	dut : entity work.data_arbiter
		generic map(
			address_width => address_width
		)
		port map(
			-- combined data bus (Avalon-MM)
			comb_addr => comb_addr,
			comb_rdreq => comb_rdreq,
			comb_rddata => comb_rddata,
			comb_wrreq => comb_wrreq,
			comb_wrdata => comb_wrdata,
			comb_waitrequest => comb_waitrequest,

			-- load bus (Avalon-MM, read only)
			load_addr => load_addr,
			load_rdreq => load_rdreq,
			load_rddata => load_rddata,
			load_waitrequest => load_waitrequest,

			-- store bus (Avalon-MM, write only)
			store_addr => store_addr,
			store_wrreq => store_wrreq,
			store_wrdata => store_wrdata,
			store_waitrequest => store_waitrequest
		);
end architecture;

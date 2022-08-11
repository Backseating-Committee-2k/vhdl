library ieee;
use ieee.std_logic_1164.ALL;

use work.bss2k.ALL;

entity mem_to_pcie is
	port(
		-- async reset
		reset : in std_logic;

		-- clock
		clk : in std_logic;

		-- cpu side
		i_addr : in address;
		i_rdreq : in std_logic;
		i_rddata : out instruction;
		i_waitrequest : std_logic;
		d_addr : in address;
		d_rdreq : in std_logic;
		d_rddata : out word;
		d_wrreq : in std_logic;
		d_wrdata : in word;
		d_waitrequest : out std_logic;

		-- PCIe side (Avalon-ST)
		rx_ready : out std_logic;
		rx_valid : in std_logic;
		rx_data : in std_logic_vector(63 downto 0);
		rx_sop : in std_logic;
		rx_eop : in std_logic;
		rx_err : in std_logic;

		tx_ready : in std_logic;
		tx_valid : out std_logic;
		tx_data : out std_logic_vector(63 downto 0);
		tx_sop : out std_logic;
		tx_eop : out std_logic;
		tx_err : out std_logic;

		cpl_pending : out std_logic;

		device_id : in std_logic_vector(15 downto 0);

		-- host address lookup
		cpu_address : out address;
		host_address : in std_logic_vector(63 downto 0)
	);
end entity;

architecture rtl of mem_to_pcie is
	signal i_rdvalid : std_logic;
	signal i_lastaddr : address;
	signal i_lastaddr_valid : std_logic;

	signal i_rdbusy : std_logic;
	signal i_set_rdbusy : std_logic;
	signal i_reset_rdbusy : std_logic;

	subtype tag is std_logic_vector(7 downto 0);
	constant i_tag : tag := x"00";
	constant d_tag : tag := x"01";
begin
	i_waitrequest <= i_rdreq and not i_rdvalid;

	i_rdvalid <= '0' when ?? not i_lastaddr_valid else
				 '1' when i_addr = i_lastaddr else
				 '0';

	i_rdbusy <= '0' when ?? reset else
		    '1' when ?? i_set_rdbusy else
		    '0' when ?? i_reset_rdbusy else
		    unaffected;

	requester : process(reset, clk) is
		type state is (idle, header1, header2);
		variable s : state;

		variable current_tag : tag;
		variable current_address : address;
	begin
		if(?? reset) then
			s := idle;
			i_set_rdbusy <= '0';
			tx_valid <= '0';
			tx_data <= (others => 'U');
			tx_sop <= 'U';
			tx_eop <= 'U';
			tx_err <= 'U';
		elsif(rising_edge(clk)) then
			i_set_rdbusy <= '0';

			tx_valid <= '0';
			tx_data <= (others => 'U');
			tx_sop <= 'U';
			tx_eop <= 'U';

			-- never generate errors
			tx_err <= '0';

			-- TODO look at tx_ready
			case s is
				when idle =>
					if(?? i_rdreq and not i_rdbusy) then
						tx_valid <= '1';
						tx_data <= device_id &	-- requester
							   i_tag &	-- tag
							   x"FF" &	-- enables
							   "0" &	-- reserved
							   "0" &	-- write
							   "1" &	-- 64 bit
							   "00000" &	-- type: mem
							   "0" &	-- reserved
							   "000" &	-- class
							   "0000" &	-- reserved
							   "0" &	-- digest
							   "0" &	-- poisoned?
							   "00" &	-- attrib
							   "00" &	-- reserved
							   "0000000010"; -- length
						tx_sop <= '1';
						tx_eop <= '0';

						cpu_address <= i_addr;

						i_set_rdbusy <= '1';

						s := header1;
					end if;
				when header1 =>
					-- TODO other buses
					cpu_address <= i_addr;

					tx_valid <= '1';
					tx_data <= host_address;
					tx_sop <= '0';
					tx_eop <= '1';

					s := idle;
				when header2 =>
					null;
			end case;
		end if;
	end process;

	completion_handler : process(reset, clk) is
		type state is (ignore, header2, data);
		variable s : state;
	begin
		if(?? reset) then
			i_reset_rdbusy <= '1';
			i_lastaddr_valid <= '0';
			i_lastaddr <= (others => 'U');
			s := ignore;
		elsif(rising_edge(clk)) then
			i_reset_rdvalid <= '0';

			if(?? rx_valid) then
				if(?? rx_sop) then
					-- header1 "state" is here, not in the state machine
					-- SOP resets to header1, and the state is immediately
					-- left afterwards
					if(rx_data(30) = '1' and
							rx_data(28 downto 24) = "01010") then
						s := header2;
					else
						s := ignore;
					end if;
				else
					case s is
						when ignore =>
							null;
						when header2 =>
							if(rx_data(31 downto 16) = device_id and
									rx_data(15 downto 8) = i_tag) then
								s := data;
							else
								s := ignore;
							end if;
						when data =>
							-- TODO handle other buses
							i_rddata <= rx_data;
							i_reset_rdbusy <= '1';
							i_lastaddr <= i_addr;
							i_lastaddr_valid <= '1';
					end case;
				end if;
			end if;
		end if;
	end process;
end architecture;

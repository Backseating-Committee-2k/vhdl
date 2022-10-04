library ieee;

use ieee.std_logic_1164.ALL;
use ieee.std_logic_misc.ALL;
use ieee.numeric_std.ALL;

entity avalon_mm_to_pcie_avalon_st is
	generic(
		word_width : natural;
		tag : std_logic_vector(7 downto 0)
	);
	port(
		-- async reset
		reset : in std_logic;

		-- clock
		clk : in std_logic;

		-- requester side (Avalon-MM)
		req_addr : in std_logic_vector(63 downto 0);
		req_rdreq : in std_logic;
		req_rddata : out std_logic_vector(word_width - 1 downto 0);
		req_wrreq : in std_logic;
		req_wrdata : in std_logic_vector(word_width - 1 downto 0);
		req_waitrequest : out std_logic;

		-- completer side (PCIe Avalon-ST)
		cmp_rx_ready : out std_logic;
		cmp_rx_valid : in std_logic;
		cmp_rx_data : in std_logic_vector(63 downto 0);
		cmp_rx_sop : in std_logic;
		cmp_rx_eop : in std_logic;
		cmp_rx_err : in std_logic;

		cmp_rx_bardec : in std_logic_vector(7 downto 0);

		cmp_tx_ready : in std_logic;
		cmp_tx_valid : out std_logic;
		cmp_tx_data : out std_logic_vector(63 downto 0);
		cmp_tx_sop : out std_logic;
		cmp_tx_eop : out std_logic;
		cmp_tx_err : out std_logic;

		cmp_tx_req : out std_logic;
		cmp_tx_start : in std_logic;

		cmp_cpl_pending : out std_logic;

		device_id : in std_logic_vector(15 downto 0)
	);
end entity;

architecture syn of avalon_mm_to_pcie_avalon_st is
	constant address_width : natural := 64;
	subtype address is std_logic_vector(address_width - 1 downto 0);

	-- word_width is generic parameter
	subtype word is std_logic_vector(word_width - 1 downto 0);

	-- PCIe byte count
	subtype byte_count is std_logic_vector(11 downto 0);
	constant count : byte_count :=
			byte_count(
				to_unsigned(
					word_width / 8,			-- in 8 bit bytes
					byte_count'length));

	-- PCIe length field
	subtype length_field is std_logic_vector(9 downto 0);
	constant length : length_field :=
			length_field(
				to_unsigned(
					word_width / 32,		-- in 32 bit DWORDs
					length_field'length));

	signal addr : address;
	signal is_64bit : std_logic;

	-- endian converted
	signal rddata_be : std_logic_vector(63 downto 0);

	signal is_write : std_logic;
	signal wrdata : std_logic_vector(63 downto 0);
	signal wrdata_le : std_logic_vector(63 downto 0);

	signal busy : std_logic;

	signal rd_waitrequest : std_logic;

	signal set_busy : std_logic;
	signal reset_busy_rd : std_logic;
	signal reset_busy_wr : std_logic;
begin
	busy <= '1' when ?? set_busy else
			'0' when ?? reset_busy_rd else
			'0' when ?? reset_busy_wr else
			unaffected;

	-- pulse waitrequest low to acknowledge a write, otherwise
	-- use the value from read mechanism
	req_waitrequest <= rd_waitrequest and not reset_busy_wr;

	is_64bit <= or_reduce(addr(63 downto 32));

	rddata_be <= cmp_rx_data(7 downto 0) &
			cmp_rx_data(15 downto 8) &
			cmp_rx_data(23 downto 16) &
			cmp_rx_data(31 downto 24) &
			cmp_rx_data(39 downto 32) &
			cmp_rx_data(47 downto 40) &
			cmp_rx_data(55 downto 48) &
			cmp_rx_data(63 downto 56);

	wrdata_le <= wrdata(7 downto 0) &
			wrdata(15 downto 8) &
			wrdata(23 downto 16) &
			wrdata(31 downto 24) &
			wrdata(39 downto 32) &
			wrdata(47 downto 40) &
			wrdata(55 downto 48) &
			wrdata(63 downto 56);

	cmp_cpl_pending <= busy;

	request_generator : process(reset, clk) is
		type state is (idle, header1, header2, data, wait_read);
		variable s : state;
	begin
		if(?? reset) then
			s := idle;
			cmp_tx_req <= '0';
			cmp_tx_valid <= '0';
			set_busy <= '0';
			reset_busy_wr <= '0';
		elsif(rising_edge(clk)) then
			cmp_tx_req <= '0';
			cmp_tx_valid <= '0';
			cmp_tx_data <= (others => 'U');
			cmp_tx_sop <= 'U';
			cmp_tx_eop <= 'U';
			cmp_tx_err <= '0';
			set_busy <= '0';
			reset_busy_wr <= '0';
			case s is
				when idle =>
					if(?? (req_rdreq and not busy)) then
						s := header1;
						is_write <= '0';
						addr <= req_addr;
						cmp_tx_req <= '1';
					elsif(?? (req_wrreq and not busy)) then
						s := header1;
						is_write <= '1';
						addr <= req_addr;
						wrdata <= (others => '0');
						for i in 0 to wrdata'length / req_wrdata'length - 1 loop
							wrdata(req_wrdata'high + i * req_wrdata'length downto req_wrdata'low + i * req_wrdata'length) <= req_wrdata;
						end loop;
					end if;
				when header1 =>
					if(?? (cmp_tx_ready and cmp_tx_start)) then
						cmp_tx_valid <= '1';
						cmp_tx_data <= device_id &	-- requester id
								   tag &			-- tag
								   x"F" &			-- last DWORD BE
								   x"F" &			-- first DWORD BE
								   "0" &			-- reserved
								   is_write &		-- data attached?
								   is_64bit &		-- 64 bit address
								   "00000" &		-- type: memory access
								   "0" &			-- reserved
								   "000" &			-- traffic class
								   "0000" &			-- reserved
								   "0" &			-- no checksum
								   "0" &			-- not poisoned
								   "00" &			-- attributes
								   "00" &			-- reserved
								   length;		-- length in DWORDs
						cmp_tx_sop <= '1';
						cmp_tx_eop <= '0';
						set_busy <= '1';
						s := header2;
					else
						cmp_tx_req <= '1';
					end if;
				when header2 =>
					if(?? cmp_tx_ready) then
						cmp_tx_valid <= '1';
						if(?? is_64bit) then
							cmp_tx_data <= addr(31 downto 2) & "00" & addr(63 downto 32);
						else
							cmp_tx_data <= x"00000000" & addr(31 downto 2) & "00";
						end if;
						cmp_tx_sop <= '0';
						if(?? is_write) then
							cmp_tx_eop <= '0';
							reset_busy_wr <= '1';
							s := data;
						else
							cmp_tx_eop <= '1';
							s := wait_read;
						end if;
					end if;
				when data =>
					if(?? cmp_tx_ready) then
						cmp_tx_valid <= '1';
						cmp_tx_data <= wrdata_le;
						cmp_tx_sop <= '0';
						cmp_tx_eop <= '1';
						s := idle;
					end if;
				when wait_read =>
					if ?? reset_busy_rd then
						s := idle;
					end if;
			end case;
		end if;
	end process;

	cmp_rx_ready <= '1';

	completion_parser : process(reset, clk) is
		type state is (idle, header2, data);
		variable s : state;

		variable rx_has_data : std_logic;
		variable rx_type : std_logic_vector(4 downto 0);
		variable rx_tc : std_logic_vector(2 downto 0);
		variable rx_ep : std_logic;
		variable rx_attr : std_logic_vector(1 downto 0);
		variable rx_length : std_logic_vector(9 downto 0);
		variable rx_cpl_id : std_logic_vector(15 downto 0);
		variable rx_status : std_logic_vector(2 downto 0);
		variable rx_byte_count : std_logic_vector(11 downto 0);

		variable rx_req_id : std_logic_vector(15 downto 0);
		variable rx_tag : std_logic_vector(7 downto 0);
		variable rx_lower_address : std_logic_vector(6 downto 0);
	begin
		if(?? reset) then
			s := idle;
			reset_busy_rd <= '1';
			req_rddata <= (others => 'U');
			rd_waitrequest <= '1';
		elsif(rising_edge(clk)) then
			reset_busy_rd <= '0';
			req_rddata <= (others => 'U');
			rd_waitrequest <= '1';
			if(?? cmp_rx_valid) then
				if(?? cmp_rx_sop) then
					rx_has_data := cmp_rx_data(30);
					rx_type := cmp_rx_data(28 downto 24);
					rx_tc := cmp_rx_data(22 downto 20);
					rx_ep := cmp_rx_data(14);
					rx_attr := cmp_rx_data(13 downto 12);
					rx_length := cmp_rx_data(9 downto 0);
					rx_cpl_id := cmp_rx_data(63 downto 48);
					rx_status := cmp_rx_data(47 downto 45);
					rx_byte_count := cmp_rx_data(43 downto 32);

					if((?? rx_has_data) and
							rx_type = "01010" and
							rx_tc = "000" and
							rx_ep = '0' and
							rx_attr = "00" and
							rx_length = length and
							rx_status = "000" and
							rx_byte_count = count) then
						s := header2;
					end if;
				else
					case s is
						when idle =>
							null;
						when header2 =>
							rx_req_id := cmp_rx_data(31 downto 16);
							rx_tag := cmp_rx_data(15 downto 8);
							rx_lower_address := cmp_rx_data(6 downto 0);

							if(not (?? cmp_rx_eop) and
									rx_req_id = device_id and
									rx_tag = tag and
									rx_lower_address = addr(6 downto 0)) then
								s := data;
							else
								s := idle;
							end if;
						when data =>
							req_rddata <= rddata_be(req_rddata'range);
							rd_waitrequest <= '0';
							reset_busy_rd <= '1';
							s := idle;
					end case;
				end if;
			end if;
		end if;
	end process;
end architecture;

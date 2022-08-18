library ieee;

use ieee.std_logic_1164.ALL;

package pcie_arbiter_types is
	subtype data is std_logic_vector(63 downto 0);
	subtype bardec is std_logic_vector(7 downto 0);

	subtype logic_per_agent is std_logic_vector;
	type data_per_agent is array (natural range <>) of data;
	type bardec_per_agent is array (natural range <>) of bardec;
end package;

library ieee;

use ieee.std_logic_1164.ALL;
use ieee.std_logic_misc.ALL;
use work.pcie_arbiter_types.ALL;

entity pcie_arbiter is
	generic(
		num_agents : natural
	);

	port(
		clk : in std_logic;
		reset_n : in std_logic;

		merged_tx_req : out std_logic;
		merged_tx_start : in std_logic;

		merged_tx_ready : in std_logic;
		merged_tx_valid : out std_logic;
		merged_tx_data : out data;
		merged_tx_sop : out std_logic;
		merged_tx_eop : out std_logic;
		merged_tx_err : out std_logic;

		merged_cpl_pending : out std_logic;

		-- request sending data
		arb_tx_req : in logic_per_agent(1 to num_agents);
		-- start strobe (high one cycle before bus free)
		arb_tx_start : out logic_per_agent(1 to num_agents);

		arb_tx_ready : out logic_per_agent(1 to num_agents);
		arb_tx_valid : in logic_per_agent(1 to num_agents);
		arb_tx_data : in data_per_agent(1 to num_agents);
		arb_tx_sop : in logic_per_agent(1 to num_agents);
		arb_tx_eop : in logic_per_agent(1 to num_agents);
		arb_tx_err : in logic_per_agent(1 to num_agents);

		arb_cpl_pending : in logic_per_agent(1 to num_agents)
	);
end entity;

architecture syn of pcie_arbiter is
	signal idle : boolean;
	signal selected : natural range 1 to num_agents;
begin
	-- distribute "ready" signal
	arb_tx_ready <= (others => merged_tx_ready);

	-- demultiplex data path
	merged_tx_valid <= arb_tx_valid(selected);
	merged_tx_data <= arb_tx_data(selected);
	merged_tx_sop <= arb_tx_sop(selected);
	merged_tx_eop <= arb_tx_eop(selected);
	merged_tx_err <= arb_tx_err(selected);

	-- combine "completion pending"
	merged_cpl_pending <= or_reduce(arb_cpl_pending);

	-- selection logic
	process(reset_n, clk) is
		-- currently selected source is sending EOP
		variable at_eop : boolean;
		-- currently selected source has request flag set
		variable will_continue : boolean;

		-- it is currently safe to decide
		variable can_decide : boolean;
		-- it is currently safe to switch
		variable can_switch : boolean;

		-- no agent wants to send, go idle
		variable next_is_idle : boolean;
		-- agent selected next time it is safe to switch
		variable next_agent : natural range 1 to num_agents;
	begin
		if(reset_n = '0') then
			idle <= true;
			selected <= 1;
			next_is_idle := true;
			next_agent := 1;
		elsif(rising_edge(clk)) then
			at_eop :=
					not idle and
					(arb_tx_valid(selected) = '1') and
					(arb_tx_eop(selected) = '1');
			will_continue :=
					not idle and
					(arb_tx_req(selected) = '1');

			-- we can adjust our decision who goes next if
			-- 1. we're currently idle, or
			-- 2. the selected agent is not sending valid data, or
			-- 3. the selected agent is not sending an EOP, or
			-- 4. the selected agent has indicated that it doesn't want to
			--    send more data
			--
			-- "EOP" in this case means that the next cycle is going to be a SOP
			can_decide := idle or not at_eop or not will_continue;
			can_switch := idle or at_eop;

			if(can_decide) then
				next_is_idle := true;
				for agent in 1 to num_agents loop
					if(next_is_idle and arb_tx_req(agent) = '1') then
						next_is_idle := false;
						next_agent := agent;
					end if;
				end loop;
			end if;

			if(not idle or next_is_idle or merged_tx_start = '1') then
				merged_tx_req <= '0';
			else
				merged_tx_req <= '1';
			end if;

			if(can_switch) then
				if(next_is_idle or merged_tx_start = '0') then
					arb_tx_start <= (others => '0');
					idle <= true;
				else
					arb_tx_start <= (others => '0');
					arb_tx_start(next_agent) <= '1';
					selected <= next_agent;
					idle <= false;
				end if;
			else
				arb_tx_start <= (others => '0');
			end if;
		end if;
	end process;
end architecture;

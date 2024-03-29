library ieee;
use ieee.std_logic_1164.ALL;
use ieee.std_logic_misc.ALL;

use work.bss2k.ALL;

entity top is
	port(
		-- PCIe #PERST
		pcie_nperst : in std_logic;

		-- PCIe refclk
		refclk : in std_logic;

		-- PCIe rx
		pcie_rx : in std_logic_vector(3 downto 0);

		-- PCIe tx
		pcie_tx : out std_logic_vector(3 downto 0);

		-- independent clock
		fixedclk_serdes : in std_logic;

		-- debug port
		debug_clk : out std_logic;
		debug_data : out std_logic_vector(7 downto 0)
	);
end entity;

architecture rtl of top is
	-- async reset
	signal cpu_reset : std_logic;

	-- clock
	signal cpu_clk : std_logic;

	-- status
	signal cpu_halted : std_logic;
	signal cpu_assertion_failed : std_logic;

	-- instruction bus (Avalon-MM)
	signal cpu_i_addr : address;
	signal cpu_i_rddata : instruction;
	signal cpu_i_rdreq : std_logic;
	signal cpu_i_waitrequest : std_logic;

	-- data bus (Avalon-MM)
	signal cpu_d_addr : address;
	signal cpu_d_rddata : word;
	signal cpu_d_rdreq : std_logic;
	signal cpu_d_wrdata : word;
	signal cpu_d_wrreq : std_logic;
	signal cpu_d_waitrequest : std_logic;

	signal cpu_d_waitrequest_ram : std_logic;
	signal cpu_d_waitrequest_textmode : std_logic;

	-- debug port
	signal debug_clk_int : std_logic;
	signal debug_data_valid_int : std_logic;
	signal debug_data_invalid_int : std_logic;
	signal debug_data_int : std_logic_vector(7 downto 0);

	-- translated host address
	signal cpu_i_addr_host : std_logic_vector(63 downto 0);
	signal cpu_d_addr_host : std_logic_vector(63 downto 0);

	-- address of textmode texture on host
	signal textmode_address_host : std_logic_vector(63 downto 0);
	signal textmode_start : std_logic;
	signal textmode_done : std_logic;

	component cpu is
		port(
			-- async reset
			reset : in std_logic;

			-- clock
			clk : in std_logic;

			-- status
			halted : out std_logic;
			assertion_failed : out std_logic;

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
			d_waitrequest : in std_logic
		);
	end component;

	-- clocks
	signal pld_clk : std_logic;
	signal core_clk_out : std_logic;
	signal cal_blk_clk : std_logic;

	signal app_clk : std_logic;			-- application clock

	-- top-level PCIe component needs start and req connected
	signal pcie_arbiter_shortcut : std_logic;

	-- PCIe internal rx interface (Avalon-ST), synchronous to app_clk
	signal pcie_rx_ready : std_logic;
	signal pcie_rx_valid : std_logic;
	signal pcie_rx_data : std_logic_vector(63 downto 0);
	signal pcie_rx_sop : std_logic;
	signal pcie_rx_eop : std_logic;
	signal pcie_rx_err : std_logic;

	signal pcie_rx_mask : std_logic;
	signal pcie_rx_bardec : std_logic_vector(7 downto 0);

	-- PCIe internal tx interface (Avalon-ST), synchronous to app_clk
	signal pcie_tx_ready : std_logic;
	signal pcie_tx_valid : std_logic;
	signal pcie_tx_data : std_logic_vector(63 downto 0);
	signal pcie_tx_sop : std_logic;
	signal pcie_tx_eop : std_logic;
	signal pcie_tx_err : std_logic;

	-- configuration/status interface
	signal cfg_busdev : std_logic_vector(12 downto 0);

	-- completion interface
	signal cpl_pending : std_logic;

	-- PCIe internal interface for CPU control block
	-- rx side
	signal control_rx_ready : std_logic;
	signal control_rx_valid : std_logic;
	signal control_rx_data : std_logic_vector(63 downto 0);
	signal control_rx_sop : std_logic;
	signal control_rx_eop : std_logic;
	signal control_rx_err : std_logic;
	signal control_rx_bardec : std_logic_vector(7 downto 0);
	-- tx side
	signal control_tx_ready : std_logic;
	signal control_tx_valid : std_logic;
	signal control_tx_data : std_logic_vector(63 downto 0);
	signal control_tx_sop : std_logic;
	signal control_tx_eop : std_logic;
	signal control_tx_err : std_logic;
	-- power management
	signal control_cpl_pending : std_logic;
	-- arbiter interface
	signal control_tx_req : std_logic;
	signal control_tx_start : std_logic;

	-- PCIe internal interface for CPU instruction DMA access
	-- rx side
	signal cpu_i_rx_ready : std_logic;
	signal cpu_i_rx_valid : std_logic;
	signal cpu_i_rx_data : std_logic_vector(63 downto 0);
	signal cpu_i_rx_sop : std_logic;
	signal cpu_i_rx_eop : std_logic;
	signal cpu_i_rx_err : std_logic;
	signal cpu_i_rx_bardec : std_logic_vector(7 downto 0);
	-- tx side
	signal cpu_i_tx_ready : std_logic;
	signal cpu_i_tx_valid : std_logic;
	signal cpu_i_tx_data : std_logic_vector(63 downto 0);
	signal cpu_i_tx_sop : std_logic;
	signal cpu_i_tx_eop : std_logic;
	signal cpu_i_tx_err : std_logic;
	-- power management
	signal cpu_i_cpl_pending : std_logic;
	-- arbiter interface
	signal cpu_i_tx_req : std_logic;
	signal cpu_i_tx_start : std_logic;

	-- PCIe internal interface for CPU DMA access
	-- rx side
	signal cpu_d_rx_ready : std_logic;
	signal cpu_d_rx_valid : std_logic;
	signal cpu_d_rx_data : std_logic_vector(63 downto 0);
	signal cpu_d_rx_sop : std_logic;
	signal cpu_d_rx_eop : std_logic;
	signal cpu_d_rx_err : std_logic;
	signal cpu_d_rx_bardec : std_logic_vector(7 downto 0);
	-- tx side
	signal cpu_d_tx_ready : std_logic;
	signal cpu_d_tx_valid : std_logic;
	signal cpu_d_tx_data : std_logic_vector(63 downto 0);
	signal cpu_d_tx_sop : std_logic;
	signal cpu_d_tx_eop : std_logic;
	signal cpu_d_tx_err : std_logic;
	-- power management
	signal cpu_d_cpl_pending : std_logic;
	-- arbiter interface
	signal cpu_d_tx_req : std_logic;
	signal cpu_d_tx_start : std_logic;

	-- PCIe internal interface for textmode output
	-- tx side
	signal textmode_tx_ready : std_logic;
	signal textmode_tx_valid : std_logic;
	signal textmode_tx_data : std_logic_vector(63 downto 0);
	signal textmode_tx_sop : std_logic;
	signal textmode_tx_eop : std_logic;
	signal textmode_tx_err : std_logic;
	-- power management
	signal textmode_cpl_pending : std_logic;
	-- arbiter interface
	signal textmode_tx_req : std_logic;
	signal textmode_tx_start : std_logic;

	-- interrupts
	-- current status
	signal int_sts : std_logic_vector(31 downto 0);
	-- to PCIe block
	signal app_int_sts : std_logic;
	signal app_int_ack : std_logic;
	signal app_msi_req : std_logic;
	signal app_msi_num : std_logic_vector(4 downto 0);
	signal app_msi_tc : std_logic_vector(2 downto 0);
	signal app_msi_ack : std_logic;

	-- reset
	signal npor : std_logic;	-- power on reset (external)
	signal app_rstn : std_logic;	-- application reset (generated by reset controller)
	signal srst : std_logic;	-- datapath reset (generated by reset controller)
	signal crst : std_logic;	-- configuration space reset (generated by reset controller)

	-- transceiver state
	signal dlup_exit : std_logic;
	signal hotrst_exit : std_logic;
	signal l2_exit : std_logic;
	signal ltssm : std_logic_vector(4 downto 0);
	signal rc_pll_locked : std_logic;
	signal reset_status : std_logic;
	signal suc_spd_neg : std_logic;

	-- PHY reconfiguration interface
	signal reconfig_clk : std_logic;
	signal reconfig_busy : std_logic;
	signal reconfig_fromgxb : std_logic_vector(4 downto 0);
	signal reconfig_togxb : std_logic_vector(3 downto 0);

	-- power management
	signal gxb_powerdown : std_logic;
	signal pll_powerdown : std_logic;
	signal pm_auxpwr : std_logic;
	signal pm_data : std_logic_vector(9 downto 0);
	signal pm_event : std_logic;
	signal pme_to_cr : std_logic;
	signal pme_to_sr : std_logic;

	-- local management interface
	signal lmi_addr : std_logic_vector(11 downto 0);
	signal lmi_rden : std_logic;
	signal lmi_din : std_logic_vector(31 downto 0);
	signal lmi_wren : std_logic;
	signal lmi_dout : std_logic_vector(31 downto 0);
	signal lmi_ack : std_logic;

	-- configuration space
	signal tl_cfg_add : std_logic_vector(3 downto 0);
	signal tl_cfg_ctl : std_logic_vector(31 downto 0);
	signal tl_cfg_ctl_wr : std_logic;
	signal tl_cfg_sts : std_logic_vector(52 downto 0);
	signal tl_cfg_sts_wr : std_logic;
begin
	cpu_clk <= app_clk;

	cpu_d_waitrequest <= cpu_d_waitrequest_ram and cpu_d_waitrequest_textmode;

	c : cpu
		port map(
			reset => cpu_reset,
			clk => cpu_clk,
			halted => cpu_halted,
			assertion_failed => cpu_assertion_failed,
			i_addr => cpu_i_addr,
			i_rddata => cpu_i_rddata,
			i_rdreq => cpu_i_rdreq,
			i_waitrequest => cpu_i_waitrequest,
			d_addr => cpu_d_addr,
			d_rddata => cpu_d_rddata,
			d_rdreq => cpu_d_rdreq,
			d_wrdata => cpu_d_wrdata,
			d_wrreq => cpu_d_wrreq,
			d_waitrequest => cpu_d_waitrequest
		);

	pcie_rx_ready <= control_rx_ready and cpu_i_rx_ready and cpu_d_rx_ready;

	control_rx_valid <= pcie_rx_valid;
	control_rx_data <= pcie_rx_data;
	control_rx_sop <= pcie_rx_sop;
	control_rx_eop <= pcie_rx_eop;
	control_rx_err <= pcie_rx_err;
	control_rx_bardec <= pcie_rx_bardec;

	cpu_i_rx_valid <= pcie_rx_valid;
	cpu_i_rx_data <= pcie_rx_data;
	cpu_i_rx_sop <= pcie_rx_sop;
	cpu_i_rx_eop <= pcie_rx_eop;
	cpu_i_rx_err <= pcie_rx_err;
	cpu_i_rx_bardec <= pcie_rx_bardec;

	cpu_d_rx_valid <= pcie_rx_valid;
	cpu_d_rx_data <= pcie_rx_data;
	cpu_d_rx_sop <= pcie_rx_sop;
	cpu_d_rx_eop <= pcie_rx_eop;
	cpu_d_rx_err <= pcie_rx_err;
	cpu_d_rx_bardec <= pcie_rx_bardec;

	arbiter : entity work.pcie_arbiter
		generic map(
			num_agents => 4
		)
		port map(
			reset_n => app_rstn,

			clk => app_clk,

			-- toplevel can give itself permission to start
			merged_tx_req => pcie_arbiter_shortcut,
			merged_tx_start => pcie_arbiter_shortcut,

			merged_tx_ready => pcie_tx_ready,
			merged_tx_valid => pcie_tx_valid,
			merged_tx_data => pcie_tx_data,
			merged_tx_sop => pcie_tx_sop,
			merged_tx_eop => pcie_tx_eop,
			merged_tx_err => pcie_tx_err,

			merged_cpl_pending => cpl_pending,

			-- request sending data
			arb_tx_req(1) => control_tx_req,
			arb_tx_req(2) => cpu_i_tx_req,
			arb_tx_req(3) => cpu_d_tx_req,
			arb_tx_req(4) => textmode_tx_req,

			-- start strobe (high one cycle before bus free)
			arb_tx_start(1) => control_tx_start,
			arb_tx_start(2) => cpu_i_tx_start,
			arb_tx_start(3) => cpu_d_tx_start,
			arb_tx_start(4) => textmode_tx_start,

			arb_tx_ready(1) => control_tx_ready,
			arb_tx_ready(2) => cpu_i_tx_ready,
			arb_tx_ready(3) => cpu_d_tx_ready,
			arb_tx_ready(4) => textmode_tx_ready,
			arb_tx_valid(1) => control_tx_valid,
			arb_tx_valid(2) => cpu_i_tx_valid,
			arb_tx_valid(3) => cpu_d_tx_valid,
			arb_tx_valid(4) => textmode_tx_valid,
			arb_tx_data(1) => control_tx_data,
			arb_tx_data(2) => cpu_i_tx_data,
			arb_tx_data(3) => cpu_d_tx_data,
			arb_tx_data(4) => textmode_tx_data,
			arb_tx_sop(1) => control_tx_sop,
			arb_tx_sop(2) => cpu_i_tx_sop,
			arb_tx_sop(3) => cpu_d_tx_sop,
			arb_tx_sop(4) => textmode_tx_sop,
			arb_tx_eop(1) => control_tx_eop,
			arb_tx_eop(2) => cpu_i_tx_eop,
			arb_tx_eop(3) => cpu_d_tx_eop,
			arb_tx_eop(4) => textmode_tx_eop,
			arb_tx_err(1) => control_tx_err,
			arb_tx_err(2) => cpu_i_tx_err,
			arb_tx_err(3) => cpu_d_tx_err,
			arb_tx_err(4) => textmode_tx_err,

			arb_cpl_pending(1) => control_cpl_pending,
			arb_cpl_pending(2) => cpu_i_cpl_pending,
			arb_cpl_pending(3) => cpu_d_cpl_pending,
			arb_cpl_pending(4) => textmode_cpl_pending
		);

	control_inst : entity work.control
		port map(
			reset => not app_rstn,
			clk => app_clk,

			rx_ready => control_rx_ready,
			rx_valid => control_rx_valid,
			rx_data => control_rx_data,
			rx_sop => control_rx_sop,
			rx_eop => control_rx_eop,
			rx_err => control_rx_err,

			rx_bardec => control_rx_bardec,

			tx_ready => control_tx_ready,
			tx_valid => control_tx_valid,
			tx_data => control_tx_data,
			tx_sop => control_tx_sop,
			tx_eop => control_tx_eop,
			tx_err => control_tx_err,

			tx_req => control_tx_req,
			tx_start => control_tx_start,

			cpl_pending => control_cpl_pending,

			completer_id => cfg_busdev & "000",

			cpu_reset => cpu_reset,
			cpu_halted => cpu_halted,
			cpu_assertion_failed => cpu_assertion_failed,

			interrupts => int_sts,

			mmu_address_in_a => cpu_i_addr,
			mmu_address_out_a => cpu_i_addr_host,

			mmu_address_in_b => cpu_d_addr,
			mmu_address_out_b => cpu_d_addr_host,

			textmode_target_host => textmode_address_host,
			textmode_start => textmode_start,
			textmode_done => textmode_done
		);

	cpu_dma_inst_i : entity work.avalon_mm_to_pcie_avalon_st
		generic map(
			word_width => 64,
			tag => x"00"
		)
		port map(
			reset => not app_rstn,

			clk => app_clk,

			-- requester side (Avalon-MM)
			req_addr => cpu_i_addr_host,
			req_rdreq => cpu_i_rdreq,
			req_rddata => cpu_i_rddata,
			req_wrreq => '0',
			req_wrdata => (others => 'U'),
			req_waitrequest => cpu_i_waitrequest,

			-- completer side (PCIe Avalon-ST)
			cmp_rx_ready => cpu_i_rx_ready,
			cmp_rx_valid => cpu_i_rx_valid,
			cmp_rx_data => cpu_i_rx_data,
			cmp_rx_sop => cpu_i_rx_sop,
			cmp_rx_eop => cpu_i_rx_eop,
			cmp_rx_err => cpu_i_rx_err,

			cmp_rx_bardec => cpu_i_rx_bardec,

			cmp_tx_ready => cpu_i_tx_ready,
			cmp_tx_valid => cpu_i_tx_valid,
			cmp_tx_data => cpu_i_tx_data,
			cmp_tx_sop => cpu_i_tx_sop,
			cmp_tx_eop => cpu_i_tx_eop,
			cmp_tx_err => cpu_i_tx_err,

			cmp_tx_req => cpu_i_tx_req,
			cmp_tx_start => cpu_i_tx_start,

			cmp_cpl_pending => cpu_i_cpl_pending,

			device_id => cfg_busdev & "000"
		);

	cpu_dma_inst_d : entity work.avalon_mm_to_pcie_avalon_st
		generic map(
			word_width => 32,
			tag => x"01"
		)
		port map(
			reset => not app_rstn,

			clk => app_clk,

			-- requester side (Avalon-MM)
			req_addr => cpu_d_addr_host,
			req_rdreq => cpu_d_rdreq,
			req_rddata => cpu_d_rddata,
			req_wrreq => cpu_d_wrreq,
			req_wrdata => cpu_d_wrdata,
			req_waitrequest => cpu_d_waitrequest_ram,

			-- completer side (PCIe Avalon-ST)
			cmp_rx_ready => cpu_d_rx_ready,
			cmp_rx_valid => cpu_d_rx_valid,
			cmp_rx_data => cpu_d_rx_data,
			cmp_rx_sop => cpu_d_rx_sop,
			cmp_rx_eop => cpu_d_rx_eop,
			cmp_rx_err => cpu_d_rx_err,

			cmp_rx_bardec => cpu_d_rx_bardec,

			cmp_tx_ready => cpu_d_tx_ready,
			cmp_tx_valid => cpu_d_tx_valid,
			cmp_tx_data => cpu_d_tx_data,
			cmp_tx_sop => cpu_d_tx_sop,
			cmp_tx_eop => cpu_d_tx_eop,
			cmp_tx_err => cpu_d_tx_err,

			cmp_tx_req => cpu_d_tx_req,
			cmp_tx_start => cpu_d_tx_start,

			cmp_cpl_pending => cpu_d_cpl_pending,

			device_id => cfg_busdev & "000"
		);

	textmode_inst : entity work.textmode_output
		port map(
			reset => not app_rstn,
			clk => app_clk,

			target_address => textmode_address_host,
			start => textmode_start,
			done => textmode_done,

			tx_ready => textmode_tx_ready,
			tx_valid => textmode_tx_valid,
			tx_data => textmode_tx_data,
			tx_sop => textmode_tx_sop,
			tx_eop => textmode_tx_eop,
			tx_err => textmode_tx_err,

			cpl_pending => textmode_cpl_pending,

			tx_req => textmode_tx_req,
			tx_start => textmode_tx_start,

			device_id => cfg_busdev & "000",

			-- internal data bus
			d_addr => cpu_d_addr,
			d_wrreq => cpu_d_wrreq,
			d_wrdata => cpu_d_wrdata,
			d_waitrequest => cpu_d_waitrequest_textmode
		);

	-- clocks
	pld_clk <= core_clk_out;		-- needs to be connected
	app_clk <= pld_clk;			-- app is synchronous to pld_clk
	cal_blk_clk <= core_clk_out;

	-- PCIe internal rx interface (Avalon-ST)
	pcie_rx_mask <= '0';

	-- interrupts
	int : entity work.interrupt_encoder
		port map(
			reset => not app_rstn,
			clk => app_clk,
			int_sts(31 downto 1) => (others => '0'),
			int_sts(0) => or_reduce(int_sts),
			legacy_int_sts => app_int_sts,
			legacy_int_ack => app_int_ack,
			msi_int_req => app_msi_req,
			msi_int_num => app_msi_num,
			msi_int_tc => app_msi_tc,
			msi_int_ack => app_msi_ack
		);

	-- reset
	npor <= pcie_nperst;

	-- power management
	gxb_powerdown <= '0';
	pll_powerdown <= '0';
	pm_auxpwr <= '0';
	pm_data <= "0011001001";	-- todo: 5W?
	pm_event <= '0';
	pme_to_cr <= '0';

	-- local management interface
	lmi_addr <= (others => '0');
	lmi_rden <= '0';
	lmi_din <= (others => '0');
	lmi_wren <= '0';

	pcie_inst : entity work.pcie
		port map (
			-- external PCIe interface
			rx_in0 => pcie_rx(0),
			rx_in1 => pcie_rx(1),
			rx_in2 => pcie_rx(2),
			rx_in3 => pcie_rx(3),
			tx_out0 => pcie_tx(0),
			tx_out1 => pcie_tx(1),
			tx_out2 => pcie_tx(2),
			tx_out3 => pcie_tx(3),

			-- clocks
			refclk => refclk,
			fixedclk_serdes => fixedclk_serdes,
			pclk_in => '0',				-- PIPE simulation only
			pld_clk => pld_clk,
			core_clk_out => core_clk_out,

			-- PCIe internal rx interface (Avalon-ST)
			rx_st_ready0 => pcie_rx_ready,
			rx_st_valid0 => pcie_rx_valid,
			rx_st_data0 => pcie_rx_data,
			rx_st_sop0 => pcie_rx_sop,
			rx_st_eop0 => pcie_rx_eop,
			rx_st_err0 => pcie_rx_err,

			rx_st_mask0 => pcie_rx_mask,
			rx_st_bardec0 => pcie_rx_bardec,
			rx_st_be0 => open,			-- deprecated

			-- PCIe internal tx interface (Avalon-ST)
			tx_st_ready0 => pcie_tx_ready,
			tx_st_valid0 => pcie_tx_valid,
			tx_st_data0 => pcie_tx_data,
			tx_st_sop0 => pcie_tx_sop,
			tx_st_eop0 => pcie_tx_eop,
			tx_st_err0 => pcie_tx_err,

			-- completion interface
			cpl_err => (others => '0'),		-- todo
			cpl_pending => cpl_pending,
			ko_cpl_spc_vc0 => open,			-- todo

			-- interrupts
			app_int_sts => app_int_sts,
			app_int_ack => app_int_ack,
			app_msi_req => app_msi_req,
			app_msi_num => app_msi_num,
			app_msi_tc => app_msi_tc,
			app_msi_ack => app_msi_ack,
			pex_msi_num => (others => '0'),		-- todo

			-- reset
			npor => npor,
			crst => crst,
			srst => srst,

			-- transceiver state
			dlup_exit => dlup_exit,
			hotrst_exit => hotrst_exit,
			l2_exit => l2_exit,
			ltssm => ltssm,
			rc_pll_locked => rc_pll_locked,
			reset_status => reset_status,
			suc_spd_neg => suc_spd_neg,
			rc_rx_digitalreset => open,

			-- PHY reconfiguration interface
			busy_altgxb_reconfig => reconfig_busy,
			cal_blk_clk => cal_blk_clk,
			reconfig_clk => reconfig_clk,
			reconfig_togxb => reconfig_togxb,
			reconfig_fromgxb => reconfig_fromgxb,

			-- power management
			gxb_powerdown => gxb_powerdown,
			pll_powerdown => pll_powerdown,
			pm_auxpwr => pm_auxpwr,
			pm_data => pm_data,
			pm_event => pm_event,
			pme_to_cr => pme_to_cr,
			pme_to_sr => pme_to_sr,

			-- local management interface
			lmi_addr => lmi_addr,
			lmi_din => lmi_din,
			lmi_rden => lmi_rden,
			lmi_wren => lmi_wren,
			lmi_ack => lmi_ack,
			lmi_dout => lmi_dout,

			-- configuration space
			tl_cfg_add => tl_cfg_add,
			tl_cfg_ctl => tl_cfg_ctl,
			tl_cfg_ctl_wr => tl_cfg_ctl_wr,
			tl_cfg_sts => tl_cfg_sts,
			tl_cfg_sts_wr => tl_cfg_sts_wr,

			-- PCIe credits (todo)
			tx_cred0 => open,

			-- ECC error handling (todo)
			derr_cor_ext_rcv0 => open,
			derr_cor_ext_rpl => open,
			derr_rpl => open,
			r2c_err0 => open,

			-- test interface (unused)
			test_in => (others => '0'),
			lane_act => open,

			-- simulation only (do not work on actual hardware)
			clk250_out => open,
			clk500_out => open,

			-- debug signals
			rx_fifo_empty0 => open,
			rx_fifo_full0 => open,
			tx_fifo_empty0 => open,
			tx_fifo_full0 => open,
			tx_fifo_rdptr0 => open,
			tx_fifo_wrptr0 => open,

			-- PIPE mode (disabled)
			pipe_mode => '0',

			hpg_ctrler => (others => '0'),
			phystatus_ext => '0',
			rxdata0_ext => (others => '0'),
			rxdata1_ext => (others => '0'),
			rxdata2_ext => (others => '0'),
			rxdata3_ext => (others => '0'),
			rxdatak0_ext => '0',
			rxdatak1_ext => '0',
			rxdatak2_ext => '0',
			rxdatak3_ext => '0',
			rxelecidle0_ext => '0',
			rxelecidle1_ext => '0',
			rxelecidle2_ext => '0',
			rxelecidle3_ext => '0',
			rxstatus0_ext => (others => '0'),
			rxstatus1_ext => (others => '0'),
			rxstatus2_ext => (others => '0'),
			rxstatus3_ext => (others => '0'),
			rxvalid0_ext => '0',
			rxvalid1_ext => '0',
			rxvalid2_ext => '0',
			rxvalid3_ext => '0',

			rate_ext => open,
			rxpolarity0_ext => open,
			rxpolarity1_ext => open,
			rxpolarity2_ext => open,
			rxpolarity3_ext => open,
			txcompl0_ext => open,
			txcompl1_ext => open,
			txcompl2_ext => open,
			txcompl3_ext => open,
			txdata0_ext => open,
			txdata1_ext => open,
			txdata2_ext => open,
			txdata3_ext => open,
			txdatak0_ext => open,
			txdatak1_ext => open,
			txdatak2_ext => open,
			txdatak3_ext => open,
			txdetectrx_ext => open,
			txelecidle0_ext => open,
			txelecidle1_ext => open,
			txelecidle2_ext => open,
			txelecidle3_ext => open
		);

	pll_inst : entity work.pll
		port map (
			inclk0 => fixedclk_serdes,
			c0 => reconfig_clk
		);

	pcie_reset_inst : entity work.pcie_rs_hip
		port map (
			-- power on reset (external, low active)
			npor => npor,

			-- clock
			pld_clk => pld_clk,

			-- current transceiver state
			dlup_exit => dlup_exit,		-- data link up
			hotrst_exit => hotrst_exit,	-- hot reset
			l2_exit => l2_exit,		-- layer 2
			ltssm => ltssm,			-- link training state machine

			-- generated reset signals
			app_rstn => app_rstn,		-- generated app reset (low active)
			crst => crst,			-- generated crst
			srst => srst,			-- generated srst

			test_sim => '0'
		);

	pcie_reconfig_inst : entity work.pcie_reconfig
		port map (
			reconfig_clk => reconfig_clk,
			busy => reconfig_busy,
			reconfig_fromgxb => reconfig_fromgxb,
			reconfig_togxb => reconfig_togxb
		);

	tl_cfg_sampling_inst : entity work.altpcierd_tl_cfg_sample
		port map(
			pld_clk => pld_clk,
			rstn => app_rstn,

			tl_cfg_add => tl_cfg_add,
			tl_cfg_ctl => tl_cfg_ctl,
			tl_cfg_ctl_wr => tl_cfg_ctl_wr,
			tl_cfg_sts => tl_cfg_sts,
			tl_cfg_sts_wr => tl_cfg_sts_wr,

			cfg_busdev => cfg_busdev,
			cfg_devcsr => open,
			cfg_linkcsr => open,
			cfg_prmcsr => open,
			cfg_io_bas => open,
			cfg_io_lim => open,
			cfg_np_bas => open,
			cfg_np_lim => open,
			cfg_pr_bas => open,
			cfg_pr_lim => open,
			cfg_tcvcmap => open,
			cfg_msicsr => open
	);

	-- debug port clock generation
	debug_pll_inst : entity work.debug_pll
		port map(
			inclk0 => fixedclk_serdes,
			c0 => debug_clk_int
		);

	-- debug port
	debug_port_inst : entity work.debug_port
		port map(
			outclock => debug_clk_int,
			datain_l(8) => '0',
			datain_l(7 downto 0) => debug_data_int,
			datain_h(8) => debug_data_valid_int,
			datain_h(7 downto 0) => debug_data_int,
			dataout(8) => debug_clk,
			dataout(7 downto 0) => debug_data
		);

	-- debug port fifo
	debug_fifo_inst : entity work.debug_fifo
		port map(
			aclr => not npor,
			data => pcie_rx_data,
			rdclk => debug_clk_int,
			rdreq => debug_data_valid_int,
			wrclk	=> app_clk,
			wrreq	=> pcie_rx_valid,
			q => debug_data_int,
			rdempty => debug_data_invalid_int
		);

	debug_data_valid_int <= not debug_data_invalid_int;
end architecture;

library work;
use work.ALL;

configuration rtl of top is
	for rtl
		for c : cpu
			use entity work.cpu_sequential;
			for rtl
				for register_file : registers
					use entity work.altera_registers;
				end for;
			end for;
		end for;
	end for;
end configuration;

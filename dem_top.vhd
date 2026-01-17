----------------------------------------------------------------
-- Author: dong yue
-- Date: 2025/11/11
-- Email: y.dong@outlook.com
-- Description:
-- Version:
-----------------------------------------------------------------

library IEEE;                
use IEEE.STD_LOGIC_1164.ALL; 
use IEEE.NUMERIC_STD.ALL;
-- synthesis translate_off
use ieee.std_logic_textio.all;
use std.textio.all;  
-- synthesis translate_on

library work;
use work.my_dem_pkg.all;

entity dem_top is
	port(
			sys_clk			: in std_logic;
			aresetn 		: in std_logic;
			ddc_vld 		: in std_logic;
			ddc_i 			: in std_logic_vector(15 downto 0);
			ddc_q			: in std_logic_vector(15 downto 0);
			dem_vld 		: out std_logic:='0';
			dem_sym_i		: out std_logic_vector(15 downto 0):= (others=>'0');
			dem_sym_q		: out std_logic_vector(15 downto 0):= (others=>'0');
			dem_bit 		: out std_logic_vector(7 downto 0):= (others=>'0')
		);
end dem_top;

architecture arch of dem_top is

	component agc
	port(
			sys_clk				: in std_logic;
			aresetn 			: in std_logic;
			log_ref  		: in std_logic_vector(31 downto 0);
			wave_in_valid 		: in std_logic;
			wave_in_i 			: in std_logic_vector(15 downto 0);
			wave_in_q			: in std_logic_vector(15 downto 0);
			wave_out_valid 		: out std_logic;
			wave_out_i 			: out std_logic_vector(15 downto 0);
			wave_out_q 			: out std_logic_vector(15 downto 0);
			power_out_o 		: out std_logic_vector(31 downto 0):=(others=>'0');
			exp_gain_o 			: out std_logic_vector(31 downto 0):=(others=>'0');
			agc_error 			: out std_logic_vector(31 downto 0):=(others=>'0')
		);
	end component;
	
	component tll_newer
	port(
			sys_clk				: in std_logic;
			aresetn 			: in std_logic;
			samp_vld			: in std_logic;
			samp_i				: in std_logic_vector(8 downto 0);
			samp_q				: in std_logic_vector(8 downto 0);
			en_sym 				: out std_logic;
			sym_i				: out std_logic_vector(24 downto 0);
			sym_q				: out std_logic_vector(24 downto 0);
			dmu_out_vld 		: out std_logic:='0';
			dmu_out				: out std_logic_vector(24 downto 0)
		);
	end component;

	component pll
	port(
			sys_clk		: in std_logic;
			aresetn 	: in std_logic;
			sym_type 	: in std_logic_vector(2 downto 0);
			en_sym		: in std_logic;
			sym_i		: in std_logic_vector(15 downto 0);
			sym_q		: in std_logic_vector(15 downto 0);
			euclidean_distance : out std_logic_vector(31 downto 0);
			sym_sync_en 	: out std_logic:='0';
			sym_sync_data_i	: out std_logic_vector(15 downto 0):=(others=>'0');
			sym_sync_data_q	: out std_logic_vector(15 downto 0):=(others=>'0');
			phase_diff_vld  : out std_logic:='0';
			phase_diff_out  : out std_logic_vector(19 downto 0):=(others=>'0')
		);
	end component;

	component vio_dem
		port (
				 clk : in std_logic;
				 probe_out0 : out std_logic_vector(2 downto 0);
				 probe_out1 : out std_logic_vector(0 downto 0);
				 probe_out2 : out std_logic_vector(1 downto 0);
				 probe_out3 : out std_logic_vector(31 downto 0);
				 probe_out4 : out std_logic_vector(7 downto 0);
				 probe_out5 : out std_logic_vector(7 downto 0);
				 probe_out6 : out std_logic_vector(31 downto 0);
				 probe_out7 : out std_logic_vector(7 downto 0);
				 probe_out8 : out std_logic_vector(9 downto 0);
				 probe_out9 : out std_logic_vector(24 downto 0);
				 probe_out10 : out std_logic_vector(9 downto 0);
				 probe_out11 : out std_logic_vector(9 downto 0);
				 probe_out12 : out std_logic_vector(19 downto 0);
				 probe_out13 : out std_logic_vector(9 downto 0) 
			 );
	end component;


	signal agc_vld_t	: std_logic:='0';
	signal agc_i_t		: std_logic_vector(15 downto 0):= (others=>'0');
	signal agc_q_t		: std_logic_vector(15 downto 0):= (others=>'0');
	signal agc_i_d		: std_logic_array_16(3 downto 0):= (others=>(others=>'0'));
	signal agc_q_d		: std_logic_array_16(3 downto 0):= (others=>(others=>'0'));

	signal log_ref  	: std_logic_vector(31 downto 0):= (others=>'0');
	signal power_out	: std_logic_vector(31 downto 0):= (others=>'0');
	signal exp_gain 	: std_logic_vector(31 downto 0):= (others=>'0');

	signal en_sym 		: std_logic;
	signal sym_i		: std_logic_vector(24 downto 0):=(others=>'0');
	signal sym_q		: std_logic_vector(24 downto 0):=(others=>'0');
	signal sym_type		: std_logic_vector(2 downto 0):="001";

	signal pll_select   : std_logic_vector(1 downto 0):=(others=>'0'); 

	signal sym_sync_en				: std_logic:='0';
	signal sym_sync_data_i			: std_logic_vector(15 downto 0):=(others=>'0'); 
	signal sym_sync_data_q  		: std_logic_vector(15 downto 0):=(others=>'0'); 

	signal aresetn_handset			: std_logic_vector(0 downto 0):=(others=>'0');

--	signal ddc_vld_2				: std_logic:='0'; 
--	signal ddc_i_2					: std_logic_vector(15 downto 0):=(others=>'0');
--	signal ddc_q_2					: std_logic_vector(15 downto 0):=(others=>'0');

	signal mf_vld					: std_logic:='0';
	signal mf_i_t					: std_logic_vector(31 downto 0):=(others=>'0'); 
	signal mf_q_t					: std_logic_vector(31 downto 0):=(others=>'0'); 
	signal mf_i						: std_logic_vector(15 downto 0):=(others=>'0'); 
	signal mf_q						: std_logic_vector(15 downto 0):=(others=>'0'); 
	signal agc_vld					: std_logic:='0';
	signal agc_i					: std_logic_vector(8 downto 0):= (others=>'0'); 
	signal agc_q					: std_logic_vector(8 downto 0):= (others=>'0');

	signal agc_c 					: signed(31 downto 0):= (others=>'0');
	signal agc_s 					: signed(31 downto 0):= (others=>'0');
	signal p1,p2,p3,p4 				: signed(31 downto 0):= (others=>'0');

	signal aresetn_agc				: std_logic:='0';
	signal aresetn_tll				: std_logic:='0';
	signal aresetn_pll				: std_logic:='0';

	type blind_dem_sts is (st_idle,st_acq_tll,st_acq_pll);
	signal dem_sts 				: blind_dem_sts:=st_idle;
--	constant SIG_DET_WIN_LEN	: unsigned(7 downto 0):=to_unsigned(255, 8);
--	constant SIG_OCCUR_NUM		: unsigned(7 downto 0):=to_unsigned(64, 8);
--	constant NOISE_POW			: signed(31 downto 0):=to_signed(10000*2, 32);
--	constant AGC_ERR_EXP		: signed(7 downto 0):=to_signed(-6, 8); --2^(-6)
--	constant TLL_DET_WIN_LEN 	: unsigned(9 downto 0):=to_unsigned(1023,10);
--	constant TLL_ERR_ABS		: signed(24 downto 0):=to_signed(1300,25);
--	constant TLL_LOCKED_NUM		: unsigned(9 downto 0):=to_unsigned(512,10);
--	constant PLL_DET_WIN_LEN 	: unsigned(9 downto 0):=to_unsigned(1023,10);
--	constant PLL_ERR_ABS		: signed(19 downto 0):=to_signed(200,20); --pi/128*2^13
--	constant PLL_LOCKED_NUM		: unsigned(9 downto 0):=to_unsigned(200,10);
	signal SIG_DET_WIN_LEN	: unsigned(7 downto 0):=to_unsigned(255, 8);
	signal SIG_OCCUR_NUM	: unsigned(7 downto 0):=to_unsigned(64, 8);
	signal NOISE_POW		: signed(31 downto 0):=to_signed(10000*2, 32);
	signal AGC_ERR_EXP		: signed(7 downto 0):=to_signed(-6, 8); --2^(-6)
	signal TLL_DET_WIN_LEN 	: unsigned(9 downto 0):=to_unsigned(1023,10);
	signal TLL_ERR_ABS		: signed(24 downto 0):=to_signed(1300,25);
	signal TLL_LOCKED_NUM	: unsigned(9 downto 0):=to_unsigned(512,10);
	signal PLL_DET_WIN_LEN 	: unsigned(9 downto 0):=to_unsigned(1023,10);
	signal PLL_ERR_ABS		: signed(19 downto 0):=to_signed(200,20); --pi/128*2^13
	signal PLL_LOCKED_NUM	: unsigned(9 downto 0):=to_unsigned(200,10);
	signal signal_present		: std_logic:='0';
	signal pll_locked    		: std_logic:='0';
	signal tll_locked			: std_logic:='0';
	signal agc_error 			: std_logic_vector(31 downto 0):=(others=>'0'); 
	signal error_exp 			: signed(7 downto 0):=(others=>'0'); 
	signal sig_det_win			: unsigned(7 downto 0):=(others=>'0'); 
	signal sig_occurs			: unsigned(7 downto 0):=(others=>'0'); 
	signal tll_det_win			: unsigned(9 downto 0):=(others=>'0'); 
	signal cnt_tll_locked		: unsigned(9 downto 0):=(others=>'0'); 
	signal pll_det_win			: unsigned(9 downto 0):=(others=>'0'); 
	signal cnt_pll_locked		: unsigned(9 downto 0):=(others=>'0'); 
	signal dmu_out_vld 			: std_logic:='0';
	signal dmu_out				: std_logic_vector(24 downto 0):=(others=>'0'); 


	signal phase_diff_vld  		: std_logic:='0';
	signal phase_diff_out  		: std_logic_vector(19 downto 0):=(others=>'0');

	signal probe_out4 : std_logic_vector(7 downto 0):=(others=>'0');
	signal probe_out5 : std_logic_vector(7 downto 0):=(others=>'0');
	signal probe_out6 : std_logic_vector(31 downto 0):=(others=>'0');
	signal probe_out7 : std_logic_vector(7 downto 0):=(others=>'0');
	signal probe_out8 : std_logic_vector(9 downto 0):=(others=>'0');
	signal probe_out9 : std_logic_vector(24 downto 0):=(others=>'0');
	signal probe_out10 :std_logic_vector(9 downto 0):=(others=>'0');
	signal probe_out11 :std_logic_vector(9 downto 0):=(others=>'0');
	signal probe_out12 :std_logic_vector(19 downto 0):=(others=>'0');
	signal probe_out13 :std_logic_vector(9 downto 0):=(others=>'0');

	-- synthesis translate_off
	file rec_4: text open write_mode is "D:\projects\46_high_speed_dem\sim\modelsim\sync_sym_i.txt"; 
	file rec_5: text open write_mode is "D:\projects\46_high_speed_dem\sim\modelsim\sync_sym_q.txt"; 
	file rec_6: text open write_mode is "D:\projects\46_high_speed_dem\sim\modelsim\sym_i.txt"; 
	file rec_7: text open write_mode is "D:\projects\46_high_speed_dem\sim\modelsim\sym_q.txt"; 
	file rec_8: text open write_mode is "D:\projects\46_high_speed_dem\sim\modelsim\agc_i.txt"; 
	file rec_9: text open write_mode is "D:\projects\46_high_speed_dem\sim\modelsim\agc_q.txt"; 
	-- synthesis translate_on

	attribute fsm_encoding : string;
	attribute fsm_encoding of dem_sts : signal is "sequential";
	
	attribute mark_debug : string;
	attribute mark_debug of sym_sync_en,sym_sync_data_i,sym_sync_data_q : signal is "TRUE";
	attribute mark_debug of signal_present		 : signal is "TRUE"; 
	attribute mark_debug of pll_locked    		 : signal is "TRUE";
	attribute mark_debug of tll_locked			 : signal is "TRUE";
	attribute mark_debug of agc_error 			 : signal is "TRUE";
	attribute mark_debug of error_exp 			 : signal is "TRUE";
	attribute mark_debug of sig_det_win			 : signal is "TRUE";
	attribute mark_debug of sig_occurs			 : signal is "TRUE";
	attribute mark_debug of tll_det_win			 : signal is "TRUE";
	attribute mark_debug of cnt_tll_locked		 : signal is "TRUE";
	attribute mark_debug of pll_det_win			 : signal is "TRUE";
	attribute mark_debug of cnt_pll_locked		 : signal is "TRUE";
	attribute mark_debug of dmu_out_vld 		 : signal is "TRUE";
	attribute mark_debug of dmu_out				 : signal is "TRUE";
	attribute mark_debug of agc_vld				 : signal is "TRUE";	
	attribute mark_debug of agc_i				 : signal is "TRUE";	
	attribute mark_debug of agc_q				 : signal is "TRUE";	
	attribute mark_debug of en_sym 	             : signal is "TRUE";
	attribute mark_debug of sym_i	             : signal is "TRUE";
	attribute mark_debug of sym_q	             : signal is "TRUE";
	attribute mark_debug of phase_diff_vld       : signal is "TRUE";
	attribute mark_debug of phase_diff_out		 : signal is "TRUE";
	attribute mark_debug of dem_sts				 : signal is "TRUE";
	attribute mark_debug of aresetn_agc			 : signal is "TRUE";
	attribute mark_debug of aresetn_tll			 : signal is "TRUE";
	attribute mark_debug of aresetn_pll			 : signal is "TRUE";
begin


	SIG_DET_WIN_LEN	<= unsigned(probe_out4);
	SIG_OCCUR_NUM	<= unsigned(probe_out5);
	NOISE_POW		<= signed(probe_out6); 
	AGC_ERR_EXP		<= signed(probe_out7);
	TLL_DET_WIN_LEN <= unsigned(probe_out8); 
	TLL_ERR_ABS		<= signed(probe_out9); 
	TLL_LOCKED_NUM	<= unsigned(probe_out10); 
	PLL_DET_WIN_LEN <= unsigned(probe_out11);
	PLL_ERR_ABS		<= signed(probe_out12);
	PLL_LOCKED_NUM	<= unsigned(probe_out13); 

	-- wait signal occurs and agc locked
	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if aresetn_agc = '0' then
				signal_present <= '0';
				sig_det_win <= (others=>'0'); 
				sig_occurs <= (others=>'0'); 
			elsif ddc_vld	= '1' then
				error_exp <= signed(agc_error(30 downto 23)) - 127;
				if sig_det_win = SIG_DET_WIN_LEN then
					sig_det_win <= (others=>'0'); 
					sig_occurs <= (others=>'0'); 
					if (sig_occurs >= SIG_OCCUR_NUM) then
						signal_present <= '1';
					else
						signal_present <= '0';
					end if;
				else
					sig_det_win <= sig_det_win + 1;
					if (signed(power_out) >= NOISE_POW) and (signed(error_exp) <= AGC_ERR_EXP) then
						sig_occurs <= sig_occurs + 1;
					end if;
				end if;
			end if;
		end if;
	end process; 

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			case dem_sts is
				when st_idle	 =>
					if aresetn_agc = '0' then
						dem_sts <= st_idle;
					elsif (signal_present = '1') then
						dem_sts <= st_acq_tll;
					end if;
				when st_acq_tll  =>
					if aresetn_agc = '0' then
						dem_sts <= st_idle;
					elsif (dmu_out_vld = '1') then
						if tll_det_win = TLL_DET_WIN_LEN then
							if (cnt_tll_locked < TLL_LOCKED_NUM) then
								dem_sts <= st_idle;
							else
								dem_sts <= st_acq_pll;
							end if;
						end if;
					end if;
				when st_acq_pll  =>
					if aresetn_agc = '0' then
						dem_sts <= st_idle;
					elsif (phase_diff_vld = '1') then
						if pll_det_win = PLL_DET_WIN_LEN then
							if (cnt_pll_locked < PLL_LOCKED_NUM) then
								dem_sts <= st_idle;
							end if;
						end if;
					end if;
				when others =>
					if aresetn_agc = '0' then
						dem_sts <= st_idle;
					end if;
			end case;
		end if;
	end process; 

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			case dem_sts is
				when st_idle	 =>
					tll_det_win <= (others=>'0'); 
					cnt_tll_locked <= (others=>'0'); 
					tll_locked <= '0';
					pll_det_win <= (others=>'0'); 
					cnt_pll_locked <= (others=>'0'); 
					pll_locked <= '0';
					aresetn_pll <= '0';
					if aresetn_agc = '0' then
						aresetn_tll <= '0';
					elsif (signal_present = '1') then
						aresetn_tll <= '1';
					else
						aresetn_tll <= '0';
					end if;
				when st_acq_tll	 =>
					-- wait TLL locked
					if (dmu_out_vld = '1') then
						if tll_det_win = TLL_DET_WIN_LEN then
							tll_det_win <= (others=>'0'); 
							cnt_tll_locked <= (others=>'0'); 
							if (cnt_tll_locked >= TLL_LOCKED_NUM) then
								tll_locked <= '1';
								aresetn_pll <= '1';
							else
								tll_locked <= '0';
								aresetn_pll <= '0';
							end if;
						else
							tll_det_win <= tll_det_win + 1;
							if (abs(signed(dmu_out)) <= TLL_ERR_ABS) then
								cnt_tll_locked <= cnt_tll_locked + 1;
							end if;
						end if;
					end if;
				when st_acq_pll  =>
					-- wait PLL locked
					if (phase_diff_vld = '1') then
						if pll_det_win = PLL_DET_WIN_LEN then
							pll_det_win <= (others=>'0'); 
							cnt_pll_locked <= (others=>'0'); 
							if (cnt_pll_locked >= PLL_LOCKED_NUM) then
								pll_locked <= '1';
							else
								pll_locked <= '0';
							end if;
						else
							pll_det_win <= pll_det_win + 1;
							if (abs(signed(phase_diff_out)) <= PLL_ERR_ABS) then
								cnt_pll_locked <= cnt_pll_locked + 1;
							end if;
						end if;
					end if;
				when others => null;
			end case;
		end if;
	end process;

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if aresetn = '0' or aresetn_handset(0) = '0' then
				aresetn_agc <= '0';
			else
				aresetn_agc <= '1';
			end if;
		end if;
	end process; 

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if agc_vld_t = '1' then 		
				agc_i_d(0) <= agc_i_t;	
				agc_i_d(1) <= agc_i_d(0);	
				agc_q_d(0) <= agc_q_t;	
				agc_q_d(1) <= agc_q_d(0);	
				p1 <= signed(agc_i_d(1)) * signed(agc_i_t);	
				p2 <= signed(agc_q_d(1)) * signed(agc_q_t);	
				p3 <= signed(agc_i_d(1)) * signed(agc_q_t);	
				p4 <= signed(agc_q_d(1)) * signed(agc_i_t);	
				agc_c <= p1 + p2;
				agc_s <= p3 - p4;

			end if;
		end if;
	end process; 

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if agc_vld_t = '1' then
				agc_vld  <= '1' ;
				if sym_type /= "100" then -- DQPSK
					if agc_i_t(15 downto 8) = x"00" or agc_i_t(15 downto 8) = x"FF" then 
						agc_i 	<= agc_i_t(8 downto 0);
					elsif agc_i_t(agc_i_t'high) = '1' then
						agc_i 	<= "100000000";
					elsif agc_i_t(agc_i_t'high) = '0' then
						agc_i 	<= "011111111";
					end if;
					if agc_q_t(15 downto 8) = x"00" or agc_q_t(15 downto 8) = x"FF" then 
						agc_q 	<= agc_q_t(8 downto 0);
					elsif agc_q_t(agc_q_t'high) = '1' then
						agc_q 	<= "100000000";
					elsif agc_q_t(agc_q_t'high) = '0' then
						agc_q 	<= "011111111";
					end if;
				else
					-- REF is 64
					if agc_c(31 downto 14) = "000000000000000000" or agc_c(31 downto 14) = "111111111111111111" then 
						agc_i 	<= std_logic_vector(signed(agc_c(14 downto 6)));
					elsif agc_c(31) = '1' then
						agc_i 	<= "100000000";
					elsif agc_c(31) = '0' then
						agc_i 	<= "011111111";
					end if;
					if agc_s(31 downto 14) = "000000000000000000" or agc_s(31 downto 14) = "111111111111111111" then 
						agc_q 	<= std_logic_vector(signed(agc_s(14 downto 6)));
					elsif agc_s(31) = '1' then
						agc_q 	<= "100000000";
					elsif agc_s(31) = '0' then
						agc_q 	<= "011111111";
					end if;
				end if;
			else
				agc_vld  <= '0';
			end if;
		end if;
	end process; 

	u_agc: agc
	port map(
			sys_clk			=> 	sys_clk			,
			aresetn 		=> 	aresetn_agc 	,
			--log_ref  		=> 	x"408515B5"  	,
			log_ref  		=> 	log_ref			,
			wave_in_valid 	=>  ddc_vld			,	
			wave_in_i 		=> 	ddc_i			,
			wave_in_q		=> 	ddc_q			,
			wave_out_valid 	=> 	agc_vld_t 		,
			wave_out_i 		=> 	agc_i_t 		,
			wave_out_q 		=> 	agc_q_t 		,
			power_out_o 	=> 	power_out		,
			exp_gain_o 		=> 	exp_gain		,
			agc_error 		=>  agc_error
		);

	-- synthesis translate_off
	process(sys_clk)
		variable buf: LINE;
	begin
		if rising_edge(sys_clk) then
			if agc_vld_t = '1' then
				write(buf,to_integer(signed(agc_i_t)));
				writeline(rec_8,buf);
			end if;
		end if;
	end process;

	process(sys_clk)
		variable buf: LINE;
	begin
		if rising_edge(sys_clk) then
			if agc_vld_t = '1' then
				write(buf,to_integer(signed(agc_q_t)));
				writeline(rec_9,buf);
			end if;
		end if;
	end process;
	-- synthesis translate_on

	u_tll_new: tll_newer
	port map(
			sys_clk			=> sys_clk			,
			aresetn 		=> aresetn_tll  	,
			samp_vld		=> agc_vld			,
			samp_i			=> agc_i			,
			samp_q			=> agc_q			,
			en_sym 			=> en_sym 			,
			sym_i			=> sym_i			,
			sym_q			=> sym_q			,
			dmu_out_vld 	=> dmu_out_vld		,
			dmu_out			=> dmu_out						
		);

	-- synthesis translate_off
	process(sys_clk)
		variable buf: LINE;
	begin
		if rising_edge(sys_clk) then
			if en_sym = '1' then
				write(buf,to_integer(signed(sym_i)));
				writeline(rec_6,buf);
			end if;
		end if;
	end process;

	process(sys_clk)
		variable buf: LINE;
	begin
		if rising_edge(sys_clk) then
			if en_sym = '1' then
				write(buf,to_integer(signed(sym_q)));
				writeline(rec_7,buf);
			end if;
		end if;
	end process;
	-- synthesis translate_on


	-- sym_type 
	-- 000: BPSK
	-- 001: QPSK
	-- 010: OQPSK
	-- 011: 8PSK
	-- 100: pi/4DQPSK
	-- 101: 8QAM
	-- 110: 16QAM

	u_vio_dem: vio_dem
	port map(
				 clk 		 => sys_clk				,
				 probe_out0  => open				,
	--			 probe_out0  => sym_type			,
				 probe_out1  => aresetn_handset		,
				 probe_out2  => pll_select			,
				 probe_out3  => log_ref				,
				 probe_out4  => probe_out4 				,
				 probe_out5  => probe_out5 				,
				 probe_out6  => probe_out6 				,
				 probe_out7  => probe_out7 				,
				 probe_out8  => probe_out8 				,
				 probe_out9  => probe_out9 				,
				 probe_out10 => probe_out10				,
				 probe_out11 => probe_out11				,
				 probe_out12 => probe_out12				,
				 probe_out13 => probe_out13				
			 );

	u_pll: pll
	port map(
				sys_clk				=> sys_clk				, 
				aresetn 			=> aresetn_pll			, 
				sym_type			=> sym_type				,
				en_sym				=> en_sym 				, 
				sym_i				=> sym_i(24 downto 9)	,   
				sym_q				=> sym_q(24 downto 9)	,   
				euclidean_distance  => open					,
				sym_sync_en         => sym_sync_en			,
				sym_sync_data_i	    => sym_sync_data_i		,
				sym_sync_data_q	    => sym_sync_data_q 		,
				phase_diff_vld  	=> phase_diff_vld		,
				phase_diff_out  	=> phase_diff_out		
			);

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if pll_locked = '1' then
				dem_vld <= sym_sync_en;
				dem_sym_i <= sym_sync_data_i;
				dem_sym_q <= sym_sync_data_q;
				dem_bit(1 downto 0) <= sym_sync_data_i(sym_sync_data_i'high) & sym_sync_data_q(sym_sync_data_q'high) ;
			else
				dem_vld <= '0';
			end if;
		end if;
	end process; 

	-- synthesis translate_off
	process(sys_clk)
		variable buf: LINE;
	begin
		if rising_edge(sys_clk) then
			if sym_sync_en = '1' then
				write(buf,to_integer(signed(sym_sync_data_i)));
				writeline(rec_4,buf);
			end if;
		end if;
	end process;

	process(sys_clk)
		variable buf: LINE;
	begin
		if rising_edge(sys_clk) then
			if sym_sync_en = '1' then
				write(buf,to_integer(signed(sym_sync_data_q)));
				writeline(rec_5,buf);
			end if;
		end if;
	end process;
	-- synthesis translate_on

end arch;

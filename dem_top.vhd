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

	component mf
		port (
				 aresetn : in std_logic;
				 aclk : in std_logic;
				 s_axis_data_tvalid : in std_logic;
				 s_axis_data_tready : out std_logic;
				 s_axis_data_tdata : in std_logic_vector(15 downto 0);
				 m_axis_data_tvalid : out std_logic;
				 m_axis_data_tdata : out std_logic_vector(31 downto 0) 
			 );
	end component;

	component agc
	port(
			sys_clk				: in std_logic;
			aresetn 			: in std_logic;
			start_level  		: in std_logic_vector(31 downto 0);
			wave_in_valid 		: in std_logic;
			wave_in_i 			: in std_logic_vector(15 downto 0);
			wave_in_q			: in std_logic_vector(15 downto 0);
			wave_out_valid 		: out std_logic;
			wave_out_i 			: out std_logic_vector(15 downto 0);
			wave_out_q 			: out std_logic_vector(15 downto 0);
			power_out_o 		: out std_logic_vector(31 downto 0):=(others=>'0');
			exp_gain_o 			: out std_logic_vector(31 downto 0):=(others=>'0')
		);
	end component;
	
	component sym_sync
	port(
			sys_clk		: in std_logic; -- 28.8MHz
			aresetn 	: in std_logic;
			samp_vld	: in std_logic;
			samp_i		: in std_logic_vector(8 downto 0);
			samp_q		: in std_logic_vector(8 downto 0);
			sym_en		: out std_logic:='0';
			sym_i		: out std_logic_vector(24 downto 0):=(others=>'0');
			sym_q		: out std_logic_vector(24 downto 0):=(others=>'0')
		);
    end component;

	component pll
	port(
			sys_clk		: in std_logic;
			aresetn 	: in std_logic;
			sym_type 	: in std_logic_vector(2 downto 0);
			en_sym		: in std_logic;
			sym_i		: in std_logic_vector(23 downto 0);
			sym_q		: in std_logic_vector(23 downto 0);
			sym_phase  : in std_logic_vector(23 downto 0);
			sym_sync_en 	: out std_logic:='0';
			phase_int_o	 	: out std_logic_vector(19 downto 0):=(others=>'0');
			sym_sync_data_i	: out std_logic_vector(23 downto 0):=(others=>'0');
			sym_sync_data_q	: out std_logic_vector(23 downto 0):=(others=>'0')
		);
	end component;

	component vio_dem
		port (
				 clk : in std_logic;
				 probe_out0 : out std_logic_vector(2 downto 0);
				 probe_out1 : out std_logic_vector(0 downto 0) 
			 );
	end component;

	component tll_newer
	port(
			sys_clk		: in std_logic;
			aresetn 	: in std_logic;
			samp_vld	: in std_logic;
			samp_i		: in std_logic_vector(8 downto 0);
			samp_q		: in std_logic_vector(8 downto 0);
			en_sym 		: out std_logic:='0';
			sym_i		: out std_logic_vector(24 downto 0):=(others=>'0');
			sym_q		: out std_logic_vector(24 downto 0):=(others=>'0')
		);
	end component;

	signal start_level  : std_logic_vector(31 downto 0):= (others=>'0');
	signal agc_vld		: std_logic:='0';
	signal agc_vld_t	: std_logic:='0';
	signal agc_i		: std_logic_vector(15 downto 0):= (others=>'0');
	signal agc_q		: std_logic_vector(15 downto 0):= (others=>'0');
	signal agc_i_t		: std_logic_vector(8 downto 0):= (others=>'0');
	signal agc_q_t		: std_logic_vector(8 downto 0):= (others=>'0');
	signal power_out	: std_logic_vector(31 downto 0):= (others=>'0');
	signal exp_gain 	: std_logic_vector(31 downto 0):= (others=>'0');

--	signal sym_vld_dly 	: std_logic_vector(27 downto 0):=(others=>'0'); 
--	signal sym_i_dly	: std_logic_array_24(27 downto 0):=(others=>(others=>'0'));
--	signal sym_q_dly	: std_logic_array_24(27 downto 0):=(others=>(others=>'0'));
	signal sym_vld 		: std_logic;
	signal sym_i		: std_logic_vector(24 downto 0):=(others=>'0');
	signal sym_q		: std_logic_vector(24 downto 0):=(others=>'0');
	signal sym_type		: std_logic_vector(2 downto 0):=(others=>'0'); 
	signal phase_int	: std_logic_vector(19 downto 0):=(others=>'0'); 

	signal sym_sync_en		: std_logic:='0';
	signal sym_sync_data_i	: std_logic_vector(23 downto 0):=(others=>'0');
	signal sym_sync_data_q  : std_logic_vector(23 downto 0):=(others=>'0');

	signal m_axis_phase 			: std_logic_vector(23 downto 0):=(others=>'0');
	signal m_axis_phase_tvalid		: std_logic:='0';
	signal pll_rstn					: std_logic_vector(0 downto 0):=(others=>'0');
	signal flag2					: std_logic:='0';
	signal ddc_vld_2				: std_logic:='0'; 
	signal ddc_i_2					: std_logic_vector(15 downto 0):=(others=>'0');
	signal ddc_q_2					: std_logic_vector(15 downto 0):=(others=>'0');
	signal mf_vld					: std_logic:='0';
	signal mf_i_t					: std_logic_vector(31 downto 0):=(others=>'0'); 
	signal mf_q_t					: std_logic_vector(31 downto 0):=(others=>'0'); 
	signal mf_i						: std_logic_vector(15 downto 0):=(others=>'0'); 
	signal mf_q						: std_logic_vector(15 downto 0):=(others=>'0'); 


	-- synthesis translate_off
	file rec_0: text open write_mode is "D:\projects\46_high_speed_dem\sim\modelsim\sym_i.txt"; 
	file rec_1: text open write_mode is "D:\projects\46_high_speed_dem\sim\modelsim\sym_q.txt"; 
	file rec_2: text open write_mode is "D:\projects\46_high_speed_dem\sim\modelsim\sync_sym_i.txt"; 
	file rec_3: text open write_mode is "D:\projects\46_high_speed_dem\sim\modelsim\sync_sym_q.txt"; 
	file rec_4: text open write_mode is "D:\projects\46_high_speed_dem\sim\modelsim\agc_i.txt"; 
	file rec_5: text open write_mode is "D:\projects\46_high_speed_dem\sim\modelsim\agc_q.txt"; 
	-- synthesis translate_on
--	attribute mark_debug : string;
--	attribute mark_debug of power_valid : signal is "TRUE";

begin

	-- downsample sps = 4 to 2
	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if ddc_vld = '1' then 
				flag2 <= not flag2;
			end if;
			if ddc_vld = '1' and flag2 = '1' then
				ddc_vld_2 <= '1';	
				ddc_i_2	<= ddc_i;
				ddc_q_2	<= ddc_q;
			else
				ddc_vld_2 <= '0'; 	
			end if;
		end if;
	end process; 

	-- [-5,5,5,-50,50,312,312,50,-50,5,5,-5]
	-- matching filter
	u_mf_i: mf
	port map(
				aresetn 			=> aresetn,
				aclk 				=> sys_clk,
				s_axis_data_tvalid 	=> ddc_vld_2 ,
				s_axis_data_tready 	=> open,
				s_axis_data_tdata 	=> ddc_i_2,
				m_axis_data_tvalid 	=> mf_vld,
				m_axis_data_tdata 	=> mf_i_t
			);

	u_mf_q: mf
	port map(
				aresetn 			=> aresetn,
				aclk 				=> sys_clk,
				s_axis_data_tvalid 	=> ddc_vld_2 ,
				s_axis_data_tready 	=> open,
				s_axis_data_tdata 	=> ddc_q_2,
				m_axis_data_tvalid 	=> open,
				m_axis_data_tdata 	=> mf_q_t
			);

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if mf_i_t(25 downto 24) = "00" or mf_i_t(25 downto 24) = "11" then
				mf_i <= mf_i_t(24 downto 9);
			elsif mf_i_t(mf_i_t'high) = '0' then
				mf_i <= x"7FFF";
			elsif mf_i_t(mf_i_t'high) = '1' then 
				mf_i <= x"8001";
			end if;
			if mf_q_t(25 downto 24) = "00" or mf_q_t(25 downto 24) = "11" then
				mf_q <= mf_q_t(24 downto 9);
			elsif mf_q_t(mf_q_t'high) = '0' then
				mf_q <= x"7FFF";
			elsif mf_q_t(mf_q_t'high) = '1' then
				mf_q <= x"8001";
			end if;
		end if;
	end process; 
	
	u_agc: agc
	port map(
			sys_clk			=> sys_clk		,
			aresetn 		=> aresetn		,
			start_level  	=> start_level	,
			wave_in_valid 	=> mf_vld 		,
			wave_in_i 		=> mf_i 		,
			wave_in_q		=> mf_q		,
			wave_out_valid 	=> agc_vld		,
			wave_out_i 		=> agc_i		,
			wave_out_q 		=> agc_q		,
			power_out_o 	=> power_out	,
			exp_gain_o 		=> exp_gain
		);

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			agc_vld_t <= agc_vld;
			if agc_i(15 downto 8) = "00000000" or agc_i(15 downto 8) = "11111111" then
				agc_i_t <= agc_i(8 downto 0);
			elsif agc_i(15) = '0' then
				agc_i_t <= "011111111";
			elsif agc_i(15) = '1' then
				agc_i_t <= "100000001";
			end if;
			if agc_q(15 downto 8) = "00000000" or agc_q(15 downto 8) = "11111111" then
				agc_q_t <= agc_q(8 downto 0);
			elsif agc_q(15) = '0' then
				agc_q_t <= "011111111";
			elsif agc_q(15) = '1' then
				agc_q_t <= "100000001";
			end if;
		end if;
	end process; 

	-- synthesis translate_off
	process(sys_clk)
		variable buf: LINE;
	begin
		if rising_edge(sys_clk) then
			if agc_vld = '1' then
				write(buf,to_integer(signed(agc_i)));
				writeline(rec_4,buf);
			end if;
		end if;
	end process;

	process(sys_clk)
		variable buf: LINE;
	begin
		if rising_edge(sys_clk) then
			if agc_vld = '1' then
				write(buf,to_integer(signed(agc_q)));
				writeline(rec_5,buf);
			end if;
		end if;
	end process;
	-- synthesis translate_on

	u_tll_new: tll_newer
	port map(
			sys_clk		=>  sys_clk,
			aresetn 	=>  aresetn,
			samp_vld	=>  agc_vld_t,
			samp_i		=>  agc_i_t,
			samp_q		=>  agc_q_t,
			en_sym 		=>  sym_vld,
			sym_i		=>  sym_i,
			sym_q		=>  sym_q
		);

	-- synthesis translate_off
	process(sys_clk)
		variable buf: LINE;
	begin
		if rising_edge(sys_clk) then
			if sym_vld = '1' then
				write(buf,to_integer(signed(sym_i)));
				writeline(rec_0,buf);
			end if;
		end if;
	end process;

	process(sys_clk)
		variable buf: LINE;
	begin
		if rising_edge(sys_clk) then
			if sym_vld = '1' then
				write(buf,to_integer(signed(sym_q)));
				writeline(rec_1,buf);
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
				 clk 		=> sys_clk,
				 probe_out0 => sym_type,
				 probe_out1 => pll_rstn
			 );

	u_pll: pll
	port map(
			sys_clk			=> sys_clk				, 
			aresetn 		=> pll_rstn(0)			, 
			sym_type		=> sym_type				,
			en_sym			=> sym_vld				, 
			sym_i			=> sym_i(24 downto 1)	,   
			sym_q			=> sym_q(24 downto 1)	,   
			sym_phase		=> m_axis_phase 		,
			sym_sync_en     => sym_sync_en			,
			phase_int_o	 	=> phase_int			,
			sym_sync_data_i	=> sym_sync_data_i		,
			sym_sync_data_q	=> sym_sync_data_q 
		);

	dem_vld <= sym_sync_en ;
	dem_sym_i <= sym_sync_data_i(15 downto 0);
	dem_sym_q <= sym_sync_data_q(15 downto 0);
	dem_bit(1 downto 0) <= sym_sync_data_i(sym_sync_data_i'high) & sym_sync_data_q(sym_sync_data_q'high) ;

	-- synthesis translate_off
	process(sys_clk)
		variable buf: LINE;
	begin
		if rising_edge(sys_clk) then
			if sym_sync_en = '1' then
				write(buf,to_integer(signed(sym_sync_data_i)));
				writeline(rec_2,buf);
			end if;
		end if;
	end process;

	process(sys_clk)
		variable buf: LINE;
	begin
		if rising_edge(sys_clk) then
			if sym_sync_en = '1' then
				write(buf,to_integer(signed(sym_sync_data_q)));
				writeline(rec_3,buf);
			end if;
		end if;
	end process;
	-- synthesis translate_on

end arch;

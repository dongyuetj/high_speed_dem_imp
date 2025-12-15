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

--	component mf
--		port (
--				 aresetn : in std_logic;
--				 aclk : in std_logic;
--				 s_axis_data_tvalid : in std_logic;
--				 s_axis_data_tready : out std_logic;
--				 s_axis_data_tdata : in std_logic_vector(15 downto 0);
--				 m_axis_data_tvalid : out std_logic;
--				 m_axis_data_tdata : out std_logic_vector(31 downto 0) 
--			 );
--	end component;

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
			exp_gain_o 			: out std_logic_vector(31 downto 0):=(others=>'0')
		);
	end component;
	
--	component sym_sync
--	port(
--			sys_clk		: in std_logic; -- 28.8MHz
--			aresetn 	: in std_logic;
--			samp_vld	: in std_logic;
--			samp_i		: in std_logic_vector(8 downto 0);
--			samp_q		: in std_logic_vector(8 downto 0);
--			sym_en		: out std_logic:='0';
--			sym_i		: out std_logic_vector(24 downto 0):=(others=>'0');
--			sym_q		: out std_logic_vector(24 downto 0):=(others=>'0')
--		);
--    end component;

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
			sym_sync_data_q	: out std_logic_vector(15 downto 0):=(others=>'0')
		);
	end component;

	component vio_dem
		port (
				 clk : in std_logic;
				 probe_out0 : out std_logic_vector(2 downto 0);
				 probe_out1 : out std_logic_vector(0 downto 0); 
				 probe_out2 : out std_logic_vector(1 downto 0);
				 probe_out3 : out std_logic_vector(31 downto 0)
			 );
	end component;

--	component tll_newer
--	port(
--			sys_clk		: in std_logic;
--			aresetn 	: in std_logic;
--			samp_vld	: in std_logic;
--			samp_i		: in std_logic_vector(8 downto 0);
--			samp_q		: in std_logic_vector(8 downto 0);
--			en_sym 		: out std_logic:='0';
--			sym_i		: out std_logic_vector(24 downto 0):=(others=>'0');
--			sym_q		: out std_logic_vector(24 downto 0):=(others=>'0')
--		);
--	end component;

	component cmp4
	generic(
			   data_width : integer := 32;
			   data_num   : integer := 32
		   );
	port(
			sys_clk			: in std_logic; -- 28.8MHz
			en				: in std_logic;
			data_in			: in std_logic_array_32(data_num-1 downto 0);
			max_data		: out std_logic_vector(data_width-1 downto 0):=(others=>'0');
			max_ind			: out std_logic_vector(LOG2(data_num)-1 downto 0):=(others=>'0')
		);
	end component;
	
	component power_detect
	generic(moving_window_len : integer:=16);
		port(

			sys_clk				: in std_logic; -- 28.8MHz
			aresetn 			: in std_logic;
			start_level  		: in std_logic_vector(31 downto 0);
			wave_in_valid 		: in std_logic;
			wave_in_i 			: in std_logic_vector(15 downto 0);
			wave_in_q			: in std_logic_vector(15 downto 0);

			power_valid	    : out std_logic;
			power_out		: out std_logic_vector(31 downto 0)
		);
	end component;

	signal log_ref  : std_logic_vector(31 downto 0):= (others=>'0');
	signal agc_vld_t	: std_logic:='0';
	signal agc_i_t		: std_logic_vector(15 downto 0):= (others=>'0');
	signal agc_q_t		: std_logic_vector(15 downto 0):= (others=>'0');
	signal agc_i_d		: std_logic_array_16(3 downto 0):= (others=>(others=>'0'));
	signal agc_q_d		: std_logic_array_16(3 downto 0):= (others=>(others=>'0'));
	signal power_out	: std_logic_vector(31 downto 0):= (others=>'0');
	signal exp_gain 	: std_logic_vector(31 downto 0):= (others=>'0');

--	signal sym_vld_dly 	: std_logic_vector(27 downto 0):=(others=>'0'); 
--	signal sym_i_dly	: std_logic_array_24(27 downto 0):=(others=>(others=>'0'));
--	signal sym_q_dly	: std_logic_array_24(27 downto 0):=(others=>(others=>'0'));
	signal sym_vld 		: std_logic;
	signal sym_i		: std_logic_vector(24 downto 0):=(others=>'0');
	signal sym_q		: std_logic_vector(24 downto 0):=(others=>'0');
	signal sym_type		: std_logic_vector(2 downto 0):=(others=>'0'); 
	signal pll_select   : std_logic_vector(1 downto 0):=(others=>'0'); 
	signal phase_int	: std_logic_vector(19 downto 0):=(others=>'0'); 

	signal sym_sync_en		: std_logic_vector(3 downto 0):=(others=>'0');
	signal sym_sync_data_i	: std_logic_array_16(3 downto 0):=(others=>(others=>'0'));
	signal sym_sync_data_q  : std_logic_array_16(3 downto 0):=(others=>(others=>'0'));

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
	signal cnt4 					: unsigned(1 downto 0):= (others=>'0'); 
	signal agc_vld					: std_logic_vector(3 downto 0):= (others=>'0'); 
	signal agc_i					: std_logic_array_16(3 downto 0):= (others=>(others=>'0')); 
	signal agc_q					: std_logic_array_16(3 downto 0):= (others=>(others=>'0'));
	signal symb_power_valid				: std_logic_vector(3 downto 0):=(others=>'0'); 
	signal symb_power_out				: std_logic_array_32(3 downto 0):= (others=>(others=>'0'));
	signal max_data			: std_logic_vector(32-1 downto 0):=(others=>'0');
	signal max_ind			: std_logic_vector(1 downto 0):=(others=>'0');
	signal max_ind_int 		: integer range 0 to 3:=0;

	signal agc_c : signed(31 downto 0):= (others=>'0');
	signal agc_s : signed(31 downto 0):= (others=>'0');
	signal p1,p2,p3,p4 : signed(31 downto 0):= (others=>'0');
	-- synthesis translate_off
	file rec_0: text open write_mode is "D:\projects\46_high_speed_dem\sim\modelsim\agc_i0.txt"; 
	file rec_1: text open write_mode is "D:\projects\46_high_speed_dem\sim\modelsim\agc_q0.txt"; 
	file rec_2: text open write_mode is "D:\projects\46_high_speed_dem\sim\modelsim\agc_i1.txt"; 
	file rec_3: text open write_mode is "D:\projects\46_high_speed_dem\sim\modelsim\agc_q1.txt"; 
	file rec_4: text open write_mode is "D:\projects\46_high_speed_dem\sim\modelsim\agc_i2.txt"; 
	file rec_5: text open write_mode is "D:\projects\46_high_speed_dem\sim\modelsim\agc_q2.txt"; 
	file rec_6: text open write_mode is "D:\projects\46_high_speed_dem\sim\modelsim\agc_i3.txt"; 
	file rec_7: text open write_mode is "D:\projects\46_high_speed_dem\sim\modelsim\agc_q3.txt"; 
	file rec_8: text open write_mode is "D:\projects\46_high_speed_dem\sim\modelsim\agc_i.txt"; 
	file rec_9: text open write_mode is "D:\projects\46_high_speed_dem\sim\modelsim\agc_q.txt"; 
	file rec_a: text open write_mode is "D:\projects\46_high_speed_dem\sim\modelsim\sym_i0.txt"; 
	file rec_b: text open write_mode is "D:\projects\46_high_speed_dem\sim\modelsim\sym_q0.txt"; 
	file rec_c: text open write_mode is "D:\projects\46_high_speed_dem\sim\modelsim\sym_i1.txt"; 
	file rec_d: text open write_mode is "D:\projects\46_high_speed_dem\sim\modelsim\sym_q1.txt"; 
	file rec_e: text open write_mode is "D:\projects\46_high_speed_dem\sim\modelsim\sym_i2.txt"; 
	file rec_f: text open write_mode is "D:\projects\46_high_speed_dem\sim\modelsim\sym_q2.txt"; 
	file rec_g: text open write_mode is "D:\projects\46_high_speed_dem\sim\modelsim\sym_i3.txt"; 
	file rec_h: text open write_mode is "D:\projects\46_high_speed_dem\sim\modelsim\sym_q3.txt"; 
	-- synthesis translate_on
	attribute mark_debug : string;
	attribute mark_debug of sym_sync_en,sym_sync_data_i,sym_sync_data_q: signal is "TRUE";

begin

	u_agc: agc
	port map(
			sys_clk			=> 	sys_clk			,
			aresetn 		=> 	aresetn 		,
			log_ref  		=> 	log_ref  		,
			wave_in_valid 	=>  ddc_vld			,	
			wave_in_i 		=> 	ddc_i			,
			wave_in_q		=> 	ddc_q			,
			wave_out_valid 	=> 	agc_vld_t 		,
			wave_out_i 		=> 	agc_i_t 		,
			wave_out_q 		=> 	agc_q_t 		,
			power_out_o 	=> 	power_out		,
			exp_gain_o 		=> 	exp_gain
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

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if agc_vld_t = '1' then 		
				agc_i_d(0) <= agc_i_t;	
				agc_i_d(1) <= agc_i_d(0);	
				agc_i_d(2) <= agc_i_d(1);	
				agc_i_d(3) <= agc_i_d(2);	
				agc_q_d(0) <= agc_q_t;	
				agc_q_d(1) <= agc_q_d(0);	
				agc_q_d(2) <= agc_q_d(1);	
				agc_q_d(3) <= agc_q_d(2);	

				p1 <= signed(agc_i_d(3)) * signed(agc_i_t);	
				p2 <= signed(agc_q_d(3)) * signed(agc_q_t);	

				p3 <= signed(agc_i_d(3)) * signed(agc_q_t);	
				p4 <= signed(agc_q_d(3)) * signed(agc_i_t);	

				agc_c <= p1 + p2;
				agc_s <= p3 - p4;

			end if;
		end if;
	end process; 

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if agc_vld_t = '1' then
				cnt4 <= cnt4 + 1;
			end if;
			case cnt4 is
				when "00" =>
					if agc_vld_t = '1' then
						agc_vld(0)  <= '1' 			;
						if sym_type /= "100" then
							agc_i(0) 	<= agc_i_t;
							agc_q(0) 	<= agc_q_t;
						else
							agc_i(0) 	<= std_logic_vector(signed(agc_c(26 downto 11)));
							agc_q(0) 	<= std_logic_vector(signed(agc_s(26 downto 11)));
						end if;
					else
						agc_vld  <= (others=>'0'); 
					end if;
				when "01" =>
					if agc_vld_t = '1' then
						agc_vld(1)  <= '1' 			;
						if sym_type /= "100" then
							agc_i(1) 	<=  agc_i_t;
							agc_q(1) 	<=  agc_q_t;
						else                                                               
							agc_i(1) 	<=  std_logic_vector(signed(agc_c(26 downto 11)));
							agc_q(1) 	<=  std_logic_vector(signed(agc_s(26 downto 11)));
						end if;
					else
						agc_vld  <= (others=>'0'); 
					end if;
				when "10" =>
					if agc_vld_t = '1' then
						agc_vld(2)  <= '1' 			;
						if sym_type /= "100" then
							agc_i(2) 	<=   agc_i_t;
							agc_q(2) 	<=   agc_q_t;
						else                                                                
							agc_i(2) 	<=   std_logic_vector(signed(agc_c(26 downto 11)));
							agc_q(2) 	<=   std_logic_vector(signed(agc_s(26 downto 11)));
						end if;
					else
						agc_vld  <= (others=>'0'); 
					end if;
				when "11" =>
					if agc_vld_t = '1' then
						agc_vld(3)  <= '1' 			;
						if sym_type /= "100" then
							agc_i(3) 	<=    agc_i_t;
							agc_q(3) 	<=    agc_q_t;
						else                                                                 
							agc_i(3) 	<=    std_logic_vector(signed(agc_c(26 downto 11)));
							agc_q(3) 	<=    std_logic_vector(signed(agc_s(26 downto 11)));
						end if;
					else
						agc_vld  <= (others=>'0'); 
					end if;
				when others => 
					agc_vld  <= (others=>'0'); 
			end case;
		end if;
	end process; 

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
				 probe_out1 => pll_rstn,
				 probe_out2 => pll_select,
				 probe_out3 => log_ref
			 );

	max_ind_int <= to_integer(unsigned(max_ind));

	gen_pll: for ii in 0 to 3 generate
		u_pll: pll
		port map(
					sys_clk			=> sys_clk				, 
					aresetn 		=> pll_rstn(0)			, 
					sym_type		=> "101"				,
					en_sym			=> agc_vld(ii)			, 
					sym_i			=> agc_i(ii),   
					sym_q			=> agc_q(ii),   

					euclidean_distance => open					,
					sym_sync_en     => sym_sync_en(ii)			,
					sym_sync_data_i	=> sym_sync_data_i(ii)		,
					sym_sync_data_q	=> sym_sync_data_q(ii) 
				);
	end generate gen_pll;

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			dem_vld <= sym_sync_en(max_ind_int);
			dem_sym_i <= sym_sync_data_i(max_ind_int)(15 downto 0);
			dem_sym_q <= sym_sync_data_q(max_ind_int)(15 downto 0);
			dem_bit(1 downto 0) <= sym_sync_data_i(max_ind_int)(sym_sync_data_i'high) & sym_sync_data_q(max_ind_int)(sym_sync_data_q'high) ;
		end if;
	end process; 

	gen_pwr: for jj in 0 to 3 generate
		u_pwr_detect: power_detect
		generic map(moving_window_len => 31)
		port map(

					sys_clk				=> sys_clk,
					aresetn 			=> aresetn,
					start_level  		=> (others=>'0') ,
					wave_in_valid 		=> sym_sync_en(jj),
					wave_in_i 			=> sym_sync_data_i(jj)(15 downto 0),
					wave_in_q			=> sym_sync_data_q(jj)(15 downto 0),
					power_valid	    	=> symb_power_valid(jj),
					power_out			=> symb_power_out(jj)
					);
	end generate gen_pwr;

	u_cmp: cmp4
	generic map(
			   data_width => 32,
			   data_num   => 4
		   )
	port map(
			sys_clk			=>  sys_clk,
			en				=>  sym_sync_en(3),
			data_in			=>  symb_power_out,
			max_data		=>  max_data,
			max_ind			=>  max_ind
		);
	-- synthesis translate_off
	process(sys_clk)
		variable buf: LINE;
	begin
		if rising_edge(sys_clk) then
			if agc_vld(0) = '1' then
				write(buf,to_integer(signed(agc_i(0))));
				writeline(rec_0,buf);
			end if;
		end if;
	end process;

	process(sys_clk)
		variable buf: LINE;
	begin
		if rising_edge(sys_clk) then
			if agc_vld(0) = '1' then
				write(buf,to_integer(signed(agc_q(0))));
				writeline(rec_1,buf);
			end if;
		end if;
	end process;

	process(sys_clk)
		variable buf: LINE;
	begin
		if rising_edge(sys_clk) then
			if agc_vld(1) = '1' then
				write(buf,to_integer(signed(agc_i(1))));
				writeline(rec_2,buf);
			end if;
		end if;
	end process;

	process(sys_clk)
		variable buf: LINE;
	begin
		if rising_edge(sys_clk) then
			if agc_vld(1) = '1' then
				write(buf,to_integer(signed(agc_q(1))));
				writeline(rec_3,buf);
			end if;
		end if;
	end process;

	process(sys_clk)
		variable buf: LINE;
	begin
		if rising_edge(sys_clk) then
			if agc_vld(2) = '1' then
				write(buf,to_integer(signed(agc_i(2))));
				writeline(rec_4,buf);
			end if;
		end if;
	end process;

	process(sys_clk)
		variable buf: LINE;
	begin
		if rising_edge(sys_clk) then
			if agc_vld(2) = '1' then
				write(buf,to_integer(signed(agc_q(2))));
				writeline(rec_5,buf);
			end if;
		end if;
	end process;

	process(sys_clk)
		variable buf: LINE;
	begin
		if rising_edge(sys_clk) then
			if agc_vld(3) = '1' then
				write(buf,to_integer(signed(agc_i(3))));
				writeline(rec_6,buf);
			end if;
		end if;
	end process;

	process(sys_clk)
		variable buf: LINE;
	begin
		if rising_edge(sys_clk) then
			if agc_vld(3) = '1' then
				write(buf,to_integer(signed(agc_q(3))));
				writeline(rec_7,buf);
			end if;
		end if;
	end process;

	process(sys_clk)
		variable buf: LINE;
	begin
		if rising_edge(sys_clk) then
			if sym_sync_en(0) = '1' then
				write(buf,to_integer(signed(sym_sync_data_i(0))));
				writeline(rec_a,buf);
			end if;
		end if;
	end process;

	process(sys_clk)
		variable buf: LINE;
	begin
		if rising_edge(sys_clk) then
			if sym_sync_en(0) = '1' then
				write(buf,to_integer(signed(sym_sync_data_q(0))));
				writeline(rec_b,buf);
			end if;
		end if;
	end process;

	process(sys_clk)
		variable buf: LINE;
	begin
		if rising_edge(sys_clk) then
			if sym_sync_en(1) = '1' then
				write(buf,to_integer(signed(sym_sync_data_i(1))));
				writeline(rec_c,buf);
			end if;
		end if;
	end process;

	process(sys_clk)
		variable buf: LINE;
	begin
		if rising_edge(sys_clk) then
			if sym_sync_en(1) = '1' then
				write(buf,to_integer(signed(sym_sync_data_q(1))));
				writeline(rec_d,buf);
			end if;
		end if;
	end process;

	process(sys_clk)
		variable buf: LINE;
	begin
		if rising_edge(sys_clk) then
			if sym_sync_en(2) = '1' then
				write(buf,to_integer(signed(sym_sync_data_i(2))));
				writeline(rec_e,buf);
			end if;
		end if;
	end process;

	process(sys_clk)
		variable buf: LINE;
	begin
		if rising_edge(sys_clk) then
			if sym_sync_en(2) = '1' then
				write(buf,to_integer(signed(sym_sync_data_q(2))));
				writeline(rec_f,buf);
			end if;
		end if;
	end process;

	process(sys_clk)
		variable buf: LINE;
	begin
		if rising_edge(sys_clk) then
			if sym_sync_en(3) = '1' then
				write(buf,to_integer(signed(sym_sync_data_i(3))));
				writeline(rec_g,buf);
			end if;
		end if;
	end process;

	process(sys_clk)
		variable buf: LINE;
	begin
		if rising_edge(sys_clk) then
			if sym_sync_en(3) = '1' then
				write(buf,to_integer(signed(sym_sync_data_q(3))));
				writeline(rec_h,buf);
			end if;
		end if;
	end process;
	-- synthesis translate_on

end arch;

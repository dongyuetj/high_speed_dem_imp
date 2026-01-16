----------------------------------------------------------------------------------
-- Email: y.dong@outlook.com
-- Engineer: Dong Yue 
-- Create Date: 2025/11/12
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_SIGNED.ALL; 
use ieee.std_logic_textio.all;
use std.textio.all;  

entity tb_demod is
	--  Port ( );
end tb_demod;

architecture Behavioral of tb_demod is

	component dem_top
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
	end component;

	signal sys_clk					: std_logic := '0';
	signal aresetn 					: std_logic := '1';
	constant clock_period 			: time := 31.250 ns;
	signal cnt_div_4 				: std_logic_vector(31 downto 0):= (others=>'0'); 
	signal ddc_vld 					: std_logic:='0';
	signal ddc_i 					: std_logic_vector(15 downto 0):=(others=>'0');
	signal ddc_q					: std_logic_vector(15 downto 0):=(others=>'0');
	signal dem_vld 					: std_logic:='0';
	signal	dem_sym_i		: std_logic_vector(15 downto 0):= (others=>'0');
	signal	dem_sym_q		: std_logic_vector(15 downto 0):= (others=>'0');
	signal	dem_bit 		: std_logic_vector(7 downto 0):= (others=>'0');
	file rec_r_i: text open read_mode is "D:\projects\46_high_speed_dem\sim\dem_real_signal\real_i.txt";
	file rec_r_q: text open read_mode is "D:\projects\46_high_speed_dem\sim\dem_real_signal\imag_i.txt";
	file rec_2: text open write_mode is "D:\projects\46_high_speed_dem\sim\modelsim\dem_sym_i.txt"; 
	file rec_3: text open write_mode is "D:\projects\46_high_speed_dem\sim\modelsim\dem_sym_q.txt"; 
	

begin

	clock_gen : process
	begin
		sys_clk <= '0';
		wait for clock_period;
		loop
			sys_clk <= '0';
			wait for clock_period/2;
			sys_clk <= '1';
			wait for clock_period/2;
		end loop;
	end process clock_gen;

	resetn_gen : process
	begin
		aresetn <= '1';
		wait for 10 * clock_period;
		aresetn <= '0';
		wait for 2 * clock_period;
		aresetn <= '1';
		wait;
	end process resetn_gen;

	-- read files
	process(sys_clk)
		variable data_temp :integer;
		variable l : LINE;
	begin		
		if rising_edge(sys_clk) then
			if ddc_vld = '1' then
				readline(rec_r_i,l);
				read(l,data_temp);
				ddc_i <= conv_std_logic_vector(data_temp,16);
			end if;
		end if;
	end process;

	process(sys_clk)
		variable data_temp :integer;
		variable l : LINE;
	begin		
		if rising_edge(sys_clk) then
			if ddc_vld = '1' then
				readline(rec_r_q,l);
				read(l,data_temp);
				ddc_q <= conv_std_logic_vector(data_temp,16);
			end if;
		end if;
	end process;

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if cnt_div_4 = 128-1 then
				cnt_div_4 <= (others=>'0');
				ddc_vld <= '1';
			else
				cnt_div_4 <= cnt_div_4 + '1';
				ddc_vld <= '0';
			end if;
		end if;
	end process;

	u_dem_top: dem_top
	port map(
				sys_clk		=> 	sys_clk,
				aresetn 	=> 	aresetn,
				ddc_vld 	=> 	ddc_vld,
				ddc_i 		=> 	ddc_i,
				ddc_q		=> 	ddc_q,
				dem_vld 	=> 	dem_vld,
				dem_sym_i	=> 	dem_sym_i,
				dem_sym_q	=> 	dem_sym_q,
				dem_bit 	=> 	dem_bit
			);

	-- synthesis translate_off
	process(sys_clk)
		variable buf: LINE;
	begin
		if rising_edge(sys_clk) then
			if dem_vld = '1' then
				write(buf,conv_integer(dem_sym_i));
				writeline(rec_2,buf);
			end if;
		end if;
	end process;

	process(sys_clk)
		variable buf: LINE;
	begin
		if rising_edge(sys_clk) then
			if dem_vld = '1' then
				write(buf,conv_integer(dem_sym_q));
				writeline(rec_3,buf);
			end if;
		end if;
	end process;
	-- synthesis translate_on

end Behavioral;

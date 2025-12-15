----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 2025/11/28 16:12:04
-- Design Name: 
-- Module Name: tb_pll - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_SIGNED.ALL; 
use ieee.std_logic_textio.all;
use std.textio.all;  

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity tb_pll is
--  Port ( );
end tb_pll;

architecture Behavioral of tb_pll is

	component pll
	port(
			sys_clk		: in std_logic;
			aresetn 	: in std_logic;
			sym_type 	: in std_logic_vector(2 downto 0);
			en_sym		: in std_logic;
			sym_i		: in std_logic_vector(15 downto 0);
			sym_q		: in std_logic_vector(15 downto 0);
			sym_sync_en 	: out std_logic:='0';
			sym_sync_data_i	: out std_logic_vector(15 downto 0):=(others=>'0');
			sym_sync_data_q	: out std_logic_vector(15 downto 0):=(others=>'0')
		);
	end component;

	signal sys_clk					: std_logic := '0';
	signal aresetn 					: std_logic := '1';
	constant clock_period 			: time := 31.250 ns;
	signal cnt_div_4 				: std_logic_vector(31 downto 0):= (others=>'0'); 
	signal sym_vld 					: std_logic:='0';
	signal sym_vld_d 					: std_logic:='0';
	signal sym_i 					: std_logic_vector(15 downto 0):=(others=>'0');
	signal sym_q					: std_logic_vector(15 downto 0):=(others=>'0');
	signal dem_vld 					: std_logic:='0';
	signal dem_sym 					: std_logic_vector(7 downto 0):= (others=>'0');
	signal sym_sync_en 				: std_logic:='0';
	signal sym_sync_data_i			: std_logic_vector(15 downto 0):=(others=>'0');
	signal sym_sync_data_q			: std_logic_vector(15 downto 0):=(others=>'0');
	file rec_r_i: text open read_mode is "D:\projects\46_high_speed_dem\sim\modelsim\agc_i2.txt";
	file rec_r_q: text open read_mode is "D:\projects\46_high_speed_dem\sim\modelsim\agc_q2.txt";
	file rec_2: text open write_mode is "D:\projects\46_high_speed_dem\sim\modelsim\sync_sym_i.txt"; 
	file rec_3: text open write_mode is "D:\projects\46_high_speed_dem\sim\modelsim\sync_sym_q.txt"; 
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
			if sym_vld = '1' then
				readline(rec_r_i,l);
				read(l,data_temp);
				sym_i <= conv_std_logic_vector(data_temp,16);
			end if;
		end if;
	end process;

	process(sys_clk)
		variable data_temp :integer;
		variable l : LINE;
	begin		
		if rising_edge(sys_clk) then
			if sym_vld = '1' then
				readline(rec_r_q,l);
				read(l,data_temp);
				sym_q <= conv_std_logic_vector(data_temp,16);
			end if;
		end if;
	end process;

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			sym_vld_d <= sym_vld;
			if cnt_div_4 = 256-1 then
				cnt_div_4 <= (others=>'0');
				sym_vld <= '1';
			else
				cnt_div_4 <= cnt_div_4 + '1';
				sym_vld <= '0';
			end if;
		end if;
	end process;

	u_pll: pll
	port map(
			sys_clk			=> sys_clk,
			aresetn 		=> aresetn,
			sym_type 		=> "101",
			en_sym			=> sym_vld_d,
			sym_i			=> sym_i,
			sym_q			=> sym_q,
			sym_sync_en 	=> sym_sync_en,
			sym_sync_data_i	=> sym_sync_data_i,
			sym_sync_data_q	=> sym_sync_data_q
		);

	-- synthesis translate_off
	process(sys_clk)
		variable buf: LINE;
	begin
		if rising_edge(sys_clk) then
			if sym_sync_en = '1' then
				write(buf,conv_integer(sym_sync_data_i));
				writeline(rec_2,buf);
			end if;
		end if;
	end process;

	process(sys_clk)
		variable buf: LINE;
	begin
		if rising_edge(sys_clk) then
			if sym_sync_en = '1' then
				write(buf,conv_integer(sym_sync_data_q));
				writeline(rec_3,buf);
			end if;
		end if;
	end process;
	-- synthesis translate_on

end Behavioral;

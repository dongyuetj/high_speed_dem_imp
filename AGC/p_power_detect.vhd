----------------------------------------------------------------
-- Author: dong yue
-- Date: 2022/10/17
-- Email: y.dong@outlook.com
-- Description:
-- Version:
-----------------------------------------------------------------
library IEEE;                
use IEEE.STD_LOGIC_1164.ALL; 
use ieee.std_logic_arith.all;
use ieee.std_logic_signed.all;

library work;
use work.my_dem_pkg.all;

entity p_power_detect is
	generic(
			   moving_window_len : integer:=16;
			   N : integer := 8);
	port(

			sys_clk				: in std_logic; -- 28.8MHz
			aresetn 			: in std_logic;
			start_level  		: in std_logic_vector(31 downto 0);
			wave_in_valid 		: in std_logic;
			wave_in_i 			: in std_logic_array_16(0 to N-1);
			wave_in_q			: in std_logic_array_16(0 to N-1);
			power_valid	    	: out std_logic;
			power_out			: out std_logic_vector(31 downto 0)
		);
end p_power_detect;

architecture arch of p_power_detect is

	COMPONENT delay_ram
		PORT (
				 A : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
				 D : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
				 CLK : IN STD_LOGIC;
				 CE : IN STD_LOGIC;
				 Q : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
			 );
	END COMPONENT;

	--constant POWER_REF 			: std_logic_vector(31 downto 0):=x"0D693A40"; -- 15000^2
	constant POWER_REF 				: std_logic_vector(31 downto 0):=x"003D0900"; -- 2000^2
	--constant START_LEVEL			: std_logic_vector(31 downto 0):=x"00002710";
	signal wave_in_valid_d 			: std_logic_vector(6+moving_window_len downto 0):=(others=>'0');
	signal wave_i_sqr				: std_logic_array_32(0 to N-1):=(others=>(others=>'0'));
	signal wave_q_sqr				: std_logic_array_32(0 to N-1):=(others=>(others=>'0'));
	signal wave_i_sqr_avg			: std_logic_vector(31 downto 0):=(others=>'0');
	signal wave_q_sqr_avg			: std_logic_vector(31 downto 0):=(others=>'0');
	signal wave_i_sum0				: std_logic_array_33(0 to N/2-1):=(others=>(others=>'0'));
	signal wave_q_sum0				: std_logic_array_33(0 to N/2-1):=(others=>(others=>'0'));
	signal wave_i_sum1				: std_logic_array_34(0 to N/4-1):=(others=>(others=>'0'));
	signal wave_q_sum1				: std_logic_array_34(0 to N/4-1):=(others=>(others=>'0'));
	signal wave_i_sum2				: std_logic_array_35(0 to N/4-1):=(others=>(others=>'0'));
	signal wave_q_sum2				: std_logic_array_35(0 to N/4-1):=(others=>(others=>'0'));
	signal wave_i_sum				: std_logic_vector(35 downto 0):=(others=>'0');
	signal wave_q_sum				: std_logic_vector(35 downto 0):=(others=>'0');
	signal delay_len				: std_logic_vector(4 downto 0):=(others=>'0');
	signal power_in					: std_logic_vector(32 downto 0):=(others=>'0');
	signal power_in_t				: std_logic_vector(31 downto 0):=(others=>'0');
	signal power_in_d				: std_logic_vector(31 downto 0):=(others=>'0');
	signal power_in_previous		: std_logic_vector(31 downto 0):=(others=>'0');
	signal acc_sum					: std_logic_vector(31+LOG2(moving_window_len) downto 0):=(others=>'0');
	signal power_valid_t			: std_logic:='0';
	signal power_out_t				: std_logic_vector(31 downto 0):=(others=>'0');
	signal power_out_previous		: std_logic_vector(31 downto 0):=(others=>'0');
	signal power_calc_valid 		: std_logic:='0';
	signal power_calc 				: std_logic_vector(31 downto 0):=(others=>'0');
	signal cnt_wait					: std_logic_vector(11 downto 0):=(others=>'0');
	signal cnt_stay					: std_logic_vector(11 downto 0):=(others=>'0');
begin

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			wave_in_valid_d <= wave_in_valid_d(wave_in_valid_d'high-1 downto 0) & wave_in_valid;
			if wave_in_valid = '1' then
				for ii in 0 to N-1 loop
					wave_i_sqr(ii) <= wave_in_i(ii) * wave_in_i(ii);
					wave_q_sqr(ii) <= wave_in_q(ii) * wave_in_q(ii);
				end loop;
			end if;
			if wave_in_valid_d(0) = '1' then
				for ii in 0 to N/2-1 loop
					wave_i_sum0(ii) <= (wave_i_sqr(2*ii)(31) & wave_i_sqr(2*ii)) + (wave_i_sqr(2*ii+1)(31) & wave_i_sqr(2*ii+1));
					wave_q_sum0(ii) <= (wave_q_sqr(2*ii)(31) & wave_q_sqr(2*ii)) + (wave_q_sqr(2*ii+1)(31) & wave_q_sqr(2*ii+1));
				end loop;
			end if;
			if wave_in_valid_d(1) = '1' then
				for ii in 0 to N/4-1 loop
					wave_i_sum1(ii) <= (wave_i_sum0(2*ii)(32) & wave_i_sum0(2*ii)) + (wave_i_sum0(2*ii+1)(32) & wave_i_sum0(2*ii+1));
					wave_q_sum1(ii) <= (wave_q_sum0(2*ii)(32) & wave_q_sum0(2*ii)) + (wave_q_sum0(2*ii+1)(32) & wave_q_sum0(2*ii+1));
				end loop;
			end if;
			if wave_in_valid_d(2) = '1' then
				for ii in 0 to N/8-1 loop
					wave_i_sum2(ii) <= (wave_i_sum1(2*ii)(33) & wave_i_sum1(2*ii)) + (wave_i_sum1(2*ii+1)(33) & wave_i_sum1(2*ii+1));
					wave_q_sum2(ii) <= (wave_q_sum1(2*ii)(33) & wave_q_sum1(2*ii)) + (wave_q_sum1(2*ii+1)(33) & wave_q_sum1(2*ii+1));
				end loop;
			end if;
			if wave_in_valid_d(3) = '1' then
				wave_i_sum <= ((wave_i_sum2(0)(34) & wave_i_sum2(0))) + ((wave_i_sum2(1)(34) & wave_i_sum2(1)));
				wave_q_sum <= ((wave_q_sum2(0)(34) & wave_q_sum2(0))) + ((wave_q_sum2(1)(34) & wave_q_sum2(1)));
			end if;
			if wave_in_valid_d(4) = '1' then
				wave_i_sqr_avg <= wave_i_sum(35 downto 4);
				wave_q_sqr_avg <= wave_q_sum(35 downto 4);
			end if;
		end if;
	end process;

	-- delay one clk
	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if wave_in_valid_d(5) = '1' then
				power_in <= (wave_i_sqr_avg(wave_i_sqr_avg'high)&wave_i_sqr_avg) + (wave_q_sqr_avg(wave_q_sqr_avg'high)&wave_q_sqr_avg);
				if power_in(32 downto 31) = "00" or power_in(32 downto 31) = "11" then
					power_in_t	<= power_in(31 downto 0);
				elsif power_in(power_in'high) = '1' then
					power_in_t <= x"80000001";
				elsif power_in(power_in'high) = '0' then
					power_in_t <= x"7FFFFFFF";
				end if;
				power_in_d <= power_in_t;
			end if;
		end if;
	end process;

	delay_len <= conv_std_logic_vector(moving_window_len,delay_len'length);
	
	u_delay_ram: delay_ram
	port map(
				 A 		=> delay_len ,
				 D 		=> power_in_t,
				 CLK 	=> sys_clk,
				 CE 	=> wave_in_valid_d(6),
				 Q 		=> power_in_previous
			 );

	-- delay one clk
	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if wave_in_valid_d(6+moving_window_len) = '1' then
				acc_sum <= acc_sum + power_in_d - power_in_previous;
				power_calc_valid <= '1';
			else
				power_calc_valid <= '0';
			end if;
		end if;
	end process;

	power_calc <= (acc_sum(31+LOG2(moving_window_len) downto LOG2(moving_window_len))); 


	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if aresetn = '0' then
				power_valid_t <= '0';
			else
				if power_calc_valid = '1' then
					power_valid_t <= '1';
					power_out_t <= power_calc;
				else
					power_valid_t <= '0';
				end if;
			end if;
		end if;
	end process;

	power_valid 	<= power_valid_t;
	power_out	 	<= power_out_t;

end arch;

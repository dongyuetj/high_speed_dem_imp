----------------------------------------------------------------
-- Author: dong yue
-- Date: 2022/10/17
-- Email: y.dong@outlook.com
-- Description:
-- Version:
-----------------------------------------------------------------
library IEEE;                
use IEEE.STD_LOGIC_1164.ALL; 
use ieee.numeric_std.all;

library work;
use work.my_dem_pkg.all;

entity p_power_detect is
	generic(
			   moving_window_len : integer:=4;
			   N : integer := 16);
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


	--constant POWER_REF 			: std_logic_vector(31 downto 0):=x"0D693A40"; -- 15000^2
	constant POWER_REF 				: std_logic_vector(31 downto 0):=x"003D0900"; -- 2000^2
	signal delay_len				: std_logic_vector(4 downto 0):=(others=>'0');
	--constant START_LEVEL			: std_logic_vector(31 downto 0):=x"00002710";
	signal wave_in_valid_d 			: std_logic_vector(6 downto 0):=(others=>'0');
	signal wave_i_sqr				: signed_array_32(0 to N-1):=(others=>(others=>'0'));
	signal wave_q_sqr				: signed_array_32(0 to N-1):=(others=>(others=>'0'));
	signal wave_i_sqr_avg			: signed(31 downto 0):=(others=>'0');
	signal wave_q_sqr_avg			: signed(31 downto 0):=(others=>'0');
	signal wave_i_sum0				: signed_array_33(0 to N/2-1):=(others=>(others=>'0'));
	signal wave_q_sum0				: signed_array_33(0 to N/2-1):=(others=>(others=>'0'));
	signal wave_i_sum1				: signed_array_34(0 to N/4-1):=(others=>(others=>'0'));
	signal wave_q_sum1				: signed_array_34(0 to N/4-1):=(others=>(others=>'0'));
	signal wave_i_sum2				: signed_array_35(0 to N/4-1):=(others=>(others=>'0'));
	signal wave_q_sum2				: signed_array_35(0 to N/4-1):=(others=>(others=>'0'));
	signal wave_i_sum				: signed(35 downto 0):=(others=>'0');
	signal wave_q_sum				: signed(35 downto 0):=(others=>'0');
	signal power_in					: unsigned(32 downto 0):=(others=>'0');
	signal power_in_t				: unsigned(31 downto 0):=(others=>'0');
	signal power_in_d				: unsigned(31 downto 0):=(others=>'0');
	signal power_in_d0				: unsigned(31 downto 0):=(others=>'0');
	signal power_in_d1				: unsigned(31 downto 0):=(others=>'0');
	signal power_in_d2				: unsigned(31 downto 0):=(others=>'0');
	signal power_in_d3				: unsigned(31 downto 0):=(others=>'0');
	signal acc_sum					: unsigned(31+LOG2(moving_window_len) downto 0):=(others=>'0');
	signal power_valid_t			: std_logic:='0';
	signal power_out_t				: std_logic_vector(31 downto 0):=(others=>'0');
	signal power_calc_valid 		: std_logic:='0';
	signal power_calc 				: unsigned(31 downto 0):=(others=>'0');
begin

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			wave_in_valid_d <= wave_in_valid_d(wave_in_valid_d'high-1 downto 0) & wave_in_valid;
			if wave_in_valid = '1' then
				for ii in 0 to N-1 loop
					wave_i_sqr(ii) <= signed(wave_in_i(ii)) * signed(wave_in_i(ii));
					wave_q_sqr(ii) <= signed(wave_in_q(ii)) * signed(wave_in_q(ii));
				end loop;
			end if;
			if wave_in_valid_d(0) = '1' then
				for ii in 0 to N/2-1 loop
					wave_i_sum0(ii) <= resize(wave_i_sqr(2*ii),33) + resize(wave_i_sqr(2*ii+1),33);
					wave_q_sum0(ii) <= resize(wave_q_sqr(2*ii),33) + resize(wave_q_sqr(2*ii+1),33);
				end loop;
			end if;
			if wave_in_valid_d(1) = '1' then
				for ii in 0 to N/4-1 loop
					wave_i_sum1(ii) <= resize(wave_i_sum0(2*ii),34) + resize(wave_i_sum0(2*ii+1),34);
					wave_q_sum1(ii) <= resize(wave_q_sum0(2*ii),34) + resize(wave_q_sum0(2*ii+1),34);
				end loop;
			end if;
			if wave_in_valid_d(2) = '1' then
				for ii in 0 to N/8-1 loop
					wave_i_sum2(ii) <= resize(wave_i_sum1(2*ii),35) + resize(wave_i_sum1(2*ii+1),35);
					wave_q_sum2(ii) <= resize(wave_q_sum1(2*ii),35) + resize(wave_q_sum1(2*ii+1),35);
				end loop;
			end if;
			if wave_in_valid_d(3) = '1' then
				wave_i_sum <= resize(wave_i_sum2(0),36) + resize(wave_i_sum2(1),36);
				wave_q_sum <= resize(wave_q_sum2(0),36) + resize(wave_q_sum2(1),36);
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
				power_in <= unsigned(resize(wave_i_sqr_avg,33)) + unsigned(resize(wave_q_sqr_avg,33));
				if power_in(32) = '1' then
					power_in_t <= (others=>'1');
				else
					power_in_t <= power_in(31 downto 0);
				end if;
				power_in_d <= power_in_t;
			end if;
		end if;
	end process;

	-- delay one clk
	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if aresetn = '0' then
				acc_sum <= (others=>'0');
				power_in_d0 <= (others=>'0');
				power_in_d1 <= (others=>'0');
				power_in_d2 <= (others=>'0');
				power_in_d3 <= (others=>'0');
			elsif wave_in_valid_d(6) = '1' then
				power_in_d0 <= power_in_d ;
				power_in_d1 <= power_in_d0 ;
				power_in_d2 <= power_in_d1 ;
				power_in_d3 <= power_in_d2 ;
				acc_sum <= acc_sum + power_in_d - power_in_d3;
				power_calc_valid <= '1';
			else
				power_calc_valid <= '0';
			end if;
		end if;
	end process;

	power_calc <= acc_sum(31+LOG2(moving_window_len) downto LOG2(moving_window_len)); 

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if aresetn = '0' then
				power_valid_t <= '0';
			else
				if power_calc_valid = '1' then
					power_valid_t <= '1';
					power_out_t <= std_logic_vector(power_calc);
				else
					power_valid_t <= '0';
				end if;
			end if;
		end if;
	end process;

	power_valid 	<= power_valid_t;
	power_out	 	<= power_out_t;

end arch;

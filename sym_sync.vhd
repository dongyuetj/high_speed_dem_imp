----------------------------------------------------------------
-- Author: dong yue
-- Date: 2022/10/17
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

entity sym_sync is
	port(
			sys_clk		: in std_logic; -- 28.8MHz
			aresetn 	: in std_logic;
			samp_vld	: in std_logic;
			samp_i		: in std_logic_vector(23 downto 0);
			samp_q		: in std_logic_vector(23 downto 0);
			sym_en		: out std_logic:='0';
			sym_i		: out std_logic_vector(23 downto 0):=(others=>'0');
			sym_q		: out std_logic_vector(23 downto 0):=(others=>'0')
		);
end sym_sync;

architecture arch of sym_sync is
	signal sqr_i 				: signed(47 downto 0):=(others=>'0');
	signal sqr_q 				: signed(47 downto 0):=(others=>'0');
	signal sqr_sum 				: signed(47 downto 0):=(others=>'0');
	signal cnt16 				: unsigned(9 downto 0):=(others=>'0'); -- sps * 8
	signal acc_sum_i, acc_sum_q : signed(48+LOG2(8)-1 downto 0):=(others=>'0');
	signal keep_stay 			: std_logic:='0';
	signal shift_left_2 		: std_logic:='0';
	signal shift_left_1 		: std_logic:='0';
	signal shift_right_1 		: std_logic:='0';
	attribute mark_debug : string;
	attribute mark_debug of cnt16 			   		: signal is "TRUE";
	attribute mark_debug of acc_sum_i, acc_sum_q	: signal is "TRUE";
	attribute mark_debug of keep_stay 				: signal is "TRUE";
	attribute mark_debug of shift_left_2 			: signal is "TRUE";
	attribute mark_debug of shift_left_1 			: signal is "TRUE";
	attribute mark_debug of shift_right_1 			: signal is "TRUE";
begin                                  

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if samp_vld = '1' then -- 0
				sqr_i <= signed(samp_i) * signed(samp_i);
				sqr_q <= signed(samp_q) * signed(samp_q);
			end if;
			if samp_vld = '1' then -- 1
				sqr_sum <= sqr_i + sqr_q;
			end if;
			if samp_vld = '1' then -- 2
				if cnt16(cnt16'high downto 2) = 0 then
					case cnt16(1 downto 0) is
						when "00" => 
							acc_sum_i <= 0 + abs(resize(sqr_sum,acc_sum_i'length));
						when "01" => 
							acc_sum_q <= 0 + abs(resize(sqr_sum,acc_sum_q'length));
						when "10" => 
							acc_sum_i <= acc_sum_i - abs(resize(sqr_sum,acc_sum_i'length));
						when "11" => 
							acc_sum_q <= acc_sum_q - abs(resize(sqr_sum,acc_sum_q'length));
						when others => null;
					end case;
				else
					case cnt16(1 downto 0) is
						when "00" => 
							acc_sum_i <= acc_sum_i + abs(sqr_sum);
						when "01" => 
							acc_sum_q <= acc_sum_q + abs(sqr_sum);
						when "10" => 
							acc_sum_i <= acc_sum_i - abs(sqr_sum);
						when "11" => 
							acc_sum_q <= acc_sum_q - abs(sqr_sum);
						when others => null;
					end case;
				end if;
			end if;
			if samp_vld = '1' then
				if cnt16 = 0 then
					if abs(acc_sum_q) > abs(acc_sum_i&'0') then
						if acc_sum_q(acc_sum_q'high) = '0' then
							keep_stay <= '0';
							shift_left_2 <= '0';
							shift_left_1 <= '0';
							shift_right_1 <= '1';
						else
							keep_stay <= '0';
							shift_left_2 <= '0';
							shift_left_1 <= '1';
							shift_right_1 <= '0';
						end if;
					else
						if acc_sum_i(acc_sum_i'high) = '0' then
							keep_stay <= '1';
							shift_left_2 <= '0';
							shift_left_1 <= '0';
							shift_right_1 <= '0';
						else
							keep_stay <= '0';
							shift_left_2 <= '1';
							shift_left_1 <= '0';
							shift_right_1 <= '0';
						end if;
					end if;
				end if;
			end if;
			if samp_vld = '1' then
			--	if cnt16 = 0 then
			--		if keep_stay = '1' then
			--			cnt16(1 downto 0) <= cnt16(1 downto 0) + 0;
			--		elsif shift_left_2 = '1' then
			--			cnt16(1 downto 0) <= cnt16(1 downto 0) + 2;
			--		elsif shift_right_1 = '1' then
			--			cnt16(1 downto 0) <= cnt16(1 downto 0) + 3;
			--		elsif shift_left_1 = '1' then
			--			cnt16(1 downto 0) <= cnt16(1 downto 0) + 1;
			--		end if;
			--	else
					cnt16 <= cnt16 + 1;
			--	end if;
			end if;
			if samp_vld = '1' then
				if keep_stay = '1' then
					if cnt16(1 downto 0) = "10" then
						sym_en <= '1';
						sym_i <= samp_i;
						sym_q <= samp_q;
					else
						sym_en <= '0';
					end if;
				elsif shift_left_2 = '1' then
					if cnt16(1 downto 0) = "00" then
						sym_en <= '1';
						sym_i <= samp_i;
						sym_q <= samp_q;
					else
						sym_en <= '0';
					end if;

				elsif shift_left_1 = '1' then
					if cnt16(1 downto 0) = "01" then
						sym_en <= '1';
						sym_i <= samp_i;
						sym_q <= samp_q;
					else
						sym_en <= '0';
					end if;
				elsif shift_right_1 = '1' then
					if cnt16(1 downto 0) = "11" then
						sym_en <= '1';
						sym_i <= samp_i;
						sym_q <= samp_q;
					else
						sym_en <= '0';
					end if;
				end if;
			else
				sym_en <= '0';
			end if;
		end if;
	end process; 

end arch;

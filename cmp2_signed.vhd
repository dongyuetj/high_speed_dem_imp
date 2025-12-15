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

library work;
use work.my_dem_pkg.all;

entity cmp2_signed is
	generic(
			   data_width : integer := 32;
			   data_num   : integer := 16
		   );
	port(
			sys_clk			: in std_logic; -- 28.8MHz
			en				: in std_logic;
			data_in0		: in signed(data_width-1 downto 0);
			ind0			: in std_logic_vector(LOG2(data_num)-1 downto 0);
			data_in1		: in signed(data_width-1 downto 0);
			ind1			: in std_logic_vector(LOG2(data_num)-1 downto 0);
			min_data		: out signed(data_width-1 downto 0):=(others=>'0');
			min_ind			: out std_logic_vector(LOG2(data_num)-1 downto 0):=(others=>'0')
		);
end cmp2_signed;
architecture arch of cmp2_signed is

begin

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if en = '1' then
				if data_in0 < data_in1 then
					min_data <= data_in0;
					min_ind <= ind0;
				else
					min_data <= data_in1;
					min_ind <= ind1;
				end if;
			end if;
		end if;
	end process;

end arch;

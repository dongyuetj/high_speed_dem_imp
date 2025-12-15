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

entity cmp4 is
	generic(
			   data_width : integer := 32;
			   data_num   : integer := 4
		   );
	port(
			sys_clk			: in std_logic; -- 28.8MHz
			en				: in std_logic;
			data_in			: in std_logic_array_32(data_num-1 downto 0);
			max_data		: out std_logic_vector(data_width-1 downto 0):=(others=>'0');
			max_ind			: out std_logic_vector(LOG2(data_num)-1 downto 0):=(others=>'0')
		);
end cmp4;
architecture arch of cmp4 is

	component cmp2
	generic(
			   data_width : integer := 32;
			   data_num   : integer := 4
		   );
	port(
			sys_clk			: in std_logic; -- 28.8MHz
			en				: in std_logic;
			data_in0		: in std_logic_vector(data_width-1 downto 0);
			ind0			: in std_logic_vector(LOG2(data_num)-1 downto 0);
			data_in1		: in std_logic_vector(data_width-1 downto 0);
			ind1			: in std_logic_vector(LOG2(data_num)-1 downto 0);
			max_data		: out std_logic_vector(data_width-1 downto 0);
			max_ind			: out std_logic_vector(LOG2(data_num)-1 downto 0)
		);
	end component;

	signal max_data_tmp  : std_logic_array_32(1 downto 0):=(others=>(others=>'0'));
	signal max_ind_tmp  : std_logic_array_2(1 downto 0):=(others=>(others=>'0'));

begin

	u_cmp20: cmp2
	generic map( data_width => 32, data_num => 4)
	port map(
				sys_clk		=> sys_clk,
				en			=> en,
				data_in0	=> data_in(0),
				ind0		=> "00",
				data_in1	=> data_in(1),
				ind1		=> "01",
				max_data	=> max_data_tmp(0),
				max_ind		=> max_ind_tmp(0)
			);

	u_cmp21: cmp2
	generic map( data_width => 32, data_num => 4)
	port map(
				sys_clk		=> sys_clk,
				en			=> en,
				data_in0	=> data_in(2), 
				ind0		=> "10",       
				data_in1	=> data_in(3), 
				ind1		=> "11",    
				max_data	=> max_data_tmp(1),
				max_ind		=> max_ind_tmp(1)  
			);

	u_cmp: cmp2
	generic map( data_width => 32, data_num => 4)
	port map(
				sys_clk		=> sys_clk,
				en			=> en,
				data_in0	=> max_data_tmp(0), 
				ind0		=> max_ind_tmp(0),       
				data_in1	=> max_data_tmp(1), 
				ind1		=> max_ind_tmp(1),        
				max_data	=> max_data,
				max_ind		=> max_ind
			);
end arch;

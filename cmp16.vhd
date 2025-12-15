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

entity cmp16 is
	generic(
			   data_width : integer := 32;
			   data_num   : integer := 16
		   );
	port(
			sys_clk		: in std_logic; -- 28.8MHz
			en			: in std_logic;
			data_in		: in signed_array_32(data_num-1 downto 0);
			min_data		: out signed(data_width-1 downto 0);
			min_ind			: out std_logic_vector(3 downto 0)
		);
end cmp16;
architecture arch of cmp16 is

	component cmp2_signed
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
	end component;

	signal min_data0 : signed_array_32(15 downto 0):=(others=>(others=>'0'));
	signal min_ind0 : std_logic_array_4(15 downto 0):=(others=>(others=>'0'));

	signal min_data1 : signed_array_32(7 downto 0):=(others=>(others=>'0'));
	signal min_ind1 : std_logic_array_4(7 downto 0):=(others=>(others=>'0'));

	signal min_data2 : signed_array_32(3 downto 0):=(others=>(others=>'0'));
	signal min_ind2 : std_logic_array_4(3 downto 0):=(others=>(others=>'0'));

	signal min_data3 : signed_array_32(1 downto 0):=(others=>(others=>'0'));
	signal min_ind3 : std_logic_array_4(1 downto 0):=(others=>(others=>'0'));

begin

	gen16to8: for ii in 0 to 7 generate
		u_cmp2: cmp2_signed
		generic map(
					   data_width => 32,
					   data_num   => 16
				   )
		port map(
					sys_clk		=> sys_clk,
					en			=> en,
					data_in0	=> data_in(2*ii),  
					ind0		=> cInd(2*ii),      
					data_in1	=> data_in(2*ii+1),
					ind1		=> cInd(2*ii+1),    
					min_data	=> min_data1(ii),
					min_ind		=> min_ind1(ii)
				);
	end generate gen16to8;

	gen8to4: for ii in 0 to 3 generate
		u_cmp2: cmp2_signed
		port map(
					sys_clk		=> sys_clk,
					en			=> en,
					data_in0	=> min_data1(2*ii),
					ind0		=> min_ind1(2*ii),
					data_in1	=> min_data1(2*ii+1),
					ind1		=> min_ind1(2*ii+1),
					min_data	=> min_data2(ii),
					min_ind		=> min_ind2(ii)
				);
	end generate gen8to4;

	gen4to2: for ii in 0 to 1 generate
		u_cmp2: cmp2_signed
		port map(
					sys_clk		=> sys_clk,
					en			=> en,
					data_in0	=> min_data2(2*ii),
					ind0		=> min_ind2(2*ii),
					data_in1	=> min_data2(2*ii+1),
					ind1		=> min_ind2(2*ii+1),
					min_data	=> min_data3(ii),
					min_ind		=> min_ind3(ii)
				);
	end generate gen4to2;

	u_cmp2: cmp2_signed
	port map(
				sys_clk		=> sys_clk,
				en			=> en,
				data_in0	=> min_data3(0),
				ind0		=> min_ind3(0),
				data_in1	=> min_data3(1),
				ind1		=> min_ind3(1),
				min_data	=> min_data,
				min_ind		=> min_ind
			);

end arch;

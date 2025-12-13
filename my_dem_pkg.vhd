----------------------------------------------------------------
-- Author: dong yue
-- Date: 2022/10/18
-- Email: y.dong@outlook.com
-- Description:
-- Version:
-----------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.all; 
use IEEE.NUMERIC_STD.ALL;

package my_dem_pkg is
    type std_logic_array_1 is array (natural range<>) of std_logic_vector(0 downto 0);
    type std_logic_array_2 is array (natural range<>) of std_logic_vector(1 downto 0);
    type std_logic_array_4 is array (natural range<>) of std_logic_vector(3 downto 0);
    type std_logic_array_5 is array (natural range<>) of std_logic_vector(4 downto 0);
    type std_logic_array_6 is array (natural range<>) of std_logic_vector(5 downto 0);
    type std_logic_array_7 is array (natural range<>) of std_logic_vector(6 downto 0);
    type std_logic_array_8 is array (natural range<>) of std_logic_vector(7 downto 0);
    type std_logic_array_9 is array (natural range<>) of std_logic_vector(8 downto 0);
    type std_logic_array_10 is array (natural range<>) of std_logic_vector(9 downto 0);
    type std_logic_array_13 is array (natural range<>) of std_logic_vector(12 downto 0);
    type std_logic_array_16 is array (natural range<>) of std_logic_vector(15 downto 0);
    type std_logic_array_20 is array (natural range<>) of std_logic_vector(19 downto 0);
    type std_logic_array_21 is array (natural range<>) of std_logic_vector(20 downto 0);
    type std_logic_array_22 is array (natural range<>) of std_logic_vector(21 downto 0);
    type std_logic_array_23 is array (natural range<>) of std_logic_vector(22 downto 0);
    type std_logic_array_24 is array (natural range<>) of std_logic_vector(23 downto 0);
    type std_logic_array_28 is array (natural range<>) of std_logic_vector(27 downto 0);
    type std_logic_array_32 is array (natural range<>) of std_logic_vector(31 downto 0);
    type std_logic_array_40 is array (natural range<>) of std_logic_vector(39 downto 0);
    type std_logic_array_47 is array (natural range<>) of std_logic_vector(46 downto 0);
    type std_logic_array_44 is array (natural range<>) of std_logic_vector(43 downto 0);
    type std_logic_array_48 is array (natural range<>) of std_logic_vector(47 downto 0);
    type std_logic_array_49 is array (natural range<>) of std_logic_vector(48 downto 0);
    type std_logic_array_64 is array (natural range<>) of std_logic_vector(63 downto 0);
	constant sps	 						: integer := 4; 
	constant data_width 					: integer := 16; 
	constant PI_POS 						: signed(15+4 downto 0):="00000110010010001000";
	constant PI_NEG 						: signed(15+4 downto 0):="11111001101101111000";
	constant PI_1_4_POS 					: signed(15+4 downto 0):="00000001100100100010";
	constant PI_1_4_NEG 					: signed(15+4 downto 0):="11111110011011011110";
	constant PI_3_4_POS 					: signed(15+4 downto 0):="00000100101101100110";
	constant PI_3_4_NEG 					: signed(15+4 downto 0):="11111011010010011010";
	constant snr_data_width					: integer:=8;
	function LOG2 (x : in integer) return integer;
end my_dem_pkg;

package body my_dem_pkg is
	function LOG2 (x : in integer) return integer is
		variable i : integer;
	begin
		i := 0;  
		while (2**i < x) loop
			i := i + 1;
		end loop;
		return i;
	end LOG2;
end my_dem_pkg;

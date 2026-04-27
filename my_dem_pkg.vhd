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
    type std_logic_array_18 is array (natural range<>) of std_logic_vector(17 downto 0);
    type std_logic_array_20 is array (natural range<>) of std_logic_vector(19 downto 0);
    type std_logic_array_21 is array (natural range<>) of std_logic_vector(20 downto 0);
    type std_logic_array_22 is array (natural range<>) of std_logic_vector(21 downto 0);
    type std_logic_array_23 is array (natural range<>) of std_logic_vector(22 downto 0);
    type std_logic_array_24 is array (natural range<>) of std_logic_vector(23 downto 0);
    type std_logic_array_25 is array (natural range<>) of std_logic_vector(24 downto 0);
    type std_logic_array_28 is array (natural range<>) of std_logic_vector(27 downto 0);
    type std_logic_array_32 is array (natural range<>) of std_logic_vector(31 downto 0);
    type std_logic_array_33 is array (natural range<>) of std_logic_vector(32 downto 0);
    type std_logic_array_34 is array (natural range<>) of std_logic_vector(33 downto 0);
    type std_logic_array_36 is array (natural range<>) of std_logic_vector(35 downto 0);
    type std_logic_array_40 is array (natural range<>) of std_logic_vector(39 downto 0);
    type std_logic_array_47 is array (natural range<>) of std_logic_vector(46 downto 0);
    type std_logic_array_44 is array (natural range<>) of std_logic_vector(43 downto 0);
    type std_logic_array_48 is array (natural range<>) of std_logic_vector(47 downto 0);
    type std_logic_array_49 is array (natural range<>) of std_logic_vector(48 downto 0);
    type std_logic_array_64 is array (natural range<>) of std_logic_vector(63 downto 0);
	constant sps	 						: integer := 4; 
	constant data_width 					: integer := 16; 
--	constant PI_POS 						: signed(15+4 downto 0):="00000110010010001000";
--	constant PI_NEG 						: signed(15+4 downto 0):="11111001101101111000";
--	constant PI_1_4_POS 					: signed(15+4 downto 0):="00000001100100100010";
--	constant PI_1_4_NEG 					: signed(15+4 downto 0):="11111110011011011110";
--	constant PI_3_4_POS 					: signed(15+4 downto 0):="00000100101101100110";
--	constant PI_3_4_NEG 					: signed(15+4 downto 0):="11111011010010011010";
	-- pi * 2^13
	constant PI_POS_UNWRAP 						: signed(19 downto 0):=to_signed(25736,20);
	constant PI_NEG_UNWRAP 						: signed(19 downto 0):=to_signed(-25736,20);

	constant PI_POS 						: signed(15 downto 0):=to_signed(25736,16);
	constant PI_NEG 						: signed(15 downto 0):=to_signed(-25736,16);
	constant PI_1_4_POS 					: signed(15 downto 0):=to_signed(6434,16);
	constant PI_1_4_NEG 					: signed(15 downto 0):=to_signed(-6434,16);
	constant PI_3_4_POS 					: signed(15 downto 0):=to_signed(19302,16);
	constant PI_3_4_NEG 					: signed(15 downto 0):=to_signed(-19302,16);
	constant PI_1_2_POS 					: signed(15 downto 0):=to_signed(12868,16);
	constant PI_1_2_NEG 					: signed(15 downto 0):=to_signed(-12868,16);

    type signed_array_13 is array (natural range<>) of signed(12 downto 0);
    type signed_array_14 is array (natural range<>) of signed(13 downto 0);
    type signed_array_15 is array (natural range<>) of signed(14 downto 0);
    type signed_array_16 is array (natural range<>) of signed(15 downto 0);
    type signed_array_17 is array (natural range<>) of signed(16 downto 0);
    type signed_array_18 is array (natural range<>) of signed(17 downto 0);
    type signed_array_19 is array (natural range<>) of signed(18 downto 0);
    type signed_array_20 is array (natural range<>) of signed(19 downto 0);
    type signed_array_23 is array (natural range<>) of signed(22 downto 0);
    type signed_array_24 is array (natural range<>) of signed(23 downto 0);
    type signed_array_25 is array (natural range<>) of signed(24 downto 0);
    type signed_array_26 is array (natural range<>) of signed(25 downto 0);
    type signed_array_27 is array (natural range<>) of signed(26 downto 0);
    type signed_array_28 is array (natural range<>) of signed(27 downto 0);
    type signed_array_32 is array (natural range<>) of signed(31 downto 0);
    type signed_array_33 is array (natural range<>) of signed(32 downto 0);
    type signed_array_36 is array (natural range<>) of signed(35 downto 0);
    type signed_array_39 is array (natural range<>) of signed(38 downto 0);

    type unsigned_array_16 is array (natural range<>) of unsigned(15 downto 0);
    type unsigned_array_17 is array (natural range<>) of unsigned(16 downto 0);
    type unsigned_array_18 is array (natural range<>) of unsigned(17 downto 0);

	
	constant PSK8_LUT_I						: signed_array_16(0 to 7):= (to_signed(2000,16),to_signed(1414,16),to_signed(-1414,16),to_signed(0,16),to_signed(1414,16),to_signed(0,16),to_signed(-2000,16),to_signed(-1414,16));
	constant PSK8_LUT_Q						: signed_array_16(0 to 7):= (to_signed(0,16),to_signed(1414,16),to_signed(1414,16),to_signed(2000,16),to_signed(-1414,16),to_signed(-2000,16),to_signed(0,16),to_signed(-1414,16));

	-- -12541,-12541,-4180,-4180,12541,12541,4180,4180
	constant QAM8_LUT_I						: signed_array_16(0 to 7):= ( to_signed(-12541,16), to_signed(-12641,16), to_signed(-4180,16), to_signed(-4180,16), to_signed(12541,16), to_signed(12541,16), to_signed(4180,16), to_signed(4180,16)); 
	-- 4180,-4180,4180,-4180,4180,-4180,4180,-4180
	constant QAM8_LUT_Q						: signed_array_16(0 to 7):= ( to_signed(4180,16), to_signed(-4180,16), to_signed(4180,16), to_signed(-4180,16), to_signed(4180,16), to_signed(-4180,16), to_signed(4180,16), to_signed(-4180,16));

	-- -9715,-9715,-9715,-9715,-3238,-3238,-3238,-3238,9715,9715,9715,9715,3238,3238,3238,3238,
	constant QAM16_LUT_I					: signed_array_16(0 to 15):= ( to_signed(-9715,16), to_signed(-9715,16), to_signed(-9715,16), to_signed(-9715,16), to_signed(-3238,16), to_signed(-3238,16), to_signed(-3238,16), to_signed(-3238,16), to_signed(+9715,16), to_signed(+9715,16), to_signed(+9715,16), to_signed(+9715,16), to_signed(+3238,16), to_signed(+3238,16), to_signed(+3238,16), to_signed(+3238,16));
	--9715,3238,-9715,-3238,9715,3238,-9715,-3238,9715,3238,-9715,-3238,9715,3238,-9715,-3238
	constant QAM16_LUT_Q					: signed_array_16(0 to 15):= ( to_signed(+9715,16), to_signed(+3238,16), to_signed(-9715,16), to_signed(-3238,16), to_signed(+9715,16), to_signed(+3238,16), to_signed(-9715,16), to_signed(-3238,16), to_signed(+9715,16), to_signed(+3238,16), to_signed(-9715,16), to_signed(-3238,16), to_signed(+9715,16), to_signed(+3238,16), to_signed(-9715,16), to_signed(-3238,16));

	-- psk8 phase [0,0.7854,2.3562,1.5708,-0.7854,-1.5708,3.1416,-2.3562]
	constant PSK8_PHASE 					: signed_array_16(0 to 7):=( to_signed(0,16), to_signed(6434,16), to_signed(19302,16), to_signed(12868,16), to_signed(-6434,16), to_signed(-12868,16), to_signed(25736,16), to_signed(-19302,16));
	-- qam8 phase [2.8198,-2.8198,2.3562,-2.3562,0.3218,-0.3218,0.7854,-0.7854]
	constant QAM8_PHASE 					: signed_array_16(0 to 7):=( to_signed(23100,16), to_signed(-23100,16), to_signed(19302,16), to_signed(-19302,16), to_signed(2636,16), to_signed(-2636,16), to_signed(6434,16), to_signed(-6434,16));
	-- qam16 phase [2.3562, 2.8198 ,-2.3562 ,-2.8198 , 1.8925 , 2.3562 ,-1.8925 ,-2.3562 , 0.7854 , 0.3218 ,-0.7854 ,-0.3218 , 1.2490 , 0.7854 ,-1.2490 ,-0.7854]
	constant QAM16_PHASE					: signed_array_16(0 to 15):=( to_signed(19302,16), to_signed(23100,16), to_signed(-19302,16), to_signed(-23100,16), to_signed(15503,16), to_signed(19302,16), to_signed(-15503,16), to_signed(-19302,16), to_signed(6434,16), to_signed(2636,16), to_signed(-6434,16), to_signed(-2636,16), to_signed(10232,16), to_signed(6434,16), to_signed(-10232,16), to_signed(-6434,16));

	constant cInd: std_logic_array_4(0 to 15):=	(x"0" ,x"1" ,x"2" ,x"3" ,x"4" ,x"5" ,x"6" ,x"7" ,x"8" ,x"9" ,x"A" ,x"B" ,x"C" ,x"D" ,x"E" ,x"F");


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

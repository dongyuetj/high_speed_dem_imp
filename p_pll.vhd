----------------------------------------------------------------
-- Entity: p_pll
-- Author: Dong Yue
-- Date: 2026-04-11 16:30:46
----------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library work;
use work.my_dem_pkg.all;

entity p_pll is
	generic(N:integer:=16);
    Port (
        sys_clk 	 : in  std_logic;
        rst_n   	 : in  std_logic;
		symb_en 	 : in std_logic;
		symb_i  	 : in std_logic_array_8(0 to N-1):=(others=>(others=>'0'));
		symb_q  	 : in std_logic_array_8(0 to N-1):=(others=>(others=>'0'));
		sync_symb_en : out std_logic:='0';
		sync_symb_i  : out std_logic_array_8(0 to N-1):=(others=>(others=>'0'));
		sync_symb_q  : out std_logic_array_8(0 to N-1):=(others=>(others=>'0'));
		loop_out_vld : out std_logic:='0';
		loop_dout	 : out std_logic_vector(31 downto 0):=(others=>'0')
    );
end p_pll;

architecture rtl of p_pll is

	COMPONENT COS_SIN_LUT
		PORT (
				 clka : IN STD_LOGIC;
				 addra : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
				 douta : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
				 clkb : IN STD_LOGIC;
				 addrb : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
				 doutb : OUT STD_LOGIC_VECTOR(31 DOWNTO 0) 
			 );
	END COMPONENT;

	COMPONENT ATAN_LUT
		PORT (
				 clka : IN STD_LOGIC;
				 addra : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
				 douta : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
				 clkb : IN STD_LOGIC;
				 addrb : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
				 doutb : OUT STD_LOGIC_VECTOR(15 DOWNTO 0) 
			 );
	END COMPONENT;

	-- Q0.16
	constant PI_Q3P28				: signed(31 downto 0):=to_signed(843314857,32); -- round(pi * 2^26)
	constant DOUBLE_PI_Q3P28		: signed(31 downto 0):=to_signed(2*843314857,32);

	signal pll_vld_d 				: std_logic_vector(13 downto 0):=(others=>'0');
	signal douta    				: std_logic_array_32(0 to N-1):=(others=>(others=>'0'));
	signal cos_lut,sin_lut			: signed_array_16(0 to N-1):=(others=>(others=>'0'));
	signal iq_sign					: std_logic_array_2(0 to N-1):=(others=>(others=>'0'));
	signal iq_sign_reg				: std_logic_array_2(0 to N-1):=(others=>(others=>'0'));
	signal P1,P2,P3,P4				: signed_array_24(0 to N-1):=(others=>(others=>'0'));
	signal phase_detection_real		: signed_array_25(0 to N-1):=(others=>(others=>'0'));
	signal phase_detection_imag 	: signed_array_25(0 to N-1):=(others=>(others=>'0'));	
	signal min_num					: signed_array_25(0 to N-1):=(others=>(others=>'0'));
	signal max_denom 				: signed_array_25(0 to N-1):=(others=>(others=>'0'));	
	signal min_num_int				: signed_array_11(0 to N-1):=(others=>(others=>'0'));
	signal max_denom_int 			: signed_array_11(0 to N-1):=(others=>(others=>'0'));	
	signal shift_left				: std_logic_array_3(0 to N-1):=(others=>(others=>'0'));	
	signal ratio_int				: signed_array_18(0 to N-1):=(others=>(others=>'0'));
	signal lower_pos				: std_logic_vector(0 to N-1):=(others=>'0');
	signal phase_in					: signed_array_16(0 to N-1):=(others=>(others=>'0'));	
	signal addr_atan				: std_logic_array_10(0 to N-1):=(others=>(others=>'0'));
	signal dout_atan				: std_logic_array_16(0 to N-1):=(others=>(others=>'0'));
	signal phase_diff 				: signed_array_18(0 to N-1):=(others=>(others=>'0'));
	signal err_add0					: signed(20 downto 0):=(others=>'0');
	signal err_add1					: signed(20 downto 0):=(others=>'0');
	signal err_total		 		: signed(21 downto 0):=(others=>'0');
	signal vp		 				: signed(31 downto 0):=(others=>'0');
	signal vi 						: signed(31 downto 0):=(others=>'0');
	signal v 						: signed(31 downto 0):=(others=>'0');
	signal v_vec 					: signed_array_32(0 to N-1):=(others=>(others=>'0'));
	signal phase_int 				: signed(31 downto 0):=(others=>'0');
	signal phase_int_v	 			: signed_array_32(0 to N-1):=(others=>(others=>'0'));
	signal phase_int_v_wrap	 		: signed_array_32(0 to N-1):=(others=>(others=>'0'));
	signal phase_int_v_wrap_fix	 	: std_logic_array_16(0 to N-1):=(others=>(others=>'0'));
	attribute MARK_DEBUG : string;
	attribute MARK_DEBUG of phase_int : signal is "TRUE";
begin

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if rst_n = '0' then
				pll_vld_d <= (others=>'0');
			else
				pll_vld_d <= pll_vld_d(pll_vld_d'high-1 downto 0)& symb_en;
			end if;
		end if;
	end process;

	-- (Q7.0 + 1j * Q7.0) * (Q1.14 + 1j *Q1.14) = Q8.14 + Q8.14 = Q9.14
	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if symb_en = '1' then
				for ii in 0 to N-1 loop
					P1(ii) <= signed(symb_i(ii)) * cos_lut(ii);
					P2(ii) <= signed(symb_q(ii)) * sin_lut(ii); 
					P3(ii) <= signed(symb_i(ii)) * (-sin_lut(ii));
					P4(ii) <= signed(symb_q(ii)) * cos_lut(ii);
				end loop;
			end if;
			if pll_vld_d(0) = '1' then
				for ii in 0 to N-1 loop
					phase_detection_real(ii) <=	resize(P1(ii),25) + resize(P2(ii),25) ;
					phase_detection_imag(ii) <=	resize(P3(ii),25) + resize(P4(ii),25) ;
				end loop;
			end if;
		end if;
	end process;
	
	gen: for ii in 0 to N-1 generate
		-- Q2.13
		phase_int_v_wrap_fix(ii) <= std_logic_vector(phase_int_v_wrap(ii)(31)&phase_int_v_wrap(ii)(29 downto 15));
		iq_sign(ii) <= std_logic_vector(phase_detection_imag(ii)(24 downto 24)) & std_logic_vector(phase_detection_real(ii)(24 downto 24));
		cos_lut(ii) <= signed(douta(ii)(15 downto 0));
		sin_lut(ii) <= signed(douta(ii)(31 downto 16));
		min_num_int(ii) <= min_num(ii)(24 downto 14);
		max_denom_int(ii) <= max_denom(ii)(24 downto 14);
	end generate gen;

	-- Q2.7
	gen_nco: for ii in 0 to N/2-1 generate
		u_lut: COS_SIN_LUT
		PORT map(
					clka => sys_clk,
					addra => phase_int_v_wrap_fix(2*ii)(15 downto 6),
					douta => douta(2*ii),
					clkb => sys_clk,
					addrb => phase_int_v_wrap_fix(2*ii+1)(15 downto 6),
					doutb => douta(2*ii+1)
				);

		u_atan: ATAN_LUT
		PORT map(
					clka  => sys_clk,
					addra => addr_atan(2*ii),
					douta => dout_atan(2*ii),
					clkb  => sys_clk,
					addrb => addr_atan(2*ii+1),
					doutb => dout_atan(2*ii+1)
				);

	end generate gen_nco;

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			sync_symb_en <= pll_vld_d(1) ;
			if pll_vld_d(1) = '1' then
				for ii in 0 to N-1 loop
					-- Q9.14 tuncated to Q7.0
					if phase_detection_real(ii)(24 downto 21) = "0000" or phase_detection_real(ii)(24 downto 21) = "1111" then
						sync_symb_i(ii) <= std_logic_vector(phase_detection_real(ii)(21 downto 14)) ;
					elsif phase_detection_real(ii)(24)='1' then
						sync_symb_i(ii) <= x"80";
					elsif phase_detection_real(ii)(24)='0' then
						sync_symb_i(ii) <= x"7F";
					end if;
					if phase_detection_imag(ii)(24 downto 21) = "0000" or phase_detection_imag(ii)(24 downto 21) = "1111" then
						sync_symb_q(ii) <= std_logic_vector(phase_detection_imag(ii)(21 downto 14)) ;
					elsif phase_detection_imag(ii)(24)='1' then
						sync_symb_q(ii) <= x"80";
					elsif phase_detection_imag(ii)(24)='0' then
						sync_symb_q(ii) <= x"7F";
					end if;
				end loop;
			end if;
		end if;
	end process;

	-- Q9.14 
	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if pll_vld_d(1) = '1' then
				for ii in 0 to N-1 loop
					if abs(phase_detection_real(ii)) > abs(phase_detection_imag(ii)) then
						min_num(ii) <= abs(phase_detection_imag(ii));
						max_denom(ii) <= abs(phase_detection_real(ii));
						lower_pos(ii) <= '1';
					else
						min_num(ii) <= abs(phase_detection_real(ii));
						max_denom(ii) <= abs(phase_detection_imag(ii));
						lower_pos(ii) <= '0';
					end if;
					iq_sign_reg(ii) <= iq_sign(ii);
					case iq_sign(ii) is
						when "00" => --  pi/4,1
							phase_in(ii) <= PI_1_4_POS;
						when "01" => -- 3*pi/4,2
							phase_in(ii) <= PI_3_4_POS;
						when "10" => -- -pi/4,4
							phase_in(ii) <= PI_1_4_NEG;
						when "11" => -- -3*pi/4,3
							phase_in(ii) <= PI_3_4_NEG;
						when others => null;
					end case;
				end loop;
			end if;
		end if;
	end process;

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if pll_vld_d(2) = '1' then
				for ii in 0 to N-1 loop
					if max_denom_int(ii)(7) = '1' then
						shift_left(ii) <= "000";
					elsif max_denom_int(ii)(6) = '1' then
						shift_left(ii) <= "001";
					elsif max_denom_int(ii)(5) = '1' then
						shift_left(ii) <= "010";
					elsif max_denom_int(ii)(4) = '1' then
						shift_left(ii) <= "011";
					elsif max_denom_int(ii)(3) = '1' then
						shift_left(ii) <= "100";
					elsif max_denom_int(ii)(2) = '1' then
						shift_left(ii) <= "101";
					elsif max_denom_int(ii)(1) = '1' then
						shift_left(ii) <= "110";
					elsif max_denom_int(ii)(0) = '1' then
						shift_left(ii) <= "111";
					else
						shift_left(ii) <= "000";
					end if;
				end loop;
			end if;
		end if;
	end process;

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if pll_vld_d(3) = '1' then
				for ii in 0 to N-1 loop
					case shift_left(ii) is 
						when "000" =>
							ratio_int(ii) <= resize(min_num_int(ii),18);
						when "001" =>
							ratio_int(ii) <= resize(min_num_int(ii),18) sll 1;
						when "010" =>
							ratio_int(ii) <= resize(min_num_int(ii),18) sll 2;
						when "011" =>
							ratio_int(ii) <= resize(min_num_int(ii),18) sll 3;
						when "100" =>
							ratio_int(ii) <= resize(min_num_int(ii),18) sll 4;
						when "101" =>
							ratio_int(ii) <= resize(min_num_int(ii),18) sll 5;
						when "110" =>
							ratio_int(ii) <= resize(min_num_int(ii),18) sll 6;
						when "111" =>
							ratio_int(ii) <= resize(min_num_int(ii),18) sll 7;
						when others => null;
					end case;
				end loop;
			end if;
		end if;
	end process;

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if pll_vld_d(4) = '1' then
				for ii in 0 to N-1 loop
					if ratio_int(ii) > 1023 then
						addr_atan(ii) <= std_logic_vector(to_unsigned(1023,10));
					elsif ratio_int(ii) <= 1 then
						addr_atan(ii) <= std_logic_vector(to_unsigned(1,10));
					else
						addr_atan(ii) <= std_logic_vector(ratio_int(ii)(9 downto 0));
					end if;
				end loop;
			end if;
		end if;
	end process;

	--pll_vld_d(5), wait atan rom

	--Q2.13 -> Q4.13
	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if pll_vld_d(6) = '1' then
				for ii in 0 to N-1 loop
					case iq_sign_reg(ii) is
						when "00" => -- 1
							if lower_pos(ii) = '1' then
								phase_diff(ii) <= resize(signed(dout_atan(ii)),18) - resize(phase_in(ii),18);
							else
								phase_diff(ii) <= resize(PI_1_2_POS,18) - resize(signed(dout_atan(ii)),18) - resize(phase_in(ii),18);
							end if;
						when "01" => -- 2
							if lower_pos(ii) = '1' then
								phase_diff(ii) <= resize(PI_POS,18) - resize(signed(dout_atan(ii)),18) - resize(phase_in(ii),18);
							else
								phase_diff(ii) <= resize(PI_1_2_POS,18) + resize(signed(dout_atan(ii)),18) - resize(phase_in(ii),18);
							end if;
						when "10" => -- 4
							if lower_pos(ii) = '1' then
								phase_diff(ii) <= resize(-signed(dout_atan(ii)),18) - resize(phase_in(ii),18);
							else
								phase_diff(ii) <= resize(PI_1_2_NEG,18) + resize(signed(dout_atan(ii)),18) - resize(phase_in(ii),18);
							end if;
						when "11" => -- 3
							if lower_pos(ii) = '1' then
								phase_diff(ii) <= resize(PI_NEG,18) + resize(signed(dout_atan(ii)),18) - resize(phase_in(ii),18);
							else
								phase_diff(ii) <= resize(PI_1_2_NEG,18) - resize(signed(dout_atan(ii)),18) - resize(phase_in(ii),18);
							end if;
						when others => null;
					end case;
				end loop;
			end if;
		end if;
	end process;

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if rst_n = '0' then
				err_add0 <= (others => '0');
				err_add1 <= (others => '0');
				err_total <= (others=>'0');
			else
				--Q4.13 -> Q7.13
				if pll_vld_d(7) = '1' then
					err_add0 <= resize(phase_diff(0),21) + resize(phase_diff(1),21) + resize(phase_diff(2),21) + resize(phase_diff(3),21) + resize(phase_diff(4),21) + resize(phase_diff(5),21) + resize(phase_diff(6),21) + resize(phase_diff(7),21) ;
					err_add1 <= resize(phase_diff(8),21) + resize(phase_diff(9),21) + resize(phase_diff(10),21) + resize(phase_diff(11),21) + resize(phase_diff(12),21) + resize(phase_diff(13),21) + resize(phase_diff(14),21) + resize(phase_diff(15),21) ;
				end if;
				-- Q7.13 -> 8.13
				if pll_vld_d(8) = '1' then
					err_total <= resize(err_add0,22) + resize(err_add1,22);
				end if;
			end if;
		end if;
	end process;

	-- Q8.13 /16 -> 4.17
	-- K1 = (1/2^11+1/2^9); K1*Q4.17 = Q0.28 + Q0.26
	-- K2 = (1/2^11);	K2*Q4.17 = Q0.28
	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if rst_n = '0' then
				vi <= (others=>'0');
				vp <= (others=>'0');
			else
				if pll_vld_d(9)  = '1' then
					-- Q0.28 + Q0.28 = Q1.28 , 32 bit means Q3.28, so it means there are two redundant integal bits.
					vp <= resize(err_total,32) + (resize(err_total,32) sll 2);
					-- Q1.28 + Q1.28 = Q3.28 (1 redundant integal bit)
					vi <= vi + resize(err_total,32);
				end if; 
			end if;
		end if;
	end process;

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if rst_n = '0' then
				v <= (others=>'0');
			elsif pll_vld_d(10)  = '1' then
				-- Q3.28 
				v <= vp + vi;
			end if;
		end if;
	end process;

	loop_out_vld <= pll_vld_d(11);
	loop_dout <= std_logic_vector(v) ;

	-- Q3.28
	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if rst_n = '0' then
				phase_int <= (others=>'0');
				v_vec <= (others=>(others=>'0'));
			else
				if pll_vld_d(11)  = '1' then
					phase_int <= phase_int + (v sll 4); -- 16*v
					v_vec(0) <= v;
					v_vec(1) <= (v sll 1);
					v_vec(2) <= (v sll 1) + v;
					v_vec(3) <= (v sll 2);
					v_vec(4) <= (v sll 2) + v;
					v_vec(5) <= (v sll 2) + (v sll 1);
					v_vec(6) <= (v sll 3) - v;
					v_vec(7) <= (v sll 3);
					v_vec(8) <= (v sll 3) + v;
					v_vec(9) <= (v sll 3) + (v sll 1);
					v_vec(10) <= (v sll 3) + v + (v sll 1);
					v_vec(11) <= (v sll 3) + (v sll 2);
					v_vec(12) <= (v sll 3) + (v sll 2) + v;
					v_vec(13) <= (v sll 4) - (v sll 1) ;
					v_vec(14) <= (v sll 4) - v ;
					v_vec(15) <= (v sll 4);
				end if;
				-- to void overlfow
				if pll_vld_d(12) = '1' then
					if phase_int > PI_Q3P28 then
						phase_int <= phase_int - DOUBLE_PI_Q3P28;
					elsif phase_int < - PI_Q3P28 then
						phase_int <= phase_int + DOUBLE_PI_Q3P28;
					else
						phase_int <= phase_int;
					end if;
					for ii in 0 to N-1 loop
						if phase_int > PI_Q3P28 then
							phase_int_v(ii) <= phase_int - DOUBLE_PI_Q3P28 + v_vec(ii) ;
						elsif phase_int < - PI_Q3P28 then
							phase_int_v(ii) <= phase_int + DOUBLE_PI_Q3P28 + v_vec(ii) ;
						else
							phase_int_v(ii) <= phase_int + v_vec(ii) ;
						end if;
					end loop;
				end if;
			end if;
		end if;
	end process;

	-- unwrap
	-- Q3.28 
	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if rst_n = '0' then
				phase_int_v_wrap <=	(others=>(others=>'0'));
			elsif pll_vld_d(13) = '1' then
				for ii in 0 to N-1 loop
					if phase_int_v(ii) > PI_Q3P28 then
						phase_int_v_wrap(ii) <= phase_int_v(ii) - DOUBLE_PI_Q3P28;
					elsif phase_int_v(ii) < - PI_Q3P28 then
						phase_int_v_wrap(ii) <= phase_int_v(ii) + DOUBLE_PI_Q3P28;
					else
						phase_int_v_wrap(ii) <= phase_int_v(ii);
					end if;
				end loop;
			end if;
		end if;
	end process;
	-- pll_vld_d(14) addr vld
	-- pll_vld_d(15) cos, sin vld, sync with symb_en

end rtl;

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

entity pll is
	port(
			sys_clk		: in std_logic;
			aresetn 	: in std_logic;
			sym_type 	: in std_logic_vector(2 downto 0);
			en_sym		: in std_logic;
			sym_i		: in std_logic_vector(23 downto 0);
			sym_q		: in std_logic_vector(23 downto 0);
			sym_phase   : in std_logic_vector(23 downto 0);
			sym_sync_en 	: out std_logic:='0';
			phase_int_o	 	: out std_logic_vector(19 downto 0):=(others=>'0');
			sym_sync_data_i	: out std_logic_vector(23 downto 0):=(others=>'0');
			sym_sync_data_q	: out std_logic_vector(23 downto 0):=(others=>'0')
		);
end pll;

architecture arch of pll is

	component phase_rotator
		port (
				 aclk : in std_logic;
				 aresetn : in std_logic;
				 s_axis_phase_tvalid : in std_logic;
				 s_axis_phase_tdata : in std_logic_vector(23 downto 0);
				 s_axis_cartesian_tvalid : in std_logic;
				 s_axis_cartesian_tdata : in std_logic_vector(47 downto 0);
				 m_axis_dout_tvalid : out std_logic;
				 m_axis_dout_tdata : out std_logic_vector(47 downto 0)
			 );
	end component;

	component atan2
		port (
				 aclk : in std_logic;
				 aresetn : in std_logic;
				 s_axis_cartesian_tvalid : in std_logic;
				 s_axis_cartesian_tdata : in std_logic_vector(47 downto 0);
				 m_axis_dout_tvalid : out std_logic;
				 m_axis_dout_tdata : out std_logic_vector(23 downto 0)
			 );
	end component;

	component cos_sin
		port (
				 aclk : in std_logic;
				 aresetn : in std_logic;
				 s_axis_phase_tvalid : in std_logic;
				 s_axis_phase_tdata : in std_logic_vector(15 downto 0);
				 m_axis_dout_tvalid : out std_logic;
				 m_axis_dout_tdata : out std_logic_vector(31 downto 0)
			 );
	end component;

	signal phase_valid 						: std_logic:='0';
	signal phase_data 						: std_logic_vector(23 downto 0):=(others=>'0');
	signal cartesian_data 					: std_logic_vector(47 downto 0):=(others=>'0');
	signal rotator_valid					: std_logic:='0';
	signal rotator_data						: std_logic_vector(47 downto 0):=(others=>'0');
	signal en_sym_rotate					: std_logic:='0';
	signal sym_i_rotate						: std_logic_vector(23 downto 0):=(others=>'0');
	signal sym_q_rotate						: std_logic_vector(23 downto 0):=(others=>'0');

	signal s_axis_cartesian_tvalid 			: std_logic:='0';
	signal s_axis_cartesian_tdata 			: std_logic_vector(47 downto 0):=(others=>'0');
	signal phase_in							: signed(19 downto 0):=(others=>'0');
	signal ped_valid						: std_logic := '0';
	signal ped_data							: std_logic_vector(23 downto 0):=(others=>'0');

	signal phase_diff_valid					: std_logic := '0';
	signal phase_diff_wrap_valid 			: std_logic := '0';
	signal phase_diff_wrap_valid_d0			: std_logic := '0';
	signal div_valid						: std_logic := '0';
	signal p_div_valid						: std_logic := '0';
	signal intg_valid						: std_logic := '0';
	signal intg_wrap_valid					: std_logic := '0';
	signal loop_flt_valid					: std_logic := '0';
	signal loop_flt_wrap_valid				: std_logic := '0';
	signal phase_int_valid					: std_logic := '0';
	signal phase_int_wrap_valid				: std_logic := '0';

	signal phase_diff						: signed(15+4 downto 0):=(others=>'0');
	signal div2,div4						: signed(15+4 downto 0):=(others=>'0');
	signal p1								: signed(15+4 downto 0):=(others=>'0');
	signal p2								: signed(15+4 downto 0):=(others=>'0');
	signal integral_part 					: signed(15+4 downto 0):=(others=>'0');
	signal loop_flt 						: signed(15+4 downto 0):=(others=>'0');
	signal phase_int 						: signed(15+4 downto 0):=(others=>'0');
	signal phase_int_wrap 					: signed(15+4 downto 0):=(others=>'0');

	-- QPSK
	signal iq_sign		: std_logic_vector(1 downto 0):=(others=>'0');

	-- cos/sin table for 8PSK (scaled by 127)
--    type lut_array is array (0 to 7) of signed(7 downto 0);
--    constant COS_LUT : lut_array := (
--        to_signed(127,8),  -- 0°
--        to_signed( 90,8),  -- 45°
--        to_signed(  0,8),  -- 90°
--        to_signed(-90,8),  -- 135°
--        to_signed(-127,8), -- 180°
--        to_signed(-90,8),  -- 225°
--        to_signed(  0,8),  -- 270°
--        to_signed( 90,8)   -- 315°
--    );
--
--    constant SIN_LUT : lut_array := (
--        to_signed(  0,8),  -- 0°
--        to_signed( 90,8),  -- 45°
--        to_signed(127,8),  -- 90°
--        to_signed( 90,8),  -- 135°
--        to_signed(  0,8),  -- 180°
--        to_signed(-90,8),  -- 225°
--        to_signed(-127,8), -- 270°
--        to_signed(-90,8)   -- 315°
--    );

   -- signal metric : array(0 to 7) of signed(23 downto 0);
   -- signal best_idx : unsigned(2 downto 0);

	attribute mark_debug : string;
	attribute mark_debug of phase_valid 				: signal is "TRUE";	
	attribute mark_debug of phase_data 					: signal is "TRUE";	
	attribute mark_debug of cartesian_data 				: signal is "TRUE";	
	attribute mark_debug of rotator_valid				: signal is "TRUE";	
	attribute mark_debug of rotator_data				: signal is "TRUE";	
	attribute mark_debug of en_sym_rotate				: signal is "TRUE";	
	attribute mark_debug of sym_i_rotate				: signal is "TRUE";	
	attribute mark_debug of sym_q_rotate				: signal is "TRUE";	
	attribute mark_debug of s_axis_cartesian_tvalid 	: signal is "TRUE";	
	attribute mark_debug of s_axis_cartesian_tdata 		: signal is "TRUE";	
	attribute mark_debug of phase_in					: signal is "TRUE";	
	attribute mark_debug of ped_valid					: signal is "TRUE";	
	attribute mark_debug of ped_data					: signal is "TRUE";	
	attribute mark_debug of phase_diff_valid			: signal is "TRUE";	
	attribute mark_debug of phase_diff_wrap_valid 		: signal is "TRUE";	
	attribute mark_debug of phase_diff_wrap_valid_d0	: signal is "TRUE";	
	attribute mark_debug of div_valid					: signal is "TRUE";	
	attribute mark_debug of p_div_valid					: signal is "TRUE";	
	attribute mark_debug of intg_valid					: signal is "TRUE";	
	attribute mark_debug of intg_wrap_valid				: signal is "TRUE";	
	attribute mark_debug of loop_flt_valid				: signal is "TRUE";	
	attribute mark_debug of loop_flt_wrap_valid			: signal is "TRUE";	
	attribute mark_debug of phase_int_valid				: signal is "TRUE";	
	attribute mark_debug of phase_int_wrap_valid		: signal is "TRUE";	
	attribute mark_debug of phase_diff					: signal is "TRUE";	
	attribute mark_debug of div2,div4					: signal is "TRUE";	
	attribute mark_debug of p1							: signal is "TRUE";	
	attribute mark_debug of p2							: signal is "TRUE";	
	attribute mark_debug of integral_part 				: signal is "TRUE";	
	attribute mark_debug of loop_flt 					: signal is "TRUE";	
	attribute mark_debug of phase_int 					: signal is "TRUE";	
	attribute mark_debug of phase_int_wrap 				: signal is "TRUE";	
begin
	phase_int_o	 <= std_logic_vector(phase_int);	
	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if en_sym ='1' then
				phase_valid <= '1';	
--				if sym_i(sym_i'high) = '0' then
--					phase_in <= (others=>'0');
--				else
--					phase_in <= PI_POS;
--				end if;
				--phase_corr  <= std_logic_vector(sym_phase-signed(phase_int(15 downto 0)&"00000000"));
				phase_data 	<= std_logic_vector(0-signed(phase_int(15 downto 0)&"00000000"));
				cartesian_data 	<= sym_q & sym_i;
			else
				phase_valid <= '0';	
			end if;
		end if;
	end process;

	u_rotator: phase_rotator
	port map(
				aclk 					=> sys_clk			,
				aresetn 				=> aresetn			,
				s_axis_phase_tvalid 	=> phase_valid 		,
				s_axis_phase_tdata 		=> phase_data 		,
				s_axis_cartesian_tvalid => phase_valid		,
				s_axis_cartesian_tdata 	=> cartesian_data 	,
				m_axis_dout_tvalid 		=> rotator_valid	,
				m_axis_dout_tdata 		=> rotator_data
			);

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			en_sym_rotate <= rotator_valid	;
			sym_i_rotate  <= rotator_data(23 downto 0);
			sym_q_rotate  <= rotator_data(47 downto 24);
		end if;
	end process;

	sym_sync_en 		<= en_sym_rotate ;
	sym_sync_data_i		<= sym_i_rotate  ;
	sym_sync_data_q		<= sym_q_rotate  ;

	iq_sign	<= sym_i_rotate(sym_i_rotate'high)&sym_q_rotate(sym_q_rotate'high);

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if aresetn = '0' then
				s_axis_cartesian_tvalid <= '0';
				s_axis_cartesian_tdata <= (others=>'0');
				phase_in <= (others=>'0');
			else
				if en_sym_rotate = '1' then
					if sym_i_rotate = x"000000" then
						s_axis_cartesian_tdata(23 downto 0)  <= x"000001";
					else
						s_axis_cartesian_tdata(23 downto 0)  <= sym_i_rotate;
					end if;
					s_axis_cartesian_tdata(47 downto 24) <= sym_q_rotate;
					s_axis_cartesian_tvalid <= '1';
					case sym_type is
						when "000" => --BPSK
							case iq_sign(1) is
								when '0' =>
									phase_in <= (others=>'0');
								when '1' =>
									phase_in <= PI_POS;
								when others => null;
							end case;
						when "001" => --QPSK
							case iq_sign is
								when "00" => -- ++
									phase_in <= PI_1_4_POS;
								when "01" => -- +-
									phase_in <= PI_1_4_NEG;
								when "10" => -- -+ 
									phase_in <= PI_3_4_POS;
								when "11" => -- --
									phase_in <= PI_3_4_NEG;
								when others => null;
							end case;
				--		when "010" => -- OQPSK
				--			null;
						when "011" => -- 8PSK
							null;
						--	for k in 0 to 7 loop
						--		metric(k) <= resize(din_i,24) * resize(COS_LUT(k),24) + resize(din_q,24) * resize(SIN_LUT(k),24);
						--	end loop;
				--		when "100" => -- pi/4DQPSK
				--			null;
				--		when "101" => -- 8QAM
				--			null;
				--		when "110" => -- 16QAM
				--			null;
						when others => null;
					end case;
				else
					s_axis_cartesian_tvalid <= '0';
				end if; 
			end if;
		end if;
	end process;

	u_atan2: atan2
	port map(
				 aclk 						=> sys_clk,
				 aresetn					=> aresetn,
				 s_axis_cartesian_tvalid 	=> s_axis_cartesian_tvalid,
				 s_axis_cartesian_tdata 	=> s_axis_cartesian_tdata,
				 m_axis_dout_tvalid 		=> ped_valid,
				 m_axis_dout_tdata 			=> ped_data
			);

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if ped_valid = '1' then
				phase_diff	<=  resize(signed(ped_data(23 downto 8)),20) - phase_in;
				--phase_diff	<=  signed(ped_data(19 downto 0)) - phase_in;
			end if;
			phase_diff_valid <= ped_valid;
			if phase_diff_valid = '1' then
				if (phase_diff > PI_POS) then -- pi
					phase_diff <= phase_diff + PI_NEG + PI_NEG;
				elsif (phase_diff < PI_NEG) then
					phase_diff <= phase_diff + PI_POS + PI_POS;
				end if;
			end if;
			phase_diff_wrap_valid <= phase_diff_valid;
			if phase_diff_wrap_valid = '1' then
				if (phase_diff > PI_POS) then -- pi
					phase_diff <= phase_diff + PI_NEG + PI_NEG;
				elsif (phase_diff < PI_NEG) then
					phase_diff <= phase_diff + PI_POS + PI_POS;
				end if;
			end if;
			phase_diff_wrap_valid_d0 <= phase_diff_wrap_valid;
		end if;
	end process;

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if phase_diff_wrap_valid_d0 = '1' then
				div2 <= phase_diff(phase_diff'high)&phase_diff(phase_diff'high)&phase_diff(phase_diff'high downto 2);
				div4 <= phase_diff(phase_diff'high)&phase_diff(phase_diff'high)&phase_diff(phase_diff'high)&phase_diff(phase_diff'high)&phase_diff(phase_diff'high downto 4);
			end if;
			div_valid <= phase_diff_wrap_valid_d0;
		end if;
	end process;

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if div_valid = '1' then
				p1 <= signed(div4)+signed(div2); -- K1 = 1/2^4+1/2^2;
				p2 <= signed(div4);				 -- K2 = 1/2^4;
			end if;
			p_div_valid <= div_valid;
		end if;
	end process;

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if aresetn = '0' then
				integral_part <= (others=>'0');
			elsif p_div_valid = '1' then
				integral_part <= integral_part + p2;
			end if;
			intg_valid <= p_div_valid;

			if intg_valid = '1' then
				if integral_part > PI_POS then
					integral_part <= integral_part + PI_NEG + PI_NEG;
				elsif integral_part < PI_NEG then
					integral_part <= integral_part + PI_POS + PI_POS;
				end if;
			end if;
			intg_wrap_valid <= intg_valid;
		end if;
	end process;

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if aresetn = '0' then
				loop_flt <= (others=>'0');
			elsif intg_wrap_valid = '1' then
				loop_flt <= p1 + integral_part;
			end if;
			loop_flt_valid <= intg_wrap_valid;

			if loop_flt_valid = '1' then
				if loop_flt > PI_POS then
					loop_flt <= loop_flt + PI_NEG + PI_NEG;
				elsif loop_flt < PI_NEG then
					loop_flt <= loop_flt + PI_POS + PI_POS;
				end if;
			end if;
			loop_flt_wrap_valid <= loop_flt_valid;
		end if;
	end process;

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if aresetn = '0' then
				phase_int <= (others=>'0');
			elsif loop_flt_wrap_valid = '1' then
				phase_int <= phase_int  + loop_flt;
			end if;
			phase_int_valid <= loop_flt_wrap_valid;

			if phase_int_valid = '1' then
				if phase_int > PI_POS then
					phase_int <= phase_int + PI_NEG + PI_NEG;
				elsif phase_int < PI_NEG then
					phase_int <= phase_int + PI_POS + PI_POS;
				end if;
			end if;
			phase_int_wrap_valid <= phase_int_valid;
		end if;
	end process;

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if phase_int_wrap_valid = '0' then
				if (phase_int > PI_POS) then -- pi
					phase_int_wrap <= phase_int + PI_NEG + PI_NEG;
				elsif (phase_int < PI_NEG) then
					phase_int_wrap <= phase_int + PI_POS + PI_POS;
				else
					phase_int_wrap <= phase_int;
				end if;
			end if;
		end if;
	end process;

end arch;

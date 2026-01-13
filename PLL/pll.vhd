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
			sym_i		: in std_logic_vector(15 downto 0);
			sym_q		: in std_logic_vector(15 downto 0);
			euclidean_distance : out std_logic_vector(31 downto 0);
			sym_sync_en 	: out std_logic:='0';
			sym_sync_data_i	: out std_logic_vector(15 downto 0):=(others=>'0');
			sym_sync_data_q	: out std_logic_vector(15 downto 0):=(others=>'0');
			phase_diff_vld  : out std_logic:='0';
			phase_diff_out  : out std_logic_vector(19 downto 0):=(others=>'0')
		);
end pll;

architecture arch of pll is

	component phase_rotator
		port (
				 aclk : in std_logic;
				 aresetn : in std_logic;
				 s_axis_phase_tvalid : in std_logic;
				 s_axis_phase_tdata : in std_logic_vector(15 downto 0);
				 s_axis_cartesian_tvalid : in std_logic;
				 s_axis_cartesian_tdata : in std_logic_vector(31 downto 0);
				 m_axis_dout_tvalid : out std_logic;
				 m_axis_dout_tdata : out std_logic_vector(31 downto 0)
			 );
	end component;

	component atan2
		port (
				 aclk : in std_logic;
				 aresetn : in std_logic;
				 s_axis_cartesian_tvalid : in std_logic;
				 s_axis_cartesian_tdata : in std_logic_vector(31 downto 0);
				 m_axis_dout_tvalid : out std_logic;
				 m_axis_dout_tdata : out std_logic_vector(15 downto 0)
			 );
	end component;

	component cmp16
	generic(
			   data_width : integer := 32;
			   data_num   : integer := 16
		   );
	port(
			sys_clk			: in std_logic; -- 28.8MHz
			en				: in std_logic;
			data_in			: in signed_array_32(data_num-1 downto 0);
			min_data		: out signed(data_width-1 downto 0):=(others=>'0');
			min_ind			: out std_logic_vector(LOG2(data_num)-1 downto 0):=(others=>'0')
		);
	end component;

	signal phase_valid 						: std_logic:='0';
	signal phase_data 						: std_logic_vector(15 downto 0):=(others=>'0');
	signal cartesian_data 					: std_logic_vector(31 downto 0):=(others=>'0');
	signal rotator_valid					: std_logic:='0';
	signal rotator_data						: std_logic_vector(31 downto 0):=(others=>'0');
	signal en_sym_rotate					: std_logic:='0';
	signal sym_i_rotate						: std_logic_vector(15 downto 0):=(others=>'0');
	signal sym_q_rotate						: std_logic_vector(15 downto 0):=(others=>'0');

	signal s_axis_cartesian_tvalid 			: std_logic:='0';
	signal s_axis_cartesian_tdata 			: std_logic_vector(31 downto 0):=(others=>'0');
	signal phase_in							: signed(15 downto 0):=(others=>'0');
	signal ped_valid						: std_logic := '0';
	signal ped_data							: std_logic_vector(15 downto 0):=(others=>'0');

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

	signal phase_diff						: signed(19 downto 0):=(others=>'0');
	signal div2,div4						: signed(19 downto 0):=(others=>'0');
	signal p1								: signed(19 downto 0):=(others=>'0');
	signal p2								: signed(19 downto 0):=(others=>'0');
	signal integral_part 					: signed(19 downto 0):=(others=>'0');
	signal loop_flt 						: signed(19 downto 0):=(others=>'0');
	signal phase_int 						: signed(19 downto 0):=(others=>'0');
	signal phase_int_wrap 					: signed(19 downto 0):=(others=>'0');
	signal complex_flag 					: std_logic := '1';
	signal shift_flag 						: std_logic := '0';
	signal phase_int_tmp					: std_logic_vector(15 downto 0):=(others=>'0'); 
	signal err_i,err_q						: signed_array_16(15 downto 0):=(others=>(others=>'0'));
	signal err_i_2,err_q_2					: signed_array_32(15 downto 0):=(others=>(others=>'0'));
	signal err_sum							: signed_array_32(15 downto 0):=(others=>(others=>'0'));
	signal min_ind_int 						: integer range 0 to 15:=0;
	signal min_data							: signed(31 downto 0):=(others=>'0');
	signal min_ind							: std_logic_vector(3 downto 0):=(others=>'0');


	-- QPSK
	signal iq_sign		: std_logic_vector(1 downto 0):=(others=>'0');
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
	euclidean_distance <= std_logic_vector(min_data);
	phase_int_tmp <= std_logic_vector(phase_int_wrap(19)&phase_int_wrap(14 downto 0));

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if en_sym ='1' then
				phase_valid <= '1';	
				phase_data 	<= std_logic_vector(0-signed(phase_int_tmp));
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
			sym_i_rotate  <= rotator_data(15 downto 0);
			sym_q_rotate  <= rotator_data(31 downto 16);
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
				shift_flag <= '0';
				complex_flag <= '0';
			else
				if en_sym_rotate = '1' then
					if sym_i_rotate = x"0000" then
						s_axis_cartesian_tdata(15 downto 0)  <= x"0001";
					else
						s_axis_cartesian_tdata(15 downto 0)  <= sym_i_rotate;
					end if;
					s_axis_cartesian_tdata(31 downto 16) <= sym_q_rotate;
					s_axis_cartesian_tvalid <= '1';
				else
					s_axis_cartesian_tvalid <= '0';
				end if; 
				case sym_type is
					when "000" => --BPSK
						case sym_i_rotate(sym_i_rotate'high) is
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
					when "010" => -- OQPSK, needs sps * 2
								  --	complex_flag <= not complex_flag;
								  --	if complex_flag = '1' then 
								  --		if signed(sym_q_rotate) >= 0 then
								  --			phase_in <= PI_1_2_POS;
								  --		else
								  --			phase_in <= PI_1_2_NEG;
								  --		end if;
								  --	else
								  --		if signed(sym_i_rotate) >= 0 then
								  --			phase_in <= (others=>'0');
								  --		else
								  --			phase_in <= PI_POS;
								  --		end if;
								  --	end if;
						if abs(signed(sym_i_rotate)) >= abs(signed(sym_q_rotate)) then
							if signed(sym_i_rotate)>= 0 then
								phase_in <= (others=>'0'); 
							else
								phase_in <= PI_POS;
							end if;
						else
							if signed(sym_q_rotate)>= 0 then
								phase_in <= PI_1_2_POS;
							else
								phase_in <= PI_1_2_NEG;
							end if;
						end if;
					when "011" => -- 8PSK
						for kk in 0 to 7 loop
							err_i(kk) <= signed(sym_i_rotate(15 downto 0)) - PSK8_LUT_I(kk);
							err_q(kk) <= signed(sym_q_rotate(15 downto 0)) - PSK8_LUT_Q(kk);
							err_i_2(kk) <= err_i(kk) * err_i(kk); 
							err_q_2(kk) <= err_q(kk) * err_q(kk);
							err_sum(kk) <= err_i_2(kk) + err_q_2(kk);
						end loop;
						err_sum(15 downto 8) <= (others=>x"7FFFFFFF"); 
					when "100" => -- pi/4DQPSK
								  --	shift_flag <= not shift_flag;
								  --	if shift_flag = '0' then
						if signed(sym_i_rotate) >= 0 and signed(sym_q_rotate) >= 0 then
							phase_in <= PI_1_4_POS;
						elsif signed(sym_i_rotate) > 0 and signed(sym_q_rotate) < 0 then
							phase_in <= PI_1_4_NEG;
						elsif signed(sym_i_rotate) <= 0 and signed(sym_q_rotate) <= 0 then
							phase_in <= PI_3_4_NEG;
						elsif signed(sym_i_rotate) < 0 and  signed(sym_q_rotate)> 0 then
							phase_in <= PI_3_4_POS;
						end if;
						--	else
						--		if abs(signed(sym_i_rotate)) >= abs(signed(sym_q_rotate)) then
						--			if signed(sym_i_rotate)>= 0 then
						--				phase_in <= (others=>'0'); 
						--			else
						--				phase_in <= PI_POS;
						--			end if;
						--		else
						--			if signed(sym_q_rotate)>= 0 then
						--				phase_in <= PI_1_2_POS;
						--			else
						--				phase_in <= PI_1_2_NEG;
						--			end if;
						--		end if;
						--	end if;
					when "101" =>  -- 8QAM
						for mm in 0 to 7 loop
							err_i(mm) <= signed(sym_i_rotate) - QAM8_LUT_I(mm);
							err_q(mm) <= signed(sym_q_rotate) - QAM8_LUT_Q(mm);
							err_i_2(mm) <= err_i(mm) * err_i(mm); 
							err_q_2(mm) <= err_q(mm) * err_q(mm);
							err_sum(mm) <= err_i_2(mm) + err_q_2(mm);
						end loop;
						err_sum(15 downto 8) <= (others=>x"7FFFFFFF"); 
					when "110" =>  -- 16QAM
						for nn in 0 to 15 loop
							err_i(nn) <= signed(sym_i_rotate) - QAM16_LUT_I(nn);
							err_q(nn) <= signed(sym_q_rotate) - QAM16_LUT_Q(nn);
							err_i_2(nn) <= err_i(nn) * err_i(nn); 
							err_q_2(nn) <= err_q(nn) * err_q(nn);
							err_sum(nn) <= err_i_2(nn) + err_q_2(nn);
						end loop;
					when others => null;
				end case;
			end if;
		end if;
	end process;

	u_cmp16: cmp16
	generic map( data_width => 32, data_num   => 16)
	port map(
			sys_clk			=> sys_clk,
			en				=> '1',
			data_in			=> err_sum,
			min_data		=> min_data,
			min_ind			=> min_ind
		);

	u_atan2: atan2
	port map(
				 aclk 						=> sys_clk,
				 aresetn					=> aresetn,
				 s_axis_cartesian_tvalid 	=> s_axis_cartesian_tvalid,
				 s_axis_cartesian_tdata 	=> s_axis_cartesian_tdata,
				 m_axis_dout_tvalid 		=> ped_valid,
				 m_axis_dout_tdata 			=> ped_data
			);

	min_ind_int <= to_integer(unsigned(min_ind));

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if ped_valid = '1' then
				case sym_type is
					-- bpsk
					when "000" =>
						phase_diff	<=  resize(signed(ped_data),20) - resize(phase_in,20);
					-- qpsk
					when "001" =>
						phase_diff	<=  resize(signed(ped_data),20) - resize(phase_in,20);
					-- oqpsk
					when "010" =>
						phase_diff	<=  resize(signed(ped_data),20) - resize(phase_in,20);
					-- 8psk
					when "011" =>
						if min_ind_int = 6 then
							if signed(sym_q_rotate)> 0 then
								phase_diff	<=  resize(signed(ped_data),20) - PI_POS_UNWRAP;
							else
								phase_diff	<=  resize(signed(ped_data),20) - PI_NEG_UNWRAP;
							end if;
						else
							phase_diff	<=  resize(signed(ped_data),20) - resize(PSK8_PHASE(min_ind_int),20);
						end if;
					-- pi/4 dqpsk
					when "100" =>
						phase_diff	<=  resize(signed(ped_data),20) - resize(phase_in,20);
					-- 8qam
					when "101" =>
						if signed(sym_q_rotate) = 0 or signed(sym_i_rotate) = 0 then
							phase_diff	<=  (others=>'0');
						else
							phase_diff	<=  resize(signed(ped_data),20) - resize(QAM8_PHASE(min_ind_int),20);
						end if;
					-- 16qam
					when "110" =>
						if signed(sym_q_rotate) = 0 or signed(sym_i_rotate) = 0 then
							phase_diff	<=  (others=>'0');
						else
							phase_diff	<=  resize(signed(ped_data),20) - resize(QAM16_PHASE(min_ind_int),20);
						end if;
					when others => null;
				end case;
			end if;
			phase_diff_valid <= ped_valid;
		end if;
	end process;

	phase_diff_vld <= phase_diff_valid ;
	phase_diff_out <= std_logic_vector(phase_diff);

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if phase_diff_valid = '1' then
				div2 <= phase_diff(phase_diff'high)&phase_diff(phase_diff'high)&phase_diff(phase_diff'high downto 2);
				div4 <= phase_diff(phase_diff'high)&phase_diff(phase_diff'high)&phase_diff(phase_diff'high)&phase_diff(phase_diff'high)&phase_diff(phase_diff'high downto 4);
			end if;
			div_valid <= phase_diff_valid;
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
		end if;
	end process;

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if aresetn = '0' then
				loop_flt <= (others=>'0');
			elsif intg_valid = '1' then
				loop_flt <= p1 + integral_part;
			end if;
			loop_flt_valid <= intg_valid;
		end if;
	end process;

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if aresetn = '0' then
				phase_int <= (others=>'0');
			elsif loop_flt_valid = '1' then
				phase_int <= phase_int  + loop_flt;
			end if;
			phase_int_valid <= loop_flt_valid;
			if phase_int_valid = '1' then
				if phase_int > PI_POS_UNWRAP then
					phase_int <= phase_int + PI_NEG_UNWRAP + PI_NEG_UNWRAP;
				elsif phase_int < PI_NEG_UNWRAP then
					phase_int <= phase_int + PI_POS_UNWRAP + PI_POS_UNWRAP;
				end if;
			end if;
			phase_int_wrap_valid <= phase_int_valid;
		end if;
	end process;

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if phase_int_wrap_valid = '0' then
				if (phase_int > PI_POS_UNWRAP) then -- pi
					phase_int_wrap <= phase_int + PI_NEG_UNWRAP + PI_NEG_UNWRAP;
				elsif (phase_int < PI_NEG_UNWRAP) then
					phase_int_wrap <= phase_int + PI_POS_UNWRAP + PI_POS_UNWRAP;
				else
					phase_int_wrap <= phase_int;
				end if;
			end if;
		end if;
	end process;

end arch;

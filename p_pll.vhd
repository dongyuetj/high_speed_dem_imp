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
	generic(N:integer:=8);
    Port (
        sys_clk 	 : in  std_logic;
        rst_n   	 : in  std_logic;
		symb_en 	 : in std_logic;
		symb_i  	 : in std_logic_array_8(0 to N-1):=(others=>(others=>'0'));
		symb_q  	 : in std_logic_array_8(0 to N-1):=(others=>(others=>'0'));
		sync_symb_en : out std_logic:='0';
		sync_symb_i  : out std_logic_array_8(0 to N-1):=(others=>(others=>'0'));
		sync_symb_q  : out std_logic_array_8(0 to N-1):=(others=>(others=>'0'))
    );
end p_pll;

architecture rtl of p_pll is

	component cordic_pll
		port (
				 aclk : in std_logic;
				 s_axis_phase_tvalid : in std_logic;
				 s_axis_phase_tdata : in std_logic_vector(15 downto 0);
				 m_axis_dout_tvalid : out std_logic;
				 m_axis_dout_tdata : out std_logic_vector(31 downto 0) 
			 );
	end component;

	component cmpy_pll
		port (
				 aclk : in std_logic;
				 s_axis_a_tvalid : in std_logic;
				 s_axis_a_tdata : in std_logic_vector(15 downto 0);
				 s_axis_b_tvalid : in std_logic;
				 s_axis_b_tdata : in std_logic_vector(31 downto 0);
				 m_axis_dout_tvalid : out std_logic;
				 m_axis_dout_tdata : out std_logic_vector(63 downto 0) 
			 );
	end component;
	-- Q7.16
	constant ZEROP25				: signed(23 downto 0):=to_signed(2**14,24);

	-- Q0.16
	constant ZEROP25_Q0p16			: signed(16 downto 0):=to_signed(2**14,17);

	constant PI_Q8P26				: signed(34 downto 0):=to_signed(210828714,35); -- round(pi * 2^26)
	constant PI_Q9P26				: signed(35 downto 0):=to_signed(210828714,36); -- round(pi * 2^26)
	constant DOUBLE_PI_Q8P26		: signed(34 downto 0):=to_signed(2*210828714,35);
	constant DOUBLE_PI_Q9P26		: signed(35 downto 0):=to_signed(2*210828714,36);

	constant PI_Q2P13				: signed(15 downto 0):=to_signed(25736,16); -- round(pi * 2^13)

	signal pll_vld_d 				: std_logic_vector(12 downto 0):=(others=>'0');
	signal nco_cfg_vld 				: std_logic:='0';
	signal nco_pinc    				: std_logic_array_16(0 to N-1):=(others=>(others=>'0'));
	signal nco_out_vld 				: std_logic_vector(0 to N-1):=(others=>'0');
	signal nco_data    				: std_logic_array_32(0 to N-1):=(others=>(others=>'0'));
	signal cos,sin					: signed_array_16(0 to N-1):=(others=>(others=>'0'));
	signal s_axis_a_tvalid 			: std_logic:='0';
	signal s_axis_a_tdata 			: std_logic_array_16(0 to N-1):=(others=>(others=>'0'));
	signal s_axis_b_tvalid 			: std_logic:='0';
	signal s_axis_b_tdata 			: std_logic_array_32(0 to N-1):=(others=>(others=>'0'));
	signal m_axis_dout_tvalid 		: std_logic_vector(0 to N-1):=(others=>'0');
	signal m_axis_dout_tdata 		: std_logic_array_64(0 to N-1):=(others=>(others=>'0'));
	signal iq_sign					: std_logic_array_2(0 to N-1):=(others=>(others=>'0'));
	signal phase_detection_real		: std_logic_array_25(0 to N-1):=(others=>(others=>'0'));
	signal phase_detection_imag 	: std_logic_array_25(0 to N-1):=(others=>(others=>'0'));	
	signal phase_diff 				: signed_array_25(0 to N-1):=(others=>(others=>'0'));

	signal err_1 					: signed_array_26(0 to N/2-1):=(others=>(others=>'0'));
	signal err_2 					: signed_array_27(0 to N/4-1):=(others=>(others=>'0'));
	signal err		 				: signed(27 downto 0):=(others=>'0');
	signal err_avg		 			: signed(15 downto 0):=(others=>'0');

	signal K11xerr		 			: signed(17 downto 0):=(others=>'0');
	signal K2xerr		 			: signed(17 downto 0):=(others=>'0');
	signal K1xerr		 			: signed(18 downto 0):=(others=>'0');
	signal int_temp 				: signed(23 downto 0):=(others=>'0');
	signal int_out	 				: signed(16 downto 0):=(others=>'0');
	signal loop_out					: signed(17 downto 0):=(others=>'0');

	signal intx1					: signed(20 downto 0):=(others=>'0');
	signal intx2					: signed(20 downto 0):=(others=>'0');
	signal intx4					: signed(20 downto 0):=(others=>'0');
	signal intx8					: signed(20 downto 0):=(others=>'0');

	signal intx1_t					: signed(20 downto 0):=(others=>'0');
	signal intx2_t					: signed(20 downto 0):=(others=>'0');
	signal intx3_t					: signed(20 downto 0):=(others=>'0');
	signal intx4_t					: signed(20 downto 0):=(others=>'0');
	signal intx5_t					: signed(20 downto 0):=(others=>'0');
	signal intx6_t					: signed(20 downto 0):=(others=>'0');
	signal intx7_t					: signed(20 downto 0):=(others=>'0');
	signal intx8_t					: signed(20 downto 0):=(others=>'0');

	signal phase_int 				: signed(21 downto 0):=(others=>'0');
	signal phase_int_wrap 			: signed(34 downto 0):=(others=>'0');
	signal phase_int_v	 			: signed_array_36(0 to N-1):=(others=>(others=>'0'));
	signal phase_int_v_wrap	 		: signed_array_36(0 to N-1):=(others=>(others=>'0'));
	signal phase_int_v_wrap_fix	 	: std_logic_array_16(0 to N-1):=(others=>(others=>'0'));
begin

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			for ii in 0 to N-1 loop
				if nco_out_vld(ii) = '1' then
					cos(ii) <= signed(nco_data(ii)(15 downto 0));
					sin(ii) <= signed(nco_data(ii)(31 downto 16));
				end if;
			end loop;
		end if;
	end process;

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			s_axis_a_tvalid <= symb_en;
			s_axis_b_tvalid	<= symb_en;
			for ii in 0 to N-1 loop
				s_axis_a_tdata(ii) <= symb_q(ii) & symb_i(ii);
				s_axis_b_tdata(ii)(15 downto 0) <= std_logic_vector(cos(ii)) ;
				s_axis_b_tdata(ii)(31 downto 16) <= std_logic_vector(-sin(ii)); 
			end loop;
		end if;
	end process;

	
	-- (Q7.0 + 1j * Q7.0) * (Q1.14 + 1j *Q1.14) = Q8.14 + Q8.14 = Q9.14
	gen_nco: for ii in 0 to N-1 generate

		nco_pinc(ii) <= phase_int_v_wrap_fix(ii);

		u_cordic: cordic_pll
		port map(
					aclk => sys_clk,
					s_axis_phase_tvalid => '1',
					s_axis_phase_tdata => nco_pinc(ii), 
					m_axis_dout_tvalid => nco_out_vld(ii),
					m_axis_dout_tdata => nco_data(ii)
				);

		u_cmpy_pll: cmpy_pll
		port map(
				 aclk => sys_clk,
				 s_axis_a_tvalid => s_axis_a_tvalid,
				 s_axis_a_tdata  => s_axis_a_tdata(ii),
				 s_axis_b_tvalid => s_axis_b_tvalid,
				 s_axis_b_tdata  => s_axis_b_tdata(ii),
				 m_axis_dout_tvalid => m_axis_dout_tvalid(ii),
				 m_axis_dout_tdata  => m_axis_dout_tdata(ii)
			 );

		iq_sign(ii) <= m_axis_dout_tdata(ii)(56) & m_axis_dout_tdata(ii)(24);
		phase_detection_imag(ii) <= m_axis_dout_tdata(ii)(56 downto 32);
		phase_detection_real(ii) <= m_axis_dout_tdata(ii)(24 downto 0);

	end generate gen_nco;

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if rst_n = '0' then
				pll_vld_d <= (others=>'0');
			else
				pll_vld_d <= pll_vld_d(pll_vld_d'high-1 downto 0)& m_axis_dout_tvalid(0);
			end if;
			sync_symb_en <= m_axis_dout_tvalid(0);
			-- Q9.14 tuncated to Q7.0
			for ii in 0 to N-1 loop
				if phase_detection_real(ii)(24 downto 21) = "0000" or phase_detection_real(ii)(24 downto 21) = "1111" then
					sync_symb_i(ii) <= phase_detection_real(ii)(21 downto 14) ;
				elsif phase_detection_real(ii)(24)='1' then
					sync_symb_i(ii) <= x"80";
				elsif phase_detection_real(ii)(24)='0' then
					sync_symb_i(ii) <= x"7F";
				end if;
				if phase_detection_imag(ii)(24 downto 21) = "0000" or phase_detection_imag(ii)(24 downto 21) = "1111" then
					sync_symb_q(ii) <= phase_detection_imag(ii)(21 downto 14) ;
				elsif phase_detection_imag(ii)(24)='1' then
					sync_symb_q(ii) <= x"80";
				elsif phase_detection_imag(ii)(24)='0' then
					sync_symb_q(ii) <= x"7F";
				end if;
				-- Q9.14 +/- Q9.14 = Q10.14
				if m_axis_dout_tvalid(ii) = '1' then
					case iq_sign(ii) is
						when "00" => --  pi/4
							phase_diff(ii) <= signed(phase_detection_imag(ii)) - signed(phase_detection_real(ii));
						when "10" => -- -pi/4
							phase_diff(ii) <= signed(phase_detection_imag(ii)) + signed(phase_detection_real(ii));
						when "01" => -- -3*pi/4
							phase_diff(ii) <= -signed(phase_detection_imag(ii)) - signed(phase_detection_real(ii));
						when "11" => -- 3*pi/4
							phase_diff(ii) <= -signed(phase_detection_imag(ii)) + signed(phase_detection_real(ii));
						when others => null;
					end case;
				end if;
			end loop;
		end if;
	end process;

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			-- Q10.14 + Q10.14 = Q11.14
			if pll_vld_d(0) = '1' then
				for ii in 0 to N/2 -1 loop
					err_1(ii) <= resize(phase_diff(2*ii),26) + resize(phase_diff(2*ii+1),26);
				end loop;
			end if;
			-- Q11.15 + Q11.15 = Q12.14
			if pll_vld_d(1)  = '1' then
				for ii in 0 to N/4 -1 loop
					err_2(ii) <= resize(err_1(2*ii),27) + resize(err_1(2*ii+1),27);
				end loop;
			end if;
			-- Q12.15 + Q12.15 = Q13.14
			if pll_vld_d(2) = '1' then
				err <= resize(err_2(0),28) + resize(err_2(1),28);
			end if;
		end if;
	end process;


	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			-- err Q13.14 / 8 = Q10.17
			-- err_avg = Q10.5
			if pll_vld_d(3) = '1' then
				err_avg <= err(27 downto 12)
		end if;
	end process;

	-- K1 = (1/2^11+1/2^9); K1*Q10.5 = Q0.16 + Q1.14
	-- K2 = (1/2^11);	K2*Q10.5 = Q0.16
	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if rst_n = '0' then
				int_temp <= (others=>'0');
			else
				if pll_vld_d(4)  = '1' then
					-- Q1.14 -> Q1.16
					K11xerr <= resize(err_avg,18) sll 2;
					-- Q0.16 -> Q1.16
					K2xerr <= resize(err_avg,18);
				end if; 
				if pll_vld_d(5)  = '1' then
					-- Q1.16 + Q1.16 = Q2.16
					K1xerr <= resize(K2xerr,19) + resize(K11xerr, 19);
					-- Q2.16 -> Q7.16
					int_temp <= int_temp + resize(K2xerr,24);
				end if; 
				-- Q7.16
				if pll_vld_d(6)  = '1' then
					if int_temp > ZEROP25 then
						int_out <= ZEROP25_Q0p16;
					elsif int_temp < -ZEROP25 then
						int_out <= -ZEROP25_Q0p16;
					else
						int_out <= int_temp(16 downto 0);
					end if;
				end if;
			end if;
		end if;
	end process;

	-- Q0.16 * 8 = Q3.13
	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if pll_vld_d(7)  = '1' then
				-- Q2.16 -> Q2.13
				-- Q2.13 + Q3.13  = Q4.13
				loop_out <= resize(K1xerr(18 downto 3),18) + resize(int_out,18);
				-- Q4.13 -> Q8.13
				intx1  <= resize(int_out,22);
				intx2  <= resize(int_out,22) sll 1;
				intx4  <= resize(int_out,22) sll 2;
				intx8  <= resize(int_out,22) sll 3;
			end if;
		end if;
	end process;

	-- Q8.13
	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if rst_n = '0' then
				phase_int <= (others=>'0');
			else
				if pll_vld_d(8)  = '1' then
					phase_int <= phase_int + resize(loop_out,22);
					intx1_t   <= intx1;
					intx2_t   <= intx2;
					intx3_t   <= intx1 + intx2; 
					intx4_t   <= intx4;
					intx5_t   <= intx1 + intx4;
					intx6_t   <= intx2 + intx4;
					intx7_t   <= intx8 - intx1;
					intx8_t   <= intx8;
				end if;
			end if;
		end if;
	end process;

	-- Q8.26
	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if pll_vld_d(9) = '1' then
				if phase_int > PI_Q8P26 then
					phase_int_wrap <= phase_int - DOUBLE_PI_Q8P26;
				elsif phase_int < - PI_Q8P26 then
					phase_int_wrap <= phase_int + DOUBLE_PI_Q8P26;
				else
					phase_int_wrap <= phase_int;
				end if;
			end if;
		end if;
	end process;

	-- Q9.26 (36 bits)
	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if pll_vld_d(10) = '1' then
				phase_int_v(0) <= phase_int_wrap + resize(intx1_t,36); 
				phase_int_v(1) <= phase_int_wrap + resize(intx2_t,36); 
				phase_int_v(2) <= phase_int_wrap + resize(intx3_t,36); 
				phase_int_v(3) <= phase_int_wrap + resize(intx4_t,36); 
				phase_int_v(4) <= phase_int_wrap + resize(intx5_t,36); 
				phase_int_v(5) <= phase_int_wrap + resize(intx6_t,36); 
				phase_int_v(6) <= phase_int_wrap + resize(intx7_t,36); 
				phase_int_v(7) <= phase_int_wrap + resize(intx8_t,36); 
			end if;
		end if;
	end process;

	-- Q9.26 (36 bits)
	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			for ii in 0 to N-1 loop
				if pll_vld_d(11) = '1' then
					if phase_int_v(ii) > PI_Q9P26 then
						phase_int_v_wrap(ii) <= phase_int_v(ii) - DOUBLE_PI_Q9P26;
					elsif phase_int_v(ii) < - PI_Q9P26 then
						phase_int_v_wrap(ii) <= phase_int_v(ii) + DOUBLE_PI_Q9P26;
					else
						phase_int_v_wrap(ii) <= phase_int_v(ii);
					end if;
				end if;
			end loop;
		end if;
	end process;

	-- Q2.13 (16 bits)
	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			nco_cfg_vld	<= pll_vld_d(12);
			for ii in 0 to N-1 loop
				if pll_vld_d(12) = '1' then
					if signed(phase_int_v_wrap(ii)) > PI_Q9P26 then
						phase_int_v_wrap_fix(ii) <= std_logic_vector(PI_Q2P13);
					elsif signed(phase_int_v_wrap(ii)) < - PI_Q9P26 then
						phase_int_v_wrap_fix(ii) <= std_logic_vector(-PI_Q2P13);
					else
						phase_int_v_wrap_fix(ii) <= std_logic_vector(phase_int_v_wrap(ii)(28 downto 13));
					end if;
				end if;
			end loop;
		end if;
	end process;

end rtl;

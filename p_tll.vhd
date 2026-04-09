----------------------------------------------------------------
-- Entity: p_tll
-- Author: Dong Yue
-- Date: 2026-04-01 15:55:05
----------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library work;
use work.my_dem_pkg.all;

entity p_tll is
	generic(N:integer:=4);
    Port (
        sys_clk : in  std_logic;
        rst_n   : in  std_logic;
		iq_vld : in std_logic;
		data_i : in std_logic_array_8(N-1 downto 0);
		data_q : in std_logic_array_8(N-1 downto 0);
		symb_en : out std_logic_vector(N-1 downto 0):=(others=>'0');
		symb_i : out std_logic_array_16(N-1 downto 0):=(others=>(others=>'0'));
		symb_q : out std_logic_array_16(N-1 downto 0):=(others=>(others=>'0'))
    );
end p_tll;

architecture rtl of p_tll is
	-- Q3.16（符号位 1 + 整数位3 + 16 位小数）即可用 20 位定点整数表示
	constant ONE 		: unsigned(15 downto 0):= to_unsigned(65535,16);
	constant HALF_ONE 	: unsigned(15 downto 0):= to_unsigned(32768,16);
	constant K1 		: signed(16 downto 0):= to_signed(-4764,17);
	constant K2 		: signed(16 downto 0):= to_signed(-6,17);
	signal iq_vld_d		: std_logic_vector(12 downto 0):=(others=>'0');
	signal data_i_reg   : std_logic_array_8(0 to N-1):=(others=>(others=>'0'));
	signal data_q_reg 	: std_logic_array_8(0 to N-1):=(others=>(others=>'0'));
	signal CNT  		: unsigned(15 downto 0):= ONE;
	signal W 			: unsigned(15 downto 0):= to_unsigned(32768,16);
	signal Wx1 			: unsigned(15 downto 0):= to_unsigned(32768,16);
	signal Wx2 			: unsigned(16 downto 0):= to_unsigned(32768,17);
	signal Wx3 			: unsigned(16 downto 0):= to_unsigned(32768,17);
	signal Wx4 			: unsigned(17 downto 0):= to_unsigned(32768,18);
	signal Wx5 			: unsigned(17 downto 0):= to_unsigned(32768,18);
	signal Wx6 			: unsigned(17 downto 0):= to_unsigned(32768,18);
	signal Wx7 			: unsigned(18 downto 0):= to_unsigned(32768,19);
	signal Wx8 			: unsigned(18 downto 0):= to_unsigned(32768,19);
	signal underflow 	: std_logic_vector(0 to N-1):=(others=>'0');
	signal diff			: unsigned_array_16(0 to N-1):=(others=>(others=>'0'));
	signal mu 			: unsigned_array_17(0 to N-1):=(others=>(others=>'0'));
	signal mu_vec		: unsigned_array_17(0 to N-1):=(others=>(others=>'0'));
	signal interp_i_vec : std_logic_array_8(0 to N-1):=(others=>(others=>'0'));
	signal interp_q_vec : std_logic_array_8(0 to N-1):=(others=>(others=>'0'));
	signal xI 			: signed_array_26(0 to N-1):=(others=>(others=>'0'));
	signal xQ 			: signed_array_26(0 to N-1):=(others=>(others=>'0'));
	signal xI_t 		: signed_array_18(0 to N-1):=(others=>(others=>'0'));
	signal xQ_t 		: signed_array_18(0 to N-1):=(others=>(others=>'0'));
	signal TEDBuffI 	: signed_array_18(0 to 1):=(others=>(others=>'0'));
	signal TEDBuffQ 	: signed_array_18(0 to 1):=(others=>(others=>'0'));
	signal e_vec 		: signed_array_36(0 to N-1):=(others=>(others=>'0'));
	signal e_add 		: signed_array_18(0 to N/2-1):=(others=>(others=>'0'));
	signal e_add1		: signed_array_19(0 to N/4-1):=(others=>(others=>'0'));
	signal e_total 		: signed(19 downto 0):=(others=>'0');
	signal vp,vi_p    	: signed(35 downto 0):=(others=>'0');
	signal v			: signed(35 downto 0):=(others=>'0');
	signal v_next		: signed(35 downto 0):=(others=>'0');
	signal vi			: signed(35 downto 0):=(others=>'0');
	signal vi_next		: signed(35 downto 0):=(others=>'0');
	constant V_MAX : signed(35 downto 0) := to_signed(16384,36);
	constant V_MIN : signed(35 downto 0) := to_signed(-16384,36);
	constant VI_MAX : signed(35 downto 0) := to_signed(16384,36);
	constant VI_MIN : signed(35 downto 0) := to_signed(-16384,36);
begin

	-- calculate diff for all branches
    process(sys_clk)
    begin
        if rising_edge(sys_clk) then
			iq_vld_d(0)  <= iq_vld;
			iq_vld_d(1)  <= iq_vld_d(0);
			iq_vld_d(2)  <= iq_vld_d(1);
			iq_vld_d(3)  <= iq_vld_d(2);
			iq_vld_d(4)  <= iq_vld_d(3);
			iq_vld_d(5)  <= iq_vld_d(4);
			iq_vld_d(6)  <= iq_vld_d(5);
			iq_vld_d(7)  <= iq_vld_d(6);
			iq_vld_d(8)  <= iq_vld_d(7);
			iq_vld_d(9)  <= iq_vld_d(8);
			iq_vld_d(10) <= iq_vld_d(9);
			iq_vld_d(11) <= iq_vld_d(10);
			iq_vld_d(12) <= iq_vld_d(11);
			if iq_vld = '1' then
				for ii in 0 to N-1 loop
					data_i_reg(ii) <= data_i(ii);
					data_q_reg(ii) <= data_q(ii);
					Wx1 <= W;
					Wx2 <= W&'0';
					Wx3 <= W + W&"0";
					Wx4 <= W&"00";
					Wx5 <= W + W&"00";
					Wx6 <= W&"00" + W&'0';
					Wx7 <= W&"000" - W;
					Wx8 <= W&"000";
				end loop;
			end if;
			if iq_vld_d(0) = '1' then
				diff(0) <= CNT ;
				diff(1) <= CNT - Wx1(15 downto 0);
				diff(2) <= CNT - Wx2(15 downto 0);
				diff(3) <= CNT - Wx3(15 downto 0);
				diff(4) <= CNT - Wx4(15 downto 0);
				diff(5) <= CNT - Wx5(15 downto 0);
				diff(6) <= CNT - Wx6(15 downto 0);
				diff(7) <= CNT - Wx7(15 downto 0);
				CNT <= CNT - Wx8(15 downto 0);
			end if;
        end if;
    end process;

	-- update mu when underflow
	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if iq_vld_d(1) = '1' then
				for ii in 0 to N - 1 loop
					if diff(ii) < W then
						underflow(ii) <= '1';
						mu(ii) <= diff(ii)&'0';
					else
						underflow(ii) <= '0';
					end if;
				end loop;
			end if;
		end if;
	end process;

	-- keep mu when not underflow
	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if iq_vld_d(2) = '1' then
				if underflow(0) = '1' then
					mu_vec(0) <= mu(0);
				else
					mu_vec(0) <= mu_vec(N-1);
				end if;
				if underflow(1) = '1' then
					mu_vec(1) <= mu(1);
				else
					mu_vec(1) <= mu_vec(0);
				end if;
				if underflow(2) = '1' then
					mu_vec(2) <= mu(2);
				else
					mu_vec(2) <= mu_vec(1);
				end if;
				if underflow(3) = '1' then
					mu_vec(3) <= mu(3);
				else
					mu_vec(3) <= mu_vec(2);
				end if;
				if underflow(4) = '1' then
					mu_vec(4) <= mu(4);
				else
					mu_vec(4) <= mu_vec(3);
				end if;
				if underflow(5) = '1' then
					mu_vec(5) <= mu(5);
				else
					mu_vec(5) <= mu_vec(4);
				end if;
				if underflow(6) = '1' then
					mu_vec(6) <= mu(6);
				else
					mu_vec(6) <= mu_vec(5);
				end if;
				if underflow(7) = '1' then
					mu_vec(7) <= mu(7);
				else
					mu_vec(7) <= mu_vec(6);
				end if;
			end if;
		end if;
	end process;

	-- interpolation, Q0.17 * Q0.7 = Q.0.24
	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if iq_vld_d(3) = '1' then
				xI(0) <= signed(mu_vec(0)(16)&mu_vec(0)) * signed(data_i_reg(0)) + (signed(to_signed(65535,18))-signed(mu_vec(0)(16)&mu_vec(0))) * signed(xd_i);
				xQ(0) <= signed(mu_vec(0)(16)&mu_vec(0)) * signed(data_q_reg(0)) + (signed(to_signed(65535,18))-signed(mu_vec(0)(16)&mu_vec(0))) * signed(xd_q);
				for ii in 1 to N - 1 loop
					xI(ii) <= signed(mu_vec(ii)(16)&mu_vec(ii)) * signed(data_i_reg(ii)) + (signed(to_signed(65535,18))-signed(mu_vec(ii)(16)&mu_vec(ii))) * signed(data_i_reg(ii-1));
					xQ(ii) <= signed(mu_vec(ii)(16)&mu_vec(ii)) * signed(data_q_reg(ii)) + (signed(to_signed(65535,18))-signed(mu_vec(ii)(16)&mu_vec(ii))) * signed(data_q_reg(ii-1));
				end loop;
				xd_i <= data_i_reg(N-1); 
				xd_q <= data_q_reg(N-1);
			end if;
		end if;
	end process;

	-- truncation, Q0.24 -> Q0.17
	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if iq_vld_d(4) = '1' then
				for ii in 1 to N - 1 loop
					xI_t(ii) <= xI(ii)(24 downto 7);
					xQ_t(ii) <= xQ(ii)(24 downto 7);
				end loop;
			end if;
		end if;
	end process;

	-- calculate error 
	-- Q0.17 * Q0.17 -> Q0.34(two signed bits)
	-- so Q0.34 + Q0.34 = Q1.34, 
	-- a signed bit is used as an integer bit.
	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if iq_vld_d(5) = '1' then
				if underflow(0) = '1' then
					e_vec(0) <= TEDBuffI(0)*(TEDBuffI(1) - xI_t(0)) + TEDBuffQ(0)*(TEDBuffQ(1) - xQ_t(0)); 
				else
					e_vec(0) <= (others=>'0');
				end if;
				if underflow(1) = '1' then
					e_vec(1) <= xI_t(0) * (TEDBuffI(0) - xI_t(1)) + xQ_t(0) * (TEDBuffQ(0) - xQ_t(1));
				else
					e_vec(1) <= (others=>'0');
				end if;
				if underflow(2) = '1' then
					e_vec(2) <= xI_t(1) * (xI_t(0) - xI_t(2)) + xQ_t(1) * (xQ_t(0) - xQ_t(2));
				else
					e_vec(2) <= (others=>'0');
				end if;
				if underflow(3) = '1' then
					e_vec(3) <= xI_t(2) * (xI_t(1) - xI_t(3)) + xQ_t(2) * (xQ_t(1) - xQ_t(3));
				else
					e_vec(3) <= (others=>'0');
				end if;
				if underflow(4) = '1' then
					e_vec(4) <= xI_t(3) * (xI_t(2) - xI_t(4)) + xQ_t(3) * (xQ_t(2) - xQ_t(4));
				else
					e_vec(4) <= (others=>'0');
				end if;
				if underflow(5) = '1' then
					e_vec(5) <= xI_t(4) * (xI_t(3) - xI_t(5)) + xQ_t(4) * (xQ_t(3) - xQ_t(5));
				else
					e_vec(5) <= (others=>'0');
				end if;
				if underflow(6) = '1' then
					e_vec(6) <= xI_t(5) * (xI_t(4) - xI_t(6)) + xQ_t(5) * (xQ_t(4) - xQ_t(6));
				else
					e_vec(6) <= (others=>'0');
				end if;
				if underflow(7) = '1' then
					e_vec(7) <= xI_t(6) * (xI_t(5) - xI_t(7)) + xQ_t(6) * (xQ_t(5) - xQ_t(7));
				else
					e_vec(7) <= (others=>'0');
				end if;
				TEDBuffI(0) <= xI_t(N-1);
				TEDBuffI(1) <= xI_t(N-2);
				TEDBuffQ(0) <= xQ_t(N-1);
				TEDBuffQ(1) <= xQ_t(N-2);
			end if;
		end if;
	end process;

	-- parallel adder, 
	-- Q1.16 + Q1.16 = Q2.16
	-- Q2.16 + Q2.16 = Q3.16
	-- Q3.16 + Q3.16 = Q4.16
	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if iq_vld_d(6) = '1' then
				e_add(0) <= resize(e_vec(0)(35 downto 19),18) + resize(e_vec(1)(35 downto 19),18);
				e_add(1) <= resize(e_vec(2)(35 downto 19),18) + resize(e_vec(3)(35 downto 19),18);
				e_add(2) <= resize(e_vec(4)(35 downto 19),18) + resize(e_vec(5)(35 downto 19),18);
				e_add(3) <= resize(e_vec(6)(35 downto 19),18) + resize(e_vec(7)(35 downto 19),18);
			end if;
			if iq_vld_d(7) = '1' then
				e_add1(0) <= resize(e_add(0),19) + resize(e_add(1),19);
				e_add1(1) <= resize(e_add(2),19) + resize(e_add(3),19);
			end if;
			if iq_vld_d(8) = '1' then
				e_total <= resize(e_add1(0),20) + resize(e_add1(1),20);
			end if;
		end if;
	end process;

	--  loop filter, Q4.16 / 4 = Q2.16
	-- Q2.16 * Q0.16 = Q2.32 
	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if iq_vld_d(9) = '1' then
				vp   <= K1 * e_total(e_total'high downto 2);
				vi_p <= K2 * e_total(e_total'high downto 2);
			end if;
			if iq_vld_d(10) = '1' then
				vi_next <= vi + vi_p;
			end if;
			if iq_vld_d(11) = '1' then
				if vi_next > VI_MAX then
					vi <= VI_MAX;
				elsif vi_next < VI_MIN then
					vi <= VI_MIN;
				else
					vi <= vi_next;
				end if;
			end if;
			if iq_vld_d(12) = '1' then
				v_next <= vi + vp;
			end if;
			if iq_vld_d(13) = '1' then
				if v_next > V_MAX then
					v <= V_MAX;
				elsif v_next < V_MIN then
					v <= V_MIN;
				else
					v <= v_next;
				end if;
			end if;
		end if;
	end process;

	-- update W, loop gain 2^16
	-- Q2.16 * Q0.16 = Q2.32, only keep the fractional part.
	-- 2 signed bits, 2 integer bits, 32 fractional bits
	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if iq_vld_d(12) = '1' then
				W <= HALF_ONE + unsigned(v(31 downto 16));
			end if;
		end if;
	end process;
	

end rtl;

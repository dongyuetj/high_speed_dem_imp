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
	constant ONE 		: unsigned(15 downto 0):= (others=>'1');
	constant HALF_ONE 	: unsigned(15 downto 0):= to_unsigned(2**15,16);
	constant K1 		: signed(16 downto 0):= to_signed(-3072,17);
	constant K2 		: signed(16 downto 0):= to_signed(-32,17);
	constant V_MAX 		: signed(40 downto 0):=to_signed(2**39,41);
	constant V_MIN 		: signed(40 downto 0):=to_signed(-2**39,41);
	constant VI_MAX 	: signed(40 downto 0):=to_signed(2**14,41);
	constant VI_MIN 	: signed(40 downto 0):=to_signed(-2**14,41);
	constant ONE_Q1p16 	: signed(17 downto 0):=to_signed(2**16,18);
	signal iq_vld_d		: std_logic_vector(18 downto 0):=(others=>'0');
	signal data_i_reg   : std_logic_array_8(0 to N-1):=(others=>(others=>'0'));
	signal data_q_reg 	: std_logic_array_8(0 to N-1):=(others=>(others=>'0'));
	signal xd_i,xd_q	: std_logic_vector(7 downto 0):=(others=>'0');
	signal CNT  		: unsigned(15 downto 0):= ONE;
	signal W 			: unsigned(15 downto 0):= to_unsigned(2**15,16);
	signal Wx1 			: unsigned(15 downto 0):= to_unsigned(2**15,16);
	signal Wx2 			: unsigned(16 downto 0):= to_unsigned(2**15,17);
	signal Wx3 			: unsigned(16 downto 0):= to_unsigned(2**15,17);
	signal Wx4 			: unsigned(17 downto 0):= to_unsigned(2**15,18);
	signal Wx5 			: unsigned(17 downto 0):= to_unsigned(2**15,18);
	signal Wx6 			: unsigned(17 downto 0):= to_unsigned(2**15,18);
	signal Wx7 			: unsigned(18 downto 0):= to_unsigned(2**15,19);
	signal Wx8 			: unsigned(18 downto 0):= to_unsigned(2**15,19);
	signal underflow 	: std_logic_vector(0 to N-1):=(others=>'0');
	signal diff			: unsigned_array_16(0 to N-1):=(others=>(others=>'0'));
	signal mu 			: unsigned_array_18(0 to N-1):=(others=>(others=>'0'));
	signal mu_ext 		: signed_array_18(0 to N-1):=(others=>(others=>'0'));
	signal one_minus_mu	: signed_array_18(0 to N-1):=(others=>(others=>'0'));
	signal mu_cur 		: unsigned(17 downto 0):=(others=>'0');
	signal mulI0		: signed_array_26(0 to N-1):=(others=>(others=>'0'));
	signal mulQ0		: signed_array_26(0 to N-1):=(others=>(others=>'0'));
	signal mulI1		: signed_array_26(0 to N-1):=(others=>(others=>'0'));
	signal mulQ1		: signed_array_26(0 to N-1):=(others=>(others=>'0'));
	signal interp_i_vec : std_logic_array_8(0 to N-1):=(others=>(others=>'0'));
	signal interp_q_vec : std_logic_array_8(0 to N-1):=(others=>(others=>'0'));
	signal xI 			: signed_array_26(0 to N-1):=(others=>(others=>'0'));
	signal xQ 			: signed_array_26(0 to N-1):=(others=>(others=>'0'));
	signal xI_t 		: signed_array_19(0 to N-1):=(others=>(others=>'0'));
	signal xQ_t 		: signed_array_19(0 to N-1):=(others=>(others=>'0'));
	signal TEDBuffI 	: signed_array_19(0 to 1):=(others=>(others=>'0'));
	signal TEDBuffQ 	: signed_array_19(0 to 1):=(others=>(others=>'0'));
	signal diffI 		: signed_array_20(0 to N-1):=(others=>(others=>'0'));
	signal diffQ 		: signed_array_20(0 to N-1):=(others=>(others=>'0'));
	signal mulI 		: signed_array_39(0 to N-1):=(others=>(others=>'0'));
	signal mulQ 		: signed_array_39(0 to N-1):=(others=>(others=>'0'));
	signal e_vec 		: signed_array_39(0 to N-1):=(others=>(others=>'0'));
	signal e_add 		: signed_array_25(0 to N/2-1):=(others=>(others=>'0'));
	signal e_add1		: signed_array_26(0 to N/4-1):=(others=>(others=>'0'));
	signal e_total 		: signed(26 downto 0):=(others=>'0');
	signal e_in 		: signed(24 downto 0):=(others=>'0');
	signal vp,vi_p    	: signed(40 downto 0):=(others=>'0');
	signal v			: signed(40 downto 0):=(others=>'0');
	signal v_next		: signed(40 downto 0):=(others=>'0');
	signal vi			: signed(40 downto 0):=(others=>'0');
	signal vi_next		: signed(40 downto 0):=(others=>'0');
	signal vp_1, vp_2   : signed(40 downto 0):=(others=>'0');
begin       

	-- calculate diff for all branches
    process(sys_clk)
    begin
        if rising_edge(sys_clk) then
			iq_vld_d <= iq_vld_d(iq_vld_d'high-1 downto 0) & iq_vld;
			if iq_vld = '1' then
				for ii in 0 to N-1 loop
					data_i_reg(ii) <= data_i(ii);
					data_q_reg(ii) <= data_q(ii);
				end loop;
				Wx1 <= W;
				Wx2 <= (W&'0');
				Wx3 <= ('0'&W)+ (W&'0');
				Wx4 <= (W&"00");
				Wx5 <= ("00"&W) + (W&"00");
				Wx6 <= (W&"00") + ('0'&W&'0');
				Wx7 <= (W&"000") - ("000"&W);
				Wx8 <= (W&"000");
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
						-- unsigned 16 was extended to Q1.16 by adding a signed bit and an integer bit
						mu(ii) <= '0' & diff(ii) & '0';
					else
						underflow(ii) <= '0';
						mu(ii) <= mu_cur;
					end if;
				end loop;
			end if;
		end if;
	end process;

	-- interpolation 
	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if iq_vld_d(2) = '1' then
				for ii in 0 to N-1 loop
					mu_ext(ii)        <= signed(mu(ii));
					one_minus_mu(ii)  <= ONE_Q1p16 - signed(mu(ii));
				end loop;
			end if;
			-- Q1.16 * Q0.7 = Q1.23, 2 signed bits + 23 fractional bits
			if iq_vld_d(3) = '1' then
				for ii in 0 to N-1 loop
					mulI0(ii) <= mu_ext(ii) * signed(data_i_reg(ii));
					mulQ0(ii) <= mu_ext(ii) * signed(data_q_reg(ii));
				end loop;
				for ii in 1 to N-1 loop
					mulI1(ii) <= one_minus_mu(ii) * signed(data_i_reg(ii-1));
					mulQ1(ii) <= one_minus_mu(ii) * signed(data_q_reg(ii-1));
				end loop;
				mulI1(0) <= one_minus_mu(0) * signed(xd_i);
				mulQ1(0) <= one_minus_mu(0) * signed(xd_q);
			end if;
			-- Q1.23 + Q1.23 = Q2.23
			if iq_vld_d(4) = '1' then
				for ii in 0 to N-1 loop
					xI(ii) <= mulI0(ii) + mulI1(ii); -- do not need to extention due to 2 signed bits
					xQ(ii) <= mulQ0(ii) + mulQ1(ii);
				end loop;
				xd_i <= data_i_reg(N-1); 
				xd_q <= data_q_reg(N-1);
				mu_cur <= mu(N-1);
			end if;
		end if;
	end process;

	-- truncation, Q2.23 -> Q2.16
	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if iq_vld_d(5) = '1' then
				for ii in 0 to N - 1 loop
					xI_t(ii) <= xI(ii)(25 downto 7);
					xQ_t(ii) <= xQ(ii)(25 downto 7);
				end loop;
			end if;
		end if;
	end process;

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if iq_vld_d(6) = '1' then
				for ii in 0 to N-1 loop
					if underflow(ii) = '1' then
						symb_en(ii) <= '1';
						symb_i(ii)  <= std_logic_vector(xI_t(ii)(18 downto 3));
						symb_q(ii)  <= std_logic_vector(xQ_t(ii)(18 downto 3));
					else
						symb_en(ii) <= '0';
					end if;
				end loop;
			else
				symb_en <= (others=>'0');
			end if;
		end if;
	end process;

	-- calculate error 
	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if iq_vld_d(6) = '1' then
				TEDBuffI(0) <= xI_t(N-1);
				TEDBuffI(1) <= xI_t(N-2);
				TEDBuffQ(0) <= xQ_t(N-1);
				TEDBuffQ(1) <= xQ_t(N-2);
				-- Q2.16 - Q2.16 = Q3.16 , vld6
				diffI(0) <= resize(TEDBuffI(1),20) - resize(xI_t(0),20);
				diffQ(0) <= resize(TEDBuffQ(1),20) - resize(xQ_t(0),20);
				diffI(1) <= resize(TEDBuffI(0),20) - resize(xI_t(1),20);
				diffQ(1) <= resize(TEDBuffQ(0),20) - resize(xQ_t(1),20);
				for ii in 2 to N-1 loop
					diffI(ii) <= resize(xI_t(ii-2),20) - resize(xI_t(ii),20);
					diffQ(ii) <= resize(xQ_t(ii-2),20) - resize(xQ_t(ii),20);
				end loop;
			end if;
			if iq_vld_d(7) = '1' then
				-- Q3.16 * Q3.16 = Q6.32 (two signed bits) , vld7
				mulI(0)  <= TEDBuffI(0)* diffI(0);
				mulQ(0)  <= TEDBuffQ(0)* diffQ(0);
				mulI(1)  <= xI_t(0) * diffI(1) ;
				mulQ(1)  <= xQ_t(0) * diffQ(1) ;
				for ii in 2 to N-1 loop
					mulI(ii)  <= xI_t(ii-1) * diffI(ii);
					mulQ(ii)  <= xQ_t(ii-1) * diffQ(ii);
				end loop;
			end if;
			if iq_vld_d(8) = '1' then
				for ii in 0 to N-1 loop
					-- Q6.32 + Q6.32 = Q7.32 (two signed bits) , vld8
					if underflow(ii) = '1' then
						e_vec(ii) <= mulI(ii) + mulQ(ii);
					else
						e_vec(ii) <= (others=>'0');
					end if;
				end loop;
			end if;
		end if;
	end process;

	-- parallel adder, 
	-- Q7.32 -> Q7.16
	-- Q7.16 + Q7.16 = Q8.16
	-- Q5.16 + Q5.16 = Q9.16
	-- Q6.16 + Q6.16 = Q10.16
	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if iq_vld_d(9) = '1' then
				e_add(0) <= resize(e_vec(0)(36 downto 12),25) + resize(e_vec(1)(36 downto 12),25);
				e_add(1) <= resize(e_vec(2)(36 downto 12),25) + resize(e_vec(3)(36 downto 12),25);
				e_add(2) <= resize(e_vec(4)(36 downto 12),25) + resize(e_vec(5)(36 downto 12),25);
				e_add(3) <= resize(e_vec(6)(36 downto 12),25) + resize(e_vec(7)(36 downto 12),25);
			end if;
			if iq_vld_d(10) = '1' then
				e_add1(0) <= resize(e_add(0),26) + resize(e_add(1),26);
				e_add1(1) <= resize(e_add(2),26) + resize(e_add(3),26);
			end if;
			if iq_vld_d(11) = '1' then
				e_total <= resize(e_add1(0),27) + resize(e_add1(1),27);
			end if;
		end if;
	end process;

	e_in <= e_total(e_total'high downto 2);
	--  loop filter, Q10.16 / 4 = Q8.16
	-- Q8.16 * Q0.16 = Q8.32 
	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if iq_vld_d(12) = '1' then
				vp_1 <= - (resize(e_in, vp'length) sll 11);
				vp_2 <= - (resize(e_in, vp'length) sll 10);
				vi_p <= - (resize(e_in, vi_p'length) sll 5);
			end if;
			if iq_vld_d(13) = '1' then
				vp <=  vp_1 + vp_2;
			end if;
			if iq_vld_d(14) = '1' then
				vi_next <= vi + vi_p;
			end if;
			if iq_vld_d(15) = '1' then
				if vi_next > VI_MAX then
					vi <= VI_MAX;
				elsif vi_next < VI_MIN then
					vi <= VI_MIN;
				else
					vi <= vi_next;
				end if;
			end if;
			if iq_vld_d(16) = '1' then
				v_next <= vi + vp;
			end if;
			-- Q8.32
			if iq_vld_d(17) = '1' then
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
	-- Q8.32, only keep the fractional part.
	-- 2 signed bits, 2 integer bits, 32 fractional bits
	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if iq_vld_d(18) = '1' then
				W <= HALF_ONE + unsigned(v(31 downto 16));
			end if;
		end if;
	end process;

end rtl;

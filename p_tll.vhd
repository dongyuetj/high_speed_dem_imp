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
	constant ONE 		: signed(19 downto 0):= to_signed(65536,20);
	constant HALF_ONE 	: signed(19 downto 0):= to_signed(32768,20);
	constant K1 		: signed(19 downto 0):= to_signed(-4764,20);
	constant K2 		: signed(19 downto 0):= to_signed(-6,20);
	signal CNT  		: signed(19 downto 0):= ONE;
	signal W 			: signed(19 downto 0):= HALF_ONE;
	signal underflow 	: std_logic_vector(0 to N-1):=(others=>'0');
	signal mu 			: signed_array_20(0 to N-1):=(others=>(others=>'0'));
	signal interp_i_vec : std_logic_array_8(0 to N-1):=(others=>(others=>'0'));
	signal interp_q_vec : std_logic_array_8(0 to N-1):=(others=>(others=>'0'));
	signal TEDBuffI 	: std_logic_array_8(0 to N-1):=(others=>(others=>'0'));
	signal TEDBuffQ 	: std_logic_array_8(0 to N-1):=(others=>(others=>'0'));
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
			if iq_vld = '1' then
				diff(0) <= CNT ;
				diff(1) <= CNT - signed(W);
				diff(2) <= CNT - signed(W&'0');
				diff(3) <= CNT - W - signed(W&'0');
				CNT <= CNT - signed(W&"00");
			end if;
        end if;
    end process;

	-- update mu when underflow
	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if iq_vld_d(0) = '1' then
				for ii in 0 to N - 1 loop
					if signed(diff(ii)) < signed(W) then
						mu(ii) <= diff(ii)(15 downto 0)&'0';
						underflow(ii) <= '1';
					else
						underflow(ii) <= '0';
					end if;
				end if;
			end if;
		end if;
	end process;

	-- keep mu when not underflow
	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if iq_vld_d(1) = '1' then
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

	-- interpolation
	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if iq_vld_d(2) = '1' then
				xI(0) <= mu_vec(0)*data_i(0) + (1-mu_vec(0)) * xd_i(ii-1);
				xQ(0) <= mu_vec(0)*data_q(0) + (1-mu_vec(0)) * xd_q(ii-1);
				for ii in 1 to N - 1 loop
					xI(ii) <= mu_vec(ii)*data_i(ii) + (1-mu_vec(ii)) * data_i(ii-1);
					xQ(ii) <= mu_vec(ii)*data_q(ii) + (1-mu_vec(ii)) * data_q(ii-1);
				end loop;
				xd_i <= data_i(N); 
				xd_q <= data_q(N);
			end if;
		end if;
	end process;

	-- calculate error 
	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if iq_vld_d(3) = '1' then
				if underflow(0) = '1' then
					e_vec(0) <= TEDBuffI(0)*(TEDBuffI(1) - xI(0)) + TEDBuffQ(0)*(TEDBuffQ(1) - xQ(0)); 
				else
					e_vec(0) <= (others=>'0');
				end if;
				if underflow(1) = '1' then
					e_vec(1) <= xI(0) * (TEDBuffI(0) - xI(1)) + xQ(0) * (TEDBuffQ(0) - xQ(1));
				else
					e_vec(1) <= (others=>'0');
				end if;
				if underflow(2) = '1' then
					e_vec(2) <= xI(1) * (xI(0) - xI(2)) + xQ(1) * (xQ(0) - xQ(2));
				else
					e_vec(2) <= (others=>'0');
				end if;
				if underflow(3) = '1' then
					e_vec(3) <= xI(2) * (xI(1) - xI(3)) + xQ(2) * (xQ(1) - xQ(3));
				else
					e_vec(3) <= (others=>'0');
				end if;
				if underflow(4) = '1' then
					e_vec(4) <= xI(3) * (xI(2) - xI(4)) + xQ(3) * (xQ(2) - xQ(4));
				else
					e_vec(4) <= (others=>'0');
				end if;
				if underflow(5) = '1' then
					e_vec(5) <= xI(4) * (xI(3) - xI(5)) + xQ(4) * (xQ(3) - xQ(5));
				else
					e_vec(5) <= (others=>'0');
				end if;
				if underflow(6) = '1' then
					e_vec(6) <= xI(5) * (xI(4) - xI(6)) + xQ(5) * (xQ(4) - xQ(6));
				else
					e_vec(6) <= (others=>'0');
				end if
				if underflow(7) = '1' then
					e_vec(7) <= xI(6) * (xI(5) - xI(7)) + xQ(6) * (xQ(5) - xQ(7));
				else
					e_vec(7) <= (others=>'0');
				end if
				TEDBuffI(0) <= xI(N-1);
				TEDBuffI(1) <= xI(N-2);
				TEDBuffQ(0) <= xQ(N-1);
				TEDBuffQ(1) <= xQ(N-2);
			end if;
		end if;
	end process;

	-- parallel adder
	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if iq_vld_d(4) = '1' then
				e_add(0) <= e_vec(0) + e_vec(1);
				e_add(1) <= e_vec(2) + e_vec(3);
				e_add(2) <= e_vec(4) + e_vec(5);
				e_add(3) <= e_vec(6) + e_vec(7);
			end if;
			if iq_vld_d(5) = '1' then
				e_add1(0) <= e_add(0) + e_add(1);
				e_add1(1) <= e_add(2) + e_add(3);
			end if;
			if iq_vld_d(6) = '1' then
				e_total <= e_add1(0) + e_add1(1);
			end if;
		end if;
	end process;

	--  TLL
	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if iq_vld_d(7) = '1' then
				vp   <= K1 * e_total(e_total'high downto 2);
				vi_p <= K2 * e_total(e_total'high downto 2);
			end if;
			if iq_vld_d(8) = '1' then
				vi <= vi + vi_p
			end if;
			if iq_vld_d(9) = '1' then
				v = vp + vi;
			end if;
		end if;
	end process;

	-- update W
	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if iq_vld_d(10) = '1' then
				W <= HALF_ONE + v(v'high downto 17);
			end if;
		end if;
	end process;
	

end rtl;



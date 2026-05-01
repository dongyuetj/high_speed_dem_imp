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
	generic(N:integer:=16);
    Port (
        sys_clk : in  std_logic;
        rst_n   : in  std_logic;
		iq_vld : in std_logic;
		data_i : in std_logic_array_8(0 to N-1);
		data_q : in std_logic_array_8(0 to N-1);
		symb_en : out std_logic_vector(0 to N-1):=(others=>'0');
		symb_i : out std_logic_array_16(0 to N-1):=(others=>(others=>'0'));
		symb_q : out std_logic_array_16(0 to N-1):=(others=>(others=>'0'));
		loop_out_vld : out std_logic:='0';
		loop_dout	 : out std_logic_vector(31 downto 0):=(others=>'0')
    );
end p_tll;

architecture rtl of p_tll is

	constant ONE 		: unsigned(15 downto 0):= (others=>'1');
	constant HALF_ONE 	: unsigned(15 downto 0):= to_unsigned(2**15,16);
	-- -3072/2^16, Q0.16
	constant K1 		: signed(16 downto 0):= to_signed(-3072,17);
	-- -32/2^16, Q0.16
	constant K2 		: signed(16 downto 0):= to_signed(-32,17);
	-- 128, Q15.16
	constant V_MAX 		: signed(31 downto 0):= to_signed(2**23,32);
	-- -128, Q15.16
	constant V_MIN 		: signed(31 downto 0):=  to_signed(-2**23,32);
	-- 0.25, Q15.16
	constant VI_MAX 	: signed(31 downto 0):= to_signed(2**14,32);
	-- -0.25, Q15.16
	constant VI_MIN 	: signed(31 downto 0):= to_signed(-2**14,32);

	-- 4095
	constant E_MAX 		: signed(12 downto 0):=  to_signed(4095,13);
	-- -4096
	constant E_MIN 		: signed(12 downto 0):= to_signed(-4096,13);

	-- 1, Q1.16
	constant ONE_Q1p16 	: signed(17 downto 0):= to_signed(2**16,18);

	signal first_data_in_flag : std_logic:='0';
	signal iq_vld_d		: std_logic_vector(18 downto 0):=(others=>'0');
	signal data_i_reg   : std_logic_array_8(0 to 2*N-1):=(others=>(others=>'0'));
	signal data_q_reg 	: std_logic_array_8(0 to 2*N-1):=(others=>(others=>'0'));
	signal CNT  		: unsigned(15 downto 0):= (others=>'0');
	signal W 			: unsigned(15 downto 0):= to_unsigned(2**15,16);
	signal underflow 	: std_logic_vector(0 to N-1):=(others=>'0');
	signal diff			: unsigned_array_16(0 to N-1):=(others=>(others=>'0'));
	signal mu_ext 		: std_logic_array_18(0 to N-1):=(others=>(others=>'0'));
	signal one_minus_mu	: signed_array_18(0 to N-1):=(others=>(others=>'0'));
	signal mu_cur 		: std_logic_vector(17 downto 0):=(others=>'0');
	signal mulI0		: signed_array_26(0 to N-1):=(others=>(others=>'0'));
	signal mulQ0		: signed_array_26(0 to N-1):=(others=>(others=>'0'));
	signal mulI1		: signed_array_26(0 to N-1):=(others=>(others=>'0'));
	signal mulQ1		: signed_array_26(0 to N-1):=(others=>(others=>'0'));
	signal interp_i_vec : std_logic_array_8(0 to N-1):=(others=>(others=>'0'));
	signal interp_q_vec : std_logic_array_8(0 to N-1):=(others=>(others=>'0'));
	signal xI 			: signed_array_26(0 to N-1):=(others=>(others=>'0'));
	signal xQ 			: signed_array_26(0 to N-1):=(others=>(others=>'0'));
	signal xI_t 		: signed_array_16(0 to N-1):=(others=>(others=>'0'));
	signal xQ_t 		: signed_array_16(0 to N-1):=(others=>(others=>'0'));
	signal TEDBuffI 	: signed_array_16(0 to 1):=(others=>(others=>'0'));
	signal TEDBuffQ 	: signed_array_16(0 to 1):=(others=>(others=>'0'));
	signal diffI 		: signed_array_17(0 to N-1):=(others=>(others=>'0'));
	signal diffQ 		: signed_array_17(0 to N-1):=(others=>(others=>'0'));
	signal mulI 		: signed_array_33(0 to N-1):=(others=>(others=>'0'));
	signal mulQ 		: signed_array_33(0 to N-1):=(others=>(others=>'0'));
	signal e_vec 		: signed_array_33(0 to N-1):=(others=>(others=>'0'));
	signal e_vec_int	: signed_array_13(0 to N-1):=(others=>(others=>'0'));
	signal e_add 		: signed_array_14(0 to N/2-1):=(others=>(others=>'0'));
	signal e_add1		: signed_array_16(0 to 1):=(others=>(others=>'0'));
	signal e_total 		: signed(16 downto 0):=(others=>'0');
	signal e_in 		: signed(13 downto 0):=(others=>'0');
	signal vp    	: signed(31 downto 0):=(others=>'0');
	signal v			: signed(31 downto 0):=(others=>'0');
	signal vi			: signed(31 downto 0):=(others=>'0');
	attribute MARK_DEBUG : string;
	attribute MARK_DEBUG of mu_cur : signal is "TRUE";
begin       

	-- calculate diff for all branches
	--	Wx1 <= W;
	--	Wx2 <= (W&'0');
	--	Wx3 <= ('0'&W)+ (W&'0');
	--	Wx4 <= (W&"00");
	--	Wx5 <= ("00"&W) + (W&"00");
	--	Wx6 <= (W&"00") + ('0'&W&'0');
	--	Wx7 <= (W&"000") - ("000"&W);
	--	Wx8 <= (W&"000");
	--	Wx9 <= (W&"000");
	--	Wx10 <= (W&"000");
	--	Wx11 <= (W&"000");
	--	Wx12 <= (W&"000");
	--	Wx13 <= (W&"000");
	--	Wx14 <= (W&"000");
	--	Wx15 <= (W&"000");
	--	Wx16 <= (W&"0000");

    process(sys_clk)
    begin
        if rising_edge(sys_clk) then
			if rst_n = '0' then
				CNT <= (others=>'0');
				first_data_in_flag <= '0';
				iq_vld_d <= (others=>'0');
			else
				if first_data_in_flag = '1' then
					iq_vld_d <= iq_vld_d(iq_vld_d'high-1 downto 0) & iq_vld;
				else
					iq_vld_d <= (others=>'0');
				end if;
				if iq_vld = '1' then
					first_data_in_flag <= '1';
					for ii in 0 to N-1 loop
						data_i_reg(ii+N) <= data_i(ii);
						data_q_reg(ii+N) <= data_q(ii);
						data_i_reg(ii) <= data_i_reg(ii+N);
						data_q_reg(ii) <= data_q_reg(ii+N);
					end loop;
					diff(0)  <= CNT ;
					diff(1)  <= CNT - W;
					diff(2)  <= CNT - (W sll 1);
					diff(3)  <= CNT - (W sll 1) - W;
					diff(4)  <= CNT - (W sll 2);
					diff(5)  <= CNT - (W sll 2) - W;
					diff(6)  <= CNT - (W sll 2) - (W sll 1);
					diff(7)  <= CNT - (W sll 3)+ W;
					diff(8)  <= CNT - (W sll 3);
					diff(9)  <= CNT - (W sll 3) - W; 
					diff(10) <= CNT - (W sll 3) - (W sll 1); 
					diff(11) <= CNT - (W sll 3) - (W sll 1) - W;
					diff(12) <= CNT - (W sll 3) - (W sll 2);
					diff(13) <= CNT - (W sll 3) - (W sll 2) - W;
					diff(14) <= CNT - (W sll 4) + (W sll 1);
					diff(15) <= CNT - (W sll 4) + W;
					CNT <= CNT - (W sll 4);
				end if;
			end if;
        end if;
    end process;

	-- update mu when underflow
	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if iq_vld_d(0) = '1' then
				for ii in 0 to N - 1 loop
					if diff(ii) < W then
						underflow(ii) <= '1';
						-- unsigned 16 was extended to Q1.16 by adding a signed bit and an integer bit
						mu_ext(ii)        <= std_logic_vector('0' & diff(ii) & '0');
						one_minus_mu(ii)  <= ONE_Q1p16 - signed('0' & diff(ii) & '0');
					else
						underflow(ii) <= '0';
						mu_ext(ii)        <= mu_cur;
						one_minus_mu(ii)  <= ONE_Q1p16 - signed(mu_cur);
					end if;
				end loop;
			end if;
		end if;
	end process;

	-- interpolation 
	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			-- Q1.16 * Q7.0 = Q8.16, 2 signed bits + 8 integer bits + 16 fractional bits
			if iq_vld_d(1) = '1' then
				for ii in 0 to N-1 loop
					mulI0(ii) <= signed(mu_ext(ii)) * signed(data_i_reg(N+ii));
					mulQ0(ii) <= signed(mu_ext(ii)) * signed(data_q_reg(N+ii));
					mulI1(ii) <= one_minus_mu(ii) * signed(data_i_reg(N+ii-1));
					mulQ1(ii) <= one_minus_mu(ii) * signed(data_q_reg(N+ii-1));
				end loop;
			end if;
			-- Q8.16 + Q8.16 = Q9.16
			if rst_n = '0' then
				mu_cur <= std_logic_vector(to_unsigned(2**15,18));
			else
				if iq_vld_d(2) = '1' then
					for ii in 0 to N-1 loop
						xI(ii) <= mulI0(ii) + mulI1(ii); -- do not need to extention due to 2 signed bits
						xQ(ii) <= mulQ0(ii) + mulQ1(ii);
					end loop;
				end if;
				if underflow(N-1) = '1' then
					mu_cur <= mu_ext(N-1);
				elsif underflow(N-2) = '1' then
					mu_cur <= mu_ext(N-2);
				elsif underflow(N-3) = '1' then
					mu_cur <= mu_ext(N-3);
				elsif underflow(N-4) = '1' then
					mu_cur <= mu_ext(N-4);
				elsif underflow(N-5) = '1' then
					mu_cur <= mu_ext(N-5);
				elsif underflow(N-6) = '1' then
					mu_cur <= mu_ext(N-6);
				elsif underflow(N-7) = '1' then
					mu_cur <= mu_ext(N-7);
				elsif underflow(N-8) = '1' then
					mu_cur <= mu_ext(N-8);
				elsif underflow(N-9) = '1' then
					mu_cur <= mu_ext(N-9);
				elsif underflow(N-10) = '1' then
					mu_cur <= mu_ext(N-10);
				elsif underflow(N-11) = '1' then
					mu_cur <= mu_ext(N-11);
				elsif underflow(N-12) = '1' then
					mu_cur <= mu_ext(N-12);
				elsif underflow(N-13) = '1' then
					mu_cur <= mu_ext(N-13);
				elsif underflow(N-14) = '1' then
					mu_cur <= mu_ext(N-14);
				elsif underflow(N-15) = '1' then
					mu_cur <= mu_ext(N-15);
				elsif underflow(N-16) = '1' then
					mu_cur <= mu_ext(N-16);
				end if;
			end if;
		end if;
	end process;

	-- truncation, Q9.16 -> Q9.6
	gen: for ii in 0 to N-1 generate
		xI_t(ii) <= xI(ii)(25 downto 10);
		xQ_t(ii) <= xQ(ii)(25 downto 10);
	end generate gen;

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			symb_en <= (others => '0');
			for i in 0 to N-1 loop
				if iq_vld_d(3+i) = '1' then
					if underflow(i) = '1' then
						symb_en(i) <= '1';
						symb_i(i)  <= std_logic_vector(xI_t(i));
						symb_q(i)  <= std_logic_vector(xQ_t(i));
					end if;
				end if;
			end loop;
		end if;
	end process;

	-- calculate error 
	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if iq_vld_d(3) = '1' then
				-- Q9.6 - Q9.6 = Q10.6 
				diffI(0) <= resize(TEDBuffI(1),17) - resize(xI_t(0),17);
				diffQ(0) <= resize(TEDBuffQ(1),17) - resize(xQ_t(0),17);
				diffI(1) <= resize(TEDBuffI(0),17) - resize(xI_t(1),17);
				diffQ(1) <= resize(TEDBuffQ(0),17) - resize(xQ_t(1),17);
				for ii in 2 to N-1 loop
					diffI(ii) <= resize(xI_t(ii-2),17) - resize(xI_t(ii),17);
					diffQ(ii) <= resize(xQ_t(ii-2),17) - resize(xQ_t(ii),17);
				end loop;
			end if;
			if iq_vld_d(4) = '1' then
				-- Q9.6 * Q10.6 = Q19.12 (two signed bits) , vld7
				mulI(0)  <= TEDBuffI(0)* diffI(0);
				mulQ(0)  <= TEDBuffQ(0)* diffQ(0);
				mulI(1)  <= xI_t(0) * diffI(1) ;
				mulQ(1)  <= xQ_t(0) * diffQ(1) ;
				for ii in 2 to N-1 loop
					mulI(ii)  <= xI_t(ii-1) * diffI(ii);
					mulQ(ii)  <= xQ_t(ii-1) * diffQ(ii);
				end loop;
			end if;
			if iq_vld_d(5) = '1' then
				for ii in 0 to N-1 loop
					-- Q19.12 + Q19.12 = Q20.12
					if underflow(ii) = '1' then
						e_vec(ii) <= mulI(ii) + mulQ(ii);
					else
						e_vec(ii) <= (others=>'0');
					end if;
				end loop;
				TEDBuffI(0) <= xI_t(N-1);
				TEDBuffI(1) <= xI_t(N-2);
				TEDBuffQ(0) <= xQ_t(N-1);
				TEDBuffQ(1) <= xQ_t(N-2);
			end if;
		end if;
	end process;

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if iq_vld_d(6) = '1' then
				for ii in 0 to N-1 loop
					if signed(e_vec(ii)(32 downto 12)) > signed(E_MAX) then
						e_vec_int(ii) <= E_MAX; -- 4095
					elsif signed(e_vec(ii)(32 downto 12)) < signed(E_MIN) then
						e_vec_int(ii) <= E_MIN; -- -4096
					else
						e_vec_int(ii) <= e_vec(ii)(24 downto 12);
					end if;
				end loop;
			end if;
		end if;
	end process;

	-- parallel adder, 
	-- Q20.12 -> Q12.0
	-- Q12.0 + Q12.0 -> Q13.0
	-- Q12.0 + Q12.0 -> Q14.0
	-- Q12.0 + Q12.0 -> Q15.0

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if iq_vld_d(7) = '1' then
				e_add1(0) <= resize(e_vec_int(0),16) + resize(e_vec_int(1),16) + resize(e_vec_int(2),16) + resize(e_vec_int(3),16) + resize(e_vec_int(4),16) + resize(e_vec_int(5),16) + resize(e_vec_int(6),16) + resize(e_vec_int(7),16);
				e_add1(1) <= resize(e_vec_int(8),16) + resize(e_vec_int(9),16) + resize(e_vec_int(10),16) + resize(e_vec_int(11),16) + resize(e_vec_int(12),16) + resize(e_vec_int(13),16) + resize(e_vec_int(14),16) + resize(e_vec_int(15),16);
			end if;
			if iq_vld_d(8) = '1' then
				e_total <= resize(e_add1(0),17) + resize(e_add1(1),17);
			end if;
		end if;
	end process;

	e_in <= e_total(e_total'high downto 3);

	--  loop filter, Q15.0 / 4 = Q13.0
	-- Q13.0 * Q0.16 = Q13.16 (two signed bits) 
	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if rst_n = '0' then
				vi <= (others=>'0');
				vp <= (others=>'0');
				v  <= (others=>'0');
			else
				if iq_vld_d(9) = '1' then
					vi <= vi - (resize(e_in, vi'length) sll 5);
					vp <=  -(resize(e_in, vp'length) sll 11) - (resize(e_in, vp'length) sll 10); 
				end if;
				if iq_vld_d(10) = '1' then
					v <= vi + vp;
				end if;
			end if;
		end if;
	end process;

	loop_out_vld <= iq_vld_d(10);
	loop_dout <= std_logic_vector(v) ;

	-- update W, loop gain 2^16
	-- Q8.32, only keep the fractional part.
	-- 2 signed bits, 2 integer bits, 32 fractional bits
	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if rst_n = '0' then
				W <= HALF_ONE ;
			elsif iq_vld_d(11) = '1' then
				W <= HALF_ONE + unsigned(v(31 downto 16));
			end if;
		end if;
	end process;

end rtl;

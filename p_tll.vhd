----------------------------------------------------------------
-- Entity: p_tll
-- Author: Dong Yue
-- Date: 2026-04-01 15:55:05
----------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use ieee.std_logic_textio.all;
use std.textio.all;
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
	-- -0.4428 * 2^17
	constant K1 		: signed(17 downto 0):= to_signed(-58040,18);
	-- -0.0015 * 2^17 
	constant K2 		: signed(17 downto 0):= to_signed(-194,18);
--	-- 128, Q15.16
--	constant V_MAX 		: signed(31 downto 0):= to_signed(2**23,32);
--	-- -128, Q15.16
--	constant V_MIN 		: signed(31 downto 0):=  to_signed(-2**23,32);
--	-- 0.25, Q15.16
--	constant VI_MAX 	: signed(31 downto 0):= to_signed(2**14,32);
--	-- -0.25, Q15.16
--	constant VI_MIN 	: signed(31 downto 0):= to_signed(-2**14,32);
	-- 4095
	constant E_MAX 		: signed(12 downto 0):=  to_signed(4095,13);
	-- -4096
	constant E_MIN 		: signed(12 downto 0):= to_signed(-4096,13);

	signal iq_vld_d		: std_logic_vector(18 downto 0):=(others=>'0');
	signal data_i_reg   : std_logic_array_8(0 to N):=(others=>(others=>'0'));
	signal data_q_reg 	: std_logic_array_8(0 to N):=(others=>(others=>'0'));
	signal CNT  		: unsigned(15 downto 0):= (others=>'0');
	signal W 			: unsigned(15 downto 0):= HALF_ONE;
	signal underflow 	: std_logic_vector(0 to N-1):="0101010101010101";
	signal underflow_hist 	: std_logic_vector(0 to N):="10101010101010101";
	signal e_vld     	: std_logic_vector(0 to N-1):="0101010101010101";
	signal diff			: unsigned_array_16(0 to N-1):=(others=>(others=>'0'));
	signal mu 		    : unsigned_array_16(0 to N-1):=(others=>(others=>'0'));
	signal one_minus_mu	: unsigned_array_16(0 to N-1):=(others=>(others=>'1'));
	signal mu_tmp 		: unsigned_array_16(0 to N-1):=(others=>(others=>'0'));
	signal one_minus_mu_tmp	: unsigned_array_16(0 to N-1):=(others=>(others=>'0'));
	signal mu_cur       : unsigned(15 downto 0):=(others=>'0');
	signal mulI0		: signed_array_26(0 to N-1):=(others=>(others=>'0'));
	signal mulQ0		: signed_array_26(0 to N-1):=(others=>(others=>'0'));
	signal mulI1		: signed_array_26(0 to N-1):=(others=>(others=>'0'));
	signal mulQ1		: signed_array_26(0 to N-1):=(others=>(others=>'0'));
	signal xI 			: signed_array_26(0 to N-1):=(others=>(others=>'0'));
	signal xQ 			: signed_array_26(0 to N-1):=(others=>(others=>'0'));
	signal xI_t 		: signed_array_16(0 to N-1):=(others=>(others=>'0'));
	signal xQ_t 		: signed_array_16(0 to N-1):=(others=>(others=>'0'));
	signal histBuffI 	: signed_array_16(0 to N+1):=(others=>(others=>'0'));
	signal histBuffQ 	: signed_array_16(0 to N+1):=(others=>(others=>'0'));
	signal diffI 		: signed_array_17(0 to N-1):=(others=>(others=>'0'));
	signal diffQ 		: signed_array_17(0 to N-1):=(others=>(others=>'0'));
	signal mulI 		: signed_array_33(0 to N-1):=(others=>(others=>'0'));
	signal mulQ 		: signed_array_33(0 to N-1):=(others=>(others=>'0'));
	signal e_vec 		: signed_array_34(0 to N-1):=(others=>(others=>'0'));
	signal e_vec_int	: signed_array_16(0 to N-1):=(others=>(others=>'0'));
	signal e_add1		: signed_array_16(0 to 1):=(others=>(others=>'0'));
	signal e_total 		: signed(16 downto 0):=(others=>'0');
	signal e_in 		: signed(13 downto 0):=(others=>'0');
	signal vp    	    : signed(31 downto 0):=(others=>'0');
	signal vi			: signed(31 downto 0):=(others=>'0');
	signal v			: signed(31 downto 0):=(others=>'0');
	signal v_t			: std_logic_vector(15 downto 0):=(others=>'0');
    signal cnt_symb          : unsigned(15 downto 0):=(others=>'0');
	attribute MARK_DEBUG : string;
	attribute MARK_DEBUG of mu_cur : signal is "TRUE";
    file rec_w_err : text open write_mode is "err.txt";
    file rec_w_w : text open write_mode is "w.txt";
    file rec_w_v : text open write_mode is "v.txt";
    file rec_w_mu : text open write_mode is "mu.txt";
begin       

    -- pipeline vld
    process(sys_clk)
    begin
        if rising_edge(sys_clk) then
			if rst_n = '0' then
				iq_vld_d <= (others=>'0');
			else
                iq_vld_d <= iq_vld_d(iq_vld_d'high-1 downto 0) & iq_vld;
			end if;
        end if;
    end process;

	-- register input samples
	process(sys_clk)
    begin
        if rising_edge(sys_clk) then
            if iq_vld = '1' then
                for ii in 0 to N-1 loop
                    data_i_reg(ii+1) <= data_i(ii);
                    data_q_reg(ii+1) <= data_q(ii);
                end loop;
                data_i_reg(0) <= data_i_reg(N);
                data_q_reg(0) <= data_q_reg(N);
            end if;
        end if;
    end process;

	-- interpolation 
	process(sys_clk)
    begin
        if rising_edge(sys_clk) then
            -- Q1.16 * Q7.0 = Q8.16, 2 signed bits + 8 integer bits + 16 fractional bits
            if iq_vld_d(0) = '1' then
                for ii in 0 to N-1 loop
                    mulI0(ii) <= signed(resize(one_minus_mu(ii),18)) * signed(data_i_reg(ii));
                    mulQ0(ii) <= signed(resize(one_minus_mu(ii),18)) * signed(data_q_reg(ii));
                    mulI1(ii) <= signed(resize(mu(ii),18)) * signed(data_i_reg(ii+1));
                    mulQ1(ii) <= signed(resize(mu(ii),18)) * signed(data_q_reg(ii+1));
                end loop;
            end if;
			-- Q8.16 + Q8.16 = Q9.16
            if iq_vld_d(1) = '1' then
                for jj in 0 to N-1 loop
                    xI(jj) <= mulI0(jj) + mulI1(jj); -- do not need to extention due to 2 signed bits
                    xQ(jj) <= mulQ0(jj) + mulQ1(jj);
                end loop;
            end if;
        end if;
    end process;

	-- truncation, Q9.16 -> Q9.6
	gen: for ii in 0 to N-1 generate
		xI_t(ii) <= xI(ii)(25 downto 10);
		xQ_t(ii) <= xQ(ii)(25 downto 10);
	end generate gen;

    -- output symbols
	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			symb_en <= (others => '0');
			for i in 0 to N-1 loop
				if iq_vld_d(2+i) = '1' then
					if underflow(i) = '1' then
						symb_en(i) <= '1';
						symb_i(i)  <= std_logic_vector(xI_t(i));
						symb_q(i)  <= std_logic_vector(xQ_t(i));
					end if;
				end if;
			end loop;
		end if;
	end process;

	gen1: for jj in 0 to N-1 generate
		histBuffI(jj+2) <= xI_t(jj);
		histBuffQ(jj+2) <= xQ_t(jj);
	end generate gen1;

	-- GDTED
	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
            -- pre - cur
			if iq_vld_d(2) = '1' then
				-- Q9.6 - Q9.6 = Q10.6 
				for ii in 2 to N+1 loop
					diffI(ii-2) <= resize(histBuffI(ii-2),17) - resize(histBuffI(ii),17);
					diffQ(ii-2) <= resize(histBuffQ(ii-2),17) - resize(histBuffQ(ii),17);
				end loop;
			end if;
            -- mid * (pre - cur)
			if iq_vld_d(3) = '1' then
				-- Q9.6 * Q10.6 = Q19.12 (two signed bits) , vld7
				for jj in 2 to N+1 loop
					mulI(jj-2)  <= histBuffI(jj-1) * diffI(jj-2);
					mulQ(jj-2)  <= histBuffQ(jj-1) * diffQ(jj-2);
				end loop;
			end if;
			if iq_vld_d(4) = '1' then
				for kk in 0 to N-1 loop
					-- Q19.12 + Q19.12 = Q20.12
                    e_vec(kk) <=resize(mulI(kk),34) + resize(mulQ(kk),34);
				end loop;
                   -- histBuffI(1) <= histBuffI(N+1);
                   -- histBuffQ(1) <= histBuffQ(N+1);
                   -- histBuffI(0) <= histBuffI(N);
                   -- histBuffQ(0) <= histBuffQ(N);
                -- store history samples
                if underflow(N-1) = '0' and underflow(N-2) = '1' then
                    histBuffI(1) <= histBuffI(N+1);
                    histBuffQ(1) <= histBuffQ(N+1);
                elsif underflow(N-1) = '1' and underflow(N-2) = '0' then
                    histBuffI(1) <= histBuffI(N+1);
                    histBuffQ(1) <= histBuffQ(N+1);
                elsif underflow(N-1) = '1' and underflow(N-2) = '1' then
                    histBuffI(1) <= (others=>'0');
                    histBuffQ(1) <= (others=>'0');
                end if;
                if underflow(N-2) = '0' and underflow(N-3) = '1' then
                    histBuffI(0) <= histBuffI(N);
                    histBuffQ(0) <= histBuffQ(N);
                elsif underflow(N-2) = '1' and underflow(N-3) = '0' then
                    histBuffI(0) <= histBuffI(N);
                    histBuffQ(0) <= histBuffQ(N);
                elsif underflow(N-2) = '1' and underflow(N-3) = '1' then
                    histBuffI(0) <= (others=>'0');
                    histBuffQ(0) <= (others=>'0');
                end if;
			end if;
		end if;
	end process;

    -- error constraint
    -- make equivalent to matlab
	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if iq_vld_d(5) = '1' then
				for ii in 0 to N-1 loop
			--		if signed(e_vec(ii)(32 downto 12)) > signed(E_MAX) then
			--			e_vec_int(ii) <= E_MAX; -- 4095
			--		elsif signed(e_vec(ii)(32 downto 12)) < signed(E_MIN) then
			--			e_vec_int(ii) <= E_MIN; -- -4096
			--		else
                    if e_vld(ii) = '1' then
						e_vec_int(ii) <= e_vec(ii)(27 downto 12);
                    else
						e_vec_int(ii) <= (others=>'0');
                    end if;
			--		end if;
				end loop;
			end if;
		end if;
	end process;

	-- parallel adder 
	-- Q20.12 -> Q12.0
	-- 16 to 8: Q12.0 + Q12.0 -> Q13.0
	-- 8 to 4 : Q13.0 + Q13.0 -> Q14.0
	-- 4 to 2 : Q14.0 + Q14.0 -> Q15.0
    -- 2 to 1 : Q15.0 + Q15.0 -> Q16.0

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if iq_vld_d(6) = '1' then
				e_add1(0) <= e_vec_int(0) + e_vec_int(1) + e_vec_int(2) + e_vec_int(3) + e_vec_int(4) + e_vec_int(5) + e_vec_int(6) + e_vec_int(7);
				e_add1(1) <= e_vec_int(8) + e_vec_int(9) + e_vec_int(10) + e_vec_int(11) + e_vec_int(12) + e_vec_int(13) + e_vec_int(14) + e_vec_int(15);
			end if;
			if iq_vld_d(7) = '1' then
				e_total <= resize(e_add1(0),17) + resize(e_add1(1),17);
			end if;
		end if;
	end process;

	e_in <= e_total(e_total'high downto 3);

    process(sys_clk)
        variable buf : line;
    begin
        if rising_edge(sys_clk) then
            if iq_vld_d(8) = '1' then
                cnt_symb <= cnt_symb + 1;
                write(buf, to_integer(signed(e_in)));
                writeline(rec_w_err, buf);
            end if;
        end if;
    end process;


	-- e_in, Q16.0 / 8 = Q13.0
	-- Q13.0 * Q0.17 = Q13.17 (two signed bits) 
	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if rst_n = '0' then
				vp <= (others=>'0');
				vi <= (others=>'0');
				v  <= (others=>'0');
			else
				if iq_vld_d(8) = '1' then
			--		vp <=  -(resize(e_in, vp'length) sll 11) - (resize(e_in, vp'length) sll 10); 
			--		vi <= vi - (resize(e_in, vi'length) sll 5);
                    vp <= K1 * e_in; 
                    vi <= vi + K2 * e_in;
				end if;
                -- Q13.17 + Q13.17 = Q14.17
				if iq_vld_d(9) = '1' then
					v <= vi + vp;
				end if;
			end if;
		end if;
	end process;

    process(sys_clk)
        variable buf : line;
    begin
        if rising_edge(sys_clk) then
            if iq_vld_d(10) = '1' then
                write(buf, to_integer(v));
                writeline(rec_w_v, buf);
            end if;
        end if;
    end process;

	loop_out_vld <= iq_vld_d(9);
	loop_dout <= std_logic_vector(v) ;

	-- update W, loop gain 2^16
    -- fraction part [16:0]
    -- integer part [30:17]
    -- signed [31]

    v_t <= std_logic_vector(resize(v(31 downto 17),16));

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if rst_n = '0' then
				W <= HALF_ONE ;
			elsif iq_vld_d(10) = '1' then
				W <= HALF_ONE + unsigned(v_t);
			end if;
		end if;
	end process;

    process(sys_clk)
        variable buf : line;
    begin
        if rising_edge(sys_clk) then
            if iq_vld_d(11) = '1' then
                write(buf, to_integer(W));
                writeline(rec_w_w, buf);
            end if;
        end if;
    end process;

    -- calculate diff
	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if rst_n = '0' then
				CNT <= (others=>'0');
			elsif iq_vld_d(11) = '1' then
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
    end process;

	-- update mu
	process(sys_clk)
        variable mu_val      : unsigned(15 downto 0);
        variable one_mu_val  : unsigned(15 downto 0);
	begin
		if rising_edge(sys_clk) then
			if rst_n = '0' then
				mu_cur <= (others=>'0');
			else
                if iq_vld_d(12) = '1' then
                    underflow_hist(0) <= underflow(N-1);
                    -- update mu when underflow
                    for ii in 0 to N - 1 loop
                        if diff(ii) < W then
                            underflow(ii) <= '1';
                            underflow_hist(ii+1) <= '1';
                        else
                            underflow(ii) <= '0';
                            underflow_hist(ii+1) <= '0';
                        end if;
                        -- calculate mu and 1-mu no matter underflow
                        -- unsigned 16 was extended to Q1.16 by adding a signed bit and an integer bit
                        mu_tmp(ii)            <= unsigned(diff(ii)(14 downto 0)&'0');
                        one_minus_mu_tmp(ii)  <= ONE - unsigned(diff(ii)(14 downto 0)&'0');
                        -- init mu and 1-mu with mu_cur
                        mu(ii)        <= mu_cur;
                        one_minus_mu(ii)  <= ONE - mu_cur;
                    end loop;
                end if;
                if iq_vld_d(13) = '1' then
                    for jj in 0 to N-1 loop
                        if underflow(jj) = '1' then
                            mu_val     := mu_tmp(jj);
                            one_mu_val := one_minus_mu_tmp(jj);
                        end if;
                        mu(jj)       <= mu_val;
                        one_minus_mu(jj) <= one_mu_val;
                        if underflow_hist(jj+1) = '1' and underflow_hist(jj) = '0' then
                            e_vld(jj) <= '1';
                        else
                            e_vld(jj) <= '0';
                        end if;
                    end loop;
                end if;
                -- store last valid mu
                if iq_vld_d(14) = '1' then
                    if underflow(15) = '1' then
                        mu_cur <= mu(15);
                    elsif underflow(14) = '1' then
                        mu_cur <= mu(14);
                    elsif underflow(13) = '1' then
                        mu_cur <= mu(13);
                    elsif underflow(12) = '1' then
                        mu_cur <= mu(12);
                    elsif underflow(11) = '1' then
                        mu_cur <= mu(11);
                    elsif underflow(10) = '1' then
                        mu_cur <= mu(10);
                    elsif underflow(9) = '1' then
                        mu_cur <= mu(9);
                    elsif underflow(8) = '1' then
                        mu_cur <= mu(8);
                    elsif underflow(7) = '1' then
                        mu_cur <= mu(7);
                    elsif underflow(6) = '1' then
                        mu_cur <= mu(6);
                    elsif underflow(5) = '1' then
                        mu_cur <= mu(5);
                    elsif underflow(4) = '1' then
                        mu_cur <= mu(4);
                    elsif underflow(3) = '1' then
                        mu_cur <= mu(3);
                    elsif underflow(2) = '1' then
                        mu_cur <= mu(2);
                    elsif underflow(1) = '1' then
                        mu_cur <= mu(1);
                    elsif underflow(0) = '1' then
                        mu_cur <= mu(0);
                    end if;
                end if;
			end if;
		end if;
	end process;


    process(sys_clk)
        variable buf : line;
    begin
        if rising_edge(sys_clk) then
            if iq_vld_d(14) = '1' then
                for ii in 0 to N-1 loop
                    write(buf, to_integer(mu(ii)));
                    writeline(rec_w_mu, buf);
                end loop;
            end if;
        end if;
    end process;


end rtl;

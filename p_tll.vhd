----------------------------------------------------------------
-- Entity: p_tll
-- Author: Dong Yue
-- Date: 2026-04-01 15:55:05
----------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL; use ieee.std_logic_textio.all;
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

    -- Q3.16
	constant ONE 		    : signed(7+15+8 downto 0):= to_signed(2**24,31);
	constant ONE_unsigned 	: unsigned(16+8 downto 0):= "1000000000000000000000000";
	constant HALF_ONE 	    : signed(7+15+8 downto 0):= to_signed(2**23,31);
	-- locked, BnTs = 0.0001
	-- Q0.25
	constant K1 		: signed(25 downto 0):= to_signed(-298137,26);
	-- Q0.25
	constant K2 		: signed(25 downto 0):= to_signed(-20,26);
--	-- catched, BnTs = 0.005
--	-- Q0.25
--	constant K1 		: signed(25 downto 0):= to_signed(-14858231,26);
--	-- Q0.25
--	constant K2 		: signed(25 downto 0):= to_signed(-49527,26);

	signal iq_vld_d		: std_logic_vector(18 downto 0):=(others=>'0');
	signal data_i_reg   : std_logic_array_8(0 to N):=(others=>(others=>'0'));
	signal data_q_reg 	: std_logic_array_8(0 to N):=(others=>(others=>'0'));
	signal CNT  		: signed(7+15+8 downto 0):= ONE;
	signal CNT_NEXT  	: signed(7+15+8 downto 0):= (others=>'0');
	signal W 			: signed(7+15+8 downto 0):= HALF_ONE;
	signal Wx1 			: signed(7+15+8 downto 0):= (others=>'0');
	signal Wx2 			: signed(7+15+8 downto 0):= (others=>'0');
	signal Wx3 			: signed(7+15+8 downto 0):= (others=>'0');
	signal Wx4 			: signed(7+15+8 downto 0):= (others=>'0');
	signal Wx5 			: signed(7+15+8 downto 0):= (others=>'0');
	signal Wx6 			: signed(7+15+8 downto 0):= (others=>'0');
	signal Wx7 			: signed(7+15+8 downto 0):= (others=>'0');
	signal Wx8 			: signed(7+15+8 downto 0):= (others=>'0');
	signal Wx9 			: signed(7+15+8 downto 0):= (others=>'0');
	signal Wx10 		: signed(7+15+8 downto 0):= (others=>'0');
	signal Wx11 		: signed(7+15+8 downto 0):= (others=>'0');
	signal Wx12 		: signed(7+15+8 downto 0):= (others=>'0');
	signal Wx13 		: signed(7+15+8 downto 0):= (others=>'0');
	signal Wx14 		: signed(7+15+8 downto 0):= (others=>'0');
	signal Wx15 		: signed(7+15+8 downto 0):= (others=>'0');
	signal Wx16 		: signed(7+15+8 downto 0):= (others=>'0');
	signal underflow_hist 	: std_logic_vector(0 to N):="10101010101010101";
	signal underflow_hist_reg 	: std_logic_vector(0 to N):="10101010101010101";
--	signal e_vld     	: std_logic_vector(0 to N-1):="0101010101010101";
--	signal mu_step 		: unsigned(15 downto 0):= (others=>'0');
	signal diff			: signed_array_31(0 to N):=(others=>(others=>'0'));
	signal mu 		    : unsigned_array_24(0 to N-1):=(others=>(others=>'0'));
	signal one_minus_mu	: unsigned_array_25(0 to N-1):=(others=>"1000000000000000000000000");
	signal mu_tmp 		: unsigned_array_24(0 to N-1):=(others=>(others=>'0'));
    signal mu_pre       : unsigned(15 downto 0):=(others=>'0');
	signal one_minus_mu_ext	: unsigned_array_26(0 to N-1):=(others=>"01000000000000000000000000");
	signal mu_ext 		: unsigned_array_26(0 to N-1):=(others=>(others=>'0'));
	signal one_minus_mu_tmp	: unsigned_array_24(0 to N-1):=(others=>(others=>'0'));
	signal mu_cur       : unsigned(23 downto 0):=(others=>'0');
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
	signal e_vec 		: signed_array_33(0 to N-1):=(others=>(others=>'0'));
	signal e_add		: signed_array_35(0 to 3):=(others=>(others=>'0'));
	signal err 			: signed(36 downto 0):=(others=>'0');
	signal vtmp    	    : signed(62 downto 0):=(others=>'0');
	signal vp    	    : signed(62 downto 0):=(others=>'0');
	signal vi			: signed(62 downto 0):=(others=>'0');
	signal v			: signed(62 downto 0):=(others=>'0');
	signal v_t			: signed(15+7+8 downto 0):=(others=>'0');
    signal cnt_symb          : unsigned(15 downto 0):=(others=>'0');
	attribute MARK_DEBUG : string;
	attribute MARK_DEBUG of mu_cur : signal is "TRUE";
    file rec_w_err : text open write_mode is "err.txt";
    file rec_w_w : text open write_mode is "w.txt";
    file rec_w_v : text open write_mode is "v.txt";
    file rec_w_mu : text open write_mode is "mu.txt";
    file rec_w_cnt : text open write_mode is "cnt.txt";
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

	gen2: for kk in 0 to N-1 generate
		mu_ext(kk) <= resize(mu(kk),26);
		one_minus_mu_ext(kk) <= resize(one_minus_mu(kk),26);
	end generate gen2;

	-- interpolation 
	process(sys_clk)
    begin
        if rising_edge(sys_clk) then
            -- Q1.16 * Q7.0 = Q8.16, 2 signed bits + 8 integer bits + 16 fractional bits
            if iq_vld_d(0) = '1' then
                for ii in 0 to N-1 loop
                    mulI0(ii) <= signed(one_minus_mu_ext(ii)(25 downto 8)) * signed(data_i_reg(ii));
                    mulQ0(ii) <= signed(one_minus_mu_ext(ii)(25 downto 8)) * signed(data_q_reg(ii));
                    mulI1(ii) <= signed(mu_ext(ii)(25 downto 8)) * signed(data_i_reg(ii+1));
                    mulQ1(ii) <= signed(mu_ext(ii)(25 downto 8)) * signed(data_q_reg(ii+1));
                end loop;
            end if;
			-- Q8.16 + Q8.16 = Q9.16
            if iq_vld_d(1) = '1' then
                for jj in 0 to N-1 loop
                    xI(jj) <= mulI0(jj) + mulI1(jj); -- do not need to extention due to 2 signed bits
                    xQ(jj) <= mulQ0(jj) + mulQ1(jj);
                end loop;
                underflow_hist_reg <= underflow_hist;
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
					if underflow_hist_reg(i+1) = '1' then
                        cnt_symb <= cnt_symb + 1;
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
				--	if e_vld(kk) = '1' then
                    if underflow_hist(kk+1) = '1' and underflow_hist(kk) = '0' then
						e_vec(kk) <= mulI(kk) + mulQ(kk);
					else
						e_vec(kk) <= (others=>'0');
					end if;
				end loop;
                   -- histBuffI(1) <= histBuffI(N+1);
                   -- histBuffQ(1) <= histBuffQ(N+1);
                   -- histBuffI(0) <= histBuffI(N);
                   -- histBuffQ(0) <= histBuffQ(N);
                -- store history samples
                if underflow_hist(N) = '0' and underflow_hist(N-1) = '1' then
                    histBuffI(1) <= histBuffI(N+1);
                    histBuffQ(1) <= histBuffQ(N+1);
                    histBuffI(0) <= histBuffI(N);
                    histBuffQ(0) <= histBuffQ(N);
                elsif underflow_hist(N) = '1' and underflow_hist(N-1) = '0' then
                    histBuffI(1) <= histBuffI(N+1);
                    histBuffQ(1) <= histBuffQ(N+1);
                    histBuffI(0) <= histBuffI(N);
                    histBuffQ(0) <= histBuffQ(N);
                elsif underflow_hist(N) = '1' and underflow_hist(N-1) = '1' then
                    histBuffI(1) <= histBuffI(N+1);
                    histBuffQ(1) <= histBuffQ(N+1);
                    histBuffI(0) <= (others=>'0');
                    histBuffQ(0) <= (others=>'0');
                elsif underflow_hist(N) = '0' and underflow_hist(N-1) = '0' then
                    histBuffI(1) <= histBuffI(N);
                    histBuffQ(1) <= histBuffQ(N);
                    histBuffI(0) <= histBuffI(N-1);
                    histBuffQ(0) <= histBuffQ(N-1);
                end if;
			end if;
		end if;
	end process;

	-- parallel adder 

	-- Q20.12 + Q20.12 + Q20.12 + Q20.12 = Q22.12
	-- Q22.12 + Q22.12 + Q22.12 + Q22.12 = Q24.12
	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if iq_vld_d(5) = '1' then
				e_add(0) <= resize(e_vec(0),35)  + resize(e_vec(1),35)  + resize(e_vec(2),35)  + resize(e_vec(3),35);
				e_add(1) <= resize(e_vec(4),35)  + resize(e_vec(5),35)  + resize(e_vec(6),35)  + resize(e_vec(7),35);
				e_add(2) <= resize(e_vec(8),35)  + resize(e_vec(9),35)  + resize(e_vec(10),35) + resize(e_vec(11),35);
				e_add(3) <= resize(e_vec(12),35) + resize(e_vec(13),35) + resize(e_vec(14),35) + resize(e_vec(15),35);
			end if;
			if iq_vld_d(6) = '1' then
				err <= resize(e_add(0),37) + resize(e_add(1),37) + resize(e_add(2),37) + resize(e_add(3),37);
			end if;
		end if;
	end process;

    process(sys_clk)
        variable buf : line;
    begin
        if rising_edge(sys_clk) then
            if iq_vld_d(7) = '1' then
                write(buf, to_integer(signed(err)));
                writeline(rec_w_err, buf);
            end if;
        end if;
    end process;


	-- 37bits * 26bits = 63bits
	-- err, Q24.12 / 8 = Q21.15
	-- Q21.15 * Q0.25 = Q21.40 (two signed bits) 
	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if rst_n = '0' then
				vp <= (others=>'0');
				vi <= (others=>'0');
				v  <= (others=>'0');
			else
				if iq_vld_d(7) = '1' then
				--	if abs(err(36 downto 15)) > 1000  then
				--		vp <= (others=>'0');
				--		vtmp <= (others=>'0');
				--	else
						vp <= K1 * err; 
						vtmp <= K2 * err;
				--	end  if;
				end if;
				--Q21.40 + Q21.40 = Q22.40
				if iq_vld_d(8) = '1' then
                    vi <= vi + vtmp;
				end if;
				--Q22.40 + Q22.40 = Q22.40
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
                write(buf, to_integer(v(62 downto 31)));
                writeline(rec_w_v, buf);
            end if;
        end if;
    end process;

	loop_out_vld <= iq_vld_d(9);
	loop_dout <= std_logic_vector(v(62 downto 31));

	-- update W, loop gain 2^16
	-- Q22.40/2^16 = Q6.56

	-- signed bits: [62]
    -- integer bits:	[61 60 59 58 57 56]
	-- fraction bits: [55:40];
    v_t <= v(62 downto 40-8);

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if rst_n = '0' then
				W <= HALF_ONE ;
			elsif iq_vld_d(10) = '1' then
				W <= HALF_ONE + v_t;
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
	
	 Wx1	<=  W;
	 Wx2    <= (W sll 1);
	 Wx3    <= (W sll 1) + W;
	 Wx4    <= (W sll 2);
	 Wx5    <= (W sll 2) + W;
	 Wx6    <= (W sll 2) + (W sll 1);
	 Wx7    <= (W sll 3) - W;
	 Wx8    <= (W sll 3);
	 Wx9    <= (W sll 3) + W; 
	 Wx10   <= (W sll 3) + (W sll 1); 
	 Wx11   <= (W sll 3) + (W sll 1) + W;
	 Wx12   <= (W sll 3) + (W sll 2);
	 Wx13   <= (W sll 3) + (W sll 2) + W;
	 Wx14   <= (W sll 4) - (W sll 1);
	 Wx15   <= (W sll 4) - W;
	 Wx16   <= (W sll 4);

    -- calculate diff
	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if rst_n = '0' then
				CNT <= ONE;
			elsif iq_vld_d(11) = '1' then
                diff(0)  <= CNT ;
                diff(1)  <= CNT - Wx1;
                diff(2)  <= CNT - Wx2;
                diff(3)  <= CNT - Wx3;
                diff(4)  <= CNT - Wx4 ;
                diff(5)  <= CNT - Wx5 ;
                diff(6)  <= CNT - Wx6 ;
                diff(7)  <= CNT - Wx7 ;
                diff(8)  <= CNT - Wx8 ;
                diff(9)  <= CNT - Wx9 ;
                diff(10) <= CNT - Wx10 ;
                diff(11) <= CNT - Wx11 ;
                diff(12) <= CNT - Wx12 ;
                diff(13) <= CNT - Wx13 ;
                diff(14) <= CNT - Wx14 ;
                diff(15) <= CNT - Wx15 ;
                diff(16) <= CNT - Wx16 ;
                CNT <= CNT - Wx16 ;
			elsif iq_vld_d(12) = '1' then
                CNT(CNT'high downto 16+8) <= (others=>'0');
                CNT_NEXT(15+8 downto 0) <= CNT(15+8 downto 0);
            end if;
        end if;
    end process;

    process(sys_clk)
        variable buf : line;
    begin
        if rising_edge(sys_clk) then
            if iq_vld_d(13) = '1' then
                write(buf, to_integer(CNT_NEXT));
                writeline(rec_w_cnt, buf);
            end if;
        end if;
    end process;


	--mu_step <= unsigned(W(14 downto 0)&'0');

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
                    underflow_hist(0) <= underflow_hist(N);
                    for ii in 0 to N - 1 loop
                        --if diff(ii) < 0 then
                        if unsigned(diff(ii)(15+8 downto 0)) < unsigned(W(15+8 downto 0)) then
                            underflow_hist(ii+1) <= '1';
                        else
                            underflow_hist(ii+1) <= '0';
                        end if;
                    end loop;
                     -- update mu when underflow_hist
                    for ii in 0 to N - 1 loop
                        mu_tmp(ii) <= unsigned(diff(ii)(22 downto 0)&'0');
                        mu(ii) <= mu_cur;
                    end loop;
                end if;
                if iq_vld_d(13) = '1' then
                    if underflow_hist(1) = '1' then
                        for ii in 0 to N-1 loop
                            mu(ii) <= mu_tmp(ii);
                        end loop;
                    end if;
                    if underflow_hist(2) = '1' then
                        for ii in 1 to N-1 loop
                            mu(ii) <= mu_tmp(ii);
                        end loop;
                    end if;
                    if underflow_hist(3) = '1' then
                        for ii in 2 to N-1 loop
                            mu(ii) <= mu_tmp(ii);
                        end loop;
                    end if;
                    if underflow_hist(4) = '1' then
                        for ii in 3 to N-1 loop
                            mu(ii) <= mu_tmp(ii);
                        end loop;
                    end if;
                    if underflow_hist(5) = '1' then
                        for ii in 4 to N-1 loop
                            mu(ii) <= mu_tmp(ii);
                        end loop;
                    end if;
                    if underflow_hist(6) = '1' then
                        for ii in 5 to N-1 loop
                            mu(ii) <= mu_tmp(ii);
                        end loop;
                    end if;
                    if underflow_hist(7) = '1' then
                        for ii in 6 to N-1 loop
                            mu(ii) <= mu_tmp(ii);
                        end loop;
                    end if;
                    if underflow_hist(8) = '1' then
                        for ii in 7 to N-1 loop
                            mu(ii) <= mu_tmp(ii);
                        end loop;
                    end if;
                    if underflow_hist(9) = '1' then
                        for ii in 8 to N-1 loop
                            mu(ii) <= mu_tmp(ii);
                        end loop;
                    end if;
                    if underflow_hist(10) = '1' then
                        for ii in 9 to N-1 loop
                            mu(ii) <= mu_tmp(ii);
                        end loop;
                    end if;
                    if underflow_hist(11) = '1' then
                        for ii in 10 to N-1 loop
                            mu(ii) <= mu_tmp(ii);
                        end loop;
                    end if;
                    if underflow_hist(12) = '1' then
                        for ii in 11 to N-1 loop
                            mu(ii) <= mu_tmp(ii);
                        end loop;
                    end if;
                    if underflow_hist(13) = '1' then
                        for ii in 12 to N-1 loop
                            mu(ii) <= mu_tmp(ii);
                        end loop;
                    end if;
                    if underflow_hist(14) = '1' then
                        for ii in 13 to N-1 loop
                            mu(ii) <= mu_tmp(ii);
                        end loop;
                    end if;
                    if underflow_hist(15) = '1' then
                        for ii in 14 to N-1 loop
                            mu(ii) <= mu_tmp(ii);
                        end loop;
                    end if;
                    if underflow_hist(16) = '1' then
                        for ii in 15 to N-1 loop
                            mu(ii) <= mu_tmp(ii);
                        end loop;
                    end if;
                end if;
                -- store last valid mu
                if iq_vld_d(14) = '1' then
                    if underflow_hist(16) = '1' then
                        mu_cur <= mu(15);
                    elsif underflow_hist(15) = '1' then
                        mu_cur <= mu(14);
                    elsif underflow_hist(14) = '1' then
                        mu_cur <= mu(13);
                    elsif underflow_hist(13) = '1' then
                        mu_cur <= mu(12);
                    elsif underflow_hist(12) = '1' then
                        mu_cur <= mu(11);
                    elsif underflow_hist(11) = '1' then
                        mu_cur <= mu(10);
                    elsif underflow_hist(10) = '1' then
                        mu_cur <= mu(9);
                    elsif underflow_hist(9) = '1' then
                        mu_cur <= mu(8);
                    elsif underflow_hist(8) = '1' then
                        mu_cur <= mu(7);
                    elsif underflow_hist(7) = '1' then
                        mu_cur <= mu(6);
                    elsif underflow_hist(6) = '1' then
                        mu_cur <= mu(5);
                    elsif underflow_hist(5) = '1' then
                        mu_cur <= mu(4);
                    elsif underflow_hist(4) = '1' then
                        mu_cur <= mu(3);
                    elsif underflow_hist(3) = '1' then
                        mu_cur <= mu(2);
                    elsif underflow_hist(2) = '1' then
                        mu_cur <= mu(1);
                    elsif underflow_hist(1) = '1' then
                        mu_cur <= mu(0);
                    end if;
					for ii in 0 to N-1 loop
						one_minus_mu(ii) <= ONE_unsigned - unsigned('0'&mu(ii));
					end loop;
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

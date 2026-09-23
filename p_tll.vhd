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
	signal CNT  		: unsigned(15 downto 0):= (others=>'0');
	signal W 			: unsigned(15 downto 0):= HALF_ONE;
	signal Wx1 			: unsigned(15 downto 0):= (others=>'0');
	signal Wx2 			: unsigned(15 downto 0):= (others=>'0');
	signal Wx3 			: unsigned(15 downto 0):= (others=>'0');
	signal Wx4 			: unsigned(15 downto 0):= (others=>'0');
	signal Wx5 			: unsigned(15 downto 0):= (others=>'0');
	signal Wx6 			: unsigned(15 downto 0):= (others=>'0');
	signal Wx7 			: unsigned(15 downto 0):= (others=>'0');
	signal Wx8 			: unsigned(15 downto 0):= (others=>'0');
	signal Wx9 			: unsigned(15 downto 0):= (others=>'0');
	signal Wx10 		: unsigned(15 downto 0):= (others=>'0');
	signal Wx11 		: unsigned(15 downto 0):= (others=>'0');
	signal Wx12 		: unsigned(15 downto 0):= (others=>'0');
	signal Wx13 		: unsigned(15 downto 0):= (others=>'0');
	signal Wx14 		: unsigned(15 downto 0):= (others=>'0');
	signal Wx15 		: unsigned(15 downto 0):= (others=>'0');
	signal Wx16 		: unsigned(15 downto 0):= (others=>'0');
	signal mu_step 		: unsigned(15 downto 0):= (others=>'0');
	signal underflow 	: std_logic_vector(0 to N-1):="0101010101010101";
	signal underflow_hist 	: std_logic_vector(0 to N):="10101010101010101";
	signal e_vld     	: std_logic_vector(0 to N-1):="0101010101010101";
	signal diff			: unsigned_array_16(0 to N-1):=(others=>(others=>'0'));
	signal mu 		    : unsigned_array_16(0 to N-1):=(others=>(others=>'0'));
	signal one_minus_mu	: unsigned_array_16(0 to N-1):=(others=>(others=>'1'));
	signal mu_tmp 		: unsigned_array_16(0 to N-1):=(others=>(others=>'0'));
	signal one_minus_mu_ext	: unsigned_array_18(0 to N-1):=(others=>(others=>'1'));
	signal mu_ext 		: unsigned_array_18(0 to N-1):=(others=>(others=>'0'));
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
	signal e_vec 		: signed_array_33(0 to N-1):=(others=>(others=>'0'));
	signal e_add		: signed_array_35(0 to 3):=(others=>(others=>'0'));
	signal err 			: signed(36 downto 0):=(others=>'0');
	signal vtmp    	    : signed(62 downto 0):=(others=>'0');
	signal vp    	    : signed(62 downto 0):=(others=>'0');
	signal vi			: signed(62 downto 0):=(others=>'0');
	signal v			: signed(62 downto 0):=(others=>'0');
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

	gen2: for kk in 0 to N-1 generate
		mu_ext(kk) <= resize(mu(kk),18);
		one_minus_mu_ext(kk) <= resize(one_minus_mu(kk),18);
	end generate gen2;

	-- interpolation 
	process(sys_clk)
    begin
        if rising_edge(sys_clk) then
            -- Q1.16 * Q7.0 = Q8.16, 2 signed bits + 8 integer bits + 16 fractional bits
            if iq_vld_d(0) = '1' then
                for ii in 0 to N-1 loop
                    mulI0(ii) <= signed(one_minus_mu_ext(ii)) * signed(data_i_reg(ii));
                    mulQ0(ii) <= signed(one_minus_mu_ext(ii)) * signed(data_q_reg(ii));
                    mulI1(ii) <= signed(mu_ext(ii)) * signed(data_i_reg(ii+1));
                    mulQ1(ii) <= signed(mu_ext(ii)) * signed(data_q_reg(ii+1));
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
		histBuffI(jj+2) <= (others=>'0') when (underflow_hist(jj) = '1') and (underflow_hist(jj+1) = '1')  else
						   histBuffI(jj+1) when (underflow_hist(jj) = '0') and (underflow_hist(jj+1) = '0')  else
						   xI_t(jj);

		histBuffQ(jj+2) <= (others=>'0') when (underflow_hist(jj) = '1') and (underflow_hist(jj+1) = '1')  else 
						   histBuffQ(jj+1) when (underflow_hist(jj) = '0') and (underflow_hist(jj+1) = '0')  else
						   xQ_t(jj);
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
					if e_vld(kk) = '1' then
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
                if underflow(N-1) = '0' and underflow(N-2) = '1' then
                    histBuffI(1) <= histBuffI(N+1);
                    histBuffQ(1) <= histBuffQ(N+1);
                    histBuffI(0) <= histBuffI(N);
                    histBuffQ(0) <= histBuffQ(N);
                elsif underflow(N-1) = '1' and underflow(N-2) = '0' then
                    histBuffI(1) <= histBuffI(N+1);
                    histBuffQ(1) <= histBuffQ(N+1);
                    histBuffI(0) <= histBuffI(N);
                    histBuffQ(0) <= histBuffQ(N);
                elsif underflow(N-1) = '1' and underflow(N-2) = '1' then
                    histBuffI(1) <= histBuffI(N+1);
                    histBuffQ(1) <= histBuffQ(N+1);
                    histBuffI(0) <= (others=>'0');
                    histBuffQ(0) <= (others=>'0');
                elsif underflow(N-1) = '0' and underflow(N-2) = '0' then
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
                cnt_symb <= cnt_symb + 1;
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
					if abs(err(36 downto 15)) > 4096  then
						vp <= (others=>'0');
						vtmp <= (others=>'0');
					else
						vp <= K1 * err; 
						vtmp <= K2 * err;
					end  if;
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
    v_t <= std_logic_vector(v(55 downto 40));

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
	
	 Wx1	<=  W;
	 Wx2    <= (W sll 1);
	 Wx3    <= (W sll 1) - W;
	 Wx4    <= (W sll 2);
	 Wx5    <= (W sll 2) - W;
	 Wx6    <= (W sll 2) - (W sll 1);
	 Wx7    <= (W sll 3)+ W;
	 Wx8    <= (W sll 3);
	 Wx9    <= (W sll 3) - W; 
	 Wx10   <= (W sll 3) - (W sll 1); 
	 Wx11   <= (W sll 3) - (W sll 1) - W;
	 Wx12   <= (W sll 3) - (W sll 2);
	 Wx13   <= (W sll 3) - (W sll 2) - W;
	 Wx14   <= (W sll 4) + (W sll 1);
	 Wx15   <= (W sll 4) + W;
	 Wx16   <= (W sll 4);

    -- calculate diff
	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if rst_n = '0' then
				CNT <= (others=>'0');
			elsif iq_vld_d(11) = '1' then
                diff(0)  <= CNT ;
				if CNT >= Wx1 then
					diff(1)  <= CNT - Wx1;
				else
					diff(1) <= CNT - Wx1 + ONE;
				end if;
				if CNT >= Wx2 then
					diff(2)  <= CNT - Wx2;
				else
					diff(2)  <= CNT - Wx2 + ONE ;
				end if;
				if CNT >= Wx3 then
					diff(3)  <= CNT - Wx3;
				else
					diff(3)  <= CNT - Wx3 + ONE ;
				end if;
				if CNT >= Wx4 then
					diff(4)  <= CNT - Wx4 ;
				else
					diff(4)  <= CNT - Wx4 + ONE  ;
				end if;
				if CNT >= Wx5 then
					diff(5)  <= CNT - Wx5 ;
				else
					diff(5)  <= CNT - Wx5 + ONE  ;
				end if;
				if CNT >= Wx6 then
					diff(6)  <= CNT - Wx6 ;
				else
					diff(6)  <= CNT - Wx6 + ONE  ;
				end if;
				if CNT >= Wx7 then
					diff(7)  <= CNT - Wx7 ;
				else
					diff(7)  <= CNT - Wx7 + ONE  ;
				end if;
				if CNT >= Wx8 then
					diff(8)  <= CNT - Wx8 ;
				else
					diff(8)  <= CNT - Wx8 + ONE  ;
				end if;
				if CNT >= Wx9 then
					diff(9)  <= CNT - Wx9 ;
				else
					diff(9)  <= CNT - Wx9 + ONE  ;
				end if;
				if CNT >= Wx10 then
					diff(10) <= CNT - Wx10 ;
				else
					diff(10) <= CNT - Wx10 + ONE  ;
				end if;
				if CNT >= Wx11 then
					diff(11) <= CNT - Wx11 ;
				else
					diff(11) <= CNT - Wx11 + ONE  ;
				end if;
				if CNT >= Wx12 then
					diff(12) <= CNT - Wx12 ;
				else
					diff(12) <= CNT - Wx12 + ONE  ;
				end if;
				if CNT >= Wx13 then
					diff(13) <= CNT - Wx13 ;
				else
					diff(13) <= CNT - Wx13 + ONE  ;
				end if;
				if CNT >= Wx14 then
					diff(14) <= CNT - Wx14 ;
				else
					diff(14) <= CNT - Wx14 + ONE  ;
				end if;
				if CNT >= Wx15 then
					diff(15) <= CNT - Wx15 ;
				else
					diff(15) <= CNT - Wx15 + ONE  ;
				end if;
				if CNT >= Wx16 then
					CNT <= CNT - Wx16;
				else
					CNT <= CNT - Wx16 + ONE  ;
				end if;
            end if;
        end if;
    end process;


	mu_step <= unsigned(W(14 downto 0)&'0');

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
						--if diff(ii)(15)='1' then -->=0.5
						--	mu_tmp(ii)            <= ONE;
						--	one_minus_mu_tmp(ii)  <= (others=>'0');
						--else
						mu_tmp(ii)            <= unsigned(diff(ii)(14 downto 0)&'0');
						--	one_minus_mu_tmp(ii)  <= ONE - unsigned(diff(ii)(14 downto 0)&'0');
						--end if;
                        -- init mu and 1-mu with mu_cur
                        mu(ii)        <= mu_cur;
                    end loop;
					--mu_tmp(0)  <= mu_cur -  mu_step;
					--mu_tmp(1)  <= mu_cur - (mu_step sll 1);                             
					--mu_tmp(2)  <= mu_cur - (mu_step sll 1) - mu_step;                   
					--mu_tmp(3)  <= mu_cur - (mu_step sll 2);                             
					--mu_tmp(4)  <= mu_cur - (mu_step sll 2) - mu_step;                   
					--mu_tmp(5)  <= mu_cur - (mu_step sll 2) - (mu_step sll 1);           
					--mu_tmp(6)  <= mu_cur - (mu_step sll 3)+ mu_step;                    
					--mu_tmp(7)  <= mu_cur - (mu_step sll 3);                             
					--mu_tmp(8)  <= mu_cur - (mu_step sll 3) - mu_step;                   
					--mu_tmp(9)  <= mu_cur - (mu_step sll 3) - (mu_step sll 1);           
					--mu_tmp(10) <= mu_cur - (mu_step sll 3) - (mu_step sll 1) - mu_step; 
					--mu_tmp(11) <= mu_cur - (mu_step sll 3) - (mu_step sll 2);           
					--mu_tmp(12) <= mu_cur - (mu_step sll 3) - (mu_step sll 2) - mu_step; 
					--mu_tmp(13) <= mu_cur - (mu_step sll 4) + (mu_step sll 1);           
					--mu_tmp(14) <= mu_cur - (mu_step sll 4) + mu_step;                   
					--mu_tmp(15) <= mu_cur - (mu_step sll 4) ; 
                end if;
                if iq_vld_d(13) = '1' then
					mu_val     := mu_cur;
                    for jj in 0 to N-1 loop
                        if underflow(jj) = '1' then
                            mu_val     := mu_tmp(jj);
                        end if;
                        mu(jj)       <= mu_val;
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
					for ii in 0 to N-1 loop
						one_minus_mu(ii) <= ONE - mu(ii);
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

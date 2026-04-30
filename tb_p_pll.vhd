----------------------------------------------------------------
-- Testbench
-- Author: Dong Yue
-- Date: 2026-04-15 15:52:56
----------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use ieee.std_logic_textio.all;
use std.textio.all;
library work;
use work.my_dem_pkg.all;

entity tb_tb_p_pll is
end tb_tb_p_pll;

architecture sim of tb_tb_p_pll is

    constant CLK_PERIOD : time := 10 ns;

	component p_pll
	generic(N:integer:=16);
    Port (
        sys_clk 	 : in  std_logic;
        rst_n   	 : in  std_logic;
		symb_en 	 : in std_logic;
		symb_i  	 : in std_logic_array_8(0 to N-1):=(others=>(others=>'0'));
		symb_q  	 : in std_logic_array_8(0 to N-1):=(others=>(others=>'0'));
		sync_symb_en : out std_logic:='0';
		sync_symb_i  : out std_logic_array_8(0 to N-1):=(others=>(others=>'0'));
		sync_symb_q  : out std_logic_array_8(0 to N-1):=(others=>(others=>'0'));
		loop_out_vld : out std_logic:='0';
		loop_dout	 : out std_logic_vector(31 downto 0):=(others=>'0')
    );
	end component;

	constant N : integer:=16;

    signal sys_clk : std_logic := '0';
    signal rst_n   : std_logic := '0';

    -- DUT I/O
	signal symb_en 	   : std_logic:='0';
    signal symb_i      : std_logic_array_8(0 to N-1):=(others=>(others=>'0'));
    signal symb_q      : std_logic_array_8(0 to N-1):=(others=>(others=>'0'));

	signal sync_symb_en : std_logic:='0';
	signal sync_symb_i  : std_logic_array_8(0 to N-1):=(others=>(others=>'0'));
	signal sync_symb_q  : std_logic_array_8(0 to N-1):=(others=>(others=>'0'));

	signal cnt_div 		: unsigned(7 downto 0):=(others=>'0');
	signal iq_vld  		: std_logic:='0';
	signal iq_vld_d  	: std_logic:='0';

	signal loop_out_vld  : std_logic:='0';
	signal loop_dout	 : std_logic_vector(31 downto 0):=(others=>'0');

    -- File I/O
    file rec_r_i0 : text open read_mode  is "D:\projects\46_high_speed_dem\sim\tll_data_i0.txt";
    file rec_r_q0 : text open read_mode  is "D:\projects\46_high_speed_dem\sim\tll_data_q0.txt";
    file rec_r_i1 : text open read_mode  is "D:\projects\46_high_speed_dem\sim\tll_data_i1.txt";
    file rec_r_q1 : text open read_mode  is "D:\projects\46_high_speed_dem\sim\tll_data_q1.txt";
    file rec_r_i2 : text open read_mode  is "D:\projects\46_high_speed_dem\sim\tll_data_i2.txt";
    file rec_r_q2 : text open read_mode  is "D:\projects\46_high_speed_dem\sim\tll_data_q2.txt";
    file rec_r_i3 : text open read_mode  is "D:\projects\46_high_speed_dem\sim\tll_data_i3.txt";
    file rec_r_q3 : text open read_mode  is "D:\projects\46_high_speed_dem\sim\tll_data_q3.txt";
    file rec_r_i4 : text open read_mode  is "D:\projects\46_high_speed_dem\sim\tll_data_i4.txt";
    file rec_r_q4 : text open read_mode  is "D:\projects\46_high_speed_dem\sim\tll_data_q4.txt";
    file rec_r_i5 : text open read_mode  is "D:\projects\46_high_speed_dem\sim\tll_data_i5.txt";
    file rec_r_q5 : text open read_mode  is "D:\projects\46_high_speed_dem\sim\tll_data_q5.txt";
    file rec_r_i6 : text open read_mode  is "D:\projects\46_high_speed_dem\sim\tll_data_i6.txt";
    file rec_r_q6 : text open read_mode  is "D:\projects\46_high_speed_dem\sim\tll_data_q6.txt";
    file rec_r_i7 : text open read_mode  is "D:\projects\46_high_speed_dem\sim\tll_data_i7.txt";
    file rec_r_q7 : text open read_mode  is "D:\projects\46_high_speed_dem\sim\tll_data_q7.txt";
    file rec_r_i8 : text open read_mode  is "D:\projects\46_high_speed_dem\sim\tll_data_i8.txt";
    file rec_r_q8 : text open read_mode  is "D:\projects\46_high_speed_dem\sim\tll_data_q8.txt";
    file rec_r_i9 : text open read_mode  is "D:\projects\46_high_speed_dem\sim\tll_data_i9.txt";
    file rec_r_q9 : text open read_mode  is "D:\projects\46_high_speed_dem\sim\tll_data_q9.txt";
    file rec_r_i10 : text open read_mode  is "D:\projects\46_high_speed_dem\sim\tll_data_i10.txt";
    file rec_r_q10 : text open read_mode  is "D:\projects\46_high_speed_dem\sim\tll_data_q10.txt";
    file rec_r_i11 : text open read_mode  is "D:\projects\46_high_speed_dem\sim\tll_data_i11.txt";
    file rec_r_q11 : text open read_mode  is "D:\projects\46_high_speed_dem\sim\tll_data_q11.txt";
    file rec_r_i12 : text open read_mode  is "D:\projects\46_high_speed_dem\sim\tll_data_i12.txt";
    file rec_r_q12 : text open read_mode  is "D:\projects\46_high_speed_dem\sim\tll_data_q12.txt";
    file rec_r_i13 : text open read_mode  is "D:\projects\46_high_speed_dem\sim\tll_data_i13.txt";
    file rec_r_q13 : text open read_mode  is "D:\projects\46_high_speed_dem\sim\tll_data_q13.txt";
    file rec_r_i14 : text open read_mode  is "D:\projects\46_high_speed_dem\sim\tll_data_i14.txt";
    file rec_r_q14 : text open read_mode  is "D:\projects\46_high_speed_dem\sim\tll_data_q14.txt";
    file rec_r_i15 : text open read_mode  is "D:\projects\46_high_speed_dem\sim\tll_data_i15.txt";
    file rec_r_q15 : text open read_mode  is "D:\projects\46_high_speed_dem\sim\tll_data_q15.txt";
    file rec_w_i : text open write_mode is "D:\projects\46_high_speed_dem\sim\pll_sync_symb_i.txt";
    file rec_w_q : text open write_mode is "D:\projects\46_high_speed_dem\sim\pll_sync_symb_q.txt";

begin

    ----------------------------------------------------------------
    -- DUT Instantiation
    ----------------------------------------------------------------
    uut : entity work.p_pll
    port map (
        sys_clk 	 => sys_clk,
        rst_n   	 => rst_n,
		symb_en 	 => iq_vld_d,
		symb_i  	 => symb_i,
		symb_q  	 => symb_q,
		sync_symb_en => sync_symb_en,
		sync_symb_i  => sync_symb_i,
		sync_symb_q  => sync_symb_q,
		loop_out_vld => loop_out_vld ,
		loop_dout	 => loop_dout
    );

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			iq_vld_d <= iq_vld; 
			if cnt_div = 15 then
				cnt_div <= (others=>'0');
				iq_vld <= '1';
			else
				cnt_div <= cnt_div + 1;
				iq_vld <= '0';
			end if;
		end if;
	end process;

    ----------------------------------------------------------------
    -- Clock Generator
    ----------------------------------------------------------------
    clock_gen : process
    begin
        while true loop
            sys_clk <= '0';
            wait for CLK_PERIOD/2;
            sys_clk <= '1';
            wait for CLK_PERIOD/2;
        end loop;
    end process;

    ----------------------------------------------------------------
    -- Reset Generator
    ----------------------------------------------------------------
    rst_gen : process
    begin
        rst_n <= '0';
        wait for 10*CLK_PERIOD;
        rst_n <= '1';
        wait;
    end process;

    ----------------------------------------------------------------
    -- Read I Channel
    ----------------------------------------------------------------
    process(sys_clk)
        variable l : line;
        variable data_temp : integer;
    begin
        if rising_edge(sys_clk) then
			if iq_vld = '1' then
				if not endfile(rec_r_i0) then
					readline(rec_r_i0, l);
					read(l, data_temp);
					symb_i(0) <= std_logic_vector(to_signed(data_temp,8));
				end if;
			end if;
        end if;
    end process;

	----------------------------------------------------------------
	-- Read Q Channel
	----------------------------------------------------------------
	process(sys_clk)
		variable l : line;
		variable data_temp : integer;
	begin
		if rising_edge(sys_clk) then
			if iq_vld = '1' then
				if not endfile(rec_r_q0) then
					readline(rec_r_q0, l);
					read(l, data_temp);
					symb_q(0) <= std_logic_vector(to_signed(data_temp,8));
				end if;
			end if;
		end if;
	end process;

	----------------------------------------------------------------
	-- Read I Channel
	----------------------------------------------------------------
	process(sys_clk)
		variable l : line;
		variable data_temp : integer;
	begin
		if rising_edge(sys_clk) then
			if iq_vld = '1' then
				if not endfile(rec_r_i1) then
					readline(rec_r_i1, l);
					read(l, data_temp);
					symb_i(1) <= std_logic_vector(to_signed(data_temp,8));
				end if;
			end if;
		end if;
	end process;

	----------------------------------------------------------------
	-- Read Q Channel
	----------------------------------------------------------------
	process(sys_clk)
		variable l : line;
		variable data_temp : integer;
	begin
		if rising_edge(sys_clk) then
			if iq_vld = '1' then
				if not endfile(rec_r_q1) then
					readline(rec_r_q1, l);
					read(l, data_temp);
					symb_q(1) <= std_logic_vector(to_signed(data_temp,8));
				end if;
			end if;
		end if;
	end process;
	----------------------------------------------------------------
	-- Read I Channel
	----------------------------------------------------------------
	process(sys_clk)
		variable l : line;
		variable data_temp : integer;
	begin
		if rising_edge(sys_clk) then
			if iq_vld = '1' then
				if not endfile(rec_r_i2) then
					readline(rec_r_i2, l);
					read(l, data_temp);
					symb_i(2) <= std_logic_vector(to_signed(data_temp,8));
				end if;
			end if;
		end if;
	end process;

	----------------------------------------------------------------
	-- Read Q Channel
	----------------------------------------------------------------
	process(sys_clk)
		variable l : line;
		variable data_temp : integer;
	begin
		if rising_edge(sys_clk) then
			if iq_vld = '1' then
				if not endfile(rec_r_q2) then
					readline(rec_r_q2, l);
					read(l, data_temp);
					symb_q(2) <= std_logic_vector(to_signed(data_temp,8));
				end if;
			end if;
		end if;
	end process;
	----------------------------------------------------------------
	-- Read I Channel
	----------------------------------------------------------------
	process(sys_clk)
		variable l : line;
		variable data_temp : integer;
	begin
		if rising_edge(sys_clk) then
			if iq_vld = '1' then
				if not endfile(rec_r_i3) then
					readline(rec_r_i3, l);
					read(l, data_temp);
					symb_i(3) <= std_logic_vector(to_signed(data_temp,8));
				end if;
			end if;
		end if;
	end process;

	----------------------------------------------------------------
	-- Read Q Channel
	----------------------------------------------------------------
	process(sys_clk)
		variable l : line;
		variable data_temp : integer;
	begin
		if rising_edge(sys_clk) then
			if iq_vld = '1' then
				if not endfile(rec_r_q3) then
					readline(rec_r_q3, l);
					read(l, data_temp);
					symb_q(3) <= std_logic_vector(to_signed(data_temp,8));
				end if;
			end if;
		end if;
	end process;
	----------------------------------------------------------------
	-- Read I Channel
	----------------------------------------------------------------
	process(sys_clk)
		variable l : line;
		variable data_temp : integer;
	begin
		if rising_edge(sys_clk) then
			if iq_vld = '1' then
				if not endfile(rec_r_i4) then
					readline(rec_r_i4, l);
					read(l, data_temp);
					symb_i(4) <= std_logic_vector(to_signed(data_temp,8));
				end if;
			end if;
		end if;
	end process;

	----------------------------------------------------------------
	-- Read Q Channel
	----------------------------------------------------------------
	process(sys_clk)
		variable l : line;
		variable data_temp : integer;
	begin
		if rising_edge(sys_clk) then
			if iq_vld = '1' then
				if not endfile(rec_r_q4) then
					readline(rec_r_q4, l);
					read(l, data_temp);
					symb_q(4) <= std_logic_vector(to_signed(data_temp,8));
				end if;
			end if;
		end if;
	end process;
	----------------------------------------------------------------
	-- Read I Channel
	----------------------------------------------------------------
	process(sys_clk)
		variable l : line;
		variable data_temp : integer;
	begin
		if rising_edge(sys_clk) then
			if iq_vld = '1' then
				if not endfile(rec_r_i5) then
					readline(rec_r_i5, l);
					read(l, data_temp);
					symb_i(5) <= std_logic_vector(to_signed(data_temp,8));
				end if;
			end if;
		end if;
	end process;

	----------------------------------------------------------------
	-- Read Q Channel
	----------------------------------------------------------------
	process(sys_clk)
		variable l : line;
		variable data_temp : integer;
	begin
		if rising_edge(sys_clk) then
			if iq_vld = '1' then
				if not endfile(rec_r_q5) then
					readline(rec_r_q5, l);
					read(l, data_temp);
					symb_q(5) <= std_logic_vector(to_signed(data_temp,8));
				end if;
			end if;
		end if;
	end process;
	----------------------------------------------------------------
	-- Read I Channel
	----------------------------------------------------------------
	process(sys_clk)
		variable l : line;
		variable data_temp : integer;
	begin
		if rising_edge(sys_clk) then
			if iq_vld = '1' then
				if not endfile(rec_r_i6) then
					readline(rec_r_i6, l);
					read(l, data_temp);
					symb_i(6) <= std_logic_vector(to_signed(data_temp,8));
				end if;
			end if;
		end if;
	end process;

	----------------------------------------------------------------
	-- Read Q Channel
	----------------------------------------------------------------
	process(sys_clk)
		variable l : line;
		variable data_temp : integer;
	begin
		if rising_edge(sys_clk) then
			if iq_vld = '1' then
				if not endfile(rec_r_q6) then
					readline(rec_r_q6, l);
					read(l, data_temp);
					symb_q(6) <= std_logic_vector(to_signed(data_temp,8));
				end if;
			end if;
		end if;
	end process;
	----------------------------------------------------------------
	-- Read I Channel
	----------------------------------------------------------------
	process(sys_clk)
		variable l : line;
		variable data_temp : integer;
	begin
		if rising_edge(sys_clk) then
			if iq_vld = '1' then
				if not endfile(rec_r_i7) then
					readline(rec_r_i7, l);
					read(l, data_temp);
					symb_i(7) <= std_logic_vector(to_signed(data_temp,8));
				end if;
			end if;
		end if;
	end process;

	----------------------------------------------------------------
	-- Read Q Channel
	----------------------------------------------------------------
	process(sys_clk)
		variable l : line;
		variable data_temp : integer;
	begin
		if rising_edge(sys_clk) then
			if iq_vld = '1' then
				if not endfile(rec_r_q7) then
					readline(rec_r_q7, l);
					read(l, data_temp);
					symb_q(7) <= std_logic_vector(to_signed(data_temp,8));
				end if;
			end if;
		end if;
	end process;

	----------------------------------------------------------------
	-- Read I Channel
	----------------------------------------------------------------
	process(sys_clk)
		variable l : line;
		variable data_temp : integer;
	begin
		if rising_edge(sys_clk) then
			if iq_vld = '1' then
				if not endfile(rec_r_i8) then
					readline(rec_r_i8, l);
					read(l, data_temp);
					symb_i(8) <= std_logic_vector(to_signed(data_temp,8));
				end if;
			end if;
		end if;
	end process;

	----------------------------------------------------------------
	-- Read Q Channel
	----------------------------------------------------------------
	process(sys_clk)
		variable l : line;
		variable data_temp : integer;
	begin
		if rising_edge(sys_clk) then
			if iq_vld = '1' then
				if not endfile(rec_r_q8) then
					readline(rec_r_q8, l);
					read(l, data_temp);
					symb_q(8) <= std_logic_vector(to_signed(data_temp,8));
				end if;
			end if;
		end if;
	end process;
	----------------------------------------------------------------
	-- Read I Channel
	----------------------------------------------------------------
	process(sys_clk)
		variable l : line;
		variable data_temp : integer;
	begin
		if rising_edge(sys_clk) then
			if iq_vld = '1' then
				if not endfile(rec_r_i9) then
					readline(rec_r_i9, l);
					read(l, data_temp);
					symb_i(9) <= std_logic_vector(to_signed(data_temp,8));
				end if;
			end if;
		end if;
	end process;

	----------------------------------------------------------------
	-- Read Q Channel
	----------------------------------------------------------------
	process(sys_clk)
		variable l : line;
		variable data_temp : integer;
	begin
		if rising_edge(sys_clk) then
			if iq_vld = '1' then
				if not endfile(rec_r_q9) then
					readline(rec_r_q9, l);
					read(l, data_temp);
					symb_q(9) <= std_logic_vector(to_signed(data_temp,8));
				end if;
			end if;
		end if;
	end process;
	----------------------------------------------------------------
	-- Read I Channel
	----------------------------------------------------------------
	process(sys_clk)
		variable l : line;
		variable data_temp : integer;
	begin
		if rising_edge(sys_clk) then
			if iq_vld = '1' then
				if not endfile(rec_r_i10) then
					readline(rec_r_i10, l);
					read(l, data_temp);
					symb_i(10) <= std_logic_vector(to_signed(data_temp,8));
				end if;
			end if;
		end if;
	end process;

	----------------------------------------------------------------
	-- Read Q Channel
	----------------------------------------------------------------
	process(sys_clk)
		variable l : line;
		variable data_temp : integer;
	begin
		if rising_edge(sys_clk) then
			if iq_vld = '1' then
				if not endfile(rec_r_q10) then
					readline(rec_r_q10, l);
					read(l, data_temp);
					symb_q(10) <= std_logic_vector(to_signed(data_temp,8));
				end if;
			end if;
		end if;
	end process;
	----------------------------------------------------------------
	-- Read I Channel
	----------------------------------------------------------------
	process(sys_clk)
		variable l : line;
		variable data_temp : integer;
	begin
		if rising_edge(sys_clk) then
			if iq_vld = '1' then
				if not endfile(rec_r_i11) then
					readline(rec_r_i11, l);
					read(l, data_temp);
					symb_i(11) <= std_logic_vector(to_signed(data_temp,8));
				end if;
			end if;
		end if;
	end process;

	----------------------------------------------------------------
	-- Read Q Channel
	----------------------------------------------------------------
	process(sys_clk)
		variable l : line;
		variable data_temp : integer;
	begin
		if rising_edge(sys_clk) then
			if iq_vld = '1' then
				if not endfile(rec_r_q11) then
					readline(rec_r_q11, l);
					read(l, data_temp);
					symb_q(11) <= std_logic_vector(to_signed(data_temp,8));
				end if;
			end if;
		end if;
	end process;
	----------------------------------------------------------------
	-- Read I Channel
	----------------------------------------------------------------
	process(sys_clk)
		variable l : line;
		variable data_temp : integer;
	begin
		if rising_edge(sys_clk) then
			if iq_vld = '1' then
				if not endfile(rec_r_i12) then
					readline(rec_r_i12, l);
					read(l, data_temp);
					symb_i(12) <= std_logic_vector(to_signed(data_temp,8));
				end if;
			end if;
		end if;
	end process;

	----------------------------------------------------------------
	-- Read Q Channel
	----------------------------------------------------------------
	process(sys_clk)
		variable l : line;
		variable data_temp : integer;
	begin
		if rising_edge(sys_clk) then
			if iq_vld = '1' then
				if not endfile(rec_r_q12) then
					readline(rec_r_q12, l);
					read(l, data_temp);
					symb_q(12) <= std_logic_vector(to_signed(data_temp,8));
				end if;
			end if;
		end if;
	end process;
	----------------------------------------------------------------
	-- Read I Channel
	----------------------------------------------------------------
	process(sys_clk)
		variable l : line;
		variable data_temp : integer;
	begin
		if rising_edge(sys_clk) then
			if iq_vld = '1' then
				if not endfile(rec_r_i13) then
					readline(rec_r_i13, l);
					read(l, data_temp);
					symb_i(13) <= std_logic_vector(to_signed(data_temp,8));
				end if;
			end if;
		end if;
	end process;

	----------------------------------------------------------------
	-- Read Q Channel
	----------------------------------------------------------------
	process(sys_clk)
		variable l : line;
		variable data_temp : integer;
	begin
		if rising_edge(sys_clk) then
			if iq_vld = '1' then
				if not endfile(rec_r_q13) then
					readline(rec_r_q13, l);
					read(l, data_temp);
					symb_q(13) <= std_logic_vector(to_signed(data_temp,8));
				end if;
			end if;
		end if;
	end process;
	----------------------------------------------------------------
	-- Read I Channel
	----------------------------------------------------------------
	process(sys_clk)
		variable l : line;
		variable data_temp : integer;
	begin
		if rising_edge(sys_clk) then
			if iq_vld = '1' then
				if not endfile(rec_r_i14) then
					readline(rec_r_i14, l);
					read(l, data_temp);
					symb_i(14) <= std_logic_vector(to_signed(data_temp,8));
				end if;
			end if;
		end if;
	end process;

	----------------------------------------------------------------
	-- Read Q Channel
	----------------------------------------------------------------
	process(sys_clk)
		variable l : line;
		variable data_temp : integer;
	begin
		if rising_edge(sys_clk) then
			if iq_vld = '1' then
				if not endfile(rec_r_q14) then
					readline(rec_r_q14, l);
					read(l, data_temp);
					symb_q(14) <= std_logic_vector(to_signed(data_temp,8));
				end if;
			end if;
		end if;
	end process;
	----------------------------------------------------------------
	-- Read I Channel
	----------------------------------------------------------------
	process(sys_clk)
		variable l : line;
		variable data_temp : integer;
	begin
		if rising_edge(sys_clk) then
			if iq_vld = '1' then
				if not endfile(rec_r_i15) then
					readline(rec_r_i15, l);
					read(l, data_temp);
					symb_i(15) <= std_logic_vector(to_signed(data_temp,8));
				end if;
			end if;
		end if;
	end process;

	----------------------------------------------------------------
	-- Read Q Channel
	----------------------------------------------------------------
	process(sys_clk)
		variable l : line;
		variable data_temp : integer;
	begin
		if rising_edge(sys_clk) then
			if iq_vld = '1' then
				if not endfile(rec_r_q15) then
					readline(rec_r_q15, l);
					read(l, data_temp);
					symb_q(15) <= std_logic_vector(to_signed(data_temp,8));
				end if;
			end if;
		end if;
	end process;

    ----------------------------------------------------------------
    -- Write I Channel
    ----------------------------------------------------------------
    process(sys_clk)
        variable buf : line;
    begin
        if rising_edge(sys_clk) then
			for ii in 0 to 7 loop
				if sync_symb_en = '1' then
					write(buf, to_integer(signed(sync_symb_i(ii))));
					writeline(rec_w_i, buf);
				end if;
			end loop;
        end if;
    end process;

    ----------------------------------------------------------------
    -- Write Q Channel
    ----------------------------------------------------------------
    process(sys_clk)
        variable buf : line;
    begin
        if rising_edge(sys_clk) then
			for ii in 0 to 7 loop
				if sync_symb_en = '1' then
					write(buf, to_integer(signed(sync_symb_q(ii))));
					writeline(rec_w_q, buf);
				end if;
			end loop;
        end if;
    end process;
end sim;



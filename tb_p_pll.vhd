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
    file rec_r_i : text open read_mode  is "hs_symb_i.txt";
    file rec_r_q : text open read_mode  is "hs_symb_q.txt";
    file rec_w_i : text open write_mode is "pll_sync_symb_i.txt";
    file rec_w_q : text open write_mode is "pll_sync_symb_q.txt";

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
				if not endfile(rec_r_i) then
                    for ii in 0 to 15 loop
                        readline(rec_r_i, l);
                        read(l, data_temp);
                        symb_i(ii) <= std_logic_vector(to_signed(data_temp,8));
                    end loop;
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
				if not endfile(rec_r_q) then
                    for ii in 0 to 15 loop
                        readline(rec_r_q, l);
                        read(l, data_temp);
                        symb_q(ii) <= std_logic_vector(to_signed(data_temp,8));
                    end loop;
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



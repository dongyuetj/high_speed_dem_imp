----------------------------------------------------------------
-- Testbench
-- Author: Dong Yue
-- Date: 2026-04-17 17:51:30
----------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use ieee.std_logic_textio.all;
use std.textio.all;

entity tb_tb_hs_dem is
end tb_tb_hs_dem;

architecture sim of tb_tb_hs_dem is

	component hs_dem
	generic( N : integer := 16);
    Port (
        sys_clk  : in  std_logic;
        rst_n    : in  std_logic;
		data_vld : in std_logic;
		data0_i  : in std_logic_vector(15 downto 0);
		data0_q  : in std_logic_vector(15 downto 0);
		data1_i  : in std_logic_vector(15 downto 0);
		data1_q  : in std_logic_vector(15 downto 0);
		dem_vld  : out std_logic:='0';
		dem_sym_i		: out std_logic_vector(15 downto 0):= (others=>'0');
		dem_sym_q		: out std_logic_vector(15 downto 0):= (others=>'0');
		dem_byte : out std_logic_vector(7 downto 0):=(others=>'0')
    );
	end component;

    constant DDC_CLK_PERIOD : time := 10 ns;
    constant CLK_PERIOD : time := 10 ns;

    signal sys_clk : std_logic := '0';
    signal rst_n   : std_logic := '0';

    -- DUT I/O
    signal data0_i      : std_logic_vector(15 downto 0):=(others=>'0');
    signal data0_q      : std_logic_vector(15 downto 0):=(others=>'0');
    signal data1_i      : std_logic_vector(15 downto 0):=(others=>'0');
    signal data1_q      : std_logic_vector(15 downto 0):=(others=>'0');
	signal data_vld		: std_logic:='1';
	signal dem_vld  	: std_logic:='0';
	signal dem_byte 	: std_logic_vector(7 downto 0):=(others=>'0');

    -- File I/O
  --  file rec_r_i0 : text open read_mode  is "D:\projects\46_high_speed_dem\sim\rd_data_i.txt";
  --  file rec_r_q0 : text open read_mode  is "D:\projects\46_high_speed_dem\sim\rd_data_q.txt";
    file rec_r_i0 : text open read_mode  is "ddc_i0.txt";
    file rec_r_q0 : text open read_mode  is "ddc_q0.txt";
    file rec_r_i1 : text open read_mode  is "ddc_i0.txt";
    file rec_r_q1 : text open read_mode  is "ddc_q0.txt";
    file rec_w_i : text open write_mode is "dem_byte.txt";

begin

    ----------------------------------------------------------------
    -- DUT Instantiation
    ----------------------------------------------------------------
	uut : entity work.hs_dem
	generic map( N => 16)
	port map (
				 sys_clk  => sys_clk,
				 rst_n    => rst_n,
				 data_vld => '1',
				 data0_i  => data0_i,
				 data0_q  => data0_q,
				 data1_i  => data1_i,
				 data1_q  => data1_q,
				 dem_vld  => dem_vld,
				 dem_byte => dem_byte
	);

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
        wait for 5*CLK_PERIOD;
        rst_n <= '1';
       -- wait for 300 us;
       -- rst_n <= '0';
       -- wait for 10*CLK_PERIOD;
       -- rst_n <= '1';
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
            if not endfile(rec_r_i0) then
                readline(rec_r_i0, l);
                read(l, data_temp);
                data0_i <= std_logic_vector(to_signed(data_temp,16));
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
            if not endfile(rec_r_q0) then
                readline(rec_r_q0, l);
                read(l, data_temp);
                data0_q <= std_logic_vector(to_signed(data_temp,16));
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
            if not endfile(rec_r_i1) then
                readline(rec_r_i1, l);
                read(l, data_temp);
                data1_i <= std_logic_vector(to_signed(data_temp,16));
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
            if not endfile(rec_r_q1) then
                readline(rec_r_q1, l);
                read(l, data_temp);
                data1_q <= std_logic_vector(to_signed(data_temp,16));
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
            if dem_vld = '1' then
                write(buf, to_integer(signed(dem_byte)));
                writeline(rec_w_i, buf);
            end if;
        end if;
    end process;

--    ----------------------------------------------------------------
--    -- Write Q Channel
--    ----------------------------------------------------------------
--    process(sys_clk)
--        variable buf : line;
--    begin
--        if rising_edge(sys_clk) then
--            if wave_valid = '1' then
--                write(buf, to_integer(signed(wave_q)));
--                writeline(rec_w_q, buf);
--            end if;
--        end if;
--    end process;

end sim;



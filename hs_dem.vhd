----------------------------------------------------------------
-- Entity: hs_dem
-- Author: Dong Yue
-- Date: 2026-04-15 17:57:04
----------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library work;
use work.my_dem_pkg.all;
use std.textio.all;
library work;

entity hs_dem is
	generic( N : integer := 8);
    Port (
        sys_clk  : in  std_logic;
        ddc_clk  : in  std_logic;
        rst_n    : in  std_logic;
		data_vld : in std_logic;
		data0_i  : in std_logic_vector(15 downto 0);
		data0_q  : in std_logic_vector(15 downto 0);
		data1_i  : in std_logic_vector(15 downto 0);
		data1_q  : in std_logic_vector(15 downto 0);
		dem_vld  : out std_logic:='0';
		dem_byte : out std_logic_vector(7 downto 0):=(others=>'0')
    );
end hs_dem;

architecture rtl of hs_dem is

	component fifo_s2p
		port (
				 wr_clk : in std_logic;
				 rd_clk : in std_logic;
				 rst : in std_logic;
				 din : in std_logic_vector(15 downto 0);
				 wr_en : in std_logic;
				 rd_en : in std_logic;
				 dout : out std_logic_vector(127 downto 0);
				 full : out std_logic;
				 empty : out std_logic;
				 wr_rst_busy : out std_logic;
				 rd_rst_busy : out std_logic 
			 );
	end component;

	component p_agc
		generic( N : integer := 8);
		port(
				sys_clk				: in std_logic; -- 28.8MHz
				aresetn 			: in std_logic;
				log_ref  			: in std_logic_vector(31 downto 0);
				wave_in_valid 		: in std_logic;
				wave_in_i 			: in std_logic_array_16(0 to N-1);
				wave_in_q			: in std_logic_array_16(0 to N-1);
				wave_out_valid 		: out std_logic;
				wave_out_i 			: out std_logic_array_16(0 to N-1);
				wave_out_q 			: out std_logic_array_16(0 to N-1);
				power_out_o 		: out std_logic_vector(31 downto 0):=(others=>'0');
				exp_gain_o 			: out std_logic_vector(31 downto 0):=(others=>'0');
				agc_error 			: out std_logic_vector(31 downto 0):=(others=>'0')
			);
	end component;

	component p_tll
		generic( N : integer := 8);
		Port (
				 sys_clk : in  std_logic;
				 rst_n   : in  std_logic;
				 iq_vld : in std_logic;
				 data_i : in std_logic_array_8(0 to N-1);
				 data_q : in std_logic_array_8(0 to N-1);
				 symb_en : out std_logic_vector(0 to N-1):=(others=>'0');
				 symb_i : out std_logic_array_16(0 to N-1):=(others=>(others=>'0'));
				 symb_q : out std_logic_array_16(0 to N-1):=(others=>(others=>'0'))
			 );
	end component;

	component fifo_symb
		port (
				 clk : in std_logic;
				 srst : in std_logic;
				 din : in std_logic_vector(7 downto 0);
				 wr_en : in std_logic;
				 rd_en : in std_logic;
				 dout : out std_logic_vector(63 downto 0);
				 full : out std_logic;
				 empty : out std_logic;
				 rd_data_count : out std_logic_vector(7 downto 0);
				 wr_rst_busy : out std_logic;
				 rd_rst_busy : out std_logic 
			 );
	end component;

	component p_pll
		generic( N: integer := 8);
		Port (
				 sys_clk 	 : in  std_logic;
				 rst_n   	 : in  std_logic;
				 symb_en 	 : in std_logic;
				 symb_i  	 : in std_logic_array_8(0 to N-1):=(others=>(others=>'0'));
				 symb_q  	 : in std_logic_array_8(0 to N-1):=(others=>(others=>'0'));
				 sync_symb_en : out std_logic;
				 sync_symb_i  : out std_logic_array_8(0 to N-1):=(others=>(others=>'0'));
				 sync_symb_q  : out std_logic_array_8(0 to N-1):=(others=>(others=>'0'))
			 );
	end component;

	component fifo_p2s
		port (
				 clk : in std_logic;
				 srst : in std_logic;
				 din : in std_logic_vector(63 downto 0);
				 wr_en : in std_logic;
				 rd_en : in std_logic;
				 dout : out std_logic_vector(7 downto 0);
				 full : out std_logic;
				 empty : out std_logic;
				 wr_rst_busy : out std_logic;
				 rd_rst_busy : out std_logic 
			 );
	end component;

	signal log_ref				: std_logic_vector(31 downto 0):=x"408515B5";
	signal power_out 			: std_logic_vector(31 downto 0):=(others=>'0');
	signal exp_gain 			: std_logic_vector(31 downto 0):=(others=>'0');
	signal agc_error 			: std_logic_vector(31 downto 0):=(others=>'0');
	signal srst 				: std_logic:='0';
	signal din0 				: std_logic_vector(15 downto 0):=(others=>'0');
	signal wr_en0 				: std_logic:='0';
	signal dout0 				: std_logic_vector(127 downto 0):=(others=>'0');
	signal full0 				: std_logic:='0';
	signal empty0 				: std_logic:='0';
	signal wr_rst_busy0 		: std_logic:='0';
	signal rd_rst_busy0 		: std_logic:='0';
	signal din1 				: std_logic_vector(15 downto 0):=(others=>'0');
	signal wr_en1 				: std_logic:='0';
	signal dout1 				: std_logic_vector(127 downto 0):=(others=>'0');
	signal full1 				: std_logic:='0';
	signal empty1 				: std_logic:='0';
	signal wr_rst_busy1 		: std_logic:='0';
	signal rd_rst_busy1 		: std_logic:='0';

	type state_type is (st_idle, st_lock_tll, st_lock_pll);
	signal dem_st 				: state_type := st_idle;
	signal rd_en 				: std_logic:='0';
	signal rd_en_d 				: std_logic:='0';
	signal wave_in_valid 		: std_logic:='0';
	signal wave_in_i 			: std_logic_array_16(0 to N-1):=(others=>(others=>'0'));
	signal wave_in_q			: std_logic_array_16(0 to N-1):=(others=>(others=>'0'));
	signal wave_out_valid 		: std_logic:='0';
	signal wave_out_i 			: std_logic_array_16(0 to N-1):=(others=>(others=>'0'));
	signal wave_out_q 			: std_logic_array_16(0 to N-1):=(others=>(others=>'0'));
	signal iq_vld 				: std_logic:='0';
	signal wave_i 				: std_logic_array_8(0 to N-1):=(others=>(others=>'0'));
	signal wave_q 				: std_logic_array_8(0 to N-1):=(others=>(others=>'0'));
	signal symb_en 				: std_logic_vector(0 to N-1):=(others=>'0');
	signal symb_i 				: std_logic_array_16(0 to N-1):=(others=>(others=>'0'));
	signal symb_q 				: std_logic_array_16(0 to N-1):=(others=>(others=>'0'));
	signal symb_i_d 			: std_logic_array_16(0 to N-1):=(others=>(others=>'0'));
	signal symb_q_d 			: std_logic_array_16(0 to N-1):=(others=>(others=>'0'));
	signal symb_i_t 			: std_logic_vector(7 downto 0):=(others=>'0');
	signal symb_q_t 			: std_logic_vector(7 downto 0):=(others=>'0');
	signal sync_symb_en 		: std_logic:='0';
	signal sync_symb_i 			: std_logic_array_8(0 to N-1):=(others=>(others=>'0'));
	signal sync_symb_q 			: std_logic_array_8(0 to N-1):=(others=>(others=>'0'));
	signal symb_wren			: std_logic:='0';
	signal rden					: std_logic:='0';
	signal rden_d				: std_logic:='0';
	signal pll_in_valid			: std_logic:='0';
	signal symb_i_dout			: std_logic_vector(63 downto 0):=(others=>'0');
	signal symb_q_dout			: std_logic_vector(63 downto 0):=(others=>'0');
	signal pll_in_i				: std_logic_array_8(0 to N-1):=(others=>(others=>'0'));
	signal pll_in_q				: std_logic_array_8(0 to N-1):=(others=>(others=>'0'));
	signal full_i, full_q 	  	: std_logic:='0';
	signal empty_i, empty_q		: std_logic:='1';
	signal wr_rst_busy_i,wr_rst_busy_q  : std_logic:='0';
	signal rd_rst_busy_i,rd_rst_busy_q  : std_logic:='0';
	signal rd_data_i_count, rd_data_q_count : std_logic_vector(7 downto 0):=(others=>'0');
	signal rd_fifo_sts 					: std_logic:='0';
	signal symb_align_sts 				: std_logic:='0';
	signal rst_n_tll,rst_n_pll			: std_logic:='1';
	signal p2s_i_din,p2s_q_din			: std_logic_vector(8*8-1 downto 0):=(others=>'0');
	signal p2s_wren						: std_logic:='0';
	signal p2s_rden						: std_logic:='0';
	signal p2s_i_dout,p2s_q_dout		: std_logic_vector(7 downto 0):=(others=>'0');
	signal p2s_i_full,p2s_q_full					: std_logic:='0';
	signal p2s_i_empty,p2s_q_empty  				: std_logic:='0';
	signal p2s_wr_rst_i_busy,p2s_wr_rst_q_busy		: std_logic:='0';
	signal p2s_rd_rst_i_busy,p2s_rd_rst_q_busy		: std_logic:='0';
	signal p2s_sts									: std_logic:='0';
	file rec_w_i : text open write_mode is "D:\projects\46_high_speed_dem\sim\hs_symb_i.txt";
	file rec_w_q : text open write_mode is "D:\projects\46_high_speed_dem\sim\hs_symb_q.txt";
	file rec_w_ii : text open write_mode is "D:\projects\46_high_speed_dem\sim\hs_sync_symb_i.txt";
	file rec_w_qq : text open write_mode is "D:\projects\46_high_speed_dem\sim\hs_sync_symb_q.txt";
begin

    process(sys_clk)
    begin
        if rising_edge(sys_clk) then
            if rst_n = '0' then
                srst <= '1';
            else
                srst <= '0';
            end if;
        end if;
    end process;

    process(sys_clk)
    begin
        if rising_edge(sys_clk) then
            if rst_n = '0' then
                dem_st <= st_idle;
            else
				case dem_st is
					when st_idle => -- wait agc
					when st_lock_tll => -- wait tll
					when st_lock_pll => -- wait pll and stay
					when others => null;
				end case;
            end if;
        end if;
    end process;

	process(ddc_clk)
	begin
		if rising_edge(ddc_clk) then
			if (srst = '1' or  wr_rst_busy0 = '1' or wr_rst_busy1 = '1') then
				wr_en0 <= '0';
				wr_en1 <= '0';
				din0   <= (others=>'0');
				din1   <= (others=>'0'); 
			else
				wr_en0 <= data_vld ;
				wr_en1 <= data_vld ;
				din0   <= data0_i ;
				din1   <= data0_q ; 
			end if;
		end if;
	end process;

	u_fifo_i: fifo_s2p
	port map(
				wr_clk 	=> ddc_clk,
				rd_clk 	=> sys_clk,
				rst 	=> srst	  ,
				din 	=> din0   ,
				wr_en 	=> wr_en0 ,
				rd_en 	=> rd_en ,
				dout 	=> dout0  ,
				full 	=> full0  ,
				empty 	=> empty0 ,
				wr_rst_busy => wr_rst_busy0,
				rd_rst_busy => rd_rst_busy0
			 );

	u_fifo_q: fifo_s2p
	port map(
				wr_clk 	=> ddc_clk,
				rd_clk 	=> sys_clk,
				rst 	=> srst	  ,
				din 	=> din1   ,
				wr_en 	=> wr_en1 ,
				rd_en 	=> rd_en ,
				dout 	=> dout1  ,
				full 	=> full1  ,
				empty 	=> empty1 ,
				wr_rst_busy => wr_rst_busy1,
				rd_rst_busy => rd_rst_busy1
			 );

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if rst_n = '0' then
				rd_en	<= '0';
				rd_en_d <= '0';
			else
				rd_en_d <= rd_en;
				case rd_fifo_sts is
					when '0' =>
						if empty0 = '0' and empty1 = '0' then
							rd_en <= '1';
							rd_fifo_sts <= '1';
						end if;
					when '1' =>
						rd_en <= '0';
						rd_fifo_sts <= '0';
					when others => 
						rd_en <= '0';
						rd_fifo_sts <= '0';
				end case;
			end if;
		end if;
	end process;

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			wave_in_valid	<=	rd_en_d;
			if rd_en_d = '1' then
				for ii in 0 to N-1 loop
					wave_in_i(N-1-ii) <= dout0((ii+1)*16-1 downto ii*16);  
					wave_in_q(N-1-ii) <= dout1((ii+1)*16-1 downto ii*16);
				end loop;
			end if;
		end if;
	end process;

	u_agc: p_agc
	generic map( N => 8)
	port map(
			sys_clk			=> 	sys_clk,
			aresetn 		=> 	rst_n,
			log_ref  		=> 	log_ref,
			wave_in_valid 	=>  wave_in_valid,
			wave_in_i 		=>  wave_in_i,	
			wave_in_q		=>  wave_in_q,
			wave_out_valid 	=> 	wave_out_valid,
			wave_out_i 		=> 	wave_out_i,
			wave_out_q 		=> 	wave_out_q,
			power_out_o 	=> 	power_out,
			exp_gain_o 		=> 	exp_gain,
			agc_error 		=>  agc_error	
		);

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			iq_vld <= wave_out_valid; 	
			for ii in 0 to N-1 loop
				if wave_out_valid = '1' then
					if wave_out_i(ii)(15 downto 7) = "000000000" or wave_out_i(ii)(15 downto 7) = "111111111"  then
						wave_i(ii) <= wave_out_i(ii)(7 downto 0);
					elsif wave_out_i(ii)(15) = '0' then
						wave_i(ii) <= x"7F";
					elsif wave_out_i(ii)(15) = '1' then
						wave_i(ii) <= x"80";
					end if;
					if wave_out_q(ii)(15 downto 7) = "000000000" or wave_out_q(ii)(15 downto 7) = "111111111"  then
						wave_q(ii) <= wave_out_q(ii)(7 downto 0);
					elsif wave_out_q(ii)(15) = '0' then
						wave_q(ii) <= x"7F";
					elsif wave_out_q(ii)(15) = '1' then
						wave_q(ii) <= x"80";
					end if;
				end if;
			end loop;
		end if;
	end process;

	u_tll: p_tll
	generic map ( N => 8)
	port map(
				sys_clk => sys_clk,
				rst_n   => rst_n_tll,
				iq_vld 	=> iq_vld ,
				data_i 	=> wave_i ,
				data_q 	=> wave_q ,
				symb_en => symb_en,
				symb_i  => symb_i ,
				symb_q  => symb_q 
			);

    ----------------------------------------------------------------
    -- Write I Channel
    ----------------------------------------------------------------
    process(sys_clk)
        variable buf : line;
    begin
        if rising_edge(sys_clk) then
			if symb_wren = '1' then
				write(buf, to_integer(signed(symb_i_t)));
				writeline(rec_w_i, buf);
			end if;
        end if;
    end process;

    ----------------------------------------------------------------
    -- Write Q Channel
    ----------------------------------------------------------------
    process(sys_clk)
        variable buf : line;
    begin
        if rising_edge(sys_clk) then
			if symb_wren = '1' then
				write(buf, to_integer(signed(symb_q_t)));
				writeline(rec_w_q, buf);
			end if;
        end if;
    end process;

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			symb_wren <= '0';	
			for ii in 0 to N-1 loop
				if symb_en(ii) = '1' then
					symb_wren <= '1';	
					if symb_i(ii)(15 downto 13) = "000" or symb_i(ii)(15 downto 13) = "111" then 
						symb_i_t <=  symb_i(ii)(13 downto 6);
					elsif symb_i(ii)(15) = '0' then
						symb_i_t <=  x"7F";
					elsif symb_i(ii)(15) = '1' then
						symb_i_t <=  x"80";
					end if;
					if symb_q(ii)(15 downto 13) = "000" or symb_q(ii)(15 downto 13) = "111" then 
						symb_q_t <=  symb_q(ii)(13 downto 6);
					elsif symb_q(ii)(15) = '0' then
						symb_q_t <=  x"7F";
					elsif symb_q(ii)(15) = '1' then
						symb_q_t <=  x"80";
					end if;
				end if;
			end loop;
		end if;
	end process;

	u_fifo_symb_i: fifo_symb
	port map(
				clk 		=> sys_clk		,
				srst 		=> srst			,
				din 		=> symb_i_t		,
				wr_en 		=> symb_wren	,
				rd_en 		=> rden			,
				dout 		=> symb_i_dout	,
				full 		=> full_i 	  	, 
				empty 		=> empty_i	  	, 
				rd_data_count => rd_data_i_count,
				wr_rst_busy => wr_rst_busy_i,
				rd_rst_busy => rd_rst_busy_i
			);

	u_fifo_symb_q: fifo_symb
	port map(
				clk 		=> sys_clk		,
				srst 		=> srst			,
				din 		=> symb_q_t		,
				wr_en 		=> symb_wren	,
				rd_en 		=> rden			,
				dout 		=> symb_q_dout	,
				full 		=> full_q 	  	, 
				empty 		=> empty_q	  	, 
				rd_data_count => rd_data_q_count,
				wr_rst_busy => wr_rst_busy_q,
				rd_rst_busy => rd_rst_busy_q
			);

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if rst_n = '0' then
				symb_align_sts <= '0';
				rden_d <= '0';
				rden <= '0';
			else
				rden_d <= rden;
				case symb_align_sts is 
					when '0' =>
						if empty_i = '0' and empty_q = '0' then 
							symb_align_sts <= '1';
							rden <= '1';
						end if;
					when '1' =>
						symb_align_sts <= '0';
						rden <= '0';
					when others =>
						rden <= '0';
						symb_align_sts <= '0';
				end case;
			end if;
		end if;
	end process;

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			pll_in_valid <=	rden_d;
			if rden_d = '1' then
				for ii in 0 to N-1 loop
					pll_in_i(N-1-ii) <= symb_i_dout((ii+1)*8-1 downto ii*8);  
					pll_in_q(N-1-ii) <= symb_q_dout((ii+1)*8-1 downto ii*8);
				end loop;
			end if;
		end if;
	end process;

	u_pll: p_pll
	generic map( N => 8)
	port map(
				 sys_clk 	  => sys_clk,
				 rst_n   	  => rst_n_pll,
				 symb_en 	  => pll_in_valid ,
				 symb_i  	  => pll_in_i,
				 symb_q  	  => pll_in_q,
				 sync_symb_en => sync_symb_en ,
				 sync_symb_i  => sync_symb_i,
				 sync_symb_q  => sync_symb_q
			 );
	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			p2s_wren <= sync_symb_en ;
			for ii in 0 to N-1 loop
				p2s_i_din((ii+1)*8-1 downto ii*8) <= sync_symb_i(ii);
				p2s_q_din((ii+1)*8-1 downto ii*8) <= sync_symb_q(ii);
			end loop;
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
					writeline(rec_w_ii, buf);
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
					writeline(rec_w_qq, buf);
				end if;
			end loop;
        end if;
    end process;
	
	u_fifo_i_p2s: fifo_p2s
	port map(
				 clk 	=> sys_clk,
				 srst 	=> srst,
				 din 	=> p2s_i_din,
				 wr_en 	=> p2s_wren,
				 rd_en 	=> p2s_rden,
				 dout 	=> p2s_i_dout,
				 full 	=> p2s_i_full,
				 empty 	=> p2s_i_empty,
				 wr_rst_busy => p2s_wr_rst_i_busy,
				 rd_rst_busy => p2s_rd_rst_i_busy
			 );

	u_fifo_q_p2s: fifo_p2s
	port map(
				 clk 	=> sys_clk,
				 srst 	=> srst,
				 din 	=> p2s_q_din,
				 wr_en 	=> p2s_wren,
				 rd_en 	=> p2s_rden,
				 dout 	=> p2s_q_dout,
				 full 	=> p2s_q_full,
				 empty 	=> p2s_q_empty,
				 wr_rst_busy => p2s_wr_rst_q_busy,
				 rd_rst_busy => p2s_rd_rst_q_busy
			 );

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if rst_n = '0' then
				p2s_rden <= '0';
				dem_vld <= '0';
				p2s_sts <= '0';
			else
				dem_vld <= p2s_rden;
				case p2s_sts is
					when '0' =>
						if (p2s_i_empty = '0') and (p2s_q_empty = '0') then
							p2s_rden <= '1';
							p2s_sts <= '1';
						end if;
					when '1' =>
						p2s_rden <= '0';
						p2s_sts <= '0';
					when others => 
						p2s_rden <= '0';
						p2s_sts <= '0';
				end case;
			end if;
		end if;
	end process;
	
	dem_byte(0) <= p2s_i_dout(p2s_i_dout'high);
	dem_byte(1) <= p2s_q_dout(p2s_q_dout'high);

end rtl;



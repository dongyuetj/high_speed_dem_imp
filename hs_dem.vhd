----------------------------------------------------------------
-- Entity: hs_dem
-- Author: Dong Yue
-- Date: 2026-04-15 17:57:04
----------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity hs_dem is
    Port (
        sys_clk  : in  std_logic;
        rst_n    : in  std_logic;
		data_vld : in std_logic;
		data0_i  : in std_logic_vector(15 downto 0);
		data0_q  : in std_logic_vector(15 downto 0);
		data1_i  : in std_logic_vector(15 downto 0);
		data1_q  : in std_logic_vector(15 downto 0);
		dem_vld  : out std_logic:='0';
		dem_byte : out std_logic_vector(7 downto 0)
    );
end hs_dem;

architecture rtl of hs_dem is

	component fifo_s2p
		port (
				 clk : in std_logic;
				 srst : in std_logic;
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

	component fifo_symb
		port (
				 clk : in std_logic;
				 srst : in std_logic;
				 din : in std_logic_vector(7 downto 0);
				 wr_en : in std_logic;
				 rd_en : in std_logic;
				 dout : out std_logic_vector(7 downto 0);
				 full : out std_logic;
				 empty : out std_logic;
				 wr_rst_busy : out std_logic;
				 rd_rst_busy : out std_logic 
			 );
	end component;

	component p_agc
		generic( N : integer := 8)
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
		generic( N : integer := 8)
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
	end component;

	component p_pll
		generic( N: integer := 8)
		Port (
				 sys_clk 	 : in  std_logic;
				 rst_n   	 : in  std_logic;
				 symb_en 	 : in std_logic;
				 symb_i  	 : in std_logic_array_8(N-1 downto 0):=(others=>(others=>'0'));
				 symb_q  	 : in std_logic_array_8(N-1 downto 0):=(others=>(others=>'0'));
				 sync_symb_en : out std_logic_vector(N-1 downto 0):=(others=>'0');
				 sync_symb_i  : out std_logic_array_16(N-1 downto 0):=(others=>(others=>'0'));
				 sync_symb_q  : out std_logic_array_16(N-1 downto 0):=(others=>(others=>'0'))
			 );
	end component;

	signal srst 	: std_logic:='0';
	signal din0 	: std_logic_vector(15 downto 0):=(others=>'0');
	signal wr_en0 	: std_logic:='0';
	signal dout0 	: std_logic_vector(127 downto 0):=(others=>'0');
	signal full0 	: std_logic:='0';
	signal empty0 	: std_logic:='0';
	signal wr_rst_busy0 : std_logic:='0';
	signal rd_rst_busy0 : std_logic:='0';
	signal din1 	: std_logic_vector(15 downto 0):=(others=>'0');
	signal wr_en1 	: std_logic:='0';
	signal dout1 	: std_logic_vector(127 downto 0):=(others=>'0');
	signal full1 	: std_logic:='0';
	signal empty1 	: std_logic:='0';
	signal wr_rst_busy1 : std_logic:='0';
	signal rd_rst_busy1 : std_logic:='0';

	type state_type is (st_idle, st_lock_tll, st_lock_pll);
	signal dem_st : state_type := st_idle;
	signal rd_en 				: std_logic:='0';
	signal rd_en_d 				: std_logic:='0';
	signal wave_in_valid 		: std_logic:='0';
	signal wave_in_i 			: std_logic_array_16(0 to N-1):=(others=>(others=>'0'));
	signal wave_in_q			: std_logic_array_16(0 to N-1):=(others=>(others=>'0'));
	signal wave_out_valid 		: std_logic:='0';
	signal wave_out_i 			: std_logic_array_16(0 to N-1):=(others=>(others=>'0'));
	signal wave_out_q 			: std_logic_array_16(0 to N-1):=(others=>(others=>'0'));
	signal power_out_o 			: std_logic_vector(31 downto 0):=(others=>'0');
	signal exp_gain_o 			: std_logic_vector(31 downto 0):=(others=>'0');
	signal agc_error 			: std_logic_vector(31 downto 0):=(others=>'0');
	signal iq_vld 				: std_logic:='0';
	signal wave_i 				: std_logic_array_8(N-1 downto 0):=(others=>(others=>'0'));
	signal wave_q 				: std_logic_array_8(N-1 downto 0):=(others=>(others=>'0'));
	signal symb_en 				: std_logic_vector(N-1 downto 0):=(others=>'0');
	signal symb_i 				: std_logic_array_16(N-1 downto 0):=(others=>(others=>'0'));
	signal symb_q 				: std_logic_array_16(N-1 downto 0):=(others=>(others=>'0'));
	signal symb_en 				: std_logic_vector(N-1 downto 0):=(others=>'0');
	signal symb_i 				: std_logic_array_16(N-1 downto 0):=(others=>(others=>'0'));
	signal symb_q 				: std_logic_array_16(N-1 downto 0):=(others=>(others=>'0'));
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
					when st_idle =>
					when st_lock_tll =>
					when st_lock_pll =>
					when others => null;
				end case;
            end if;
        end if;
    end process;

	u_fifo_i: fifo_s2p
	port map(
				clk 	=> sys_clk,
				srst 	=> srst	  ,
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
				clk 	=> sys_clk,
				srst 	=> srst	  ,
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
			rd_en_d <= rd_en;
			case rd_fifo_sts is
				when '0' =>
					if empty0 = '0' and empty1 = '0' then
						rd_en <= '1';
					end if;
				when '1' =>
					rd_en <= '0';
				when others => 
					rd_en <= '0';
			end case;
		end if;
	end process;

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			wave_in_valid	<=	rd_en_d;
			if rd_en_d = '1' then
				for ii in 0 to N-1 loop
					wave_in_i(ii) <= dout0((ii+1)*16-1 downto ii*16);  
					wave_in_q(ii) <= dout1((ii+1)*16-1 downto ii*16);
				end loop;
			end if;
		end if;
	end process;

	u_agc: p_agc
	generic map( N => 8)
	port map(
			sys_clk			=> 	sys_clk,
			aresetn 		=> 	aresetn,
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
			end loop;;
		end if;
	end process;

	u_tll: p_tll
	generic map ( N => 8)
	port map(
				sys_clk => sys_clk,
				rst_n   => rst_n  ,
				iq_vld 	=> iq_vld ,
				data_i 	=> wave_i ,
				data_q 	=> wave_q ,
				symb_en => symb_en,
				symb_i  => symb_i ,
				symb_q  => symb_q 
			);


	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			symb_wren <= symb_en;
			for ii in 0 to N-1 loop
				if symb_en(ii) = '1' then
					if symb_i(ii)(15 downto 10) = "000000" or symb_i(ii)(15 downto 10) = "111111" then 
						symb_i_t(ii) <=  symb_i(10 downto 3);
					elsif symb_i(ii)(15) = '0' then
						symb_i_t(ii) <=  x"7F";
					elsif symb_i(ii)(15) = '1' then
						symb_i_t(ii) <=  x"80";
					end if;
					if symb_q(ii)(15 downto 10) = "000000" or symb_q(ii)(15 downto 10) = "111111" then 
						symb_q_t(ii) <=  symb_q(10 downto 3);
					elsif symb_q(ii)(15) = '0' then
						symb_q_t(ii) <=  x"7F";
					elsif symb_q(ii)(15) = '1' then
						symb_q_t(ii) <=  x"80";
					end if;
				end if;
			end loop;
		end if;
	end process;

	gen: for ii in 0 to N-1 generate
		u_fifo_symb_i: fifo_symb
		port map(
					clk 		: in std_logic;
					srst 		: in std_logic;
					din 		: in std_logic_vector(7 downto 0);
					wr_en 		: in std_logic;
					rd_en 		: in std_logic;
					dout 		: out std_logic_vector(7 downto 0);
					full 		: out std_logic;
					empty 		: out std_logic;
					wr_rst_busy : out std_logic;
					rd_rst_busy : out std_logic 
				);

		u_fifo_symb_q: fifo_symb
		port map(
					clk : in std_logic;
					srst : in std_logic;
					din : in std_logic_vector(7 downto 0);
					wr_en : in std_logic;
					rd_en : in std_logic;
					dout : out std_logic_vector(7 downto 0);
					full : out std_logic;
					empty : out std_logic;
					wr_rst_busy : out std_logic;
					rd_rst_busy : out std_logic 
				);
	end generate gen;


	u_pll: p_pll
	generic map( N => 8)
	port map(
				 sys_clk 	  => sys_clk,
				 rst_n   	  => rst_n,
				 symb_en 	  => ,
				 symb_i  	  => ,
				 symb_q  	  => ,
				 sync_symb_en =>  ,
				 sync_symb_i  =>  ,
				 sync_symb_q  =>  
			 );

end rtl;



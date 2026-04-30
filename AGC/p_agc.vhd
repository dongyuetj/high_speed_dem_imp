----------------------------------------------------------------
-- Author: dong yue
-- Date: 2022/10/17
-- Email: y.dong@outlook.com
-- Description:
-- Version:
-----------------------------------------------------------------
library IEEE;                
use IEEE.STD_LOGIC_1164.ALL; 
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library work;
use work.my_dem_pkg.all;

entity p_agc is
	generic( N : integer := 8);
	port(
			sys_clk				: in std_logic; -- 28.8MHz
			aresetn 			: in std_logic;
			log_ref  			: in std_logic_vector(31 downto 0);
			wave_in_valid 		: in std_logic;
			wave_in_i 			: in std_logic_array_16(0 to N-1);
			wave_in_q			: in std_logic_array_16(0 to N-1);
			wave_out_valid 		: out std_logic:='0';
			wave_out_i 			: out std_logic_array_16(0 to N-1):=(others=>(others=>'0'));
			wave_out_q 			: out std_logic_array_16(0 to N-1):=(others=>(others=>'0'));
			power_out_o 		: out std_logic_vector(31 downto 0):=(others=>'0');
			exp_gain_o 			: out std_logic_vector(31 downto 0):=(others=>'0');
			agc_error 			: out std_logic_vector(31 downto 0):=(others=>'0')
		);
end p_agc;

architecture arch of p_agc is

	component p_power_detect
	generic(
			   moving_window_len : integer:=16;
			   N : integer := 8);
	port(

			sys_clk				: in std_logic; -- 28.8MHz
			aresetn 			: in std_logic;
			start_level  		: in std_logic_vector(31 downto 0);
			wave_in_valid 		: in std_logic;
			wave_in_i 			: in std_logic_array_16(0 to N-1);
			wave_in_q			: in std_logic_array_16(0 to N-1);
			power_valid	    	: out std_logic;
			power_out			: out std_logic_vector(31 downto 0)
		);
	end component;

	component fix2float
		port (
				 aclk : in std_logic;
				 aresetn : in std_logic;
				 s_axis_a_tvalid : in std_logic;
				 s_axis_a_tready : out std_logic;
				 s_axis_a_tdata : in std_logic_vector(31 downto 0);
				 m_axis_result_tvalid : out std_logic;
				 m_axis_result_tdata : out std_logic_vector(31 downto 0)
			 );
	end component;

	component float2fix
		port (
				 aclk : in std_logic;
				 aresetn : in std_logic;
				 s_axis_a_tvalid : in std_logic;
				 s_axis_a_tready : out std_logic;
				 s_axis_a_tdata : in std_logic_vector(31 downto 0);
				 m_axis_result_tvalid : out std_logic;
				 m_axis_result_tdata : out std_logic_vector(31 downto 0)
			 );
	end component;

	component floating_point_add
		port (
				 aclk : in std_logic;
				 aresetn : in std_logic;
				 s_axis_a_tvalid : in std_logic;
				 s_axis_a_tready : out std_logic;
				 s_axis_a_tdata : in std_logic_vector(31 downto 0);
				 s_axis_b_tvalid : in std_logic;
				 s_axis_b_tready : out std_logic;
				 s_axis_b_tdata : in std_logic_vector(31 downto 0);
				 m_axis_result_tvalid : out std_logic;
				 m_axis_result_tdata : out std_logic_vector(31 downto 0)
			 );
	end component;

	component floating_point_sub
		port (
				 aclk : in std_logic;
				 aresetn : in std_logic;
				 s_axis_a_tvalid : in std_logic;
				 s_axis_a_tready : out std_logic;
				 s_axis_a_tdata : in std_logic_vector(31 downto 0);
				 s_axis_b_tvalid : in std_logic;
				 s_axis_b_tready : out std_logic;
				 s_axis_b_tdata : in std_logic_vector(31 downto 0);
				 m_axis_result_tvalid : out std_logic;
				 m_axis_result_tdata : out std_logic_vector(31 downto 0)
			 );
	end component;

	component floating_point_mult
		port (
				 aclk : in std_logic;
				 aresetn : in std_logic;
				 s_axis_a_tvalid : in std_logic;
				 s_axis_a_tready : out std_logic;
				 s_axis_a_tdata : in std_logic_vector(31 downto 0);
				 s_axis_b_tvalid : in std_logic;
				 s_axis_b_tready : out std_logic;
				 s_axis_b_tdata : in std_logic_vector(31 downto 0);
				 m_axis_result_tvalid : out std_logic;
				 m_axis_result_tdata : out std_logic_vector(31 downto 0)
			 );
	end component;

	component exp
		port (
				 aclk : in std_logic;
				 aresetn : in std_logic;
				 s_axis_a_tvalid : in std_logic;
				 s_axis_a_tready : out std_logic;
				 s_axis_a_tdata : in std_logic_vector(31 downto 0);
				 m_axis_result_tvalid : out std_logic;
				 m_axis_result_tdata : out std_logic_vector(31 downto 0)
			 );
	end component;

	component log
		port (
				 aclk : in std_logic;
				 aresetn : in std_logic;
				 s_axis_a_tvalid : in std_logic;
				 s_axis_a_tready : out std_logic;
				 s_axis_a_tdata : in std_logic_vector(31 downto 0);
				 m_axis_result_tvalid : out std_logic;
				 m_axis_result_tdata : out std_logic_vector(31 downto 0)
			 );
	end component;

	COMPONENT agc_shift_ram
		PORT (
				 D : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
				 CLK : IN STD_LOGIC;
				 CE : IN STD_LOGIC;
				 Q : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
			 );
	END COMPONENT;

	component floating_point_cmp
		port (
				 aclk : in std_logic;
				 aresetn : in std_logic;
				 s_axis_a_tvalid : in std_logic;
				 s_axis_a_tready : out std_logic;
				 s_axis_a_tdata : in std_logic_vector(31 downto 0);
				 s_axis_b_tvalid : in std_logic;
				 s_axis_b_tready : out std_logic;
				 s_axis_b_tdata : in std_logic_vector(31 downto 0);
				 m_axis_result_tvalid : out std_logic;
				 m_axis_result_tdata : out std_logic_vector(7 downto 0)
			 );
	end component;

--	constant REF 				: std_logic_vector(31 downto 0):="01000110100000000000000000000000";
	constant ONE 				: std_logic_vector(31 downto 0):=x"3F800000";
--	constant LOG_REF 			: std_logic_vector(31 downto 0):=x"40F33A93"; -- log(2000)
--	constant LOG_REF 			: std_logic_vector(31 downto 0):=x"408515B5"; -- log(64)
	--constant MAX_EXP_GAIN		: std_logic_vector(31 downto 0):=x"43960000";  -- 300
	constant MAX_EXP_GAIN		: std_logic_vector(31 downto 0):=x"40800000";  -- 4
	

	signal wave_i_enlarge_width : std_logic_array_32(0 to N-1):=(others=>(others=>'0'));
	signal wave_q_enlarge_width : std_logic_array_32(0 to N-1):=(others=>(others=>'0'));
	signal gain_valid			: std_logic:='0';
	signal gain					: std_logic_vector(31 downto 0):=ONE;
	signal gain_reg				: std_logic_vector(31 downto 0):=ONE;
	signal wave_float_valid		: std_logic_vector(0 to N-1):=(others=>'0');
	signal wave_i_float			: std_logic_array_32(0 to N-1):=(others=>(others=>'0'));
	signal wave_q_float			: std_logic_array_32(0 to N-1):=(others=>(others=>'0'));
	signal wave_g_valid			: std_logic_vector(0 to N-1):=(others=>'0');
	signal wave_i_g_data		: std_logic_array_32(0 to N-1):=(others=>(others=>'0'));
	signal wave_q_g_data		: std_logic_array_32(0 to N-1):=(others=>(others=>'0'));
	signal z_valid				: std_logic:='0';
	signal z_data				: std_logic_vector(31 downto 0):=(others=>'0');
	signal z_valid_t			: std_logic:='0';
	signal z_data_t				: std_logic_vector(31 downto 0):=(others=>'0');
	signal e_valid				: std_logic:='0';
	signal e_data				: std_logic_vector(31 downto 0):=(others=>'0');
	signal e_t_valid			: std_logic:='0';
	signal e_t_data				: std_logic_vector(31 downto 0):=(others=>'0');
	signal wave_fix_valid		: std_logic_vector(0 to N-1):=(others=>'0');
	signal wave_i_fix_data  	: std_logic_array_32(0 to N-1):=(others=>(others=>'0'));
	signal wave_q_fix_data  	: std_logic_array_32(0 to N-1):=(others=>(others=>'0'));
	signal power_valid	    	: std_logic:='0';
	signal power_out			: std_logic_vector(31 downto 0):=(others=>'0');
	signal z_log_valid			: std_logic:='0';
	signal z_log				: std_logic_vector(31 downto 0):=(others=>'0');
	signal z_log_div2_valid		: std_logic:='0';
	signal z_log_div2			: std_logic_vector(31 downto 0):=(others=>'0');
	signal g_valid				: std_logic:='0';
	signal g_data 				: std_logic_vector(31 downto 0):=(others=>'0');
	signal exp_gain_valid		: std_logic:='0';
	signal exp_gain      		: std_logic_vector(31 downto 0):=(others=>'0');
	signal exp_gain_cmp      	: std_logic_vector(31 downto 0):=(others=>'0');
	signal wave_abs_valid		: std_logic:='0';
	signal wave_abs_i			: std_logic_vector(15 downto 0):=(others=>'0');
	signal wave_abs_q			: std_logic_vector(15 downto 0):=(others=>'0');
	signal wave_pow2_valid		: std_logic:='0';
	signal wave_pow2_i			: std_logic_vector(31 downto 0):=(others=>'0');
	signal wave_pow2_q			: std_logic_vector(31 downto 0):=(others=>'0');
	signal wave_out_i_t			: std_logic_array_16(0 to N-1):=(others=>(others=>'0'));
	signal wave_out_q_t			: std_logic_array_16(0 to N-1):=(others=>(others=>'0'));
	signal wave_in				: std_logic_array_32(0 to N-1):=(others=>(others=>'0'));
	signal wave_dly				: std_logic_array_32(0 to N-1):=(others=>(others=>'0'));
	signal greater_equal_flag	: std_logic:='0';
	signal greater_equal_res	: std_logic_vector(7 downto 0):=(others=>'0'); 
begin

	agc_error <= e_data;
	power_out_o <= power_out;
	exp_gain_o <= exp_gain_cmp;

	u_pwr_det: p_power_detect
	generic map(moving_window_len => 4, N => N)
	port map(
				sys_clk			=> 	sys_clk			,
				aresetn 		=>  aresetn			,
				start_level  	=>  (others=>'0') 	,
				wave_in_valid 	=> 	wave_in_valid 	,
				wave_in_i 		=>	wave_in_i		,
				wave_in_q		=>	wave_in_q		,
				power_valid	    =>  power_valid		,
				power_out		=>  power_out
			);

	-- update the gain
	u_fix2float_z: fix2float
	port map(
				aclk 					=> sys_clk,
				aresetn 				=> aresetn,
				s_axis_a_tvalid 		=> power_valid,
				s_axis_a_tready 		=> open,
				s_axis_a_tdata 			=> power_out,
				m_axis_result_tvalid 	=> z_valid_t,
				m_axis_result_tdata 	=> z_data_t
			);

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			z_valid <= z_valid_t;
			if z_data_t = x"00000000" then
				z_data <= ONE;
			else
				z_data <= z_data_t;
			end if;
		end if;
	end process;

	u_log: log
	port map(
				aclk 					=> sys_clk,
				aresetn 				=> aresetn,
				s_axis_a_tvalid 		=> z_valid,
				s_axis_a_tready 		=> open,
				s_axis_a_tdata 			=> z_data,
				m_axis_result_tvalid 	=> z_log_valid,
				m_axis_result_tdata 	=> z_log
			);

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			z_log_div2_valid <= z_log_valid;
			if z_log_valid = '1' then
				if z_log = x"00000000" then
					z_log_div2 <= (others=>'0');
				else
					z_log_div2(30 downto 23) <= z_log(30 downto 23) - "00000001"; 
					z_log_div2(31) <= z_log(31); 
					z_log_div2(22 downto 0) <= z_log(22 downto 0); 
				end if;
			end if;
		end if;
	end process;

	u_float_sub0: floating_point_sub
	port map(
				aclk 					=> sys_clk,
				aresetn 				=> aresetn,
				s_axis_a_tvalid 		=> z_log_div2_valid,
				s_axis_a_tready 		=> open,
				s_axis_a_tdata 			=> log_ref,
				s_axis_b_tvalid 		=> z_log_div2_valid,
				s_axis_b_tready 		=> open,
				s_axis_b_tdata 			=> z_log_div2,
				m_axis_result_tvalid 	=> e_t_valid,
				m_axis_result_tdata 	=> e_t_data
			);

	u_float_sub1: floating_point_sub
	port map(
				aclk 					=> sys_clk,
				aresetn 				=> aresetn,
				s_axis_a_tvalid 		=> e_t_valid,
				s_axis_a_tready 		=> open,
				s_axis_a_tdata 			=> e_t_data,
				s_axis_b_tvalid 		=> e_t_valid,
				s_axis_b_tready 		=> open,
				s_axis_b_tdata 			=> gain,
				m_axis_result_tvalid 	=> e_valid,
				m_axis_result_tdata 	=> e_data
			);

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			g_valid <= e_valid;
			if e_valid = '1' then
				if e_data = x"00000000" then
					g_data <= (others=>'0');
				else
					g_data(30 downto 23) <= e_data(30 downto 23) - "00000100"; 
					g_data(31) <= e_data(31); 
					g_data(22 downto 0) <= e_data(22 downto 0); 
				end if;
			end if;
		end if;
	end process;

	u_float_add: floating_point_add
	port map(
				aclk 					=> sys_clk,
				aresetn 				=> aresetn,
				s_axis_a_tvalid	 	=> g_valid,
				s_axis_a_tready	 	=> open,
				s_axis_a_tdata 		=> g_data,
				s_axis_b_tvalid	 	=> g_valid,
				s_axis_b_tready	 	=> open,
				s_axis_b_tdata 		=> gain,
				m_axis_result_tvalid 	=> gain_valid,
				m_axis_result_tdata  	=> gain_reg
			);

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if e_valid = '1' then
				gain <= gain_reg;
			end if;
		end if;
	end process;

	u_exp: exp
	port map(
				aclk 					=> sys_clk,
				aresetn 				=> aresetn,
				s_axis_a_tvalid 		=> gain_valid,
				s_axis_a_tready 		=> open,
				s_axis_a_tdata 			=> gain_reg,
				m_axis_result_tvalid 	=> exp_gain_valid,
				m_axis_result_tdata 	=> exp_gain
			);

	u_cmp: floating_point_cmp
	port map(
				aclk 				 => sys_clk,
				aresetn 			 => aresetn,
				s_axis_a_tvalid 	 => exp_gain_valid,
				s_axis_a_tready 	 => open,
				s_axis_a_tdata 		 => exp_gain,
				s_axis_b_tvalid 	 => '1',
				s_axis_b_tready 	 => open,
				s_axis_b_tdata 		 => MAX_EXP_GAIN,
				m_axis_result_tvalid => greater_equal_flag,
				m_axis_result_tdata  => greater_equal_res
			);
	
	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if greater_equal_flag = '1' then
				if greater_equal_res(0) = '1' then
					exp_gain_cmp <= MAX_EXP_GAIN;
				else
					exp_gain_cmp <= exp_gain;
				end if;
			end if;
		end if;
	end process; 

	gen: for ii in 0 to N-1 generate
		wave_in(ii) <= wave_in_q(ii) & wave_in_i(ii);

		u_shift_ram: agc_shift_ram
		port map(
					D 		=> wave_in(ii),
					CLK 	=> sys_clk,
					CE 		=> wave_in_valid,
					Q 		=> wave_dly(ii)
				);

		wave_i_enlarge_width(ii)(15 downto 0)  <= wave_dly(ii)(15 downto 0);
		wave_i_enlarge_width(ii)(31 downto 16) <= (others=>wave_dly(ii)(15));
		wave_q_enlarge_width(ii)(15 downto 0)  <= wave_dly(ii)(31 downto 16);
		wave_q_enlarge_width(ii)(31 downto 16) <= (others=>wave_dly(ii)(31));

		u_fix2float_i: fix2float
		port map(
					aclk 					=> sys_clk,
					aresetn 				=> aresetn,
					s_axis_a_tvalid 		=> wave_in_valid,
					s_axis_a_tready 		=> open,
					s_axis_a_tdata 			=> wave_i_enlarge_width(ii),
					m_axis_result_tvalid 	=> wave_float_valid(ii),
					m_axis_result_tdata 	=> wave_i_float(ii)
				);

		u_fix2float_q: fix2float
		port map(
					aclk 					=> sys_clk,
					aresetn 				=> aresetn,
					s_axis_a_tvalid 		=> wave_in_valid,
					s_axis_a_tready 		=> open,
					s_axis_a_tdata 			=> wave_q_enlarge_width(ii),
					m_axis_result_tvalid 	=> open,
					m_axis_result_tdata 	=> wave_q_float(ii)
				);

		u_mult_gain_i: floating_point_mult
		port map(
					aclk 				   => sys_clk,
					aresetn 			   => aresetn,
					s_axis_a_tvalid        => wave_float_valid(ii),
					s_axis_a_tready        => open,
					s_axis_a_tdata         => wave_i_float(ii),
					s_axis_b_tvalid        => wave_float_valid(ii),
					s_axis_b_tready        => open,
					s_axis_b_tdata         => exp_gain_cmp,
					m_axis_result_tvalid   => wave_g_valid(ii),
					m_axis_result_tdata    => wave_i_g_data(ii)
				);

		u_mult_gain_q: floating_point_mult
		port map(
					aclk 				   => sys_clk,
					aresetn 			   => aresetn,
					s_axis_a_tvalid        => wave_float_valid(ii),
					s_axis_a_tready        => open,
					s_axis_a_tdata         => wave_q_float(ii),
					s_axis_b_tvalid        => wave_float_valid(ii),
					s_axis_b_tready        => open,
					s_axis_b_tdata         => exp_gain_cmp,
					m_axis_result_tvalid   => open,
					m_axis_result_tdata    => wave_q_g_data(ii)
				);

		u_float2fix_i: float2fix
		port map(
					aclk 					=> sys_clk,
					aresetn 				=> aresetn,
					s_axis_a_tvalid 		=> wave_g_valid(ii),
					s_axis_a_tready 		=> open,
					s_axis_a_tdata 			=> wave_i_g_data(ii),
					m_axis_result_tvalid	=> wave_fix_valid(ii),
					m_axis_result_tdata 	=> wave_i_fix_data(ii)
				);

		u_float2fix_q: float2fix
		port map(
					aclk 					=> sys_clk,
					aresetn 				=> aresetn,
					s_axis_a_tvalid 		=> wave_g_valid(ii),
					s_axis_a_tready 		=> open,
					s_axis_a_tdata 			=> wave_q_g_data(ii),
					m_axis_result_tvalid	=> open,
					m_axis_result_tdata 	=> wave_q_fix_data(ii)
				);

	end generate gen;

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			for ii in 0 to N-1 loop
				if wave_fix_valid(ii) = '1' then
					wave_out_i_t(ii)	<=	wave_i_fix_data(ii)(15 downto 0);
				end if;
				if wave_fix_valid(ii) = '1' then
					wave_out_q_t(ii)	<=	wave_q_fix_data(ii)(15 downto 0);
				end if;
			end loop;
		end if;
	end process;

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			wave_out_valid <= wave_in_valid;
			for ii in 0 to N-1 loop
				if aresetn = '0' then
					wave_out_i(ii)	<=	(others=>'0');
					wave_out_q(ii)  <=	(others=>'0');
				else
					wave_out_i(ii)	<=	wave_out_i_t(ii); 
					wave_out_q(ii)  <=	wave_out_q_t(ii);
				end if;
			end loop;
		end if;
	end process;

	
end arch;

----------------------------------------------------------------
-- Author: dong yue
-- Date: 2024/9/25
-- Email: y.dong@outlook.com
-- Description:
-- Version:
-----------------------------------------------------------------
library IEEE;                
use IEEE.STD_LOGIC_1164.ALL; 
use IEEE.NUMERIC_STD.ALL;

library work;
use work.my_dem_pkg.all;

entity tll is
	port(
			sys_clk		: in std_logic;
			aresetn 	: in std_logic;
			en_samp		: in std_logic;
			samp_i		: in std_logic_vector(23 downto 0);
			samp_q		: in std_logic_vector(23 downto 0);
			en_sym 		: out std_logic:='0';
			sym_i		: out std_logic_vector(23 downto 0):=(others=>'0');
			sym_q		: out std_logic_vector(23 downto 0):=(others=>'0')
		);
end tll;
architecture arch of tll is

	component fix2float24
		port (
				 aclk : in std_logic;
				 aresetn : in std_logic;
				 s_axis_a_tvalid : in std_logic;
				 s_axis_a_tready : out std_logic;
				 s_axis_a_tdata : in std_logic_vector(23 downto 0);
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

	component floating_point_acc
		port (
				 aclk : in std_logic;
				 aresetn : in std_logic;
				 s_axis_a_tvalid : in std_logic;
				 s_axis_a_tready : out std_logic;
				 s_axis_a_tdata : in std_logic_vector(31 downto 0);
				 s_axis_a_tlast : in std_logic;
				 m_axis_result_tvalid : out std_logic;
				 m_axis_result_tdata : out std_logic_vector(31 downto 0);
				 m_axis_result_tlast : out std_logic
			 );
	end component;

	component floating_point_div
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

	constant ONE 					: std_logic_vector(31 downto 0):=x"3F800000";
	constant TWO_POS				: std_logic_vector(31 downto 0):=x"40000000";
	constant TWO_NEG				: std_logic_vector(31 downto 0):=x"C0000000";
	constant K1						: std_logic_vector(31 downto 0):=x"B4E2B7F7";
	constant K2						: std_logic_vector(31 downto 0):=x"B0C17770";
	signal samp_i_f_d 				: std_logic_vector(31 downto 0):=(others=>'0');
	signal samp_q_f_d 				: std_logic_vector(31 downto 0):=(others=>'0');
	signal cnt_next 				: std_logic_vector(31 downto 0):= ONE;
	signal cnt		 				: std_logic_vector(31 downto 0):=(others=>'0');
	signal mu_next 					: std_logic_vector(31 downto 0):=(others=>'0');
	signal mu	 					: std_logic_vector(31 downto 0):=(others=>'0');
	signal underflow				: std_logic:='0';
	signal vi						: std_logic_vector(31 downto 0):=(others=>'0'); -- integration part
	signal vi_pre					: std_logic_vector(31 downto 0):=(others=>'0'); -- integration part
	signal vp						: std_logic_vector(31 downto 0):=(others=>'0'); -- propagation part
	signal v						: std_logic_vector(31 downto 0):=(others=>'0'); -- loop output
	signal x_buff_i				: std_logic_array_32(sps-1 downto 0):=(others=>(others=>'0'));
	signal x_buff_q				: std_logic_array_32(sps-1 downto 0):=(others=>(others=>'0'));
	signal samp_f_vld				: std_logic:='0';
	signal samp_i_f					: std_logic_vector(31 downto 0):=(others=>'0');
	signal samp_q_f					: std_logic_vector(31 downto 0):=(others=>'0');
	signal one_minus_mu_vld 		: std_logic:='0';
	signal one_minus_mu				: std_logic_vector(31 downto 0):=(others=>'0');
	signal interp_vld				: std_logic:='0';
	signal interp_part_i0			: std_logic_vector(31 downto 0):=(others=>'0');
	signal interp_part_i1			: std_logic_vector(31 downto 0):=(others=>'0');
	signal interp_part_q0			: std_logic_vector(31 downto 0):=(others=>'0');
	signal interp_part_q1			: std_logic_vector(31 downto 0):=(others=>'0');
	signal interp_final_vld			: std_logic:='0';
	signal interp_final_i			: std_logic_vector(31 downto 0):=(others=>'0');
	signal interp_final_q			: std_logic_vector(31 downto 0):=(others=>'0');
	signal ted_sub_vld				: std_logic:='0';
	signal ted_sub_i				: std_logic_vector(31 downto 0):=(others=>'0');
	signal ted_sub_q				: std_logic_vector(31 downto 0):=(others=>'0');
	signal ted_mult_vld				: std_logic:='0';
	signal ted_mult_i				: std_logic_vector(31 downto 0):=(others=>'0');
	signal ted_mult_q				: std_logic_vector(31 downto 0):=(others=>'0');
	signal ted_vld					: std_logic:='0';
	signal ted						: std_logic_vector(31 downto 0):=(others=>'0');
	signal err_vld					: std_logic:='0';
	signal err						: std_logic_vector(31 downto 0):=(others=>'0');
	signal vp_vld					: std_logic:='0';
	signal v2_vld					: std_logic:='0';
	signal v2						: std_logic_vector(31 downto 0):=(others=>'0');
	signal vi_vld					: std_logic:='0';
	signal vi_last					: std_logic:='0';
	signal v_vld					: std_logic:='0';
	signal W_vld					: std_logic:='0';
	signal W_out					: std_logic_vector(31 downto 0):=(others=>'0');
	signal cnt_next_t_vld			: std_logic:='0';
	signal cnt_next_t				: std_logic_vector(31 downto 0):=(others=>'0');
	signal w_div_cnt_vld			: std_logic:='0';
	signal w_div_cnt				: std_logic_vector(31 downto 0):=(others=>'0');
	signal one_plus_cnt_next_t_vld	: std_logic:='0';
	signal one_plus_cnt_next_t		: std_logic_vector(31 downto 0):=(others=>'0');
	signal float2fix_vld			: std_logic:='0';
	signal float2fix_i				: std_logic_vector(31 downto 0):=(others=>'0');
	signal float2fix_q				: std_logic_vector(31 downto 0):=(others=>'0');
	signal en_sym_t 				: std_logic:='0';
begin
	---------------------------------
	-- fixed point to float
	---------------------------------

	u_fix2float_i: fix2float24
	port map(
				 aclk 					=> sys_clk,
				 aresetn 				=> aresetn,
				 s_axis_a_tvalid 		=> en_samp,
				 s_axis_a_tready 		=> open,
				 s_axis_a_tdata 		=> samp_i,
				 m_axis_result_tvalid 	=> samp_f_vld,
				 m_axis_result_tdata 	=> samp_i_f
			 );

	u_fix2float_q: fix2float24
	port map(
				 aclk 					=> sys_clk,
				 aresetn 				=> aresetn,
				 s_axis_a_tvalid 		=> en_samp,
				 s_axis_a_tready 		=> open,
				 s_axis_a_tdata 		=> samp_q,
				 m_axis_result_tvalid 	=> open,
				 m_axis_result_tdata 	=> samp_q_f
			 );

	-------------------------------
	-- interpalation 
	-------------------------------
	-- update mu and cnt
	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if aresetn = '0' then
				mu  <= (others=>'0');
				cnt <= (others=>'0');
				vi_pre <= (others=>'0');
			elsif en_samp = '1' then
				mu  <= mu_next;
				cnt <= cnt_next;
				vi_pre <= vi;
			end if;
		end if;
	end process; 

	-- calculate 1-mu
	u_1_sub_mu: floating_point_sub
	port map(
				 aclk 					=> sys_clk,
				 aresetn 				=> aresetn,
				 s_axis_a_tvalid 		=> samp_f_vld,
				 s_axis_a_tready 		=> open,
				 s_axis_a_tdata 		=> x"3F800000",
				 s_axis_b_tvalid 		=> samp_f_vld,
				 s_axis_b_tready 		=> open,
				 s_axis_b_tdata 		=> mu,
				 m_axis_result_tvalid 	=> one_minus_mu_vld,
				 m_axis_result_tdata 	=> one_minus_mu
			 );

	-- real(mu * xn)
	u_mu_mult_1_i: floating_point_mult
	port map(
				 aclk 					=> sys_clk,
				 aresetn 				=> aresetn,
				 s_axis_a_tvalid 		=> one_minus_mu_vld,
				 s_axis_a_tready 		=> open,
				 s_axis_a_tdata 		=> mu,
				 s_axis_b_tvalid 		=> one_minus_mu_vld,
				 s_axis_b_tready 		=> open,
				 s_axis_b_tdata 		=> samp_i_f,
				 m_axis_result_tvalid 	=> interp_vld,
				 m_axis_result_tdata 	=> interp_part_i0
			 );

	-- real((1-mu)*xn-1)
	u_mu_mult_2_i: floating_point_mult
	port map(
				 aclk 					=> sys_clk,
				 aresetn 				=> aresetn,
				 s_axis_a_tvalid 		=> one_minus_mu_vld,
				 s_axis_a_tready 		=> open,
				 s_axis_a_tdata 		=> one_minus_mu,
				 s_axis_b_tvalid 		=> one_minus_mu_vld,
				 s_axis_b_tready 		=> open,
				 s_axis_b_tdata 		=> samp_i_f_d,
				 m_axis_result_tvalid 	=> open,
				 m_axis_result_tdata 	=> interp_part_i1
			 );

	-- imag(mu * xn)
	u_mu_mult_1_q: floating_point_mult
	port map(
				 aclk 					=> sys_clk,
				 aresetn 				=> aresetn,
				 s_axis_a_tvalid 		=> one_minus_mu_vld,
				 s_axis_a_tready 		=> open,
				 s_axis_a_tdata 		=> mu,
				 s_axis_b_tvalid 		=> one_minus_mu_vld,
				 s_axis_b_tready 		=> open,
				 s_axis_b_tdata 		=> samp_q_f,
				 m_axis_result_tvalid 	=> open,
				 m_axis_result_tdata 	=> interp_part_q0
			 );

	-- imag((1-mu)*xn-1)
	u_mu_mult_2_q: floating_point_mult
	port map(
				 aclk 					=> sys_clk,
				 aresetn 				=> aresetn,
				 s_axis_a_tvalid 		=> one_minus_mu_vld,
				 s_axis_a_tready 		=> open,
				 s_axis_a_tdata 		=> one_minus_mu,
				 s_axis_b_tvalid 		=> one_minus_mu_vld,
				 s_axis_b_tready 		=> open,
				 s_axis_b_tdata 		=> samp_q_f_d,
				 m_axis_result_tvalid 	=> open,
				 m_axis_result_tdata 	=> interp_part_q1
			 );

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if aresetn = '0' then
				samp_i_f_d <= (others=>'0')	;
				samp_q_f_d <= (others=>'0')	;
			elsif one_minus_mu_vld = '1' then
				samp_i_f_d <= samp_i_f	;
				samp_q_f_d <= samp_q_f	;
			end if;
		end if;
	end process; 

	-- real(mu*xn + (1-mu)*xn-1)
	u_interp_i: floating_point_add
	port map(
				 aclk 					=> sys_clk,
				 aresetn 				=> aresetn,
				 s_axis_a_tvalid 		=> interp_vld,
				 s_axis_a_tready 		=> open,
				 s_axis_a_tdata 		=> interp_part_i0,
				 s_axis_b_tvalid 		=> interp_vld,
				 s_axis_b_tready 		=> open,
				 s_axis_b_tdata 		=> interp_part_i1,
				 m_axis_result_tvalid 	=> interp_final_vld,
				 m_axis_result_tdata 	=> interp_final_i
			 );

	-- imag(mu*xn + (1-mu)*xn-1)
	u_interp_q: floating_point_add
	port map(
				 aclk 					=> sys_clk,
				 aresetn 				=> aresetn,
				 s_axis_a_tvalid 		=> interp_vld,
				 s_axis_a_tready 		=> open,
				 s_axis_a_tdata 		=> interp_part_q0,
				 s_axis_b_tvalid 		=> interp_vld,
				 s_axis_b_tready 		=> open,
				 s_axis_b_tdata 		=> interp_part_q1,
				 m_axis_result_tvalid 	=> open,
				 m_axis_result_tdata 	=> interp_final_q
			 );

	-------------------------------
	-- calcuate TED
	-------------------------------
	--sign(real(TEDBuff(sps))) - sign(real(xI))
	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			ted_sub_vld <= interp_final_vld ;
			if interp_final_vld = '1' then
				if x_buff_i(3)(31) = '0' and interp_final_i(31) = '0' then
					ted_sub_i <= (others=>'0');
				elsif x_buff_i(3)(31) = '1' and interp_final_i(31) = '1' then
					ted_sub_i <= (others=>'0');
				elsif x_buff_i(3)(31) = '0' and interp_final_i(31) = '1' then
					ted_sub_i <= TWO_POS;
				elsif x_buff_i(3)(31) = '1' and interp_final_i(31) = '0' then
					ted_sub_i <= TWO_NEG;
				end if;
				if x_buff_q(3)(31) = '0' and interp_final_q(31) = '0' then
					ted_sub_q <= (others=>'0');
				elsif x_buff_q(3)(31) = '1' and interp_final_q(31) = '1' then
					ted_sub_q <= (others=>'0');
				elsif x_buff_q(3)(31) = '0' and interp_final_q(31) = '1' then
					ted_sub_q <= TWO_POS;
				elsif x_buff_q(3)(31) = '1' and interp_final_q(31) = '0' then
					ted_sub_q <= TWO_NEG;
				end if;
			end if;
		end if;
	end process; 

--	u_ted_sub_i: floating_point_sub
--	port map(
--				 aclk 					=> sys_clk,
--				 aresetn 				=> aresetn,
--				 s_axis_a_tvalid 		=> interp_final_vld ,
--				 s_axis_a_tready 		=> open,
--				 s_axis_a_tdata 		=> x_buff_i(3),
--				 s_axis_b_tvalid 		=> interp_final_vld ,
--				 s_axis_b_tready 		=> open,
--				 s_axis_b_tdata 		=> interp_final_i,
--				 m_axis_result_tvalid 	=> ted_sub_vld,
--				 m_axis_result_tdata 	=> ted_sub_i
--			 );

	--sign(imag(TEDBuff(sps))) - sign(imag(xI))

--	u_ted_sub_q: floating_point_sub
--	port map(
--				 aclk 					=> sys_clk,
--				 aresetn 				=> aresetn,
--				 s_axis_a_tvalid 		=> interp_final_vld ,
--				 s_axis_a_tready 		=> open,
--				 s_axis_a_tdata 		=> x_buff_q(3),
--				 s_axis_b_tvalid 		=> interp_final_vld ,
--				 s_axis_b_tready 		=> open,
--				 s_axis_b_tdata 		=> interp_final_q,
--				 m_axis_result_tvalid 	=> open,
--				 m_axis_result_tdata 	=> ted_sub_q
--			 );

	--real(TEDBuff(sps/2)) * (sign(real(TEDBuff(sps))) - sign(real(xI)))
	u_ted_mul_i: floating_point_mult
	port map(
				 aclk 					=> sys_clk,
				 aresetn 				=> aresetn,
				 s_axis_a_tvalid 		=> ted_sub_vld ,
				 s_axis_a_tready 		=> open,
				 s_axis_a_tdata 		=> ted_sub_i,
				 s_axis_b_tvalid 		=> ted_sub_vld ,
				 s_axis_b_tready 		=> open,
				 s_axis_b_tdata 		=> x_buff_i(1),
				 m_axis_result_tvalid 	=> ted_mult_vld,
				 m_axis_result_tdata 	=> ted_mult_i
			 );
	--imag(TEDBuff(sps/2)) * (sign(imag(TEDBuff(sps))) - sign(imag(xI)))
	u_ted_mul_q: floating_point_mult
	port map(
				 aclk 					=> sys_clk,
				 aresetn 				=> aresetn,
				 s_axis_a_tvalid 		=> ted_sub_vld ,
				 s_axis_a_tready 		=> open,
				 s_axis_a_tdata 		=> ted_sub_q,
				 s_axis_b_tvalid 		=> ted_sub_vld ,
				 s_axis_b_tready 		=> open,
				 s_axis_b_tdata 		=> x_buff_q(1), 
				 m_axis_result_tvalid 	=> open,
				 m_axis_result_tdata 	=> ted_mult_q
			 );

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if aresetn = '0' then
				x_buff_i(0) <= (others=>'0'); 
				x_buff_q(0) <= (others=>'0');
				x_buff_i(1) <= (others=>'0');
				x_buff_q(1) <= (others=>'0'); 
				x_buff_i(2) <= (others=>'0'); 
				x_buff_q(2) <= (others=>'0'); 
				x_buff_i(3) <= (others=>'0'); 
				x_buff_q(3) <= (others=>'0'); 
			elsif ted_mult_vld = '1' then
				x_buff_i(0)<= interp_final_i;
				x_buff_q(0)<= interp_final_q;
				x_buff_i(1)<= x_buff_i(0);
				x_buff_q(1)<= x_buff_q(0);
				x_buff_i(2)<= x_buff_i(1);
				x_buff_q(2)<= x_buff_q(1);
				x_buff_i(3)<= x_buff_i(2);
				x_buff_q(3)<= x_buff_q(2);
			end if;
		end if;
	end process; 

	-- calculate ted = real(TEDBuff(sps/2)) * (real(TEDBuff(sps)) - real(xI)) + imag(TEDBuff(sps/2)) * (imag(TEDBuff(sps)) - imag(xI))
	u_ted_add: floating_point_add
	port map(
				 aclk 					=> sys_clk,
				 aresetn 				=> aresetn,
				 s_axis_a_tvalid 		=> ted_mult_vld ,
				 s_axis_a_tready 		=> open,
				 s_axis_a_tdata 		=> ted_mult_i,
				 s_axis_b_tvalid 		=> ted_mult_vld ,
				 s_axis_b_tready 		=> open,
				 s_axis_b_tdata 		=> ted_mult_q,
				 m_axis_result_tvalid 	=> ted_vld,
				 m_axis_result_tdata 	=> ted
			 );

	-------------------------------
	-- loop filter
	-------------------------------
	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			err_vld <= ted_vld ;
			if (ted_vld = '1') and (underflow = '1') then
				en_sym_t <= '1';
				err <= ted;
			else
				en_sym_t <= '0';
				err <= (others=>'0');
			end if;
		end if;
	end process; 

	-----------------------------
	-- float to fixed point
	-----------------------------
	u_float2fix_i: float2fix
	port map(
				 aclk 					=> sys_clk,
				 aresetn 				=> aresetn,
				 s_axis_a_tvalid 		=> en_sym_t ,
				 s_axis_a_tready 		=> open,
				 s_axis_a_tdata 		=> interp_final_i,
				 m_axis_result_tvalid 	=> float2fix_vld,
				 m_axis_result_tdata 	=> float2fix_i
			 );

	u_float2fix_q: float2fix
	port map(
				 aclk 					=> sys_clk,
				 aresetn 				=> aresetn,
				 s_axis_a_tvalid 		=> en_sym_t ,
				 s_axis_a_tready 		=> open,
				 s_axis_a_tdata 		=> interp_final_q,
				 m_axis_result_tvalid 	=> open,
				 m_axis_result_tdata 	=> float2fix_q
			 );

	en_sym 	<= float2fix_vld;
	sym_i	<= float2fix_i(23 downto 0);
	sym_q	<= float2fix_q(23 downto 0);

	-- vp = k1 * ted
	u_k1_mul: floating_point_mult
	port map(
				 aclk 					=> sys_clk,
				 aresetn 				=> aresetn,
				 s_axis_a_tvalid 		=> err_vld,
				 s_axis_a_tready 		=> open,
				 s_axis_a_tdata 		=> K1,
				 s_axis_b_tvalid 		=> err_vld,
				 s_axis_b_tready 		=> open,
				 s_axis_b_tdata 		=> err,
				 m_axis_result_tvalid 	=> vp_vld,
				 m_axis_result_tdata 	=> vp
			 );

	-- k2 * ted
	u_k2_mul: floating_point_mult
	port map(
				 aclk 					=> sys_clk,
				 aresetn 				=> aresetn,
				 s_axis_a_tvalid 		=> err_vld,
				 s_axis_a_tready 		=> open,
				 s_axis_a_tdata 		=> K2,
				 s_axis_b_tvalid 		=> err_vld,
				 s_axis_b_tready 		=> open,
				 s_axis_b_tdata 		=> err,
				 m_axis_result_tvalid 	=> v2_vld,
				 m_axis_result_tdata 	=> v2
			 );

	-- int(k2 * ted)
	-- vi = vi + v2;
	u_int: floating_point_add
	port map(
				aclk 					=> sys_clk,
				aresetn					=> aresetn,
				s_axis_a_tvalid 		=> v2_vld,
				s_axis_a_tready 		=> open,
				s_axis_a_tdata 			=> v2,
				s_axis_b_tvalid 		=> v2_vld,
				s_axis_b_tready 		=> open,
				s_axis_b_tdata 			=> vi_pre,
				m_axis_result_tvalid 	=> vi_vld,
				m_axis_result_tdata 	=> vi
			);

	-- loop filter output v = vi + vp
	u_loop_out: floating_point_add 
	port map(
				aclk 					=> sys_clk,
				aresetn 				=> aresetn,
				s_axis_a_tvalid 		=> vi_vld,
				s_axis_a_tready 		=> open,
				s_axis_a_tdata 			=> vi,
				s_axis_b_tvalid 		=> vi_vld,
				s_axis_b_tready 		=> open,
				s_axis_b_tdata 			=> vp,
				m_axis_result_tvalid 	=> v_vld,
				m_axis_result_tdata 	=> v
			 );

	-- calculate W = 1/sps + v
	u_w_out: floating_point_add 
	port map(
				aclk 					=> sys_clk,
				aresetn 				=> aresetn,
				s_axis_a_tvalid 		=> v_vld,
				s_axis_a_tready 		=> open,
				s_axis_a_tdata 			=> v,
				s_axis_b_tvalid 		=> v_vld,
				s_axis_b_tready 		=> open,
				s_axis_b_tdata 			=> x"3E800000", -- 1/sps = 0.25
				m_axis_result_tvalid 	=> W_vld,
				m_axis_result_tdata 	=> W_out
			 );

	-------------------------------
	-- interp control
	-------------------------------
	-- calculate cnt_next_t = cnt - W
	u_cnt: floating_point_sub 
	port map(
				aclk 					=> sys_clk,
				aresetn 				=> aresetn,
				s_axis_a_tvalid 		=> W_vld,
				s_axis_a_tready 		=> open,
				s_axis_a_tdata 			=> cnt, -- 1/sps
				s_axis_b_tvalid 		=> W_vld,
				s_axis_b_tready 		=> open,
				s_axis_b_tdata 			=> W_out,
				m_axis_result_tvalid 	=> cnt_next_t_vld,
				m_axis_result_tdata 	=> cnt_next_t
			 );

	-- judge underflow or not according to the sign of cnt_next_t
	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if aresetn = '0' then
				underflow <= '0';
			elsif cnt_next_t_vld = '1' then
				if cnt_next_t(31) = '1' then 
					underflow <= '1';
				else
					underflow <= '0';
				end if;
			end if;
		end if;
	end process; 

	-- calculat cnt/W
	u_div: floating_point_div
	port map(
				 aclk 					=> sys_clk,
				 aresetn 				=> aresetn,
				 s_axis_a_tvalid 		=> cnt_next_t_vld ,
				 s_axis_a_tready 		=> open,
				 s_axis_a_tdata 		=> cnt,
				 s_axis_b_tvalid 		=> cnt_next_t_vld ,
				 s_axis_b_tready 		=> open,
				 s_axis_b_tdata 		=> W_out,
				 m_axis_result_tvalid 	=> w_div_cnt_vld,
				 m_axis_result_tdata 	=> w_div_cnt
			 );

	-- calculate 1 + cnt_next_t
	u_add: floating_point_add
	port map(
				 aclk 					=> sys_clk,
				 aresetn 				=> aresetn,
				 s_axis_a_tvalid 		=> cnt_next_t_vld ,
				 s_axis_a_tready 		=> open,
				 s_axis_a_tdata 		=> ONE,
				 s_axis_b_tvalid 		=> cnt_next_t_vld ,
				 s_axis_b_tready 		=> open,
				 s_axis_b_tdata 		=> cnt_next_t,
				 m_axis_result_tvalid 	=> one_plus_cnt_next_t_vld,
				 m_axis_result_tdata 	=> one_plus_cnt_next_t
			 );

	-- update mu_next and cnt_next according to underflow flag
	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if aresetn = '0' then
				cnt_next <= ONE;
	 			mu_next  <= (others=>'0');
			elsif w_div_cnt_vld = '1' then
				if cnt_next_t(31) = '1' then 
					cnt_next <= one_plus_cnt_next_t;
					mu_next <= w_div_cnt;
				else
					cnt_next <= cnt_next_t;
					mu_next <= mu;
				end if;
			end if;
		end if;
	end process; 


end arch;

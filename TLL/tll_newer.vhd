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

entity tll_newer is
	port(
			sys_clk		: in std_logic;
			aresetn 	: in std_logic;
			samp_vld	: in std_logic;
			samp_i		: in std_logic_vector(8 downto 0);
			samp_q		: in std_logic_vector(8 downto 0);
			en_sym 		: out std_logic;
			sym_i		: out std_logic_vector(24 downto 0):= (others=>'0'); 
			sym_q		: out std_logic_vector(24 downto 0):= (others=>'0'); 
			dmu_out_vld : out std_logic:='0';
			dmu_out		: out std_logic_vector(24 downto 0):= (others=>'0') 
		);
end tll_newer;

architecture arch of tll_newer is

	component div_gen
		port (
				 aclk : in std_logic;
				 aresetn : in std_logic;
				 s_axis_divisor_tvalid : in std_logic;
				 s_axis_divisor_tdata : in std_logic_vector(31 downto 0);
				 s_axis_dividend_tvalid : in std_logic;
				 s_axis_dividend_tdata : in std_logic_vector(47 downto 0);
				 m_axis_dout_tvalid : out std_logic;
				 m_axis_dout_tdata : out std_logic_vector(79 downto 0) 
			 );
	end component;

	-- TLL gain is 2^10
	type signed_array_25 is array (natural range<>) of signed(24 downto 0);
	-- Q8.16
	constant ONE			: signed(24 downto 0):= to_signed(65536, 25);
	constant HALF_ONE		: signed(24 downto 0):= to_signed(32768,25);
	constant HALF_ONE_NEG 	: signed(24 downto 0):= to_signed(-32768,25);
	constant MINIMAL		: signed(24 downto 0):= to_signed(256,25);
	-- agc REF = 64
	-- loop factor = 2^8
	-- K1 = -0.0098
	-- K2 = -3.2812e-05 
	constant K1			: signed(24 downto 0):=to_signed(-645, 25);
	constant K2			: signed(24 downto 0):=to_signed(-2, 25);
	signal one_minus_mu	: signed(24 downto 0):= (others=>'0');	
	signal xI_0			: signed(49 downto 0):= (others=>'0');	
	signal xI_1			: signed(49 downto 0):= (others=>'0');	
	signal yI_0			: signed(49 downto 0):= (others=>'0');	
	signal yI_1			: signed(49 downto 0):= (others=>'0');	

	signal samp_i_q		: std_logic_vector(24 downto 0):=(others=>'0');
	signal samp_q_q		: std_logic_vector(24 downto 0):=(others=>'0');
	signal samp_i_d		: std_logic_vector(24 downto 0):=(others=>'0');
	signal samp_q_d		: std_logic_vector(24 downto 0):=(others=>'0');
	signal cnt			: signed(24 downto 0):=ONE;
	signal mu			: signed(24 downto 0):=HALF_ONE;
	signal mu_next  	: signed(24 downto 0):=HALF_ONE;
	signal dmu		  	: signed(24 downto 0):=(others=>'0'); 
	signal TED_buff_x	: signed_array_25(1 downto 0):=(others=>(others=>'0'));
	signal TED_buff_y	: signed_array_25(1 downto 0):=(others=>(others=>'0')); 
	signal xI			: signed(49 downto 0):=(others=>'0');
	signal yI			: signed(49 downto 0):=(others=>'0');
	signal xI_t			: signed(24 downto 0):=(others=>'0');
	signal yI_t			: signed(24 downto 0):=(others=>'0');
	signal diff_x			: signed(24 downto 0):=(others=>'0');
	signal diff_y			: signed(24 downto 0):=(others=>'0');
	signal err			: signed(49 downto 0):=(others=>'0'); 
	signal err_x			: signed(49 downto 0):=(others=>'0'); 
	signal err_y			: signed(49 downto 0):=(others=>'0'); 
	signal err_t		: signed(24 downto 0):=(others=>'0'); 
	signal err_trunc	: signed(24 downto 0):=(others=>'0'); 
	signal underflow	: std_logic:='1';
	signal vi			: signed(49 downto 0):=(others=>'0'); 
	signal vp			: signed(49 downto 0):=(others=>'0'); 
	signal vi_p			: signed(49 downto 0):=(others=>'0'); 
	signal v			: signed(49 downto 0):=(others=>'0'); 
	signal v_div		: signed(49 downto 0):=(others=>'0'); 
	signal v_div_t		: signed(24 downto 0):=(others=>'0'); 
	signal W			: signed(24 downto 0):=HALF_ONE; --sps = 2;
	signal W_t			: signed(24 downto 0):=HALF_ONE;
	signal samp_vld_d  	: std_logic_vector(16 downto 0):=(others=>'0'); 
	signal div_vld 		: std_logic:='0';
	signal div_vld_d 	: std_logic:='0';
	signal div_vld_dd 	: std_logic:='0';
	signal div_vld_ddd 	: std_logic:='0';
	signal dividend  	: std_logic_vector(47 downto 0):=(others=>'0');
	signal cnt_shift	: std_logic_vector(47 downto 0):=(others=>'0');
	signal divisor   	: std_logic_vector(31 downto 0):=(others=>'0');
	signal quotient  	: std_logic_vector(79 downto 0):=(others=>'0');
	signal cnt_next 	: signed(24 downto 0):=ONE;

begin      

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			samp_vld_d <= samp_vld_d(samp_vld_d'high-1 downto 0) & samp_vld ;
		end if;
	end process;

	-- int to q8.16
	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if samp_vld = '1' then 
				samp_i_q(24 downto 16) <= samp_i(8 downto 0);
				samp_q_q(24 downto 16) <= samp_q(8 downto 0);
				samp_i_q(15 downto 0) <= (others=>'0'); 
				samp_q_q(15 downto 0) <= (others=>'0'); 
				samp_i_d <= samp_i_q ;
				samp_q_d <= samp_q_q ;
			end if;
		end if;
	end process; 

	-- linear interpolator
	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if aresetn = '0' then
				one_minus_mu <= (others=>'0');  
				xI <= (others=>'0');  
				yI <= (others=>'0');  
				xI_0 <= (others=>'0');  
				xI_1 <= (others=>'0');  
				yI_0 <= (others=>'0');  
				yI_1 <= (others=>'0');  
			else
				if samp_vld_d(0) = '1' then
					one_minus_mu <= (ONE - mu) ;
				end if;
				if samp_vld_d(1) = '1' then
					xI_0 <= one_minus_mu * signed(samp_i_d);
					xI_1 <=	mu * signed(samp_i_q);
					yI_0 <= one_minus_mu * signed(samp_q_d);
					yI_1 <=	mu * signed(samp_q_q);
				end if;
				if samp_vld_d(2) = '1' then
					xI <= xI_0 + xI_1;
					yI <= yI_0 + yI_1;
				end if;
			end if;
		end if;
	end process;

	-- truncation, Q17.32 -> Q8.16
	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if aresetn = '0' then
				xI_t <= (others=>'0');  
				yI_t <= (others=>'0');  
			else
				if samp_vld_d(3) = '1' then
					if xI(49 downto 40) = "0000000000" or xI(49 downto 40) = "1111111111" then
						xI_t(24 downto 16) <= xI(40 downto 32);
					elsif xI(49) = '0' then
						xI_t(24 downto 16) <= "011111111";
					elsif xI(49) = '1' then
						xI_t(24 downto 16) <= "100000001";
					end if;
					if yI(49 downto 40) = "0000000000" or yI(49 downto 40) = "1111111111" then
						yI_t(24 downto 16) <= yI(40 downto 32);
					elsif yI(49) = '0' then
						yI_t(24 downto 16) <= "011111111";
					elsif yI(49) = '1' then
						yI_t(24 downto 16) <= "100000001";
					end if;
					xI_t(15 downto 0) <= xI(31 downto 16);
					yI_t(15 downto 0) <= yI(31 downto 16);
				end if;
			end if;
		end if;
	end process;


	-- and update symbols and TED
	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if aresetn = '0' then
				err <= (others=>'0'); 
				en_sym <= '0';
				diff_x <= (others=>'0'); 
				diff_y <= (others=>'0'); 
				err_x <= (others=>'0'); 
				err_y <= (others=>'0'); 
				sym_i <= (others=>'0'); 
				sym_q <= (others=>'0'); 
			else
				if (samp_vld_d(4) = '1') and (underflow = '1') then
					diff_x <= (TED_buff_x(1) - xI_t);
					diff_y <= (TED_buff_y(1) - yI_t);
				end if;
				if (samp_vld_d(5) = '1') and (underflow = '1') then
					err_x <= TED_buff_x(0)*diff_x;
					err_y <= TED_buff_y(0)*diff_y;
				end if;
				if (samp_vld_d(6) = '1') and (underflow = '1') then
					err <=  err_x + err_y;
					en_sym <= '1';
					sym_i	<=	std_logic_vector(xI_t);
					sym_q	<=	std_logic_vector(yI_t);
				else
					err <= (others=>'0'); 
					en_sym <= '0';
				end if;
			end if;
		end if;
	end process;

	-- delay interpolation samples 
	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if aresetn = '0' then
				TED_buff_x(0) <= (others=>'0'); 
				TED_buff_x(1) <= (others=>'0'); 
				TED_buff_y(0) <= (others=>'0'); 
				TED_buff_y(1) <= (others=>'0'); 
			else
				if samp_vld_d(6) = '1' then
					TED_buff_x(0) <= xI_t;
					TED_buff_x(1) <= TED_buff_x(0);
					TED_buff_y(0) <= yI_t;
					TED_buff_y(1) <= TED_buff_y(0);
				end if;
			end if;
		end if;
	end process;

	-- err: Q17.32, truncation: err_t: Q8.16
	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if aresetn = '0' then
				err_t <= (others=>'0'); 
			else
				if samp_vld_d(7) = '1' then
					if err(49 downto 40) = "0000000000" or err(49 downto 40) = "1111111111" then
						err_t(24 downto 16) <= err(40 downto 32);
					elsif err(49) = '0' then
						err_t(24 downto 16) <= "011111111";
					elsif err(49) = '1' then
						err_t(24 downto 16) <= "100000001";
					end if;
					err_t(15 downto 0) <= err(31 downto 16);
				end if;
			end if;
		end if;
	end process;

	-- loop filter, v: Q17.32
	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if aresetn = '0' then
				vp <= (others=>'0'); 
				vi_p <= (others=>'0'); 
				vi <= (others=>'0'); 
				v <= (others=>'0'); 
			else
				if samp_vld_d(8) = '1' then
					vp <= K1 * err_t;
					vi_p <= K2 * err_t;
				end if;
				if samp_vld_d(9) = '1' then
					vi <= vi + vi_p;
				end if;
				if samp_vld_d(10) = '1' then
					v <= vp + vi;
				end if;
			end if;
		end if;
	end process;

	-- div loop gain, 2^8
	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if aresetn = '0' then
				v_div <= (others=>'0'); 
				v_div_t <= (others=>'0'); 
			else
				if samp_vld_d(11) = '1' then
					v_div <= resize(v(49 downto 8), v_div'length); -- sign-extend to full width
				end if;
				if samp_vld_d(12) = '1' then
					v_div_t(24 downto 16) <= v_div(40 downto 32);
					v_div_t(15 downto 0)  <= v_div(31 downto 16);
				end if;
			end if;
		end if;
	end process;

	-- calculate step and prepare to update cnt, mu
	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if aresetn = '0' then
				W 	<= HALF_ONE; 
				W_t <= HALF_ONE; 
			else
				if samp_vld_d(13) = '1' then
					W <= HALF_ONE + v_div_t;
				end if;
				if samp_vld_d(14) = '1' then
					if  W /= to_signed(0, W'length) then 
						W_t <= W ;
					else 
						W_t <= MINIMAL;
					end if;
				end if;
			end if;
		end if;
	end process;

	-- calc cnt/W
	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if aresetn = '0' then
				dividend(47 downto 41) <=(others=>'0'); 
				dividend(40 downto 0) <=(others=>'0'); 
				divisor(31 downto 25) <=(others=>'0'); 
				divisor(24 downto 0)  <= std_logic_vector(MINIMAL);
			else
				if samp_vld_d(15) = '1' then
					dividend(40 downto 0) <= std_logic_vector(cnt) & "0000000000000000";
					divisor(24 downto 0)  <= std_logic_vector(W_t);
				end if;
			end if;
		end if;
	end process;

	-- when div finished update mu and cnt
	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if aresetn = '0' then
				cnt_next <= ONE;
				cnt <= ONE;
				mu  <= HALF_ONE;
				mu_next <= HALF_ONE;
				dmu <= (others=>'0'); 
				underflow <= '1';
				div_vld_d 	<= '0';
				div_vld_dd 	<= '0';
				div_vld_ddd <= '0';
			else
				div_vld_d <= div_vld;
				if div_vld = '1' then
					cnt_next <= cnt - W;
				end if;
				div_vld_dd <= div_vld_d;
				if div_vld_d = '1' then
					if cnt_next(cnt_next'high) = '1' then
						cnt_next <= ONE + cnt_next;
						underflow <= '1';
						if quotient(72 downto 56) = "00000000000000000" or quotient(72 downto 56) = "11111111111111111" then
							mu_next <= signed(quotient(56 downto 32));
						elsif quotient(72) = '0' then
							mu_next <= ONE; 
						elsif quotient(72) = '1' then 
							mu_next <= MINIMAL;
						end if;
					else
						underflow <= '0';
						mu_next <= mu;
					end if;
				end if;
				div_vld_ddd <= div_vld_dd;
				if div_vld_dd = '1' then
					if mu_next(mu_next'high) = '1' then
						mu <= (others=>'0'); 
					elsif mu_next >= ONE then	
						mu <= ONE;
					else
						mu <= mu_next;
					end if;
					cnt <= cnt_next;
					dmu <= mu_next - mu;
				end if;
			end if;
		end if;
	end process;

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if aresetn = '0' then
				dmu_out <= (others=>'0');  
				dmu_out_vld <= '0';
			else
				dmu_out_vld <= div_vld_ddd;
				if div_vld_ddd = '1' then
					if dmu > HALF_ONE then
						dmu_out <= std_logic_vector(dmu - ONE);
					elsif dmu < HALF_ONE_NEG then
						dmu_out <= std_logic_vector(dmu + ONE);
					else
						dmu_out <= std_logic_vector(dmu);
					end if;
				end if;
			end if;
		end if;
	end process;

	u_div_gen: div_gen
	port map(
				aclk 						=> sys_clk,
				aresetn 					=> aresetn,
				s_axis_divisor_tvalid 		=> samp_vld_d(16),
				s_axis_divisor_tdata 		=> divisor,
				s_axis_dividend_tvalid 		=> samp_vld_d(16),
				s_axis_dividend_tdata 		=> dividend,
				m_axis_dout_tvalid 			=> div_vld,
				m_axis_dout_tdata 			=> quotient
			);

--	process(sys_clk)
--		variable cnt_next :signed(24 downto 0):=ONE;
--	begin
--		if rising_edge(sys_clk) then
--			if aresetn = '0' then
--				xI <= (others=>'0'); 
--				yI <= (others=>'0'); 
--				err <= (others=>'0'); 
--				en_sym <= '0';
--				sym_i  <= (others=>'0');
--				sym_q  <= (others=>'0'); 
--				vp <= (others=>'0'); 
--				vi <= (others=>'0'); 
--				v <= (others=>'0'); 
--				W <= (others=>'0'); 
--				W_t <= (others=>'0'); 
--				dividend <= (others=>'0'); 
--				divisor  <= (others=>'0'); 
--				mu  <= (others=>'0'); 
--				cnt <= (others=>'0'); 
--				mu_next <= (others=>'0'); 
--				cnt_next := (others=>'0'); 
--				underflow <= '1';
--				div_vld_d <= '0';
--			else
--				-- linear interpolator
--				if samp_vld_d(0) = '1' then
--					xI <= (ONE - mu) * signed(samp_i_d) + mu * signed(samp_i_q);
--					yI <= (ONE - mu) * signed(samp_q_d) + mu * signed(samp_q_q);
--				end if;
--				-- truncation, Q17.32 -> Q8.16
--				if samp_vld_d(1) = '1' then
--					if xI(49 downto 40) = "0000000000" or xI(49 downto 40) = "1111111111" then
--						xI_t(24 downto 16) <= xI(40 downto 32);
--					elsif xI(49) = '0' then
--						xI_t(24 downto 16) <= "011111111";
--					elsif xI(49) = '1' then
--						xI_t(24 downto 16) <= "100000001";
--					end if;
--					if yI(49 downto 40) = "0000000000" or yI(49 downto 40) = "1111111111" then
--						yI_t(24 downto 16) <= yI(40 downto 32);
--					elsif yI(49) = '0' then
--						yI_t(24 downto 16) <= "011111111";
--					elsif yI(49) = '1' then
--						yI_t(24 downto 16) <= "100000001";
--					end if;
--					xI_t(15 downto 0) <= xI(31 downto 16);
--					yI_t(15 downto 0) <= yI(31 downto 16);
--				end if;
--				-- delay interpolation samples and update symbols and TED
--				if samp_vld_d(2) = '1' then
--					TED_buff_x(0) <= xI_t;
--					TED_buff_x(1) <= TED_buff_x(0);
--					TED_buff_y(0) <= yI_t;
--					TED_buff_y(1) <= TED_buff_y(0);
--				end if;
--				if (samp_vld_d(2) = '1') and (underflow = '1') then
--					err <= TED_buff_x(0)*(TED_buff_x(1) - xI_t) + TED_buff_y(0)*(TED_buff_y(1) - yI_t);
--					en_sym <= '1';
--					sym_i	<=	std_logic_vector(xI_t);
--					sym_q	<=	std_logic_vector(yI_t);
--					err_out <=  TED_buff_x(0)*(TED_buff_x(1) - xI_t) + TED_buff_y(0)*(TED_buff_y(1) - yI_t);
--				else
--					err <= (others=>'0'); 
--					en_sym <= '0';
--				end if;
--				-- err: Q17.32, truncation: err_t: Q8.16
--				if samp_vld_d(3) = '1' then
--					if err(49 downto 40) = "0000000000" or err(49 downto 40) = "1111111111" then
--						err_t(24 downto 16) <= err(40 downto 32);
--					elsif err(49) = '0' then
--						err_t(24 downto 16) <= "011111111";
--					elsif err(49) = '1' then
--						err_t(24 downto 16) <= "100000001";
--					end if;
--					err_t(15 downto 0) <= err(31 downto 16);
--				end if;
--				-- loop filter, v: Q17.32
--				if samp_vld_d(4) = '1' then
--					vp <= K1 * err_t;
--				end if;
--				if samp_vld_d(5) = '1' then
--					vi <= vi + K2 * err_t;
--				end if;
--				if samp_vld_d(6) = '1' then
--					v <= vp + vi;
--				end if;
--				-- div loop gain, 2^8
--				if samp_vld_d(7) = '1' then
--					v_div <= resize(v(49 downto 8), v_div'length); -- sign-extend to full width
--				end if;
--				if samp_vld_d(8) = '1' then
--					v_div_t(24 downto 16) <= v_div(40 downto 32);
--					v_div_t(15 downto 0)  <= v_div(31 downto 16);
--				end if;
--				-- calculate step and prepare to update cnt, mu
--				if samp_vld_d(9) = '1' then
--					W <= HALF_ONE + v_div_t;
--				end if;
--				if samp_vld_d(10) = '1' then
--					if  W /= to_signed(0, W'length) then 
--						W_t <= W ;
--					else 
--						W_t <= MINIMAL;
--					end if;
--				end if;
--				-- calc cnt/W
--				if samp_vld_d(11) = '1' then
--					dividend(40 downto 0) <= std_logic_vector(cnt) & "0000000000000000";
--					divisor(24 downto 0)  <= std_logic_vector(W_t);
--				end if;
--				-- when div finished update mu and cnt
--				if div_vld = '1' then
--					cnt_next := cnt - W;
--					if cnt_next(cnt_next'high) = '1' then
--						cnt_next := ONE + cnt_next;
--						underflow <= '1';
--						if quotient(72 downto 56) = "00000000000000000" or quotient(72 downto 56) = "11111111111111111" then
--							mu_next <= signed(quotient(56 downto 32));
--						elsif quotient(72) = '0' then
--							mu_next <= ONE; -- 1 - 1/2
--						elsif quotient(72) = '1' then 
--							mu_next <= MINIMAL;
--						end if;
--					else
--						underflow <= '0';
--						mu_next <= mu;
--					end if;
--				end if;
--				div_vld_d <= div_vld;
--				div_vld_dd <= div_vld_d;
--				if div_vld_d = '1' then
--					if mu_next(mu_next'high) = '1' then
--						mu <= (others=>'0'); 
--					elsif mu_next >= ONE then	
--						mu <= ONE;
--					else
--						mu <= mu_next;
--					end if;
--					cnt <= cnt_next;
--					dmu <= mu_next - mu;
--				end if;
--				dmu_out_vld <= div_vld_dd;
--				if div_vld_dd = '1' then
--					if dmu > HALF_ONE then
--						dmu_out <= std_logic_vector(dmu - ONE);
--					elsif dmu < HALF_ONE_NEG then
--						dmu_out <= std_logic_vector(dmu + ONE);
--					end if;
--				end if;
--			end if;
--		end if;
--	end process; 

--	process(sys_clk)
--	begin
--		if rising_edge(sys_clk) then
--			if (samp_vld_d(2) = '1') and (underflow = '1') then
--				if err_out(49 downto 40) = "0000000000" or err_out(49 downto 40) = "1111111111" then
--					err_trunc(24 downto 16) <= err_out(40 downto 32);
--				elsif err_out(49) = '0' then
--					err_trunc(24 downto 16) <= "011111111";
--				elsif err_out(49) = '1' then
--					err_trunc(24 downto 16) <= "100000001";
--				end if;
--				err_trunc(15 downto 0) <= err(31 downto 16);
--				if (err_trunc >= HALF_ONE) then
--					err_sign_val <= std_logic_vector(signed(err_trunc) - signed(HALF_ONE));
--				end if;
--			end if;
--		end if;
--	end process; 


END ARCH;

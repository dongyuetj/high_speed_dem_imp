----------------------------------------------------------------
-- Author: Gemini AI (Modified for dong yue)
-- Date: 2024/05/20
-- Description: Power detection with Adder Tree and Moving Average
-----------------------------------------------------------------
library IEEE;                
use IEEE.STD_LOGIC_1164.ALL; 
use ieee.numeric_std.all;

library work;
use work.my_dem_pkg.all;

entity pwr_det is
    generic(
        moving_window_len : integer := 4;
        N                 : integer := 16 -- 建议为2的幂次
    );
    port(
        sys_clk        : in std_logic; 
        aresetn        : in std_logic;
        wave_in_valid  : in std_logic;
        wave_in_i      : in std_logic_array_16(0 to N-1);
        wave_in_q      : in std_logic_array_16(0 to N-1);
        power_valid    : out std_logic;
        power_out      : out std_logic_vector(31 downto 0)
    );
end pwr_det;

architecture arch of pwr_det is

    -- 定义内部对数常量用于截位
    constant LOG2_N    : integer := 4; -- N=16 时为 4
    constant LOG2_MWL  : integer := 2; -- moving_window_len=4 时为 2
    -- 流水线有效信号延迟
    signal vld_d : std_logic_vector(7 downto 0) := (others => '0');
    -- 第一级：平方运算 (Latency 1)
    signal i_sqr : signed_array_32(0 to N-1) := (others => (others => '0'));
    signal q_sqr : signed_array_32(0 to N-1) := (others => (others => '0'));
    -- 第二级：累加树 (Latency 2-5)
    signal sum0_i, sum0_q : signed_array_33(0 to 7) := (others => (others => '0'));
    signal sum1_i, sum1_q : signed_array_34(0 to 3) := (others => (others => '0'));
    signal sum2_i, sum2_q : signed_array_35(0 to 1) := (others => (others => '0'));
    signal sum3_i, sum3_q : signed(35 downto 0)     := (others => '0');
    -- 第三级：均值与求和 (Latency 6)
    signal power_in_u : unsigned(31 downto 0) := (others => '0');
    -- 第四级：滑动窗口累加 (Latency 7)
    signal power_pipe : unsigned_array_32(0 to moving_window_len-1) := (others => (others => '0'));
    signal acc_sum    : unsigned(31 + LOG2_MWL downto 0) := (others => '0');
    signal power_calc_valid : std_logic := '0';
begin

    -----------------------------------------------------------
    -- 1. 平方与累加树 (Pipeline)
    -----------------------------------------------------------
    process(sys_clk)
    begin
        if rising_edge(sys_clk) then
            if aresetn = '0' then
                vld_d <= (others => '0');
            else
                vld_d <= vld_d(vld_d'high-1 downto 0) & wave_in_valid;
            end if;

            -- Stage 0: Sqr
            if wave_in_valid = '1' then
                for ii in 0 to N-1 loop
                    i_sqr(ii) <= signed(wave_in_i(ii)) * signed(wave_in_i(ii));
                    q_sqr(ii) <= signed(wave_in_q(ii)) * signed(wave_in_q(ii));
                end loop;
            end if;

            -- Stage 1: Tree Level 0 (16 -> 8)
            if vld_d(0) = '1' then
                for ii in 0 to 7 loop
                    sum0_i(ii) <= resize(i_sqr(2*ii), 33) + resize(i_sqr(2*ii+1), 33);
                    sum0_q(ii) <= resize(q_sqr(2*ii), 33) + resize(q_sqr(2*ii+1), 33);
                end loop;
            end if;

            -- Stage 2: Tree Level 1 (8 -> 4)
            if vld_d(1) = '1' then
                for ii in 0 to 3 loop
                    sum1_i(ii) <= resize(sum0_i(2*ii), 34) + resize(sum0_i(2*ii+1), 34);
                    sum1_q(ii) <= resize(sum0_q(2*ii), 34) + resize(sum0_q(2*ii+1), 34);
                end loop;
            end if;

            -- Stage 3: Tree Level 2 (4 -> 2)
            if vld_d(2) = '1' then
                for ii in 0 to 1 loop
                    sum2_i(ii) <= resize(sum1_i(2*ii), 35) + resize(sum1_i(2*ii+1), 35);
                    sum2_q(ii) <= resize(sum1_q(2*ii), 35) + resize(sum1_q(2*ii+1), 35);
                end loop;
            end if;

            -- Stage 4: Tree Level 3 (2 -> 1)
            if vld_d(3) = '1' then
                sum3_i <= resize(sum2_i(0), 36) + resize(sum2_i(1), 36);
                sum3_q <= resize(sum2_q(0), 36) + resize(sum2_q(1), 36);
            end if;

            -- Stage 5: Normalize and Combine (I^2 + Q^2)
            if vld_d(4) = '1' then
                -- 将截位后的 I^2 和 Q^2 相加，并确保转为 unsigned 避免符号位干扰
                power_in_u <= unsigned(sum3_i(35 downto LOG2_N)) + unsigned(sum3_q(35 downto LOG2_N));
            end if;
        end if;
    end process;

    -----------------------------------------------------------
    -- 2. 滑动窗口累加 (Moving Average)
    -----------------------------------------------------------
    process(sys_clk)
        variable v_acc_sum : unsigned(acc_sum'range);
    begin
        if rising_edge(sys_clk) then
            if aresetn = '0' then
                acc_sum    <= (others => '0');
                power_pipe <= (others => (others => '0'));
                power_calc_valid <= '0';
            elsif vld_d(5) = '1' then
                -- 移位寄存器更新
                power_pipe <= power_in_u & power_pipe(0 to moving_window_len-2);
                
                -- 滑动累加：新值入，旧值出
                -- 减去的是 power_pipe 的最后一个值（即 moving_window_len 周期前的值）
                acc_sum <= acc_sum + power_in_u - power_pipe(moving_window_len-1);
                power_calc_valid <= '1';
            else
                power_calc_valid <= '0';
            end if;
        end if;
    end process;

    -----------------------------------------------------------
    -- 3. 输出截位与同步
    -----------------------------------------------------------
    process(sys_clk)
    begin
        if rising_edge(sys_clk) then
            if aresetn = '0' then
                power_valid <= '0';
                power_out   <= (others => '0');
            else
                power_valid <= power_calc_valid;
                if power_calc_valid = '1' then
                    -- 右移 LOG2_MWL 位实现除以窗口长度的操作
                    power_out <= std_logic_vector(acc_sum(31 + LOG2_MWL downto LOG2_MWL));
                end if;
            end if;
        end if;
    end process;

end arch;

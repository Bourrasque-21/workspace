LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

entity tick_gen_100hz is
    generic (
        CLK_FREQ : integer := 100_000_000;
        TICK_HZ  : integer := 100
    );
    port (
        clk          : in  std_logic;
        rst          : in  std_logic;
        run_stop_i   : in  std_logic;
        tick_100hz_o : out std_logic
    );
end entity tick_gen_100hz;

architecture prescaler_100hz of tick_gen_100hz is
    constant DIV_COUNT : integer := CLK_FREQ / TICK_HZ;

    signal cnt_reg  : integer range 0 to DIV_COUNT - 1 := 0;
    signal cnt_next : integer range 0 to DIV_COUNT - 1 := 0;

    signal tick_reg  : std_logic := '0';
    signal tick_next : std_logic := '0';
begin
    -- Sequential logic
    process (clk, rst)
    begin
        if rst = '1' then
            cnt_reg  <= 0;
            tick_reg <= '0';
        elsif rising_edge(clk) then
            cnt_reg  <= cnt_next;
            tick_reg <= tick_next;
        end if;
    end process;

    -- Combinational logic
    process (cnt_reg, run_stop_i)
    begin
        cnt_next  <= cnt_reg;
        tick_next <= '0';

        if run_stop_i = '1' then
            if cnt_reg = DIV_COUNT - 1 then
                cnt_next  <= 0;
                tick_next <= '1';
            else
                cnt_next <= cnt_reg + 1;
            end if;
        else
            cnt_next <= 0;
        end if;
    end process;

    tick_100hz_o <= tick_reg;
end architecture prescaler_100hz;

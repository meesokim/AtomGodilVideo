----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    14:42:09 02/09/2013 
-- Design Name: 
-- Module Name:    Top - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.all;
use IEEE.STD_LOGIC_UNSIGNED.all;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity TopRoland is
    port (

        -- Standard 6847 signals
        --
        -- expept DA which is now input only
        -- except nRP which re-purposed as a nWR
        
        DD     : inout std_logic_vector (7 downto 0);
        DA     : in    std_logic_vector (12 downto 0);
        nMS    : in    std_logic;
        CSS    : in    std_logic;
        nFS    : out   std_logic;
        nWR    : in    std_logic;       -- Was nRP
        AG     : in    std_logic;
        GM     : in    std_logic_vector (2 downto 0);

        -- 5 bit VGA Output

        R     : out std_logic_vector (0 downto 0);
        G     : out std_logic_vector (1 downto 0);
        B     : out std_logic_vector (0 downto 0);
        HSYNC : out std_logic;
        VSYNC : out std_logic;
        
        -- 1 bit AUDIO Output
        AUDIO : out std_logic;
        
        -- Other GODIL specific pins

        clock49 : in std_logic;
        nRST : in std_logic;

        nBXXX : in std_logic;

        -- Jumpers
        
        -- Enabled SID Audio
        SIDEN : in std_logic;

        -- Moves SID from 9FE0 to BDC0 
        nSIDD : in std_logic;

        -- charSet
        charSet : in std_logic;
        
        -- Active low version of the SID Select Signal for disabling the external bus buffers
        -- nSIDSEL : out std_logic;
        
        -- PS/2 Mouse
        PS2_CLK : inout std_logic;
        PS2_DATA : inout std_logic;

        -- UART
        uart_TxD : out std_logic;
        uart_RxD : in  std_logic;
        
        -- LEDs
        led8     : out std_logic;

        -- MISC
        CSO_B    : out std_logic
        );
end TopRoland;

architecture BEHAVIORAL of TopRoland is

    -- clock32 is the main clock
    signal clock32 : std_logic;
    
    -- clock25 is a full speed VGA clock
    signal clock25 : std_logic;
    
    -- clock15 is just used between two DCMs
    signal clock15 : std_logic;

    -- clock59 is just used between two DCMs
    signal clock59 : std_logic;
    
    -- Reset signal (active high)
    signal reset : std_logic;
    
    -- Reset signal to 6847 (active high), not currently used
    signal reset_vid : std_logic;

    -- pipelined versions of the address/data/write signals
    signal nWR1 : std_logic;
    signal nWR2 : std_logic;
    signal nMS1 : std_logic;
    signal nMS2 : std_logic;
    signal nWRMS1 : std_logic;
    signal nWRMS2 : std_logic;
    signal nBXXX1 : std_logic;
    signal nBXXX2 : std_logic;
    signal DA1  : std_logic_vector (12 downto 0);
    signal DA2  : std_logic_vector (12 downto 0);
    signal DD1  : std_logic_vector (7 downto 0);
    signal DD2  : std_logic_vector (7 downto 0);
    signal DD3  : std_logic_vector (7 downto 0);

    
    signal ram_we : std_logic;
    signal addr   : std_logic_vector (12 downto 0);
    signal din    : std_logic_vector (7 downto 0);

    -- Dout back to the Atom, that is either VRAM or SID
    signal dout  : std_logic_vector (7 downto 0);

    -- SID sigmals
    signal sid_cs : std_logic;
    signal sid_we : std_logic;
    signal sid_audio : std_logic;

    -- UART sigmals
    signal uart_cs       : std_logic;
    signal uart_we       : std_logic;
    
    -- Atom extension register signals
    signal reg_cs : std_logic;
    signal reg_we : std_logic;

    signal final_red     : std_logic;
    signal final_green1  : std_logic;
    signal final_green0  : std_logic;
    signal final_blue    : std_logic;
    signal final_vsync   : std_logic;
    signal final_hsync   : std_logic;
    signal final_char_a  : std_logic_vector (10 downto 0);
    
    signal locked1       : std_logic;
    signal locked2       : std_logic;
    signal locked3       : std_logic;
    signal locked4       : std_logic;
    
begin

    reset <= not nRST;
    reset_vid <= '0';
            
    -- Currently set at 49.152 * (31/26) * (3/7) = 25.1161318637MHz
    Inst_DCM1 : entity work.DCM1
        port map (
            CLKIN_IN  => clock49,
            RST       => '0',
            CLK0_OUT  => clock59,
            CLK0_OUT1 => open,
            CLK2X_OUT => open,
            LOCKED    => locked1
            );

    Inst_DCM2 : entity work.DCM2
        port map (
            CLKIN_IN  => clock59,
            RST       => not locked1,
            CLK0_OUT  => clock25,
            CLK0_OUT1 => open,
            CLK2X_OUT => open,
            LOCKED    => locked2
            );

    Inst_DCM3 : entity work.DCMSID0
        port map (
            CLKIN_IN  => clock49,
            RST       => '0',
            CLK0_OUT  => clock15,
            CLK0_OUT1 => open,
            CLK2X_OUT => open,
            LOCKED    => locked3
            );
            
    Inst_DCM4 : entity work.DCMSID1
        port map (
            CLKIN_IN  => clock15,
            RST       => not locked3,
            CLK0_OUT  => clock32,
            CLK0_OUT1 => open,
            CLK2X_OUT => open,
            LOCKED    => locked4
            );
            
    led8 <= not (locked1 and locked2 and locked3 and locked4);
            
    Inst_AtomGodilVideo : entity work.AtomGodilVideo
        generic map (
           CImplGraphicsExt => true,
           CImplSoftChar    => true,
           CImplSID         => true,
           CImplVGA80x40    => true,
           CImplHWScrolling => true,
           CImplMouse       => true,
           CImplUart        => true,
           CImplDoubleVideo => true,
           MainClockSpeed   => 32000000,
           DefaultBaud      => 115200          
        )
      
        port map (
            clock_vga => clock25,
            clock_main => clock32,
            clock_sid_32Mhz => clock32,
            clock_sid_dac => clock49,
            reset => reset,
            reset_vid => reset_vid,
            din => din,
            dout => dout,
            addr => addr,
            CSS => CSS,
            AG => AG,
            GM => GM,
            nFS => nFS,
            ram_we => ram_we,
            reg_cs => reg_cs,
            reg_we => reg_we,
            sid_cs => sid_cs,
            sid_we => sid_we,
            sid_audio => sid_audio,
            sid_audio_d => open,
            PS2_CLK => PS2_CLK,
            PS2_DATA => PS2_DATA,
            uart_cs => uart_cs,
            uart_we => uart_we,
            uart_RxD => uart_RxD,
            uart_TxD => uart_TxD,
            uart_escape => open,
            uart_break => open,
            final_red => final_red,
            final_green1 => final_green1,
            final_green0 => final_green0,
            final_blue => final_blue,
            final_vsync => final_vsync,
            final_hsync => final_hsync,
            charSet => charSet
            );

    
    -- Pipelined version of address/data/write signals
    process (clock32)
    begin
        if rising_edge(clock32) then
            nBXXX2 <= nBXXX1;
            nBXXX1 <= nBXXX;
            nMS2 <= nMS1;
            nMS1 <= nMS;
            nWRMS2 <= nWRMS1;
            nWRMS1 <= nWR or nMS;
            nWR2 <= nWR1;
            nWR1 <= nWR;
            DD3  <= DD2;
            DD2  <= DD1;
            DD1  <= DD;
            DA2  <= DA1;
            DA1  <= DA;
        end if;
    end process;

    -- Signals driving the VRAM
    -- Write just before the rising edge of nWR
    ram_we <= '1' when (nWRMS1 = '1' and nWRMS2 = '0' and nBXXX2 = '1') else '0';
    din    <= DD2;
    addr   <= DA2;
    
    -- Signals driving the internal registers
    -- When nSIDD=0 the registers are mapped to BDE0-BDFF
    -- When nSIDD=1 the registers are mapped to 9FE0-9FFF
    reg_cs <= '1' when (nSIDD = '1' and nMS2 = '0' and DA2(12 downto 5) =  "11111111") or
                       (nSIDD = '0' and nBXXX2 = '0' and DA2(11 downto 5) = "1101111") 
                  else '0';

    reg_we <= '1' when (nSIDD = '1' and nWRMS1 = '1' and nWRMS2 = '0') or
                       (nSIDD = '0' and nWR1 = '1' and nWR2 = '0')
                  else '0';
    
    -- Signals driving the SID
    -- When nSIDD=0 the SID is mapped to BDC0-BDDF
    -- When nSIDD=1 the SID is mapped to 9FC0-9FDF
    sid_cs <= '1' when (nSIDD = '1' and nMS2 = '0' and DA2(12 downto 5) =  "11111110") or
                       (nSIDD = '0' and nBXXX2 = '0' and DA2(11 downto 5) = "1101110") 
                  else '0';

    sid_we <= '1' when (nSIDD = '1' and nWRMS1 = '1' and nWRMS2 = '0') or
                       (nSIDD = '0' and nWR1 = '1' and nWR2 = '0')
                  else '0';


    -- Signals driving the UART
    -- When nSIDD=0 the UART is mapped to BDB0-BDBF
    -- When nSIDD=1 the UART is mapped to 9FB0-9FBF
    uart_cs <= '1' when (nSIDD = '1' and nMS2 = '0' and DA2(12 downto 4) =  "111111011") or
                        (nSIDD = '0' and nBXXX2 = '0' and DA2(11 downto 4) = "11011011") 
                   else '0';

    uart_we <= '1' when (nSIDD = '1' and nWRMS1 = '1' and nWRMS2 = '0') or
                        (nSIDD = '0' and nWR1 = '1' and nWR2 = '0')
                   else '0';
    
    AUDIO <= sid_audio when SIDEN = '1' else '0';

    -- Output the SID Select Signal so it can be used to disable the bus buffers
    -- TODO: this looks incorrect
    -- nSIDSEL <= not sid_cs;
    
    -- Tri-state data back to the Atom
    DD    <= dout when (nMS = '0' and nWR = '1') else (others => 'Z');
        
    -- 1/2/1 Bit RGB Video to GODIL Test Connector
    R(0)  <= final_red;
    G(1)  <= final_green1;
    G(0)  <= final_green0;
    B(0)  <= final_blue;
    VSYNC <= final_vsync;
    HSYNC <= final_hsync;
    
    CSO_B <= '1';
    
        
end BEHAVIORAL;


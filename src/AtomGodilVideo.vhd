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

entity AtomGodilVideo is
    port (
        -- Clock inputs
        
        -- clock25 is a full speed VGA clock      
        clock25      : in    std_logic;

        -- clock32 is the main clock      
        clock32      : in    std_logic;
        
        -- clock32 is used for the SID dac and the mouse only
        clock49      : in    std_logic;

         -- Reset inputs
        reset        : in    std_logic;

        -- Reset signal to 6847 and vga80x40
        -- Typically not held low so video
        reset_vid    : in    std_logic;
        
        -- Main Address / Data Bus
        din          : in    std_logic_vector (7 downto 0);
        dout         : out   std_logic_vector (7 downto 0);
        addr         : in    std_logic_vector (12 downto 0);

        -- 6847 Control Signals
        CSS          : in    std_logic;
        AG           : in    std_logic;
        GM           : in    std_logic_vector (2 downto 0);
        nFS          : out   std_logic;

        -- RAM signals
        ram_we       : in    std_logic;

        -- SID signals
        reg_cs       : in    std_logic;
        reg_we       : in    std_logic;

        -- SID signals
        sid_cs       : in    std_logic;
        sid_we       : in    std_logic;
        sid_audio    : out   std_logic;
        
        -- PS/2 Mouse
        PS2_CLK      : inout std_logic;
        PS2_DATA     : inout std_logic;

        -- VGA Signals
        final_red    : out   std_logic;
        final_green1 : out   std_logic;
        final_green0 : out   std_logic;
        final_blue   : out   std_logic;
        final_vsync  : out   std_logic;
        final_hsync  : out   std_logic

        );
end AtomGodilVideo;

architecture BEHAVIORAL of AtomGodilVideo is

    constant MAJOR_VERSION : std_logic_vector(3 downto 0) := "0001";
    constant MINOR_VERSION : std_logic_vector(3 downto 0) := "0000";

    -- Set this to 0 if you want dark green/dark orange background on text
    -- Set this to 1 if you want black background on text (authentic Atom)
    constant BLACK_BACKGND : std_logic := '1';

    signal clock25en : std_logic;
    -- Internal 1MHz clocks for SID
    signal div32  : std_logic_vector (4 downto 0);
    signal clock1 : std_logic;
    
    -- VGA colour signals out of mc6847, only top 2 bits are used
    signal vga_red   : std_logic_vector (7 downto 0);
    signal vga_green : std_logic_vector (7 downto 0);
    signal vga_blue  : std_logic_vector (7 downto 0);
    signal vga_vsync : std_logic;
    signal vga_hsync : std_logic;
    
    -- 8Kx8 Dual port video RAM signals
    -- Port A connects to Atom and is read/write
    -- Port B connects to MC6847 and is read only
    signal douta : std_logic_vector (7 downto 0);
    signal addrb : std_logic_vector (12 downto 0);
    signal doutb : std_logic_vector (7 downto 0);

    -- Masked (by nRST) version of the mode control signals
    signal mask  : std_logic;    
    signal gm_masked  : std_logic_vector (2 downto 0);
    signal ag_masked  : std_logic;
    signal css_masked : std_logic;

    -- SID signals
    signal sid_do  : std_logic_vector (7 downto 0);

    -- Atom extension register signals
    signal reg_addr : std_logic_vector (4 downto 0);
    signal reg_do  : std_logic_vector (7 downto 0);

    signal extensions : std_logic_vector (7 downto 0);
    signal char_addr : std_logic_vector (7 downto 0);
    signal ocrx : std_logic_vector (7 downto 0);
    signal ocry : std_logic_vector (7 downto 0);
    signal octl : std_logic_vector (7 downto 0);
    signal octl2 : std_logic_vector (7 downto 0);
    signal char_we : std_logic;
    signal char_reg : std_logic_vector (7 downto 0);
    
    signal mc6847_an_s : std_logic;
    signal mc6847_intn_ext : std_logic;
    signal mc6847_inv : std_logic;
    signal mc6847_css : std_logic;
    signal mc6847_d : std_logic_vector (7 downto 0);
    signal mc6847_d_with_pointer : std_logic_vector (7 downto 0);
    signal mc6847_char_a : std_logic_vector (10 downto 0);
    signal mc6847_addrb : std_logic_vector (12 downto 0);
    signal mc6847_addrb_hw : std_logic_vector (12 downto 0);
    signal char_d_o : std_logic_vector (7 downto 0);

    signal pointer_nr     : std_logic_vector (7 downto 0);
    signal pointer_nr_rd  : std_logic_vector (7 downto 0);
    signal pointer_x      : std_logic_vector (7 downto 0);
    signal pointer_y      : std_logic_vector (7 downto 0);
    signal pointer_y_inv  : std_logic_vector (7 downto 0);
    signal pointer_left   : std_logic;
    signal pointer_middle : std_logic;
    signal pointer_right  : std_logic;

    signal hwscrollmode   : std_logic;
    
    signal scroll_left    : std_logic_vector (7 downto 0);
    signal scroll_right   : std_logic_vector (7 downto 0);
    signal scroll_h       : std_logic_vector (7 downto 0);
    signal scroll_top     : std_logic_vector (7 downto 0);
    signal scroll_bottom  : std_logic_vector (7 downto 0);
    signal scroll_v       : std_logic_vector (7 downto 0);
    
    signal width32        : std_logic;
    signal lines          : std_logic_vector (7 downto 0);

    signal vga80x40mode  : std_logic;
    signal final_char_a  : std_logic_vector (10 downto 0);
    
    signal vga80_R       : std_logic;
    signal vga80_G       : std_logic;
    signal vga80_B       : std_logic;
    signal vga80_vsync   : std_logic;
    signal vga80_hsync   : std_logic;
    signal vga80_invert  : std_logic;
    signal vga80_char_a  : std_logic_vector (10 downto 0);
    signal vga80_char_d  : std_logic_vector (7 downto 0);
    signal vga80_addrb   : std_logic_vector (12 downto 0);
    signal vga80_addrb_hw: std_logic_vector (12 downto 0);
    
    Component vga80x40
        port(
            reset : IN std_logic;
            clk25MHz : IN std_logic;
            TEXT_D : IN std_logic_vector(7 downto 0);
            FONT_D : IN std_logic_vector(7 downto 0);
            ocrx : IN std_logic_vector(7 downto 0);
            ocry : IN std_logic_vector(7 downto 0);
            octl : IN std_logic_vector(7 downto 0);          
            octl2 : IN std_logic_vector(7 downto 0);          
            TEXT_A : OUT std_logic_vector(12 downto 0);
            FONT_A : OUT std_logic_vector(11 downto 0);
            R : OUT std_logic;
            G : OUT std_logic;
            B : OUT std_logic;
            hsync : OUT std_logic;
            vsync : OUT std_logic
            );
    end component;

    component mc6847
        port(
            clk            : in  std_logic;
            clk_ena        : in  std_logic;
            reset          : in  std_logic;
            dd             : in  std_logic_vector(7 downto 0);
            an_g           : in  std_logic;
            an_s           : in  std_logic;
            intn_ext       : in  std_logic;
            gm             : in  std_logic_vector(2 downto 0);
            css            : in  std_logic;
            inv            : in  std_logic;
            artifact_en    : in  std_logic;
            artifact_set   : in  std_logic;
            artifact_phase : in  std_logic;
            da0            : out std_logic;
            videoaddr      : out std_logic_vector(12 downto 0);
            hs_n           : out std_logic;
            fs_n           : out std_logic;
            red            : out std_logic_vector(7 downto 0);
            green          : out std_logic_vector(7 downto 0);
            blue           : out std_logic_vector(7 downto 0);
            hsync          : out std_logic;
            vsync          : out std_logic;
            hblank         : out std_logic;
            vblank         : out std_logic;
            cvbs           : out std_logic_vector(7 downto 0);
            black_backgnd  : in  std_logic;
            char_a         : out std_logic_vector(10 downto 0);
            char_d_o       : in std_logic_vector(7 downto 0)
            );
    end component;

    component VideoRam
        port (
            clka  : in  std_logic;
            wea   : in  std_logic;
            addra : in  std_logic_vector(12 downto 0);
            dina  : in  std_logic_vector(7 downto 0);
            douta : out std_logic_vector(7 downto 0);
            clkb  : in  std_logic;
            web   : in  std_logic;
            addrb : in  std_logic_vector(12 downto 0);
            dinb  : in  std_logic_vector(7 downto 0);
            doutb : out std_logic_vector(7 downto 0)
            );
    end component;

    component sid6581
        port(
            clk_1MHz : in std_logic;
            clk32 : in std_logic;
            clk_DAC : in std_logic;
            reset : in std_logic;
            cs : in std_logic;
            we : in std_logic;
            addr : in std_logic_vector(4 downto 0);
            di : in std_logic_vector(7 downto 0);    
            pot_x : in std_logic;
            pot_y : in std_logic;      
            do : out std_logic_vector(7 downto 0);
            audio_out : out std_logic;
            audio_data : out std_logic_vector(17 downto 0)
            );
    end component;
    
    component MouseRefComp
        port(
            CLK : IN std_logic;
            RESOLUTION : IN std_logic;
            RST : IN std_logic;
            SWITCH : IN std_logic;    
            PS2_CLK : INOUT std_logic;
            PS2_DATA : INOUT std_logic;      
            LEFT : OUT std_logic;
            MIDDLE : OUT std_logic;
            NEW_EVENT : OUT std_logic;
            RIGHT : OUT std_logic;
            XPOS : OUT std_logic_vector(9 downto 0);
            YPOS : OUT std_logic_vector(9 downto 0);
            ZPOS : OUT std_logic_vector(3 downto 0)
            );
    end component;

    component Pointer is
        port (
            CLK  : in  std_logic;
            PO   : in  std_logic;
            PS   : in  std_logic_vector (4 downto 0);
            X    : in  std_logic_vector (7 downto 0);
            Y    : in  std_logic_vector (7 downto 0);
            ADDR : in  std_logic_vector (12 downto 0);
            DIN  : in  std_logic_vector (7 downto 0);
            DOUT : out std_logic_vector (7 downto 0)
            );
    end component;

    function modulo5 (x : std_logic_vector(7 downto 0))
        return std_logic_vector is

        variable tmp1 : std_logic_vector(4 downto 0);
        variable tmp2 : std_logic_vector(3 downto 0);

    begin
        -- uses some tricks from here:
        -- http://homepage.cs.uiowa.edu/~jones/bcd/mod.shtml

        -- calculate modulo 15
        tmp1 := ('0' & X(7 downto 4)) + ('0' & X(3 downto 0));
        if (tmp1 = 30) then
            tmp1 := "00000";
        elsif (tmp1 >= 15) then
            tmp1 := tmp1 - 15;
        end if;

        -- calculate modulo 5
        tmp2 := tmp1(3 downto 0);
        if (tmp2 >= 10) then
            tmp2 := tmp2 - 5;
        end if;

        if (tmp2 >= 5) then
            tmp2 := tmp2 - 5;
        end if;

        return tmp2(2 downto 0);
        

    end modulo5;

begin

            
    -- Motorola MC6847
    -- Original version: https://svn.pacedev.net/repos/pace/sw/src/component/video/mc6847.vhd
    -- Updated by AlanD for his Atom FPGA: http://stardot.org.uk/forums/viewtopic.php?f=3&t=6313
    -- A further few bugs fixed by myself
    Inst_mc6847 : mc6847
        port map (
            clk            => clock25,
            clk_ena        => clock25en,
            reset          => reset_vid,
            da0            => open,
            videoaddr      => mc6847_addrb,
            dd             => mc6847_d_with_pointer,
            hs_n           => open,
            fs_n           => nFS,
            an_g           => ag_masked,
            an_s           => mc6847_an_s,
            intn_ext       => mc6847_intn_ext,
            gm             => gm_masked,
            css            => mc6847_css,
            inv            => mc6847_inv,
            red            => vga_red,
            green          => vga_green,
            blue           => vga_blue,
            hsync          => vga_hsync,
            vsync          => vga_vsync,
            artifact_en    => '0',
            artifact_set   => '0',
            artifact_phase => '0',
            hblank         => open,
            vblank         => open,
            cvbs           => open,
            black_backgnd  => BLACK_BACKGND,
            char_a         => mc6847_char_a,
            char_d_o       => char_d_o
            );
    
    Inst_vga80x40: vga80x40 PORT MAP(
        reset => reset_vid,
        clk25MHz => clock25,
        TEXT_A => vga80_addrb,
        TEXT_D => mc6847_d,
        FONT_A(10 downto 0) => vga80_char_a,
        FONT_A(11) => vga80_invert,
        FONT_D => vga80_char_d,
        ocrx => ocrx,
        ocry => ocry,
        octl => octl,
        octl2 => octl2,
        R => vga80_R,
        G => vga80_G,
        B => vga80_B,
        hsync => vga80_hsync,
        vsync => vga80_vsync 
    );

    vga80_char_d <= char_d_o when vga80_invert='0' else char_d_o xor "11111111"; 
    ---- ram for char generator      
    charrom_inst : entity work.CharRam
        port map(
            clka  => clock32,
            wea   => char_we,
            addra(10 downto 4) => char_addr(6 downto 0),
            addra(3 downto 0) => addr(3 downto 0),
            dina  => din,
            douta => char_reg,
            clkb  => clock25,
            web   => '0',
            addrb => final_char_a,
            dinb  => (others => '0'),
            doutb => char_d_o
        );


    -- 8Kx8 Dual port video RAM
    -- Port A connects to Atom and is read/write
    -- Port B connects to MC6847 and is read only    
    Inst_VideoRam : VideoRam
        port map (
            clka  => clock32,
            wea   => ram_we,
            addra => addr,
            dina  => din,
            douta => douta,
            clkb  => clock25,
            web   => '0',
            addrb => addrb,
            dinb  => (others => '0'),
            doutb => doutb
            );

    Inst_sid6581: sid6581
        port map (
            clk_1MHz => clock1,
            clk32 => clock32,
            clk_DAC => clock49,
            reset => reset,
            cs => sid_cs,
            we => sid_we,
            addr => reg_addr,
            di => din,
            do => sid_do,
            pot_x => '0',
            pot_y => '0',
            audio_out => sid_audio,
            audio_data => open 
        );

    Inst_Pointer: Pointer PORT MAP (
        CLK => clock25,
        PO => not pointer_nr(7),
        PS => pointer_nr(4 downto 0),
        X  => pointer_x,
        Y  => pointer_y,
        ADDR => mc6847_addrb, 
        DIN  => mc6847_d, 
        DOUT => mc6847_d_with_pointer
    );
    
    Inst_MouseRefComp: MouseRefComp PORT MAP(
        CLK => clock49,
        RESOLUTION => '1', -- select 256x192 resolution
        RST => reset,
        SWITCH => '0',
        LEFT => pointer_left,
        MIDDLE => pointer_middle,
        NEW_EVENT => open,
        RIGHT => pointer_right,
        XPOS(7 downto 0) => pointer_x,
        XPOS(9 downto 8) => open,
        YPOS(7 downto 0) => pointer_y,
        YPOS(9 downto 8) => open,
        ZPOS => open,
        PS2_CLK => PS2_CLK,
        PS2_DATA => PS2_DATA
    );    

    -- Clock1 is derived by dividing clock32 down by 32
    process (clock32)
    begin
        if rising_edge(clock32) then
            div32 <= div32 + 1;
        end if;
    end process;
    
    clock1 <= div32(4);

    -- A register to control extra 6847 features
    process (clock32)
    begin
        if rising_edge(clock32) then
            if (reset = '1') then
                extensions <= (others => '0');
                char_addr <= (others => '0');
                ocrx <= (others => '0');
                ocry <= (others => '0');
                -- Default to Green Foreground
                octl <= "10000010";
                -- Default to Black Background
                octl2 <= "00000000";
                pointer_nr <= "10000000";
                scroll_h <= (others => '0');
                scroll_left <= (others => '0');
                scroll_right <= (others => '0');
                scroll_v <= (others => '0');
                scroll_top <= (others => '0');
                scroll_bottom <= (others => '0');
            elsif (reg_cs = '1' and reg_we = '1') then
                case reg_addr is
                -- extensions register
                when "00000" =>
                  extensions <= din;
                -- char_addr register
                when "00001" =>
                  char_addr <= din;
                when "00010" =>
                  ocrx <= din;
                when "00011" =>
                  ocry <= din;
                when "00100" =>
                  octl <= din;
                when "00101" =>
                  octl2 <= din;
                when "00110" =>
                  scroll_h <= din;
                when "00111" =>
                  scroll_v <= din;
                when "01010" =>
                  pointer_nr <= din;
                when "01011" =>
                  scroll_left <= din;
                when "01100" =>
                  scroll_right <= din;
                when "01101" =>
                  scroll_top <= din;
                when "01110" =>
                  scroll_bottom <= din;
                  
                when others =>
                  
                end case;
            end if;
        end if;
    end process;
    
    -- Adjust the inputs to the 6847 based on the extensions register
    process (extensions, doutb, css_masked, ag_masked)
    begin
        case extensions(2 downto 0) is
    
        -- Text plus 8 Colour Semigraphics 4
        when "001" =>
            mc6847_an_s <= doutb(6);
            mc6847_intn_ext <= '0';
            mc6847_inv <= doutb(7);
            -- Replace the 64-127 and 192-255 blocks with Semigraphics 4
            -- Only tweak the data bus when actually displaying semigraphics
            if (ag_masked = '0' and doutb(6) = '1') then
                mc6847_d <= '0' & doutb(7) & doutb(5 downto 0);
            else
                mc6847_d <= doutb;
            end if;
            mc6847_css <= css_masked;              

        -- 2 Colour Text Only
        when "010" =>
            mc6847_an_s <= '0';
            mc6847_intn_ext <= '0';
            mc6847_inv <= doutb(7);
            if (ag_masked = '0' and doutb(6) = '1') then
                mc6847_d <= "00" & doutb(5 downto 0);
            else
                mc6847_d <= doutb;
            end if;
            mc6847_css <= doutb(6) xor css_masked;

        -- 4 Colour Semigraphics 6 Only
        when "011" =>
            mc6847_an_s <= '1';
            mc6847_intn_ext <= '1';
            mc6847_inv <= doutb(7);
            mc6847_d <= doutb;
            mc6847_css <= css_masked;

        -- Extended character set, lower case replaces Red Semigraphics
        -- 00-3F - Normal Upper Case
        -- 40-7F - Yellow Semigraphics 6
        -- 80-BF - Inverse Upper Case
        -- C0-FF - Normal Lower Case
        when "100" =>
            mc6847_an_s <= doutb(6) and not doutb(7);
            mc6847_intn_ext <= doutb(6);
            mc6847_inv <= not doutb(6) and doutb(7);
            mc6847_d <= doutb;
            mc6847_css <= css_masked;

        -- Extended character set, lower case replaces Red and Yello Semigraphics
        -- 00-3F - Normal Upper Case
        -- 40-7F - Normal Lower Case
        -- 80-BF - Inverse Upper Case
        -- C0-FF - Inverse Lower Case
        when "101" =>
            mc6847_an_s <= '0';
            mc6847_intn_ext <= '0';
            mc6847_inv <= doutb(7);
            mc6847_d <= doutb;
            mc6847_css <= css_masked;

        -- Extended character set, lower case replaces inverse
        -- 00-3F - Normal Upper Case
        -- 40-7F - Yellow Semigraphics 6 -- Blue
        -- 80-BF - Normal Lower Case
        -- C0-FF - Red Semigraphics 6 
        when "110" =>
            mc6847_an_s <= doutb(6);
            mc6847_intn_ext <= doutb(6);
            mc6847_inv <= '0';
            if (ag_masked = '0' and doutb(7 downto 6) = "10") then
                mc6847_d <= "01" & doutb(5 downto 0);
            else
                mc6847_d <= doutb;
            end if;
            mc6847_css <= css_masked;

        -- Just replace inverse upper case (32 chars) with lower case    
        -- 00-3F - Normal Upper Case
        -- 40-7F - Yellow Semigraphics 6
        -- 80-BF - Lower Case/Inverse Upper Case
        -- C0-FF - Red Semigraphics 6

        when "111" =>
            mc6847_an_s <= doutb(6);
            mc6847_intn_ext <= doutb(6);
            mc6847_inv <= doutb(7) and doutb(5);
            if (ag_masked = '0' and doutb(7 downto 5) = "100") then
                mc6847_d <= "01" & doutb(5 downto 0);
            else
                mc6847_d <= doutb;
            end if;
            mc6847_css <= css_masked;

        -- Default Atom Behaviour        
        -- 00-3F - Normal Upper Case
        -- 40-7F - Yellow Semigraphics 6
        -- 80-BF - Inverse Upper Case
        -- C0-FF - Red Semigraphics 6

        when others =>
            mc6847_an_s <= doutb(6);
            mc6847_intn_ext <= doutb(6);
            mc6847_inv <= doutb(7);
            mc6847_d <= doutb;
            mc6847_css <= css_masked;
        
        end case;
        
    end process;
  
    pointer_nr_rd <= pointer_nr(7) & "1111" & not pointer_middle & not pointer_right & not pointer_left;
    
    pointer_y_inv <= pointer_y xor "11111111";
    
    reg_addr <= addr(4 downto 0);
    
    reg_do <= extensions    when reg_addr = "00000" else
              char_addr     when reg_addr = "00001" else
              ocrx          when reg_addr = "00010" else
              ocry          when reg_addr = "00011" else
              octl          when reg_addr = "00100" else
              octl2         when reg_addr = "00101" else
              scroll_h      when reg_addr = "00110" else
              scroll_v      when reg_addr = "00111" else
              pointer_x     when reg_addr = "01000" else
              pointer_y_inv when reg_addr = "01001" else
              pointer_nr_rd when reg_addr = "01010" else
              scroll_left   when reg_addr = "01011" else
              scroll_right  when reg_addr = "01100" else
              scroll_top    when reg_addr = "01101" else
              scroll_bottom when reg_addr = "01110" else
              MAJOR_VERSION & MINOR_VERSION when reg_addr = "01111" else
              char_reg;
    
    
    char_we <= '1' when reg_cs = '1' and reg_we = '1' and char_addr(7) = '1' and reg_addr(4) = '1' else '0';
    
    -- Tri-state data back to the Atom
    dout <= sid_do when sid_cs = '1' else
            reg_do when reg_cs = '1' else
            douta;
    
    -- VGA Multiplexing between two controllers
    
    vga80x40mode <= extensions(7);
    hwscrollmode <= extensions(6);
    final_red    <= vga_red(7)      when vga80x40mode = '0' else vga80_R;
    final_green1 <= vga_green(7)    when vga80x40mode = '0' else vga80_G;
    final_green0 <= vga_green(6)    when vga80x40mode = '0' else vga80_G;
    final_blue   <= vga_blue(7)     when vga80x40mode = '0' else vga80_B;
    final_vsync  <= vga_vsync       when vga80x40mode = '0' else vga80_vsync;
    final_hsync  <= vga_hsync       when vga80x40mode = '0' else vga80_hsync;
    final_char_a <= mc6847_char_a   when vga80x40mode = '0' else vga80_char_a;
    addrb        <= mc6847_addrb    when vga80x40mode = '0' and hwscrollmode = '0' else
                    mc6847_addrb_hw when vga80x40mode = '0' and hwscrollmode = '1' else
                    vga80_addrb     when hwscrollmode = '0' else
                    vga80_addrb_hw;
                    

    -- 32 bytes wide in Modes 0, 2a, 3a, 4a, 4
    -- 16 bytes wide in Modes 1a, 1, 2, 3
    width32 <= '1' when ag_masked = '0' or 
                gm_masked = "010" or gm_masked = "100" or 
                gm_masked = "110" or gm_masked = "111" else '0';
                
                
     lines <= "00010000" when ag_masked = '0' else
             "01000000" when gm_masked = "000" or gm_masked = "001" or gm_masked = "010" else
             "01100000" when gm_masked = "011" or gm_masked = "100" else
             "11000000";                               
             
    -- Hardware Scrolling of atom modes
    -- mc6847_addrb -> mc6847_addrb_hw

    process (lines, width32, scroll_left, scroll_right, scroll_h, scroll_top, scroll_bottom, scroll_v, mc6847_addrb)
    variable x : std_logic_vector(5 downto 0);
    variable y : std_logic_vector(8 downto 0);
    variable scroll_h_min : std_logic_vector(7 downto 0);
    variable scroll_h_max : std_logic_vector(7 downto 0);
    variable scroll_v_min : std_logic_vector(7 downto 0);
    variable scroll_v_max : std_logic_vector(7 downto 0);

    begin
        scroll_h_min := scroll_left;
        scroll_v_min := scroll_top;
        scroll_v_max := lines - scroll_bottom;
        if (width32 = '0') then
            x := "00" & mc6847_addrb(3 downto 0);
            y := "0" & mc6847_addrb(11 downto 4);
            scroll_h_max := 16 - scroll_right;
        else
            x := "0" & mc6847_addrb(4 downto 0);
            y := "0" & mc6847_addrb(12 downto 5);        
            scroll_h_max := 32 - scroll_right;
        end if;
            
        if (x >= scroll_h_min and x < scroll_h_max) and (y >= scroll_v_min and y < scroll_v_max) then
            x := x + scroll_h;
            if (x >= scroll_h_max) then
                x := x - (scroll_h_max - scroll_h_min);
            end if;
            y := y + scroll_v;
            if (y >= scroll_v_max) then
                y := y - (scroll_v_max - scroll_v_min);
            end if;
        end if;
            
        if (width32 = '0') then
            mc6847_addrb_hw(3 downto 0) <= x(3 downto 0);
            mc6847_addrb_hw(12 downto 4) <= y;
        else
            mc6847_addrb_hw(4 downto 0) <= x(4 downto 0);
            mc6847_addrb_hw(12 downto 5) <= y(7 downto 0);
        end if;

    end process;

    
    
    -- Hardware Scrolling of vga80x40 mode
    -- vga80_addrb -> vga80_addrb_hw
    
    process (scroll_h, scroll_v, vga80_addrb)
    variable addr1 : std_logic_vector(11 downto 0);
    variable addr2 : std_logic_vector(13 downto 0);
    variable attr : std_logic;
    variable display_start : std_logic_vector(11 downto 0);
    variable x1 : std_logic_vector(6 downto 0);
    variable x2 : std_logic_vector(7 downto 0);
    begin
        -- determine if this is an attribute access or not
        if (vga80_addrb < 3200) then
            attr := '0';
        else
            attr := '1';
        end if;

        -- calculate an address in the range 0..3199 regardless of whether char or attr being accessed
        if (attr = '0') then
            addr1 := vga80_addrb(11 downto 0);
        else
            addr1 := vga80_addrb - 3200;
        end if;

        -- calculate x from the address modulo 80
        x1 := modulo5(addr1(11 downto 4)) & addr1(3 downto 0);

        -- calculate the new x after the scroll_h has been added, modulo 80
        x2 := ('0' & x1) + ('0' & scroll_h);
        if (x2 >= 80) then
            x2 := x2 - 80;
        end if;

        -- calculate the display start as 80 * scroll_v
        display_start := (scroll_v(5 downto 0) & "000000") + ("00" & scroll_v(5 downto 0) & "0000");

        -- calculate the new screen start address, extending the precision by one bit
        addr2 := ('0' & vga80_addrb) + ("00" & display_start) - ("0000000" & x1) + ("0000000" & x2(6 downto 0));
         
        -- detect wrapping in wrapping in the character and attributevregions
        if ((attr = '0' and addr2 >= 3200) or addr2  >= 6400) then
            vga80_addrb_hw <= addr2 - 3200;
        else
            vga80_addrb_hw <= addr2(12 downto 0);
        end if;
    end process;


    -- Hold internal reset low for two frames after nRST released
    -- This avoids any diaplay glitches
    process (clock25)
    variable state : std_logic_vector(2 downto 0);
    begin
        if rising_edge(clock25) then
            if (reset = '1') then
                state := "000";
            elsif (state = "000" and vga_vsync = '0') then
                state := "001";
            elsif (state = "001" and vga_vsync = '1') then
                state := "010";
            elsif (state = "010" and vga_vsync = '0') then
                state := "011";
            elsif (state = "011" and vga_vsync = '1') then
                state := "100";
            end if;
            mask <= state(2);
        end if;
    end process;
    
    process (clock25)
    begin
        if rising_edge(clock25) then
            clock25en <= not clock25en;
        end if;
    end process;
        
    -- During reset, force the 6847 mode select inputs low
    -- (this is necessary to stop the mode changing during reset, as the GODIL has 1.5K pullups)
    gm_masked  <= GM(2 downto 0) when mask = '1' else (others => '0');
    ag_masked  <= AG             when mask = '1' else '0';
    css_masked <= CSS            when mask = '1' else '0';
    
end BEHAVIORAL;

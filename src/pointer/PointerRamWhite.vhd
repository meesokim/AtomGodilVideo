library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity PointerRamWhite is

    port (
        clka  : in  std_logic;
        wea   : in  std_logic;
        addra : in  std_logic_vector(7 downto 0);
        dina  : in  std_logic_vector(7 downto 0);
        douta : out std_logic_vector(7 downto 0);
        clkb  : in  std_logic;
        web   : in  std_logic;
        addrb : in  std_logic_vector(7 downto 0);
        dinb  : in  std_logic_vector(7 downto 0);
        doutb : out std_logic_vector(7 downto 0)
        );
end PointerRamWhite;

architecture BEHAVIORAL of PointerRamWhite is

-- Shared memory
    type ram_type is array (0 to 255) of std_logic_vector (7 downto 0);
    shared variable RAM : ram_type := (
        "00000000",
        "01111100",
        "01111000",
        "01111000",
        "01111100",
        "01001110",
        "00000100",
        "00000000",

        "00000000",
        "01000000",
        "00000000",
        "00000000",
        "00000000",
        "00000000",
        "00000000",
        "00000000",

        "00000000",
        "00101100",
        "01101110",
        "01101110",
        "01100010",
        "01111110",
        "00111100",
        "00000000",

        "00000000",
        "01111110",
        "01000000",
        "01000000",
        "01000000",
        "01000000",
        "01000000",
        "00000000",

        "00000000",
        "00010000",
        "00111000",
        "00111000",
        "00111000",
        "00111000",
        "00111000",
        "00000000",

        "00000000",
        "00111000",
        "00111000",
        "00111000",
        "00111000",
        "00111000",
        "00010000",
        "00000000",

        "00000000",
        "00000000",
        "01111100",
        "01111110",
        "01111100",
        "00000000",
        "00000000",
        "00000000",

        "00000000",
        "00000000",
        "00111110",
        "01111110",
        "00111110",
        "00000000",
        "00000000",
        "00000000",

        "00000000",
        "00111000",
        "01110010",
        "01110010",
        "01100110",
        "01100110",
        "00001100",
        "00000000",

        "00000000",
        "00111000",
        "00101000",
        "00001000",
        "00010000",
        "00000000",
        "00010000",
        "00000000",

        "00000000",
        "00111000",
        "00010000",
        "00010000",
        "00010000",
        "00010000",
        "00111000",
        "00000000",

        "00000000",
        "00010000",
        "00010000",
        "01111100",
        "00010000",
        "00010000",
        "00000000",
        "00000000",

        "00000000",
        "01000000",
        "01000000",
        "01000000",
        "01010100",
        "01111110",
        "00000000",
        "00000000",

        "00000000",
        "00000000",
        "01111110",
        "01010100",
        "01000000",
        "01000000",
        "01000000",
        "00000000",

        "00000000",
        "00111110",
        "00100000",
        "00110000",
        "00100000",
        "00110000",
        "00100000",
        "00000000",

        "00000000",
        "01111100",
        "00000100",
        "00001100",
        "00000100",
        "00001100",
        "00000100",
        "00000000",

        "00000000",
        "00111100",
        "00011000",
        "00000000",
        "00000000",
        "00011000",
        "00111100",
        "00000000",

        "00000000",
        "00111100",
        "00011000",
        "00000000",
        "00000000",
        "00011000",
        "00100100",
        "00000000",

        "00000000",
        "00111100",
        "00011000",
        "00000000",
        "00000000",
        "00011000",
        "00000000",
        "00000000",

        "00000000",
        "00111100",
        "00011000",
        "00000000",
        "00000000",
        "00000000",
        "00000000",
        "00000000",

        "00000000",
        "01100000",
        "00111000",
        "00001110",
        "00010100",
        "00101010",
        "00010110",
        "00000000",

        "00000000",
        "00000110",
        "00011100",
        "01110000",
        "00101000",
        "01010100",
        "01101000",
        "00000000",

        "00000000",
        "00010110",
        "00101010",
        "00010100",
        "00001110",
        "00111000",
        "01100000",
        "00000000",

        "00000000",
        "01101000",
        "01010100",
        "00101000",
        "01110000",
        "00011100",
        "00000110",
        "00000000",

        "00000000",
        "01100110",
        "01100110",
        "00100010",
        "00100010",
        "01100110",
        "01100110",
        "00000000",

        "00000000",
        "00000000",
        "00000000",
        "01100110",
        "01100110",
        "01100110",
        "01100110",
        "00000000",

        "00000000",
        "01100110",
        "01100110",
        "01000100",
        "01000100",
        "01100110",
        "01100110",
        "00000000",

        "00000000",
        "01100110",
        "01100110",
        "01100110",
        "01100110",
        "00000000",
        "00000000",
        "00000000",

        "00000000",
        "01111100",
        "01111000",
        "01110000",
        "01100000",
        "01000000",
        "00000000",
        "00000000",

        "00000000",
        "00000000",
        "01000000",
        "01100000",
        "01110000",
        "01111000",
        "01111100",
        "00000000",

        "00000000",
        "00000000",
        "00000010",
        "00000110",
        "00001110",
        "00011110",
        "00111110",
        "00000000",

        "00000000",
        "00111110",
        "00011110",
        "00001110",
        "00000110",
        "00000010",
        "00000000",
        "00000000"
        );

--attribute RAM_STYLE : string;
--attribute RAM_STYLE of RAM: signal is "BLOCK";

begin

    process (clka)
    begin
        if rising_edge(clka) then
            if (wea = '1') then
                RAM(conv_integer(addra(7 downto 0))) := dina;
            end if;
            douta <= RAM(conv_integer(addra(7 downto 0)));
        end if;
    end process;

    process (clkb)
    begin
        if rising_edge(clkb) then
            if (web = '1') then
                RAM(conv_integer(addrb(7 downto 0))) := dinb;
            end if;
            doutb <= RAM(conv_integer(addrb(7 downto 0)));
        end if;
    end process;

end BEHAVIORAL;



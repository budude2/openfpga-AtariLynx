library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

entity lynx_cheats is
   port 
   (
      clk            : in  std_logic;  
      reset          : in  std_logic;
                           
      cheat_clear    : in  std_logic;
      cheats_enabled : in  std_logic;
      cheat_on       : in  std_logic;
      cheat_in       : in  std_logic_vector(127 downto 0);
      cheats_active  : out std_logic := '0';
                           
      BusAddr        : in  unsigned(15 downto 0);
      RAMaccess      : in  std_logic;
      cheatOverwrite : out std_logic;
      cheatData      : out std_logic_vector(7 downto 0)
   );
end entity;

architecture arch of lynx_cheats is

   constant CHEATCOUNT  : integer := 32;
   
   constant OPTYPE_ALWAYS     : std_logic_vector(3 downto 0) := x"0";
   constant OPTYPE_EQUALS     : std_logic_vector(3 downto 0) := x"1";
   constant OPTYPE_GREATER    : std_logic_vector(3 downto 0) := x"2";
   constant OPTYPE_LESS       : std_logic_vector(3 downto 0) := x"3";
   constant OPTYPE_GREATER_EQ : std_logic_vector(3 downto 0) := x"4";
   constant OPTYPE_LESS_EQ    : std_logic_vector(3 downto 0) := x"5";
   constant OPTYPE_NOT_EQ     : std_logic_vector(3 downto 0) := x"6"; 
   constant OPTYPE_EMPTY      : std_logic_vector(3 downto 0) := x"F"; 
   
   constant BYTEMASK_BIT_0    : integer := 100;
   constant BYTEMASK_BIT_1    : integer := 101;
   constant BYTEMASK_BIT_2    : integer := 102;
   constant BYTEMASK_BIT_3    : integer := 103;
   
   signal cheat_on_1  : std_logic := '0';
   
   type cheat_type is record
      address : unsigned(15 downto 0);
      data    : std_logic_vector(7 downto 0);
      enabled : std_logic;
   end record;
   
   type t_cheatmem is array(0 to CHEATCOUNT - 1) of cheat_type;
   signal cheatmem : t_cheatmem;
   
   signal cheatindex : integer range 0 to CHEATCOUNT - 1 := 0;
   
begin 

   process (clk)
   begin
      if rising_edge(clk) then
   
         cheat_on_1 <= cheat_on;
         
         -- loading new cheats
         if (reset = '1') then
            
            for i in 0 to CHEATCOUNT - 1 loop
               cheatmem(i).enabled <= '0';
            end loop;
            cheatindex <= 0;
            cheats_active <= '0';
         
         else
         
            if (cheat_clear = '1') then
            
               for i in 0 to CHEATCOUNT - 1 loop
                  cheatmem(i).enabled <= '0';
               end loop;
               cheatindex <= 0;
               cheats_active <= '0';
               
            elsif (cheat_on = '1' and cheat_on_1 = '0') then
               if (cheat_in(99 downto 96) = OPTYPE_ALWAYS) then
               
                  cheats_active <= '1';
                  
                  cheatmem(cheatindex).enabled <= '1';
                  cheatmem(cheatindex).address <= unsigned(cheat_in(79 downto 64));
                  cheatmem(cheatindex).data    <= cheat_in(7 downto 0);
                  
                  if (cheatindex < CHEATCOUNT - 1) then
                     cheatindex <= cheatindex + 1;
                  end if;
                  
               end if;
            end if; 
         
         end if;
         
         -- apply cheats
         cheatOverwrite <= '0';
         if (RAMaccess = '1' and cheats_enabled = '1') then
            for i in 0 to CHEATCOUNT - 1 loop
               if (cheatmem(i).enabled = '1' and cheatmem(i).address = BusAddr) then
                  cheatData      <= cheatmem(i).data;
                  cheatOverwrite <= '1';
               end if;
            end loop;
         end if;
         
      end if;
   end process;
 

end architecture;






library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

use work.pRegisterBus.all;
use work.pReg_suzy.all;
use work.pReg_mikey.all;

entity dummyregs is
   port 
   (
      clk            : in  std_logic;
      ce             : in  std_logic;
      reset          : in  std_logic;
      
      RegBus_Din     : in  std_logic_vector(BUS_buswidth-1 downto 0);
      RegBus_Adr     : in  std_logic_vector(BUS_busadr-1 downto 0);
      RegBus_wren    : in  std_logic;
      RegBus_rst     : in  std_logic;
      RegBus_Dout    : out std_logic_vector(BUS_buswidth-1 downto 0)
   );
end entity;

architecture arch of dummyregs is

   signal REG_SUZYSREV : std_logic_vector(SUZYSREV.upper downto SUZYSREV.lower) := (others => '0');
   
   type t_reg_wired_or is array(0 to 2) of std_logic_vector(7 downto 0);
   signal reg_wired_or : t_reg_wired_or;

begin 

   process (reg_wired_or)
      variable wired_or : std_logic_vector(7 downto 0);
   begin
      wired_or := reg_wired_or(0);
      for i in 1 to (reg_wired_or'length - 1) loop
         wired_or := wired_or or reg_wired_or(i);
      end loop;
      RegBus_Dout <= wired_or;
   end process;

   iREG_SUZYHREV : entity work.eReg generic map ( SUZYHREV ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(0), x"01");  
   iREG_SUZYSREV : entity work.eReg generic map ( SUZYSREV ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(1), REG_SUZYSREV, REG_SUZYSREV);  
   
   iREG_AUDIN    : entity work.eReg generic map ( AUDIN    ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(2), x"80");  

end architecture;






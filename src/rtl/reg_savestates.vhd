library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

use work.pBus_savestates.all;

package pReg_savestates is

   --   (                                                   adr   upper    lower    size   default)  

   -- cpu
   constant REG_SAVESTATE_CPU           : savestate_type := (  0,   56,      0,        1, x"0006FF000000FF80");
                                        
   constant REG_SAVESTATE_MEMORY        : savestate_type := (  1,    3,      0,        1, x"0000000000000000");
   
   constant REG_SAVESTATE_CART          : savestate_type := (  2,   19,      0,        1, x"0000000000000000");
   
   constant REG_SAVESTATE_MATH1         : savestate_type := (  3,   63,      0,        1, x"0000000000000000");
   constant REG_SAVESTATE_MATH2         : savestate_type := (  4,   55,      0,        1, x"0000000000000000");
   
   constant REG_SAVESTATE_SERIAL        : savestate_type := (  5,   31,      0,        1, x"000000000500FFFF");
  
   constant REG_SAVESTATE_DMA           : savestate_type := (  6,   31,      0,        1, x"0000000000008000");
   
   constant REG_SAVESTATE_IRQ           : savestate_type := (  7,    7,      0,        1, x"0000000000000000");
   
   constant REG_SAVESTATE_TIMER         : savestate_type := (  8,   26,      0,        8, x"0000000000000000");
   
   constant REG_SAVESTATE_SOUND         : savestate_type := ( 16,   53,      0,        4, x"0000000000000000");
   
   constant REG_SAVESTATE_GPUREGS       : savestate_type := ( 20,   63,      0,        6, x"0000000000000000");
  
   
end package;

-----------------------------------------------------------------
--------------- Export Package  --------------------------------
-----------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

package pexport is

   type cpu_export_type is record
      PC               : unsigned(15 downto 0);
      RegA             : unsigned(7 downto 0);
      RegX             : unsigned(7 downto 0);
      RegY             : unsigned(7 downto 0);
      RegS             : unsigned(7 downto 0);
      RegP             : unsigned(7 downto 0);
      FlagNeg          : std_logic;
      FlagOvf          : std_logic;
      FlagBrk          : std_logic;
      FlagDez          : std_logic;
      FlagIrq          : std_logic;
      FlagZer          : std_logic;
      FlagCar          : std_logic;            
      sleep            : std_logic;
      irqrequest       : std_logic;
      opcodebyte_last  : std_logic_vector(7 downto 0);
   end record;
   
   type t_exporttimer is array(0 to 7) of std_logic_vector(7 downto 0);
  
end package;

-----------------------------------------------------------------
--------------- Export module    --------------------------------
-----------------------------------------------------------------


library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     
use STD.textio.all;

use work.pexport.all;

entity export is
   port 
   (
      clk              : in std_logic;
      ce               : in std_logic;
      reset            : in std_logic;
      
      new_export       : in std_logic;
      export_cpu       : in cpu_export_type;    
      export_timer     : in t_exporttimer;
      
      export_8         : in std_logic_vector(7 downto 0);
      export_16        : in std_logic_vector(15 downto 0);
      export_32        : in std_logic_vector(31 downto 0)
   );
end entity;

architecture arch of export is
     
   signal totalticks   : unsigned(31 downto 0) := (others => '0');
   signal cyclenr      : unsigned(31 downto 0) := x"00000001";
     
   signal reset_1      : std_logic := '0';
   signal export_reset : std_logic := '0';
   signal exportnow    : std_logic;
     
begin  
 
-- synthesis translate_off
   process(clk)
   begin
      if rising_edge(clk) then
         if (reset = '1') then
            totalticks <= (others => '0');
         elsif (ce = '1') then
            totalticks <= totalticks + 1;
         end if;
         reset_1 <= reset;
      end if;
   end process;
   
   export_reset <= '1' when (reset = '0' and reset_1 = '1') else '0';
   
   exportnow <= export_reset or new_export;

   process
   
      file outfile: text;
      file outfile_irp: text;
      variable f_status: FILE_OPEN_STATUS;
      variable line_out : line;
      variable recordcount : integer := 0;
      
      constant filenamebase               : string := "R:\\debug_sim";
      variable filename_current           : string(1 to 25);
      
   begin
   
      filename_current := filenamebase & "00000000.txt";
   
      file_open(f_status, outfile, filename_current, write_mode);
      file_close(outfile);
      file_open(f_status, outfile, filename_current, append_mode); 
      
      write(line_out, string'("A  X  Y  S  NO1BDIZC S R PC   op ticks    T0 T1 T2 T3 T4 T5 T6 T7 D8 D16  D32"));
      writeline(outfile, line_out);
      
      while (true) loop
         wait until rising_edge(clk);
         if (reset = '1') then
            cyclenr <= x"00000001";
            filename_current := filenamebase & "00000000.txt";
            file_close(outfile);
            file_open(f_status, outfile, filename_current, write_mode);
            file_close(outfile);
            file_open(f_status, outfile, filename_current, append_mode);
            write(line_out, string'("A  X  Y  S  NO1BDIZC S R PC   op ticks    T0 T1 T2 T3 T4 T5 T6 T7 D8 D16  D32"));
            writeline(outfile, line_out);
         end if;
         
         if (exportnow = '1') then
         
            write(line_out, to_hstring(export_cpu.RegA) & " ");
            write(line_out, to_hstring(export_cpu.RegX) & " ");
            write(line_out, to_hstring(export_cpu.RegY) & " ");
            write(line_out, to_hstring(export_cpu.RegS) & " ");
            
            if (export_cpu.FlagNeg = '1')    then write(line_out, string'("1"));  else write(line_out, string'("0")); end if;
            if (export_cpu.FlagOvf = '1')    then write(line_out, string'("1"));  else write(line_out, string'("0")); end if;
            write(line_out, string'("1"));
            if (export_cpu.FlagBrk = '1')    then write(line_out, string'("1"));  else write(line_out, string'("0")); end if;
            if (export_cpu.FlagDez = '1')    then write(line_out, string'("1"));  else write(line_out, string'("0")); end if;
            if (export_cpu.FlagIrq = '1')    then write(line_out, string'("1"));  else write(line_out, string'("0")); end if;
            if (export_cpu.FlagZer = '1')    then write(line_out, string'("1"));  else write(line_out, string'("0")); end if;
            if (export_cpu.FlagCar = '1')    then write(line_out, string'("1 "));  else write(line_out, string'("0 ")); end if;
                                             
            if (export_cpu.sleep = '1')      then write(line_out, string'("1 "));  else write(line_out, string'("0 ")); end if;
            if (export_cpu.irqrequest = '1') then write(line_out, string'("1 "));  else write(line_out, string'("0 ")); end if;
            
            write(line_out, to_hstring(export_cpu.PC) & " ");
            write(line_out, to_hstring(export_cpu.opcodebyte_last) & " ");
            write(line_out, to_hstring(totalticks) & " ");
            
            for i in 0 to 7 loop
               write(line_out, to_hstring(export_timer(i)) & " ");
            end loop;
            
            write(line_out, to_hstring(export_8 ) & " ");
            write(line_out, to_hstring(export_16) & " ");
            write(line_out, to_hstring(export_32) & " ");
      
            writeline(outfile, line_out);
            
            cyclenr     <= cyclenr + 1;
            
            if (cyclenr mod 10000000 = 0) then
               filename_current := filenamebase & to_hstring(cyclenr) & ".txt";
               file_close(outfile);
               file_open(f_status, outfile, filename_current, write_mode);
               file_close(outfile);
               file_open(f_status, outfile, filename_current, append_mode);
               write(line_out, string'("A  X  Y  S  NO1BDIZC S R PC   op ticks    T0 T1 T2 T3 T4 T5 T6 T7 D8 D16  D32"));
               writeline(outfile, line_out);
            end if;
            
         end if;
            
      end loop;
      
   end process;
-- synthesis translate_on

end architecture;






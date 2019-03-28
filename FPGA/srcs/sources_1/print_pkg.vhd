----------------------------------------------------------------------------------
--    Copyright (C) 2019 Dejan Priversek
--
--    This program is free software: you can redistribute it and/or modify
--    it under the terms of the GNU General Public License as published by
--    the Free Software Foundation, either version 3 of the License, or
--    (at your option) any later version.
--
--    This program is distributed in the hope that it will be useful,
--    but WITHOUT ANY WARRANTY; without even the implied warranty of
--    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--    GNU General Public License for more details.
--
--    You should have received a copy of the GNU General Public License
--    along with this program.  If not, see <http://www.gnu.org/licenses/>.
----------------------------------------------------------------------------------

--custom package to ouput text to console
library STD;
use std.textio.all; 

package TextUtil is
  procedure Print(s : string);
end package TextUtil;

package body TextUtil is

  procedure Print(s : string) is 
    variable buf : line;
    
  begin
    write(buf, s); 
    WriteLine(OUTPUT, buf); 
    
  end procedure Print; 
  
end package body TextUtil;
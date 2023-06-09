with Ada.Wide_Wide_Text_IO;

with Umwi;

package Tools is

   type Access_File_Type is access all Ada.Wide_Wide_Text_IO.File_Type;

   subtype Code_Point is Natural range 0 .. 16#10FFFF#;
   subtype WWString is Umwi.WWString;

   --  Helpers to generate

   type Code_Range is tagged record
      First, Last : Code_Point;
   end record;

   type Optional_Range (Empty : Boolean) is record
      case Empty is
         when False => Codes : Code_Range;
         when True  => null;
      end case;
   end record;

   function New_Range (First, Last : Code_Point) return Optional_Range
     is (Empty => False, Codes => (First => First, Last => Last));

   function Image (This : Code_Range) return Wide_Wide_String;

   type Range_Maker is tagged private;

   type Optional_Code (Empty : Boolean := True) is record
      case Empty is
         when False => Code : Code_Point;
         when True  => null;
      end case;
   end record;

   function New_Code (C : Code_Point) return Optional_Code
   is (Empty => False, Code => C);

   function Add (This : in out Range_Maker; Code : Optional_Code)
                 return Optional_Range;
   --  Add an empty code to signal THE END. Otherwise add a single code. Once a
   --  disjoint range is detected, a non-empty range is returned.

   procedure Iterate (File : String;
                      Doing : access procedure (Line : WWString));

private

   type Range_Maker is tagged record
      First,
      Last : Optional_Code;
   end record;

end Tools;

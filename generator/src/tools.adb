with Ada.Strings.UTF_Encoding.Wide_Wide_Strings;
use  Ada.Strings.UTF_Encoding.Wide_Wide_Strings;
with Ada.Strings.Wide_Wide_Fixed;

package body Tools is

   use all type Ada.Strings.Trim_End;

   package Num_IO is new Ada.Wide_Wide_Text_IO.Integer_IO (Code_Point);
   use Num_IO;

   -------
   -- C --
   -------

   function C (X : String) return WWString is
   begin
      return Decode ("WWChar'Val (16#" & X & "#)");
   end C;

   ----------
   -- Trim --
   ----------

   function Trim (S : WWString) return WWString
   is (Ada.Strings.Wide_Wide_Fixed.Trim (S, Both));

   -----------
   -- Image --
   -----------

   function Image (This : Code_Range) return Wide_Wide_String is
      N1, N2 : WWString (1 .. 19);
   begin
      Put (N1, This.First, Base => 16);
      Put (N2, This.Last,  Base => 16);
      return
        "WWChar'Val (" & Trim (N1) & ")"
        & (if N1 /= N2
           then " .. " & "WWChar'Val (" & Trim (N2) & ")"
           else "");
   end Image;

   ---------
   -- Add --
   ---------

   function Add (This : in out Range_Maker; Code : Optional_Code)
                 return Optional_Range
   is
   begin
      if Code.Empty then
         return New_Range (This.First.Code, This.Last.Code);
      end if;

      if This.First.Empty then
         This.First := New_Code (Code.Code);
         This.Last  := This.First;
         return (Empty => True);

      elsif Code.Code > This.Last.Code + 1 then -- disjoint range seen
         return R : constant Optional_Range :=
           New_Range (This.First.Code, This.Last.Code)
         do
            This.First := New_Code (Code.Code);
            This.Last  := This.First;
         end return;

      elsif Code.Code = This.Last.Code + 1 then
         This.Last := New_Code (Code.Code);
         return (Empty => True);

      else
         raise Program_Error; -- we've gone back in codes

      end if;
   end Add;

   -------------
   -- Iterate --
   -------------

   procedure Iterate (File  : String;
                      Doing : access procedure (Line : WWString))
   is
      use Ada.Wide_Wide_Text_IO;
      F : File_Type;
   begin
      Open (F, In_File, File);

      while not End_Of_File (F) loop
         declare
            Line : constant WWString := Get_Line (F);
         begin
            Doing (Line);
         end;
      end loop;

      Close (F);
   end Iterate;

end Tools;

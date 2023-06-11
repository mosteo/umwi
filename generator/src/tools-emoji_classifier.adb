with AAA.Strings;

with Ada.Strings.UTF_Encoding.Wide_Wide_Strings;
use  Ada.Strings.UTF_Encoding.Wide_Wide_Strings;
with Ada.Wide_Wide_Text_IO; use Ada.Wide_Wide_Text_IO;

package body Tools.Emoji_Classifier is

   First : Boolean := True;

   --------------
   -- Classify --
   --------------

   procedure Classify (Line : WWString) is
      use AAA.Strings;
   begin
      if Line = "" or else Line (Line'First) = '#' then
         return;
      end if;

      declare
         Line8 : constant String := Encode (Line); -- To UTF8
         Codes : constant Vector := Split (Line8, ';', Trim => True);
         Sepco : constant Vector := Split (Codes (1), '.');
         Label : constant Vector := Split (Codes (2), '#', Trim => True);
         Info  : Vector := Label;
         --  The emoji-data.txt file is UTF8 with plenty of non-ASCII content
      begin
         if Decode (Label (1)) = Target_Label then
            Put_Line (F.all,
                      (if First then "      " else "    | ")
                      & C (Sepco (1))
                      & (if Sepco.Length in 3
                        then " .. " & C (Sepco (3))
                        else "")
                     );
            Info.Delete_First;
            Put_Line (F.all, "      --  " & Decode (Info.Flatten ('#')));
            First := False;
         end if;
      end;
   end Classify;

begin
   New_Line (F.all);
   Put_Line (F.all, "   subtype " & Target_Label & " is WWChar");
   Put_Line (F.all, "      with Static_Predicate => " & Target_Label & " in");
end Tools.Emoji_Classifier;

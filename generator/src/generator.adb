with Ada.Wide_Wide_Text_IO; use Ada.Wide_Wide_Text_IO;
with Ada.Characters.Conversions;

with AAA.Strings;

with Tools; use Tools;
with Tools.Emoji_Classifier;

procedure Generator is
   F : aliased File_Type;

   procedure Put_Line (Text : Wide_Wide_String) is
   begin
      Put_Line (F, Text);
   end Put_Line;

   procedure Put_Line is
   begin
      New_Line (F);
   end Put_Line;

   function H (S : String) return String
   is ("16#" & S & "#");

   Comb_Range : Tools.Range_Maker;
   First_Comb : Boolean := True;

   procedure Combining (Line : Tools.WWString) is
      use AAA.Strings;
      use Ada.Characters;
      Fields : constant Vector := Split (Conversions.To_String (Line), ';');
      --  The UnicodeData.txt file contains ASCII only so this is safe
   begin
      if Fields (3) (String'(Fields (3))'First) in 'M' | 'n' then
         --  A Marking general category is the combining telltale
         declare
            Opt_Range : constant Tools.Optional_Range :=
                          Comb_Range.Add
                            (New_Code (Natural'Value (H (Fields (1)))));
         begin
            if not Opt_Range.Empty then
               Put_Line ((if First_Comb then "      " else "    | ")
                         & Opt_Range.Codes.Image);
               First_Comb := False;
            end if;
         end;
      end if;
   end Combining;

begin
   Create (F, Name => "gen.ads");

   --  Preamble
   Put_Line ("package Umwi.Generated with Preelaborate is");
   Put_Line;
   Put_Line ("   --  This file is generated by the generator nested crate 😁");
   Put_Line;

   --  Combining code points
   Put_Line
     ("   subtype Combining is WWChar with Static_Predicate => Combining in");
   Tools.Iterate ("share/generator/UnicodeData.txt", Combining'Access);
   Put_Line ("   ;");

   --  Emoji
   declare
      package X is new Emoji_Classifier ("Emoji", F'Unchecked_Access);
   begin
      Tools.Iterate ("share/generator/emoji-data.txt", X.Classify'Access);
      Put_Line ("   ;");
   end;

   --  East_Asian_Width

   --  Closure
   Put_Line;
   Put_Line ("end Umwi.Generated;");

   Close (F);
end Generator;
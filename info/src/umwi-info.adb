with AAA.Strings;  use AAA.Strings;
with AAA.Table_IO; use AAA.Table_IO;

with Ada.Strings.UTF_Encoding.Wide_Wide_Strings;
use  Ada.Strings.UTF_Encoding.Wide_Wide_Strings;
with Ada.Strings.Wide_Wide_Fixed; use Ada.Strings.Wide_Wide_Fixed;
with Ada.Text_IO;
with Ada.Wide_Wide_Text_IO;
use  Ada.Wide_Wide_Text_IO;

with AnsiAda; use AnsiAda;

procedure Umwi.Info is

   subtype WChr is Wide_Wide_Character;
   subtype WStr is Wide_Wide_String;

   function Hex (I : Integer) return String is
      package Int_IO is new Ada.Text_IO.Integer_IO (Integer);
      Buffer : String (1 .. 19) := (others => ' ');
   begin
      Int_IO.Put (Buffer, I, 16);
      return Trim (Buffer);
   end Hex;

   function EAW (S : WStr; I : Integer := 1) return String
   is (if I > S'Last
       then ""
       else East_Asian_Width'(Count (S (I)).Width)'Image
            & " " & EAW (S, I + 1));

   function Codes (S : WStr; I : Integer := 1) return String
   is (if I > S'Last
       then ""
       else Hex (WChr'Pos (S (I))) & " " & Codes (S, I + 1));

begin
   Put ("Enter text: ");
   declare
      Text : constant WStr := Get_Line;
      Line : constant WStr := (Count (Text).Width + 4) * "-";
      Tab  : Table;
   begin
      Put_Line (Line);
      Put_Line ("- " & Text & " -");
      Put_Line (Line);

      Tab.Append ("Codes:").Append (Codes (Text, Text'First)).Append ("-")
        .New_Row;
      Tab.Append ("Code point count:").Append (Text'Length'Image).Append ("-")
        .New_Row;
      Tab.Append ("Width:").Append (Count (Text).Width'Image).Append ("-")
        .New_Row;
      Tab.Append ("East Asian width:").Append (EAW (Text, Text'First))
        .Append ("-").New_Row;
      Tab.Append ("Image:").Append (Encode (Text)).Append ("-")
        .New_Row;
      Tab.Append ("Color image:")
        .Append (Color_Wrap (Encode (Text), Foreground (Light_Red)))
        .Append ("-").New_Row;

      Tab.Print (Align => (1 => Ada.Strings.Right, 2 => <>));
   end;

end Umwi.Info;

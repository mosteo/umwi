with Umwi;

with Ada.Exceptions;
with Ada.Characters.Conversions;
with Ada.Strings.UTF_Encoding.Wide_Wide_Strings;
use  Ada.Strings.UTF_Encoding.Wide_Wide_Strings;
with Ada.Wide_Wide_Text_IO; use Ada.Wide_Wide_Text_IO;

procedure Demo is

   -----------
   -- Print --
   -----------

   procedure Print (Text : Umwi.WWString; Descr : Umwi.WWString := "") is
      Length : constant Natural := Umwi.Width (Text);
   begin
      if Length /= 4 then
         raise Program_Error
           with "Length check failed for " & Encode (Text);
      end if;

      Put_Line (Text & ":" & Length'Wide_Wide_Image & ": '"
                & (if Descr /= ""
                  then " # " & Descr
                  else ""));
   end Print;

   ---------
   -- Bad --
   ---------

   procedure Bad (Text : Umwi.WWString; Descr : Umwi.WWString) is
      use Ada.Characters.Conversions;
      use Ada.Exceptions;
   begin
      declare
         Length : Natural;
      begin
         Length := Umwi.Width (Text);
         raise Program_Error
           with Encode (Text) & "Should have raised but gave length:"
                              & Length'Image;
      exception
         when E : Umwi.Encoding_Error =>
            Put_Line
              (Text & " # " & Descr & ": raised with "
               & To_Wide_Wide_String (Exception_Message (E)));
      end;
   end Bad;

   function C (Pos : Positive) return Umwi.WWChar is (Umwi.WWChar'Val (Pos));

begin
   Umwi.Default.Honor_Emoji_Selectors := True;

   New_Line;
   Put_Line ("All sequences should be 4 slots in length in a monospace font ");
   Put_Line ("in a system that properly honors Unicode displaying.");
   Put_Line ("All length counts should also be 4.");
   New_Line;

   Print ("abcd", "regular ASCII");
   Print ("a·c·", "latin1 middle dot");
   Print ("xxxa" & C (16#0308#), "combining diacritic");
   Print (C (16#0308#) & "1234", "combining diacritic as 1st char (illegal)");
   Print ("😀😀", "Emoji with Default wide Presentation");
   Print ("---" & C (16#264D#) & Umwi.Text_Selector,
          "Emoji with text selector (valid)");
   Print ("★★★★", "emoji with default narrow presentation");
   Print ("☄☄☄☄", "emoji with default narrow presentation");
   Print ("☄" & Umwi.Presentation_Selector
          & "☄" & Umwi.Presentation_Selector,
          "narrow emoji with wide presentation selector");
   Print ("--" & C (16#1F1EA#) & C (16#1F1F8#), "ES country flag");
   Print ("--🧑" & C (16#1F3FB#), "face plus skin tone");
   Print ("9️⃣9️⃣", "keycap sequence base+presentation+keycap x2");
   Print ("---" & C (16#39#) & C (16#20E3#),
          "keycap sequence base+keycap (invalid)");
   Print ("--👨‍👩‍👧‍👦",
          "family (man+woman+etc, with zero-width joiner in between)");
   Print ("ばか", "japanese hiragana");
   Print ("バカ", "japanese katakana");
   Print ("馬鹿", "kanji");

   Umwi.Default.Honor_Emoji_Selectors := False;
   New_Line;
   Put_Line ("From now on, emoji selectors are not honored for the count.");
   Put_Line ("Counts still should always be 4.");
   New_Line;

   Print ("--☄" & Umwi.Presentation_Selector
          & "☄" & Umwi.Presentation_Selector,
          "narrow emoji with wide presentation selector");
   Print ("--" & C (16#264D#) & Umwi.Text_Selector,
          "wide emoji with text selector (valid)");

   Umwi.Default.Reject_Illegal := True;
   New_Line;
   Put_Line ("The following sequences should raise when Reject_Illegal:");
   New_Line;

   Bad (C (16#0308#) & "1234", "combining diacritic as 1st char (illegal)");
   Bad ("---" & C (16#39#) & C (16#20E3#),
        "base+keycap (missing presentation)");

end Demo;

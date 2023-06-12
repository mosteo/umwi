with Umwi;
with Ada.Wide_Wide_Text_IO; use Ada.Wide_Wide_Text_IO;

procedure Demo is

   procedure Print (Text : Umwi.WWString; Descr : Umwi.WWString := "") is
      Length : constant Natural := Umwi.Length (Text);
   begin
      Put_Line (Text & ":" & Length'Wide_Wide_Image & ": '"
                & (if Descr /= ""
                  then " # " & Descr
                  else ""));
   end Print;

   function C (Pos : Positive) return Umwi.WWChar is (Umwi.WWChar'Val (Pos));

begin
   Umwi.Honor_Emoji_Selectors := True;

   New_Line;
   Put_Line ("All sequences should be 4 slots in length in a monospace font ");
   Put_Line ("in a system that properly honors Unicode displaying.");
   Put_Line ("All length counts should also be 4.");
   New_Line;

   Print ("abcd", "regular ASCII");
   Print ("a·c·", "latin1 middle dot");
   Print ("xxxa" & C (16#0308#), "combining diacritic");
   Print (C (16#0308#) & "1234", "combining diacritic as first character");
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

   Umwi.Honor_Emoji_Selectors := False;
   New_Line;
   Put_Line ("From now on, emoji selectors are not honored for the count.");
   Put_Line ("Counts still should always be 4.");
   New_Line;

   Print ("--☄" & Umwi.Presentation_Selector
          & "☄" & Umwi.Presentation_Selector,
          "narrow emoji with wide presentation selector");
   Print ("--" & C (16#264D#) & Umwi.Text_Selector,
          "wide emoji with text selector (valid)");
end Demo;

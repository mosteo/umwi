with Ada.Strings.UTF_Encoding.Wide_Wide_Strings;

with Umwi.Generated;
with Umwi.Properties;

package body Umwi is

   ----------------------
   -- Emoji_Properties --
   ----------------------

   function Emoji_Properties (Symbol : WWChar) return Emoji_Property_Array
                              renames Properties.Emoji_Properties;

   -----------
   -- Width --
   -----------

   function Width (Symbol : WWChar) return East_Asian_Width
                   renames Generated.Width;

   -----------
   -- Width --
   -----------

   function Width (Symbol  : WWChar;
                   Context : Contexts := (if Narrow_Context
                                          then Narrow
                                          else Wide))
                   return Widths
   is (case East_Asian_Width'(Width (Symbol)) is
          when A      =>
            (case Context is
                when Narrow => 1,
                when Wide   => 2),
          when F | W  => 2,
          when others => 1);

   ------------
   -- Length --
   ------------

   function Length (Text           : WWString;
                    Context        : Contexts := (if Narrow_Context
                                                  then Narrow
                                                  else Wide);
                    Honor_Selector : Boolean := Honor_Emoji_Selectors;
                    Honor_Modifier : Boolean := Honor_Emoji_Modifiers)
                    return Natural
   is
      I : Integer := Text'First;

      -------------------
      -- Emoji_To_Text --
      -------------------

      function Emoji_To_Text return Match is
         --  Matches a plain emoji with text presentation selector
      begin
         if I < Text'Last
           and then Text (I) in Generated.Emoji
           and then Text (I + 1) = Text_Selector
         then
            return Matched ((if Honor_Selector
                            then 1
                            else Width (Text (I), Context)),
                            Text (I .. I + 1));
         else
            return No_Match;
         end if;
      end Emoji_To_Text;

      ------------------
      -- Not_An_Emoji --
      ------------------

      function Not_An_Emoji return Match is
         J : Natural := I + 1;
      begin
         if Text (I) in Generated.Emoji then
            return No_Match;
         end if;

         while J <= Text'Last and then
           Text (J) in Properties.Combining
         loop
            J := J + 1;
         end loop;

         return Matched ((if Text (I) in Properties.Combining
                          then 0
                          else Width (Text (I), Context)),
                         Text (I .. J - 1));
      end Not_An_Emoji;

      -------------------
      -- Flag_Sequence --
      -------------------

      function Flag_Sequence (Offset : Natural) return Match is
         subtype RI is Umwi.Regional_Indicator_Emoji_Component;
      begin
         if I + Offset < Text'Last
           and then Text (I + Offset) in RI
           and then Text (I + Offset + 1) in RI
         then
            return Matched (2, Text (I + Offset .. I + Offset + 1));
         end if;

         return No_Match;
      end Flag_Sequence;

      -----------
      -- Emoji --
      -----------

      function Emoji (Offset : Natural) return Match is
      begin
         if I + Offset <= Text'Last
           and then Text (I + Offset) in Generated.Emoji
         then
            return Matched (Width (Text (I + Offset), Context),
                            Text (I + Offset));
         else
            return No_Match;
         end if;
      end Emoji;

      ----------------
      -- Code_Point --
      ----------------

      function Code_Point (Target : WWChar; Offset : Natural) return Match is
      begin
         if I + Offset <= Text'Last and then Text (I + Offset) = Target then
            return Matched (0, Target);
         else
            return No_Match;
         end if;
      end Code_Point;

      --------------------
      -- Emoji_Modifier --
      --------------------

      function Emoji_Modifier (Offset : Natural) return Match is
      begin
         if not Honor_Modifier then
            return No_Match;
         end if;

         if I + Offset <= Text'Last
           and then Text (I + Offset) in Generated.Emoji_Modifier
         then
            return Matched (0, Text (I + Offset));
         else
            return No_Match;
         end if;
      end Emoji_Modifier;

      ------------------------
      -- M_Enclosing_Keycap --
      ------------------------

      function M_Enclosing_Keycap (Offset : Natural) return Match is
      begin
         return Code_Point (Enclosing_Keycap, Offset);
      end M_Enclosing_Keycap;

      ------------------
      -- Tag_Modifier --
      ------------------

      function Tag_Modifier (Offset : Natural) return Match is
         Len : Natural := 0;
      begin
         while I + Offset <= Text'Last loop
            if Text (I + Offset) in Tag then
               Len := Len + 1;
            end if;

            exit when Text (I + Offset) = Terminal_Tag
              or else Text (I + Offset) not in Tag;
         end loop;

         if Len > 0 then
            return Matched (0, Text (I + Offset .. I + Offset + Len));
         else
            return No_Match;
         end if;
      end Tag_Modifier;

      ------------------------
      -- Emoji_Modification --
      ------------------------

      function Emoji_Modification (Offset : Natural) return Match is
      begin
         return No_Match
           .Or_Else (Emoji_Modifier (Offset))
           .Or_Else (Code_Point (Presentation_Selector, Offset)
                     .And_Then (Offset + 1, M_Enclosing_Keycap'Access))
           .Or_Else (Tag_Modifier (Offset));
      end Emoji_Modification;

      -----------------
      -- ZWJ_Element --
      -----------------

      function ZWJ_Element (Offset : Natural) return Match is
      begin
         return No_Match
           .Or_Else (Flag_Sequence (Offset))
           .Or_Else (Emoji (Offset)
                     .And_Then (Offset + 1, Emoji_Modification'Access));
      end ZWJ_Element;

      --------------
      -- ZWJ_List --
      --------------

      function ZWJ_List (Offset : Natural) return Match is
         --  (\x{200D} zwj_element)* in possible_emoji
      begin
         if I + Offset > Text'Last
           or else Text (I + Offset) /= Zero_Width_Joiner
         then
            return No_Match;
         end if;

         return
           Matched (0, Text (I + Offset)) -- ZWJ
           .Append (ZWJ_Element (Offset + 1));
      end ZWJ_List;

      --------------------
      -- Possible_Emoji --
      --------------------

      function Possible_Emoji return Match is
         Next : constant Match := ZWJ_Element (0);
      begin
         if Next = No_Match then
            return No_Match;
         end if;

         return Next.Append (ZWJ_List (Next.Length));
      end Possible_Emoji;

      ---------------
      -- Bad_Emoji --
      ---------------

      function Bad_Emoji return Match is
         --  This happens when Possible_Emoji didn't match and Not_An_Emoji
         --  found and emoji. We simply take the width at face value.
      begin
         return Matched ((if Text (I) in Umwi.Zero_Width_Emoji_Component
                          then 0
                          else Width (Text (I), Context)),
                         Text (I));
      end Bad_Emoji;

      Length : Natural := 0;

   begin
      while I <= Text'Last loop
         declare
            Next : constant Match :=
                     No_Match
                       .Or_Else (Emoji_To_Text)
                       .Or_Else (Possible_Emoji) -- This will be a presentation
                       .Or_Else (Not_An_Emoji)
                       .Or_Else (Bad_Emoji);
         begin
            if Next.Length = 0 then
               return Length;
               --  Something very strange has happened or we have consumed all
               --  the string.
            else
               I      := I      + Next.Length;
               Length := Length + Next.Width;
            end if;
         end;
      end loop;

      return Length;
   end Length;

   ------------
   -- Length --
   ------------

   function Length (Text           : UTF8_String;
                    Context        : Contexts := (if Narrow_Context
                                                  then Narrow
                                                  else Wide);
                    Honor_Selector : Boolean := Honor_Emoji_Selectors;
                    Honor_Modifier : Boolean := Honor_Emoji_Modifiers)
                    return Natural
   is
      use Ada.Strings.UTF_Encoding.Wide_Wide_Strings;
   begin
      return Length (Text           => Decode (String (Text)),
                     Context        => Context,
                     Honor_Selector => Honor_Selector,
                     Honor_Modifier => Honor_Modifier);
   end Length;

end Umwi;

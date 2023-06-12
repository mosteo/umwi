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

      -------------------
      -- Emoji_To_Text --
      -------------------

      function Emoji_To_Text (I : Natural) return Match is
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

      function Not_An_Emoji (I : Natural) return Match is
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

      function Flag_Sequence (I : Natural) return Match is
         subtype RI is Umwi.Regional_Indicator_Emoji_Component;
      begin
         if I < Text'Last
           and then Text (I) in RI
           and then Text (I + 1) in RI
         then
            return Matched (2, Text (I .. I + 1));
         end if;

         return No_Match;
      end Flag_Sequence;

      -----------
      -- Emoji --
      -----------

      function Emoji (I : Natural) return Match is
      begin
         if I <= Text'Last
           and then Text (I) in Generated.Emoji
         then
            return Matched (Width (Text (I), Context),
                            Text (I));
         else
            return No_Match;
         end if;
      end Emoji;

      ----------------
      -- Code_Point --
      ----------------

      function Code_Point (Target : WWChar; I : Natural) return Match is
      begin
         if I <= Text'Last and then Text (I) = Target then
            return Matched (0, Target);
         else
            return No_Match;
         end if;
      end Code_Point;

      --------------------
      -- Emoji_Modifier --
      --------------------

      function M_Emoji_Modifier (I : Natural) return Match is
      begin
         if not Honor_Modifier then
            return No_Match;
         end if;

         if I  <= Text'Last
           and then Text (I) in Generated.Emoji_Modifier
         then
            return Matched (0, Text (I));
         else
            return No_Match;
         end if;
      end M_Emoji_Modifier;

      ------------------------
      -- M_Enclosing_Keycap --
      ------------------------

      function M_Enclosing_Keycap (I : Natural) return Match is
      begin
         return Code_Point (Enclosing_Keycap, I);
      end M_Enclosing_Keycap;

      ------------------
      -- Tag_Modifier --
      ------------------

      function Tag_Modifier (I : Natural) return Match is
         Len : Natural := 0;
      begin
         while I <= Text'Last loop
            if Text (I) in Tag then
               Len := Len + 1;
            end if;

            exit when Text (I) = Terminal_Tag
              or else Text (I) not in Tag;
         end loop;

         if Len > 0 then
            return Matched (0, Text (I .. I + Len));
         else
            return No_Match;
         end if;
      end Tag_Modifier;

      -------------------------
      -- Presentation_Keycap --
      -------------------------

      function Presentation_Keycap (I : Natural) return Match is
      begin
         if I > Text'Length then
            return No_Match;
         else
            return
              Code_Point (Presentation_Selector, I)
              .Maybe_Then (I, M_Enclosing_Keycap'Unrestricted_Access,
                           Honor_Selector);
                           --  The Keycap is optional!
         end if;
      end Presentation_Keycap;

      ------------------------
      -- Emoji_Modification --
      ------------------------

      function Emoji_Modification (I : Natural) return Match is
      begin
         return No_Match
           .Or_Else (I, M_Emoji_Modifier'Unrestricted_Access)
           .Or_Else (I, Presentation_Keycap'Unrestricted_Access)
           .Or_Else (I, Tag_Modifier'Unrestricted_Access);
      end Emoji_Modification;

      -----------------
      -- ZWJ_Element --
      -----------------

      function ZWJ_Element (I : Natural) return Match is

         -----------------------------
         -- Emoji_Plus_Modification --
         -----------------------------

         function Emoji_Plus_Modification (I : Natural) return Match is
         begin
            return
              Emoji (I)
              .Maybe_Then (I, Emoji_Modification'Unrestricted_Access,
                           Honor_Selector);
         end Emoji_Plus_Modification;

      begin
         return No_Match
           .Or_Else (I, Flag_Sequence'Unrestricted_Access)
           .Or_Else (I, Emoji_Plus_Modification'Unrestricted_Access);
      end ZWJ_Element;

      --------------
      -- ZWJ_List --
      --------------

      function ZWJ_List (I : Natural) return Match is
         --  (\x{200D} zwj_element)* in possible_emoji
      begin
         if I > Text'Last
           or else Text (I) /= Zero_Width_Joiner
         then
            return No_Match;
         end if;

         return
           Matched (0, Text (I)) -- ZWJ
             .Maybe_Then (I, ZWJ_Element'Unrestricted_Access,
                          Honor_Selector)
             .Maybe_Then (I, ZWJ_List'Unrestricted_Access,
                          Honor_Selector);
      end ZWJ_List;

      --------------------
      -- Possible_Emoji --
      --------------------

      function Possible_Emoji (I : Natural) return Match is
         Next : constant Match := ZWJ_Element (I);
      begin
         if Next = No_Match then
            return No_Match;
         end if;

         return Next.Append (ZWJ_List (I + Next.Length), Honor_Selector);
      end Possible_Emoji;

      ---------------
      -- Bad_Emoji --
      ---------------

      function Bad_Emoji (I : Natural) return Match is
         --  This happens when Possible_Emoji didn't match and Not_An_Emoji
         --  found and emoji. We simply take the width at face value.
      begin
         return Matched ((if Text (I) in Umwi.Zero_Width_Emoji_Component
                          then 0
                          else Width (Text (I), Context)),
                         Text (I));
      end Bad_Emoji;

      Length : Natural := 0;
      I      : Integer := Text'First;

   begin
      while I <= Text'Last loop
         declare
            Next : constant Match :=
                     No_Match
                       .Or_Else (I, Emoji_To_Text'Unrestricted_Access)
                       .Or_Else (I, Possible_Emoji'Unrestricted_Access)
                        --  This will be a presentation
                       .Or_Else (I, Not_An_Emoji'Unrestricted_Access)
                       .Or_Else (I, Bad_Emoji'Unrestricted_Access);
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

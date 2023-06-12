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

   --------------
   -- And_Then --
   --------------

   function And_Then (This : Match;
                      That : Matcher)
                      return Match
   is
   begin
      if This = No_Match then
         return No_Match;
      else
         declare
            Next : constant Match := That (This);
         begin
            if Next = No_Match then
               return No_Match;
            else
               return Next;
            end if;
         end;
      end if;
   end And_Then;

   ----------------
   -- Maybe_Then --
   ----------------

   function Maybe_Then (This           : Match;
                        That           : Matcher)
                        return Match
   is
   begin
      if This = No_Match then
         return No_Match;
      end if;

      declare
         Next : constant Match := That (This);
      begin
         if Next /= No_Match then
            return Next;
         else
            return This;
         end if;
      end;
   end Maybe_Then;

   --------------
   -- First_Of --
   --------------

   function First_Of (This  : Match;
                      Those : Alternatives) return Match
   is
   begin
      for Alt of Those loop
         declare
            Next : constant Match := Alt (This);
         begin
            if Next /= No_Match then
               return Next;
            end if;
         end;
      end loop;

      return No_Match;
   end First_Of;

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

      function Emoji_To_Text (Prev : Match) return Match is
         --  Matches a plain emoji with text presentation selector
      begin
         if Prev.I < Prev.Text'Last
           and then Text (Prev.I) in Generated.Emoji
           and then Text (Prev.I + 1) = Text_Selector
         then
            return Prev.Matching
              (Width  => (if Honor_Selector
                          then 1
                          else Width (Text (Prev.I), Context)),
               Length => 2);
         else
            return No_Match;
         end if;
      end Emoji_To_Text;

      ------------------
      -- Not_An_Emoji --
      ------------------

      function Not_An_Emoji (Prev : Match) return Match is
         J : Natural := Prev.I;
      begin
         if Prev.Next in Generated.Emoji then
            return No_Match;
         end if;

         while J + 1 <= Text'Last and then
           Text (J + 1) in Properties.Combining
         loop
            J := J + 1;
         end loop;

         return Prev.Matching
           (Width => (if Prev.Next in Properties.Combining
                      then 0
                      else Width (Prev.Next, Context)),
            Length => J - Prev.I + 1);
      end Not_An_Emoji;

      -------------------
      -- Flag_Sequence --
      -------------------

      function Flag_Sequence (Prev : Match) return Match is
         subtype RI is Umwi.Regional_Indicator_Emoji_Component;
      begin
         if Prev.I < Text'Last
           and then Text (Prev.I)     in RI
           and then Text (Prev.I + 1) in RI
         then
            return Prev.Matching (2, 2);
         end if;

         return No_Match;
      end Flag_Sequence;

      -------------
      -- M_Emoji --
      -------------

      function M_Emoji (Prev : Match) return Match is
      begin
         if Prev.Has_Input and then Prev.Next in Generated.Emoji then
            return Prev.Matching (Width (Prev.Next, Context), 1);
         else
            return No_Match;
         end if;
      end M_Emoji;

      ----------------
      -- Code_Point --
      ----------------

      function Code_Point (Prev : Match; Target : WWChar) return Match is
      begin
         if Prev.Has_Input and then Prev.Next = Target then
            return Prev.Matching (0, 1);
            --  0 because this is always used in the context of combinations
         else
            return No_Match;
         end if;
      end Code_Point;

      --------------------
      -- Emoji_Modifier --
      --------------------

      function M_Emoji_Modifier (Prev : Match) return Match is
      begin
         if not Honor_Modifier then
            return No_Match;
         end if;

         if Prev.Has_Input
           and then Prev.Next in Generated.Emoji_Modifier
         then
            return Prev.Matching (0, 1);
         else
            return No_Match;
         end if;
      end M_Emoji_Modifier;

      ------------------------
      -- M_Enclosing_Keycap --
      ------------------------

      function M_Enclosing_Keycap (Prev : Match) return Match is
      begin
         return Code_Point (Prev, Enclosing_Keycap);
      end M_Enclosing_Keycap;

      ------------------
      -- Tag_Modifier --
      ------------------

      function Tag_Modifier (Prev : Match) return Match is
         Len : Natural := 0;
         I   : Natural := Prev.I;
      begin
         while I <= Text'Last loop
            if Text (I) in Tag then
               Len := Len + 1;
               I   := I   + 1;
            end if;

            exit when Text (I) = Terminal_Tag
              or else Text (I) not in Tag;
         end loop;

         if Len > 0 then
            return Prev.Matching (0, Len);
         else
            return No_Match;
         end if;
      end Tag_Modifier;

      -------------------------
      -- Presentation_Keycap --
      -------------------------

      function Presentation_Keycap (Prev : Match) return Match is
      begin
         if not Prev.Has_Input then
            return No_Match;
         else
            return
              Code_Point (Prev, Presentation_Selector)
              .Maybe_Then (M_Enclosing_Keycap'Unrestricted_Access);
         end if;
      end Presentation_Keycap;

      ------------------------
      -- Emoji_Modification --
      ------------------------

      function Emoji_Modification (Prev : Match) return Match is
      begin
         return Prev.First_Of
           ([M_Emoji_Modifier'Unrestricted_Access,
             Presentation_Keycap'Unrestricted_Access,
             Tag_Modifier'Unrestricted_Access]);
      end Emoji_Modification;

      -----------------
      -- ZWJ_Element --
      -----------------

      function ZWJ_Element (Prev : Match) return Match is

         -----------------------------
         -- Emoji_Plus_Modification --
         -----------------------------

         function Emoji_Plus_Modification (Prev : Match) return Match is
         begin
            return
              Prev
                .And_Then (M_Emoji'Unrestricted_Access)
                .Maybe_Then (Emoji_Modification'Unrestricted_Access);
         end Emoji_Plus_Modification;

      begin
         return Prev.First_Of
           ([Flag_Sequence'Unrestricted_Access,
             Emoji_Plus_Modification'Unrestricted_Access]);
      end ZWJ_Element;

      --------------
      -- ZWJ_List --
      --------------

      function ZWJ_List (Prev : Match) return Match is
         --  (\x{200D} zwj_element)* in possible_emoji
      begin
         return
           Code_Point (Prev, Zero_Width_Joiner)
             .Maybe_Then (ZWJ_Element'Unrestricted_Access)
             .Maybe_Then (ZWJ_List   'Unrestricted_Access);
      end ZWJ_List;

      --------------------
      -- Possible_Emoji --
      --------------------

      function Possible_Emoji (Prev : Match) return Match is
      begin
         return Prev
           .And_Then   (ZWJ_Element'Unrestricted_Access)
           .Maybe_Then (ZWJ_List   'Unrestricted_Access);
      end Possible_Emoji;

      ---------------
      -- Bad_Emoji --
      ---------------

      function Bad_Emoji (Prev : Match) return Match is
         --  This happens when Possible_Emoji didn't match and Not_An_Emoji
         --  found and emoji. We simply take the width at face value.
      begin
         if Prev.Has_Input then
            if Prev.Next in Umwi.Zero_Width_Emoji_Component then
               return Prev.Matching (Width => 0, Length => 1);
            else
               return Prev.Matching (Width (Prev.Next, Context), 1);
            end if;
         else
            return No_Match;
         end if;
      end Bad_Emoji;

      Length : Natural := 0;
      I      : Integer := Text'First;

   begin
      while I <= Text'Last loop
         declare
            Next : constant Match :=
                     Empty (Text, I, Honor_Modifier, Honor_Selector)
                     .First_Of
                       ([Emoji_To_Text 'Unrestricted_Access,
                         Possible_Emoji'Unrestricted_Access,
                         Not_An_Emoji  'Unrestricted_Access,
                         Bad_Emoji     'Unrestricted_Access]);
         begin
            if Next = No_Match then
               return Length;
               --  Something very strange has happened or we have consumed all
               --  the string.
            else
               I      := I      + Next.Eaten;
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

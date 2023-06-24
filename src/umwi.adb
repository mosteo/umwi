with Ada.Strings.UTF_Encoding.Wide_Wide_Strings;

with Umwi.Generated;
with Umwi.Properties;

package body Umwi is

   ----------------------
   -- Emoji_Properties --
   ----------------------

   function Emoji_Properties (Code_Point : WWChar) return Emoji_Property_Array
                              renames Properties.Emoji_Properties;

   -----------
   -- Width --
   -----------

   function Width (Code_Point : WWChar) return East_Asian_Width
                   renames Generated.Width;

   -----------
   -- Width --
   -----------

   function Width (Code_Point : WWChar;
                   Conf       : Configuration := Default)
                   return Widths
   is (case East_Asian_Width'(Width (Code_Point)) is
          when A      =>
            (case Conf.Context is
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

   -----------
   -- Count --
   -----------

   function Count (Text : WWString;
                   Conf : Configuration := Default)
                   return Counts
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
              (Width  => (if Conf.Honor_Emoji_Selectors
                          then 1
                          else Width (Text (Prev.I), Conf)),
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
         if Prev.Next in Properties.Emoji or else
           Prev.Next in Regional_Indicator_Emoji_Component
         then
            return No_Match;
         end if;

         while J + 1 <= Text'Last and then
           Text (J + 1) in Properties.Combining
         loop
            J := J + 1;
         end loop;

         return Prev.Matching
           (Width => (if Prev.Next in Properties.Combining
                      then
                        (if Conf.Reject_Illegal
                         then raise Encoding_Error with
                           "Combining char without preceding base char at pos:"
                         & Prev.I'Image
                         else 0)
                      else Width (Prev.Next, Conf)),
            Length => J - Prev.I + 1);
      end Not_An_Emoji;

      -------------------
      -- Flag_Sequence --
      -------------------

      function Flag_Sequence (Prev : Match) return Match is
         subtype RI is Regional_Indicator_Emoji_Component;
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
            return Prev.Matching (Width (Prev.Next, Conf), 1);
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
         if not Conf.Honor_Emoji_Modifiers then
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
            if Conf.Reject_Illegal and then Prev.Next = Terminal_Tag then
               raise Encoding_Error with
                 "Tag sequence contains only the Terminal_Tag at pos:"
                 & Prev.I'Image;
            end if;
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
           ((M_Emoji_Modifier'Unrestricted_Access,
             Presentation_Keycap'Unrestricted_Access,
             Tag_Modifier'Unrestricted_Access));
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
           ((Flag_Sequence'Unrestricted_Access,
             Emoji_Plus_Modification'Unrestricted_Access));
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
         if Conf.Reject_Illegal then
            raise Encoding_Error with
              "Found an invalid emoji sequence at pos:" & Prev.I'Image;
         end if;

         if Prev.Has_Input then
            if Prev.Next in Umwi.Zero_Width_Emoji_Component then
               return Prev.Matching (Width => 0, Length => 1);
            else
               return Prev.Matching (Width (Prev.Next, Conf), 1);
            end if;
         else
            return No_Match;
         end if;
      end Bad_Emoji;

      Count : Counts := (Points => Text'Length,
                         others => <>);
      I     : Integer := Text'First;

   begin
      while I <= Text'Last loop
         declare
            Next : constant Match :=
                     Empty (Text, I,
                            Conf.Honor_Emoji_Modifiers,
                            Conf.Honor_Emoji_Selectors)
                     .First_Of
                       ((Emoji_To_Text 'Unrestricted_Access,
                         Possible_Emoji'Unrestricted_Access,
                         Not_An_Emoji  'Unrestricted_Access,
                         Bad_Emoji     'Unrestricted_Access));
         begin
            if Next = No_Match then
               return Count;
               --  Something very strange has happened or we have consumed all
               --  the string.
            else
               I := I + Next.Eaten;

               Count.Clusters := Count.Clusters + 1;
               Count.Width    := Count.Width    + Next.Width;
            end if;
         end;
      end loop;

      return Count;
   end Count;

   -----------
   -- Count --
   -----------

   function Count (Text : UTF8_String;
                   Conf : Configuration := Default)
                   return Counts
   is
      use Ada.Strings.UTF_Encoding.Wide_Wide_Strings;
   begin
      return Count (Text => Decode (String (Text)),
                    Conf => Conf);
   end Count;

   --------------
   -- Matching --
   --------------

   function Matching (This   : Match;
                      Width  : Natural;
                      Length : Positive) return Match
   is (Length => This.Length,
       Text   => This.Text,
       Pos    => This.Pos,
       HM     => This.HM,
       HS     => This.HS,
       Eaten  => This.Eaten + Length,
       Width  => (case This.Width is
                     when 0     => Width,
                     when 2     => 2,
                     when 1     =>
                       (if This.HS and then This.Next = Presentation_Selector
                        then 2
                        else 1),
                     when others => raise Program_Error));

end Umwi;

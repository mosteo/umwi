with Ada.Strings.UTF_Encoding.Wide_Wide_Strings;
with Interfaces; use Interfaces;

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

   --------------
   -- Matching --
   --------------

   function Matching (This   : Match;
                      Width  : Natural;
                      Length : Positive) return Match
   is (Length => This.Length,
       Text   => This.Text,
       Pos    => This.Pos,
       Conf   => This.Conf,
       Eaten  => This.Eaten + Length,
       Width  => (case This.Width is
                     when 0     => Width,
                     when 2     => 2,
                     when 1     =>
                       (if This.Conf.Honor_Emoji_Selectors
                          and then This.Next = Presentation_Selector
                        then 2
                        else 1),
                     when others => raise Program_Error));

   ----------------------------------------------------------------
   -- Library-level matchers                                     --
   --                                                            --
   --  These used to be nested inside Count and closed over Text --
   --  and Conf. They have been lifted so Count and the new      --
   --  iterator share a single source of truth for cluster       --
   --  segmentation. They access Text via Prev.Text and the      --
   --  configuration via Prev.Conf.                              --
   ----------------------------------------------------------------

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

   -------------------
   -- Emoji_To_Text --
   -------------------

   function Emoji_To_Text (Prev : Match) return Match is
      --  Matches a plain emoji with text presentation selector
   begin
      if Prev.I < Prev.Text'Last
        and then Prev.Text (Prev.I) in Generated.Emoji
        and then Prev.Text (Prev.I + 1) = Text_Selector
      then
         return Prev.Matching
           (Width  => (if Prev.Conf.Honor_Emoji_Selectors
                       then 1
                       else Width (Prev.Text (Prev.I), Prev.Conf)),
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

      while J + 1 <= Prev.Text'Last and then
        Prev.Text (J + 1) in Properties.Combining
      loop
         J := J + 1;
      end loop;

      return Prev.Matching
        (Width => (if Prev.Next in Properties.Combining
                   then
                     (if Prev.Conf.Reject_Illegal
                      then raise Encoding_Error with
                        "Combining char without preceding base char at pos:"
                      & Prev.I'Image
                      else 0)
                   else Width (Prev.Next, Prev.Conf)),
         Length => J - Prev.I + 1);
   end Not_An_Emoji;

   -------------------
   -- Flag_Sequence --
   -------------------

   function Flag_Sequence (Prev : Match) return Match is
      subtype RI is Regional_Indicator_Emoji_Component;
   begin
      if Prev.I < Prev.Text'Last
        and then Prev.Text (Prev.I)     in RI
        and then Prev.Text (Prev.I + 1) in RI
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
         return Prev.Matching (Width (Prev.Next, Prev.Conf), 1);
      else
         return No_Match;
      end if;
   end M_Emoji;

   -----------------------
   -- M_Emoji_Modifier --
   -----------------------

   function M_Emoji_Modifier (Prev : Match) return Match is
   begin
      if not Prev.Conf.Honor_Emoji_Modifiers then
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
      while I <= Prev.Text'Last loop
         if Prev.Text (I) in Tag then
            Len := Len + 1;
            I   := I   + 1;
         end if;

         exit when Prev.Text (I) = Terminal_Tag
           or else Prev.Text (I) not in Tag;
      end loop;

      if Len > 0 then
         if Prev.Conf.Reject_Illegal and then Prev.Next = Terminal_Tag then
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
           .Maybe_Then (M_Enclosing_Keycap'Access);
      end if;
   end Presentation_Keycap;

   ------------------------
   -- Emoji_Modification --
   ------------------------

   function Emoji_Modification (Prev : Match) return Match is
   begin
      return Prev.First_Of
        ((M_Emoji_Modifier'Access,
          Presentation_Keycap'Access,
          Tag_Modifier'Access));
   end Emoji_Modification;

   -----------------------------
   -- Emoji_Plus_Modification --
   -----------------------------

   function Emoji_Plus_Modification (Prev : Match) return Match is
   begin
      return
        Prev
          .And_Then  (M_Emoji'Access)
          .Maybe_Then (Emoji_Modification'Access);
   end Emoji_Plus_Modification;

   -----------------
   -- ZWJ_Element --
   -----------------

   function ZWJ_Element (Prev : Match) return Match is
   begin
      return Prev.First_Of
        ((Flag_Sequence'Access,
          Emoji_Plus_Modification'Access));
   end ZWJ_Element;

   --------------
   -- ZWJ_List --
   --------------

   function ZWJ_List (Prev : Match) return Match is
      --  (\x{200D} zwj_element)* in possible_emoji
   begin
      return
        Code_Point (Prev, Zero_Width_Joiner)
          .Maybe_Then (ZWJ_Element'Access)
          .Maybe_Then (ZWJ_List'Access);
   end ZWJ_List;

   --------------------
   -- Possible_Emoji --
   --------------------

   function Possible_Emoji (Prev : Match) return Match is
   begin
      return Prev
        .And_Then   (ZWJ_Element'Access)
        .Maybe_Then (ZWJ_List'Access);
   end Possible_Emoji;

   ---------------
   -- Bad_Emoji --
   ---------------

   function Bad_Emoji (Prev : Match) return Match is
      --  This happens when Possible_Emoji didn't match and Not_An_Emoji
      --  found an emoji. We simply take the width at face value.
   begin
      if Prev.Conf.Reject_Illegal then
         raise Encoding_Error with
           "Found an invalid emoji sequence at pos:" & Prev.I'Image;
      end if;

      if Prev.Has_Input then
         if Prev.Next in Umwi.Zero_Width_Emoji_Component then
            return Prev.Matching (Width => 0, Length => 1);
         else
            return Prev.Matching (Width (Prev.Next, Prev.Conf), 1);
         end if;
      else
         return No_Match;
      end if;
   end Bad_Emoji;

   ----------------
   -- Next_Match --
   ----------------

   function Next_Match (Text : WWString;
                        From : Positive;
                        Conf : Configuration) return Match
   is
      --  Single-step cluster parse. Shared single source of truth for
      --  Count and the iterator API; the latter cache the result so each
      --  cluster is parsed exactly once.
   begin
      if From > Text'Last then
         return No_Match;
      end if;

      return Empty (Text, From, Conf).First_Of
        ((Emoji_To_Text 'Access,
          Possible_Emoji'Access,
          Not_An_Emoji  'Access,
          Bad_Emoji     'Access));
   end Next_Match;

   -----------
   -- Count --
   -----------

   function Count (Text : WWString;
                   Conf : Configuration := Default)
                   return Counts
   is
      Result : Counts := (Points => Text'Length,
                          others => <>);
      I      : Integer := Text'First;
   begin
      while I <= Text'Last loop
         declare
            M : constant Match := Next_Match (Text, I, Conf);
         begin
            if M = No_Match then
               return Result;
               --  Something very strange has happened or we have consumed
               --  all the string.
            else
               I := I + M.Eaten;

               Result.Clusters := Result.Clusters + 1;
               Result.Width    := Result.Width    + M.Width;
            end if;
         end;
      end loop;

      return Result;
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
      --  Legacy behaviour: unconditionally decode and raise on malformed
      --  input. The new grapheme-cluster iterator (Clusters / Next_Cluster
      --  on UTF8_String) is best-effort by default and honours
      --  Conf.Reject_Illegal — Count is intentionally not changed here so
      --  existing callers see byte-identical behaviour.
      return Count (Text => Decode (String (Text)),
                    Conf => Conf);
   end Count;

   -------------------
   -- Next_Cluster --
   -------------------

   function Next_Cluster (Text : WWString;
                          From : Positive;
                          Conf : Configuration := Default)
                          return Grapheme_Cluster
   is
      M : constant Match := Next_Match (Text, From, Conf);
   begin
      --  The precondition guarantees From in Text'Range so Next_Match must
      --  return a non-No_Match (Bad_Emoji is the catch-all). Defensive:
      if M = No_Match then
         raise Program_Error with
           "Umwi.Next_Cluster: no cluster at position" & From'Image;
      end if;

      return (First  => From,
              Last   => From + M.Eaten - 1,
              Points => M.Eaten,
              Width  => M.Width);
   end Next_Cluster;

   ---------------------------
   -- UTF-8 best-effort     --
   ---------------------------

   --  We implement our own UTF-8 walker so we can track byte offsets per
   --  code point and recover from malformed bytes one byte at a time, which
   --  Ada.Strings.UTF_Encoding does not offer.

   procedure Decode_UTF8_Best_Effort (Source  : UTF8_String;
                                      Reject  : Boolean;
                                      Decoded : out WWString;
                                      Starts  : out Byte_Offsets;
                                      Ends    : out Byte_Offsets;
                                      Count   : out Natural);
   --  Decoded, Starts and Ends must each have length >= Source'Length.
   --  Count is set to the number of code points produced. For 1 <= k <=
   --  Count, Starts (k) / Ends (k) are the first and last byte indices in
   --  Source of the k-th code point.

   procedure Decode_UTF8_Best_Effort (Source  : UTF8_String;
                                      Reject  : Boolean;
                                      Decoded : out WWString;
                                      Starts  : out Byte_Offsets;
                                      Ends    : out Byte_Offsets;
                                      Count   : out Natural)
   is
      I : Integer := Source'First;
      K : Natural := 0;

      procedure Emit_Replacement is
      begin
         K := K + 1;
         Decoded (Decoded'First + K - 1) := WWChar'Val (16#FFFD#);
         Starts  (Starts'First  + K - 1) := I;
         Ends    (Ends'First    + K - 1) := I;
         I := I + 1;
      end Emit_Replacement;
   begin
      while I <= Source'Last loop
         declare
            B0    : constant Unsigned_32 :=
                      Unsigned_32 (Character'Pos (Source (I)));
            Len   : Natural := 0;
            CP    : Unsigned_32 := 0;
            Valid : Boolean := True;
         begin
            if B0 < 16#80# then
               Len := 1;
               CP  := B0;
            elsif (B0 and 16#E0#) = 16#C0# then
               Len := 2;
               CP  := B0 and 16#1F#;
            elsif (B0 and 16#F0#) = 16#E0# then
               Len := 3;
               CP  := B0 and 16#0F#;
            elsif (B0 and 16#F8#) = 16#F0# then
               Len := 4;
               CP  := B0 and 16#07#;
            else
               Valid := False;
            end if;

            if Valid and then I + Len - 1 <= Source'Last then
               for J in 1 .. Len - 1 loop
                  declare
                     CB : constant Unsigned_32 :=
                            Unsigned_32 (Character'Pos (Source (I + J)));
                  begin
                     if (CB and 16#C0#) /= 16#80# then
                        Valid := False;
                        exit;
                     end if;
                     CP := CP * 64 + (CB and 16#3F#);
                  end;
               end loop;

               if Valid then
                  case Len is
                     when 2 =>
                        if CP < 16#80# then
                           Valid := False;
                        end if;
                     when 3 =>
                        if CP < 16#800# then
                           Valid := False;
                        end if;
                     when 4 =>
                        if CP < 16#10000# or else CP > 16#10FFFF# then
                           Valid := False;
                        end if;
                     when others => null;
                  end case;
                  if CP in 16#D800# .. 16#DFFF# then
                     Valid := False;
                  end if;
               end if;
            elsif Valid then
               --  Truncated multi-byte sequence at end of input
               Valid := False;
            end if;

            if Valid then
               K := K + 1;
               Decoded (Decoded'First + K - 1) := WWChar'Val (Natural (CP));
               Starts  (Starts'First  + K - 1) := I;
               Ends    (Ends'First    + K - 1) := I + Len - 1;
               I := I + Len;
            else
               if Reject then
                  raise Encoding_Error with
                    "Invalid UTF-8 byte at position" & I'Image;
               end if;
               Emit_Replacement;
            end if;
         end;
      end loop;

      Count := K;
   end Decode_UTF8_Best_Effort;

   ----------------------
   -- Next_Cluster (UTF-8) --
   ----------------------

   function Next_Cluster (Text : UTF8_String;
                          From : Positive;
                          Conf : Configuration := Default)
                          return UTF8_Grapheme_Cluster
   is
      V : constant UTF8_Cluster_View := Clusters (Text, Conf);
      C : UTF8_Cluster_Cursor := First (V);
   begin
      while Has_Element (V, C) loop
         declare
            G : constant UTF8_Grapheme_Cluster := Element (V, C);
         begin
            if G.First_Byte >= From then
               return G;
            end if;
            exit when G.Last_Byte >= Text'Last;
         end;
         C := Next (V, C);
      end loop;

      raise Program_Error with
        "Umwi.Next_Cluster: no cluster at byte" & From'Image;
   end Next_Cluster;

   --------------
   -- Clusters --
   --------------

   function Clusters (Text : WWString;
                      Conf : Configuration := Default)
                      return Cluster_View
   is
   begin
      return (Text => Text'Unrestricted_Access,
              Conf => Conf);
   end Clusters;

   --------------
   -- Clusters --
   --------------

   function Clusters (Text : UTF8_String;
                      Conf : Configuration := Default)
                      return UTF8_Cluster_View
   is
      Max     : constant Natural := Text'Length;
      Buf_Txt : WWString     (1 .. Max);
      Buf_Beg : Byte_Offsets (1 .. Max);
      Buf_End : Byte_Offsets (1 .. Max);
      N       : Natural;
   begin
      Decode_UTF8_Best_Effort (Source  => Text,
                               Reject  => Conf.Reject_Illegal,
                               Decoded => Buf_Txt,
                               Starts  => Buf_Beg,
                               Ends    => Buf_End,
                               Count   => N);

      return (Points  => N,
              Decoded => Buf_Txt (1 .. N),
              Starts  => Buf_Beg (1 .. N),
              Ends    => Buf_End (1 .. N),
              Conf    => Conf);
   end Clusters;

   ---------------------------------
   -- Iterator helpers (WWString) --
   ---------------------------------

   function Build_WW_Cursor (T    : WWString;
                             From : Positive;
                             Conf : Configuration) return Cluster_Cursor
   is
      M : constant Match := Next_Match (T, From, Conf);
   begin
      if M = No_Match then
         return (Has_Cur => False, others => <>);
      end if;
      return (Has_Cur => True,
              Cur     => (First  => From,
                          Last   => From + M.Eaten - 1,
                          Points => M.Eaten,
                          Width  => M.Width));
   end Build_WW_Cursor;

   -----------
   -- First --
   -----------

   function First (V : Cluster_View) return Cluster_Cursor is
      T : WWString renames V.Text.all;
   begin
      if T'Length = 0 then
         return (Has_Cur => False, others => <>);
      end if;
      return Build_WW_Cursor (T, T'First, V.Conf);
   end First;

   -----------------
   -- Has_Element --
   -----------------

   function Has_Element (V : Cluster_View; C : Cluster_Cursor) return Boolean
   is
      pragma Unreferenced (V);
   begin
      return C.Has_Cur;
   end Has_Element;

   ----------
   -- Next --
   ----------

   function Next (V : Cluster_View; C : Cluster_Cursor) return Cluster_Cursor
   is
      T : WWString renames V.Text.all;
   begin
      if not C.Has_Cur then
         return C;
      end if;
      if C.Cur.Last >= T'Last then
         return (Has_Cur => False, others => <>);
      end if;
      return Build_WW_Cursor (T, C.Cur.Last + 1, V.Conf);
   end Next;

   -------------
   -- Element --
   -------------

   function Element (V : Cluster_View; C : Cluster_Cursor)
                     return Grapheme_Cluster
   is
      pragma Unreferenced (V);
   begin
      return C.Cur;
   end Element;

   ---------------------------------
   -- Iterator helpers (UTF-8)    --
   ---------------------------------

   function Build_UTF8_Cursor (V          : UTF8_Cluster_View;
                               From_Point : Positive)
                               return UTF8_Cluster_Cursor
   is
      M : constant Match := Next_Match (V.Decoded, From_Point, V.Conf);
   begin
      if M = No_Match then
         return (Has_Cur => False, others => <>);
      end if;

      declare
         Last_Point : constant Positive := From_Point + M.Eaten - 1;
         First_Byte : constant Positive := V.Starts (From_Point);
         Last_Byte  : constant Positive := V.Ends   (Last_Point);
      begin
         return (Has_Cur    => True,
                 Last_Point => Last_Point,
                 Cur        => (First_Byte => First_Byte,
                                Last_Byte  => Last_Byte,
                                Points     => M.Eaten,
                                Width      => M.Width));
      end;
   end Build_UTF8_Cursor;

   -----------
   -- First --
   -----------

   function First (V : UTF8_Cluster_View) return UTF8_Cluster_Cursor is
   begin
      if V.Points = 0 then
         return (Has_Cur => False, others => <>);
      end if;
      return Build_UTF8_Cursor (V, 1);
   end First;

   -----------------
   -- Has_Element --
   -----------------

   function Has_Element (V : UTF8_Cluster_View; C : UTF8_Cluster_Cursor)
                         return Boolean
   is
      pragma Unreferenced (V);
   begin
      return C.Has_Cur;
   end Has_Element;

   ----------
   -- Next --
   ----------

   function Next (V : UTF8_Cluster_View; C : UTF8_Cluster_Cursor)
                  return UTF8_Cluster_Cursor
   is
   begin
      if not C.Has_Cur then
         return C;
      end if;
      if C.Last_Point >= V.Points then
         return (Has_Cur => False, others => <>);
      end if;
      return Build_UTF8_Cursor (V, C.Last_Point + 1);
   end Next;

   -------------
   -- Element --
   -------------

   function Element (V : UTF8_Cluster_View; C : UTF8_Cluster_Cursor)
                     return UTF8_Grapheme_Cluster
   is
      pragma Unreferenced (V);
   begin
      return C.Cur;
   end Element;

end Umwi;

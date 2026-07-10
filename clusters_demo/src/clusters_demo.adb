with Ada.Strings.UTF_Encoding.Wide_Wide_Strings;
use  Ada.Strings.UTF_Encoding.Wide_Wide_Strings;
with Ada.Text_IO;    use Ada.Text_IO;
with Ada.Wide_Wide_Text_IO;
with Ada.Exceptions; use Ada.Exceptions;

with Umwi;

procedure Clusters_Demo is

   use type Umwi.UTF8_String;

   --  Self-checking driver for the grapheme-cluster iterator API
   --  (Next_Cluster / Clusters / Cluster_View / UTF8_Cluster_View).
   --
   --  Following umwi's executable-test convention (see demo/), every
   --  invariant is asserted by raising Program_Error on mismatch. The
   --  program exits successfully (status 0) only when every check passes.

   ----------
   -- Fail --
   ----------

   procedure Fail (Msg : String) is
   begin
      raise Program_Error with Msg;
   end Fail;

   --  Compact alias for code-point literals
   function CP (P : Natural) return Umwi.WWChar
   is (Umwi.WWChar'Val (P));

   --  Encode + convert to Umwi.UTF8_String, disambiguating the overloaded
   --  Encode (which has both UTF_8_String and UTF_16_Wide_String returns).
   function To_U8 (S : Umwi.WWString) return Umwi.UTF8_String is
      Buf : constant String := Encode (S);
   begin
      return Umwi.UTF8_String (Buf);
   end To_U8;

   type Width_Array is array (Positive range <>) of Natural;

   --------------
   -- Check_WW --
   --------------

   procedure Check_WW
     (Label  : String;
      Text   : Umwi.WWString;
      Widths : Width_Array;
      Conf   : Umwi.Configuration := Umwi.Default)
   is
      Total_Width    : Natural := 0;
      Total_Points   : Natural := 0;
      Total_Clusters : Natural := 0;
      Last_End       : Integer := Text'First - 1;
      K              : Natural := 0;
   begin
      for C of Umwi.Clusters (Text, Conf) loop
         K := K + 1;

         if K > Widths'Length then
            Fail (Label & ": more clusters than expected ("
                  & K'Image & " > " & Widths'Length'Image & ")");
         end if;

         if C.Width /= Widths (Widths'First + K - 1) then
            Fail (Label & ": cluster" & K'Image
                  & " width" & C.Width'Image
                  & " /= expected"
                  & Widths (Widths'First + K - 1)'Image);
         end if;

         if Integer (C.First) /= Last_End + 1 then
            Fail (Label & ": cluster" & K'Image
                  & " starts at" & C.First'Image
                  & " expected" & Integer'Image (Last_End + 1));
         end if;

         if C.Points /= C.Last - C.First + 1 then
            Fail (Label & ": cluster" & K'Image & " Points mismatch");
         end if;

         Total_Width    := Total_Width + C.Width;
         Total_Points   := Total_Points + C.Points;
         Total_Clusters := Total_Clusters + 1;
         Last_End       := C.Last;
      end loop;

      if K /= Widths'Length then
         Fail (Label & ": got" & K'Image
               & " clusters, expected" & Widths'Length'Image);
      end if;

      declare
         Agg : constant Umwi.Counts := Umwi.Count (Text, Conf);
      begin
         if Total_Width /= Agg.Width then
            Fail (Label & ": Sum.Width"
                  & Total_Width'Image
                  & " /= Count.Width" & Agg.Width'Image);
         end if;
         if Total_Points /= Agg.Points then
            Fail (Label & ": Sum.Points"
                  & Total_Points'Image
                  & " /= Count.Points" & Agg.Points'Image);
         end if;
         if Total_Clusters /= Agg.Clusters then
            Fail (Label & ": Sum.Clusters"
                  & Total_Clusters'Image
                  & " /= Count.Clusters" & Agg.Clusters'Image);
         end if;
      end;

      Put_Line ("  OK  WW    " & Label);
   end Check_WW;

   ----------------
   -- Check_UTF8 --
   ----------------

   procedure Check_UTF8
     (Label      : String;
      Text       : Umwi.UTF8_String;
      Conf       : Umwi.Configuration := Umwi.Default;
      Valid_UTF8 : Boolean            := True)
   is
      Total_Width    : Natural := 0;
      Total_Points   : Natural := 0;
      Total_Clusters : Natural := 0;
      Last_End       : Integer := Text'First - 1;
      Concat         : Umwi.UTF8_String (1 .. Text'Length);
      Concat_Last    : Natural := 0;
   begin
      for C of Umwi.Clusters (Text, Conf) loop
         if Integer (C.First_Byte) /= Last_End + 1 then
            Fail (Label & ": UTF-8 byte gap at"
                  & C.First_Byte'Image);
         end if;

         Total_Width    := Total_Width + C.Width;
         Total_Points   := Total_Points + C.Points;
         Total_Clusters := Total_Clusters + 1;

         declare
            Span : constant Umwi.UTF8_String :=
                     Text (C.First_Byte .. C.Last_Byte);
         begin
            Concat (Concat_Last + 1 .. Concat_Last + Span'Length) := Span;
            Concat_Last := Concat_Last + Span'Length;
         end;
         Last_End := C.Last_Byte;
      end loop;

      --  Byte round-trip
      if Concat_Last /= Text'Length
        or else Concat (1 .. Concat_Last) /= Text
      then
         Fail (Label & ": UTF-8 byte round-trip failed");
      end if;

      --  When the input is valid UTF-8, the iterator's totals must agree
      --  with Count (which raises on malformed input regardless of
      --  Conf.Reject_Illegal).
      if Valid_UTF8 then
         declare
            Agg : constant Umwi.Counts := Umwi.Count (Text, Conf);
         begin
            if Total_Width /= Agg.Width then
               Fail (Label & ": UTF-8 Sum.Width"
                     & Total_Width'Image
                     & " /= Count.Width" & Agg.Width'Image);
            end if;
            if Total_Clusters /= Agg.Clusters then
               Fail (Label & ": UTF-8 Sum.Clusters"
                     & Total_Clusters'Image
                     & " /= Count.Clusters" & Agg.Clusters'Image);
            end if;
         end;
      end if;

      Put_Line ("  OK  UTF8  " & Label);
   end Check_UTF8;

   --  Shared fixture: text with ASCII, an emoji ZWJ family, and CJK.
   Mixed_Text : constant Umwi.WWString :=
                  "Hello "
                  & CP (16#1F468#) & Umwi.Zero_Width_Joiner
                  & CP (16#1F469#) & Umwi.Zero_Width_Joiner
                  & CP (16#1F467#)
                  & " " & "馬鹿";

   --  Strict default config (no special honoring).
   Conf_Narrow : constant Umwi.Configuration := (others => <>);

   --  Narrow with selectors honored.
   Conf_Narrow_Sel : constant Umwi.Configuration :=
                       (Honor_Emoji_Selectors => True, others => <>);

   --  Wide context (ambiguous CJK takes 2 cells).
   Conf_Wide : constant Umwi.Configuration :=
                 (Context => Umwi.Wide, others => <>);

begin
   New_Line;
   Put_Line ("=== Umwi grapheme-cluster iterator self-checks ===");
   New_Line;

   -------------------------
   -- Targeted WW fixtures --
   -------------------------

   Check_WW ("empty",     "",     Widths => (1 .. 0 => 0));
   Check_WW ("ascii",     "abcd", Widths => (1, 1, 1, 1));
   Check_WW ("latin1",    "a·c·", Widths => (1, 1, 1, 1));

   --  Combining diacritic on a base char → one cluster, width 1.
   Check_WW ("combining acute",
             "a" & CP (16#0301#),
             Widths => (1 => 1));

   --  Regional indicator pair (ES flag) → one cluster, width 2.
   Check_WW ("ES flag",
             CP (16#1F1EA#) & CP (16#1F1F8#),
             Widths => (1 => 2));

   --  ZWJ family: man + ZWJ + woman + ZWJ + girl → one cluster, width 2.
   Check_WW ("zwj family",
             CP (16#1F468#) & Umwi.Zero_Width_Joiner
             & CP (16#1F469#) & Umwi.Zero_Width_Joiner
             & CP (16#1F467#),
             Widths => (1 => 2));

   --  Skin-tone modified person → one cluster, width 2.
   Check_WW ("skin tone",
             CP (16#1F9D1#) & CP (16#1F3FB#),
             Widths => (1 => 2));

   --  Keycap sequence "9️⃣" with presentation selectors honored:
   --  Umwi parses base+VS16 as one cluster (width 2) and the trailing
   --  U+20E3 as a separate combining cluster (width 0).
   Check_WW ("keycap (HS=True)",
             CP (16#0039#) & Umwi.Presentation_Selector & CP (16#20E3#),
             Widths => (2, 0),
             Conf   => Conf_Narrow_Sel);

   --  CJK wide chars.
   Check_WW ("kanji", "馬鹿", Widths => (2, 2));

   --  Ambiguous-width fixture: BLACK STAR U+2605 has East_Asian_Width = A.
   Check_WW ("ambiguous narrow",
             "★",
             Widths => (1 => 1),
             Conf   => Conf_Narrow);

   Check_WW ("ambiguous wide",
             "★",
             Widths => (1 => 2),
             Conf   => Conf_Wide);

   -----------------------------------
   -- Sum invariants on Mixed_Text  --
   -----------------------------------

   declare
      procedure Sum_Check (Label : String;
                           Conf  : Umwi.Configuration)
      is
         W : Natural := 0;
         P : Natural := 0;
         N : Natural := 0;
      begin
         for C of Umwi.Clusters (Mixed_Text, Conf) loop
            W := W + C.Width;
            P := P + C.Points;
            N := N + 1;
         end loop;
         declare
            Agg : constant Umwi.Counts := Umwi.Count (Mixed_Text, Conf);
         begin
            if W /= Agg.Width
              or else P /= Agg.Points
              or else N /= Agg.Clusters
            then
               Fail (Label & ": sums /= Count");
            end if;
         end;
         Put_Line ("  OK  WW    " & Label & " (sums match Count)");
      end Sum_Check;
   begin
      Sum_Check ("mixed narrow",     Conf_Narrow);
      Sum_Check ("mixed narrow+sel", Conf_Narrow_Sel);
      Sum_Check ("mixed wide",       Conf_Wide);
   end;

   --------------------------
   -- UTF-8 byte round-trip --
   --------------------------

   Check_UTF8 ("ascii utf8",
               To_U8 ("abcd"));

   Check_UTF8 ("flag utf8",
               To_U8 (CP (16#1F1EA#) & CP (16#1F1F8#)));

   Check_UTF8 ("zwj family utf8",
               To_U8 (CP (16#1F468#) & Umwi.Zero_Width_Joiner
                          & CP (16#1F469#) & Umwi.Zero_Width_Joiner
                          & CP (16#1F467#)));

   Check_UTF8 ("skin tone utf8",
               To_U8 (CP (16#1F9D1#) & CP (16#1F3FB#)));

   Check_UTF8 ("keycap utf8",
               To_U8 (CP (16#0039#) & Umwi.Presentation_Selector
                          & CP (16#20E3#)),
               Conf => Conf_Narrow_Sel);

   Check_UTF8 ("cjk utf8",
               To_U8 ("馬鹿"));

   Check_UTF8 ("mixed narrow utf8",
               To_U8 (Mixed_Text), Conf_Narrow);

   Check_UTF8 ("mixed wide utf8",
               To_U8 (Mixed_Text), Conf_Wide);

   ----------------------------------------------
   -- Malformed UTF-8: best-effort vs strict   --
   ----------------------------------------------

   declare
      Bad : constant Umwi.UTF8_String :=
              Umwi.UTF8_String
                (String'('a' & Character'Val (16#FF#) & 'b'));
   begin
      --  Best effort (default): byte round-trip must still hold, and
      --  we expect three width-1 clusters.
      Check_UTF8 ("malformed best-effort", Bad, Valid_UTF8 => False);

      declare
         Tot : Natural := 0;
         N   : Natural := 0;
      begin
         for C of Umwi.Clusters (Bad) loop
            Tot := Tot + C.Width;
            N   := N + 1;
         end loop;
         if N /= 3 or else Tot /= 3 then
            Fail ("malformed best-effort: expected 3 clusters / width 3,"
                  & " got" & N'Image & " /" & Tot'Image);
         end if;
         Put_Line ("  OK  UTF8  malformed best-effort: 3 width-1 clusters");
      end;

      --  Strict: must raise Encoding_Error.
      declare
         Strict : constant Umwi.Configuration :=
                    (Reject_Illegal => True, others => <>);
      begin
         declare
            V : constant Umwi.UTF8_Cluster_View :=
                  Umwi.Clusters (Bad, Strict);
            pragma Unreferenced (V);
         begin
            Fail ("malformed strict: expected Encoding_Error");
         end;
      exception
         when E : Umwi.Encoding_Error =>
            Put_Line ("  OK  UTF8  malformed strict raised: "
                      & Exception_Message (E));
      end;
   end;

   ------------------------------
   -- Next_Cluster spot-checks  --
   ------------------------------

   declare
      G : constant Umwi.Grapheme_Cluster :=
            Umwi.Next_Cluster ("abc", 1);
   begin
      if G.First /= 1 or else G.Last /= 1
        or else G.Width /= 1 or else G.Points /= 1
      then
         Fail ("Next_Cluster WW basic");
      end if;
      Put_Line ("  OK  WW    Next_Cluster basic");
   end;

   declare
      Flag : constant Umwi.WWString :=
               CP (16#1F1EA#) & CP (16#1F1F8#);
      G : constant Umwi.Grapheme_Cluster :=
            Umwi.Next_Cluster (Flag, 1);
   begin
      if G.First /= 1 or else G.Last /= 2
        or else G.Width /= 2 or else G.Points /= 2
      then
         Fail ("Next_Cluster WW flag: First/Last/Width/Points = ("
               & G.First'Image & "," & G.Last'Image
               & "," & G.Width'Image & "," & G.Points'Image & ")");
      end if;
      Put_Line ("  OK  WW    Next_Cluster flag");
   end;

   declare
      U : constant Umwi.UTF8_String := To_U8 ("a馬");
      G1, G2 : Umwi.UTF8_Grapheme_Cluster;
   begin
      G1 := Umwi.Next_Cluster (U, U'First);
      if G1.First_Byte /= U'First
        or else G1.Width /= 1
        or else G1.Points /= 1
      then
         Fail ("Next_Cluster UTF8 first");
      end if;
      G2 := Umwi.Next_Cluster (U, G1.Last_Byte + 1);
      if G2.First_Byte /= G1.Last_Byte + 1
        or else G2.Width /= 2
        or else G2.Last_Byte /= U'Last
      then
         Fail ("Next_Cluster UTF8 second");
      end if;
      Put_Line ("  OK  UTF8  Next_Cluster two-step walk");
   end;

   New_Line;
   Put_Line ("All grapheme-cluster iterator self-checks passed.");
end Clusters_Demo;

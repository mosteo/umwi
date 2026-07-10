package Umwi with Preelaborate is

   --  NOTE: this library isn't robust against illegal unicode sequences.
   --  In those cases it will likely report a length different from what
   --  is actually printed to the console, as interpretation will be open.

   type Contexts is (Narrow, Wide);
   --  In Narrow contexts, an ambiguous symbol will use 1 slot. This is the
   --  case of a Western locale. In a CJK locale, an ambiguous symbol would
   --  typically use 2 slots, as the rest of CJK symbols.

   type Configuration is record

      Context : Contexts := Narrow;

      Honor_Emoji_Selectors : Boolean := False;
      --  To match wcwidth behavior on Linux, used by most programs and
      --  terminals, set this to false. To be Unicode strict, set to True. This
      --  allows to force a 1-wide b/w emoji into a 2-wide color emoji and vice
      --  versa.

      Honor_Emoji_Modifiers : Boolean := True;
      --  These change the tone or combine with a previous emoji base. Not all
      --  fonts/terminals do these combinations, and instead show the skin tone
      --  as a square, or don't group the emojis as intended.

      Reject_Illegal : Boolean := False;
      --  When true, instead of doing a best-effort attempt at guessing how
      --  some bad combos will display (e.g., a keycap without preceding
      --  presentation selector, or inexistent country codes, or half a
      --  country code), just raise Encoding_Error.

      --  Composing Unicode code points are always considered to be of width
      --  0 (they combine with a previous base character to form a graphene
      --  cluster, e.j. 'a' + '´' = 'á'
   end record;

   package Defaults is

      Default : Configuration := (others => <>);
      --  Default configuration for the package overridable in individual
      --  calls, or to be directly modified here.

      Linux   : constant Configuration := (others => <>);

      Strict  : constant Configuration := (Context => Narrow,
                                           others  => True);

   end Defaults;

   Default : Configuration renames Defaults.Default;

   Encoding_Error : exception;
   --  Raised by the subprograms below that take a string when there's some
   --  unexpected combo like an emoji modifier without a precedent emoji base.

   type UTF8_String is new String;

   subtype WWChar   is Wide_Wide_Character;
   subtype WWString is Wide_Wide_String;

   type East_Asian_Width is
     (A,  -- Ambiguous. Can take either 1 or 2 slots depending on context.
      F,  -- Fullwidth. Occupies 2 slots.
      H,  -- Halfwidth. Occupies 1 slot.
      N,  -- Neutral. Occupies 1 slot.
      Na, -- Narrow. Occupies 1 slot.
      W   -- Wide. Occupies 2 slots.
     );
   --  Unicode equates 1/2 em to 1 slot and 2 em to 2 slots.
   --  https://www.unicode.org/reports/tr11/
   --  https://www.unicode.org/reports/tr44/

   subtype Widths is Positive range 1 .. 2;

   type All_Emoji_Properties is
     (Emoji,
      Emoji_Presentation,
      Emoji_Modifier_Base,
      Emoji_Modifier,
      Emoji_Component,
      Extended_Pictographic);
   --  https://www.unicode.org/reports/tr51/
   --  https://unicode.org/Public/15.0.0/ucd/emoji/emoji-data.txt

   --  An Emoji Presentation Sequence should use 2 slots no mater what their
   --  East_Asian_Width is, see in https://www.unicode.org/reports/tr11/
   --  This is an Emoji_Presentation symbol plus either 16#FE0E# (text mode,
   --  black&white, 0.5em) or 16#FE0E# (presentation mode, colorful, 1em).
   --  If omitted, a symbol with the Emoji_Presentation property should use
   --  the latter. Not all emojis can be forced into either mode, see the
   --  emoji-variation-sequences.txt Unicode file.

   --  NOTE: at present, Ubuntu terminals do not honor the Text/Presentation
   --  marker for actual width, only for the text/presentation mode. It will
   --  use the proper symbol, but it will always take the width announced by
   --  its East_Asian_Width or Emoji_Presentation property.

   --  I'm not aware of any non-wide with Emoji_Presentation symbol.

   type Emoji_Property_Array is array (All_Emoji_Properties) of Boolean;

   Text_Selector         : constant WWChar := WWChar'Val (16#FE0E#);
   --  This one has all Emoji properties as False
   Presentation_Selector : constant WWChar := WWChar'Val (16#FE0F#);
   --  This one is Emoji_Component

   Zero_Width_Joiner     : constant WWChar := WWChar'Val (16#200D#);
   --  This indicates that the next emoji should be combined with the precedent
   --  one. Not all combos are legal, but we will consider them as so.

   Enclosing_Keycap      : constant WWChar := WWChar'Val (16#2E03#);
   --  Box around previous char to simulate a keyboard key

   subtype Selectors is WWChar range Text_Selector .. Presentation_Selector;

   subtype Combining_Blocks is WWChar with Static_Predicate =>
     Combining_Blocks in
       WWChar'Val (16#0300#) .. WWChar'Val (16#036F#) -- diacritic marks
     | WWChar'Val (16#1AB0#) .. WWChar'Val (16#1AFF#) -- diacritic marks ext
     | WWChar'Val (16#1DC0#) .. WWChar'Val (16#1DFF#) -- diacritic marks suppl
     | WWChar'Val (16#20D0#) .. WWChar'Val (16#20FF#) -- diacritic marks symbol
     | WWChar'Val (16#FE20#) .. WWChar'Val (16#FE2F#) -- half marks
   ;
   --  These aren't all the combining characters; see Umwi.Properties.Combining

   subtype Regional_Indicator_Emoji_Component is WWChar range
     WWChar'Val (16#1F1E6#) .. WWChar'Val (16#1F1FF#);
   --  These form country codes that result in flags

   subtype Tag is WWChar range
     WWChar'Val (16#E0020#) .. WWChar'Val (16#E007F#);

   Terminal_Tag : constant WWChar := WWChar'Val (16#E007F#);

   subtype Zero_Width_Emoji_Component is WWChar with Static_Predicate =>
     Zero_Width_Emoji_Component in Zero_Width_Joiner | Tag
   ;
   --  Some emoji components without a preceding emoji are valid chars (e.g.
   --  '#') but others never have width no matter the preceding thing

   ----------------
   -- Properties --
   ----------------

   --  See Umwi.Properties for types that use information generated from
   --  Unicode specification documents.

   -----------------
   -- Subprograms --
   -----------------

   function Emoji_Properties (Code_Point : WWChar) return Emoji_Property_Array;
   --  See also Umwi.Emoji

   function Width (Code_Point : WWChar) return East_Asian_Width;
   --  See also Umwi.East_Asian_Width

   function Width (Code_Point : WWChar;
                   Conf       : Configuration := Default)
                   return Widths;

   type Counts is record
      Points   : Natural := 0; -- code points, same as WWString'Length
      Clusters : Natural := 0; -- grapheme clusters, "separate" symbols
      Width    : Natural := 0; -- width in fixed-pitch font columns, 2*ems
   end record;

   function Count (Text : WWString;
                   Conf : Configuration := Default)
                   return Counts;
   --  This is Width in the sense of fixed-width font slots used. Takes
   --  into account grapheme clusters (considered as one/two slots according
   --  to the base code point East Asian Width). Implements the EBNF at
   --  https://unicode.org/reports/tr51/#EBNF_and_Regex. Displaying engines
   --  that deviate from that EBNF will result in wrong lengths. In addition,
   --  when Honor_Selector, two-point sequences of emoji+selector are
   --  considered. If not Honor_Modifier, the EBNF will not combine skin tones
   --  (Emoji_Modifier code points) and break the sequence at that point. An
   --  emoji matched by the EBNF, no matter how long in actual unicode points,
   --  will occupy 2 slots.

   function Count (Text : UTF8_String;
                   Conf : Configuration := Default)
                   return Counts;
   --  This is Width in the sense of fixed-width font slots used. Takes
   --  into account grapheme clusters (considered as one/two slots according
   --  to the base code point East Asian Width). Implements the EBNF at
   --  https://unicode.org/reports/tr51/#EBNF_and_Regex. Displaying engines
   --  that deviate from that EBNF will result in wrong lengths. In addition,
   --  when Honor_Selector, two-point sequences of emoji+selector are
   --  considered. If not Honor_Modifier, the EBNF will not combine skin tones
   --  (Emoji_Modifier code points) and break the sequence at that point. An
   --  emoji matched by the EBNF, no matter how long in actual unicode points,
   --  will occupy 2 slots.
   --
   --  NOTE: this overload raises Encoding_Error on any
   --  malformed UTF-8 regardless of Conf.Reject_Illegal (legacy behaviour,
   --  preserved for backward compatibility). The grapheme cluster iterator
   --  below (Clusters / Next_Cluster on UTF8_String) is best-effort by
   --  default and only raises when Conf.Reject_Illegal is True.

   --------------------------------
   -- Grapheme cluster iteration --
   --------------------------------

   --  A grapheme cluster is one user-perceived "character" (a base code point
   --  plus any combining marks, a ZWJ sequence emoji, a flag, a keycap, etc.).
   --  See https://unicode.org/reports/tr29/.

   type Grapheme_Cluster is record
      First  : Positive; -- first code-point index in the source WWString
      Last   : Positive; -- last  code-point index (inclusive)
      Points : Positive; -- number of code points covered (Last - First + 1)
      Width  : Natural;  -- display columns (typically 0, 1 or 2)
   end record;

   type UTF8_Grapheme_Cluster is record
      First_Byte : Positive; -- first byte index in the source UTF8_String
      Last_Byte  : Positive; -- last  byte index (inclusive)
      Points     : Positive; -- number of code points covered
      Width      : Natural;  -- display columns
   end record;

   function Next_Cluster (Text : WWString;
                          From : Positive;
                          Conf : Configuration := Default)
                          return Grapheme_Cluster
     with Pre => From in Text'Range;

   function Next_Cluster (Text : UTF8_String;
                          From : Positive;
                          Conf : Configuration := Default)
                          return UTF8_Grapheme_Cluster
     with Pre => From in Text'Range;
   --  Parse a single grapheme cluster starting at the given position.
   --
   --  WWString overload: From is a code-point index into Text. The returned
   --  cluster uses the original index basis of Text.
   --
   --  UTF8_String overload: From is a byte index. When Conf.Reject_Illegal is
   --  False (default), malformed UTF-8 is handled best-effort: every byte
   --  that does not decode to a valid code point is treated as a single-byte
   --  cluster of width 1, so iteration always makes progress. When
   --  Conf.Reject_Illegal is True, Encoding_Error is raised on any malformed
   --  input.
   --
   --  Note: Count (UTF8_String) above raises Encoding_Error on malformed
   --  UTF-8 even with Reject_Illegal => False — that is legacy behaviour,
   --  intentionally preserved, not a bug.

   type Cluster_Cursor      is private;
   type UTF8_Cluster_Cursor is private;

   type Cluster_View (<>) is private
     with Iterable => (First       => First,
                       Next        => Next,
                       Has_Element => Has_Element,
                       Element     => Element);

   type UTF8_Cluster_View (<>) is private
     with Iterable => (First       => First,
                       Next        => Next,
                       Has_Element => Has_Element,
                       Element     => Element);

   function Clusters (Text : WWString;
                      Conf : Configuration := Default)
                      return Cluster_View;

   function Clusters (Text : UTF8_String;
                      Conf : Configuration := Default)
                      return UTF8_Cluster_View;
   --  Iterable views suitable for "for ... of" loops:
   --
   --     for C of Clusters (Some_WWString)    loop ...
   --        --  yields Grapheme_Cluster
   --     for C of Clusters (Some_UTF8_String) loop ...
   --        --  yields UTF8_Grapheme_Cluster
   --
   --  Same malformed-UTF-8 contract as Next_Cluster: best-effort by default,
   --  strict when Conf.Reject_Illegal is True.
   --
   --  The text passed to Clusters must outlive the iteration (the view holds
   --  the decoded representation by value; the WWString overload holds a
   --  reference to the original text).

   function First (V : Cluster_View) return Cluster_Cursor;
   function Has_Element (V : Cluster_View; C : Cluster_Cursor)
                         return Boolean;
   function Next (V : Cluster_View; C : Cluster_Cursor) return Cluster_Cursor;
   function Element (V : Cluster_View; C : Cluster_Cursor)
                     return Grapheme_Cluster;

   function First (V : UTF8_Cluster_View) return UTF8_Cluster_Cursor;
   function Has_Element (V : UTF8_Cluster_View; C : UTF8_Cluster_Cursor)
                         return Boolean;
   function Next (V : UTF8_Cluster_View; C : UTF8_Cluster_Cursor)
                  return UTF8_Cluster_Cursor;
   function Element (V : UTF8_Cluster_View; C : UTF8_Cluster_Cursor)
                     return UTF8_Grapheme_Cluster;

private

   --  Helper type to implement the recursive parser

   type Match (Length : Natural) is tagged record
      Text  : WWString (1 .. Length);
      Pos   : Positive;
      Eaten : Natural;
      Width : Natural; -- Actual visible width
      Conf  : Configuration;
   end record;

   type Matcher is access function (Prev : Match) return Match;

   -------
   -- I --
   -------

   function I (This : Match) return Natural
   is (This.Pos + This.Eaten);

   ---------------
   -- Has_Input --
   ---------------

   function Has_Input (This : Match) return Boolean
   is (This.I <= This.Text'Last);

   ----------
   -- Next --
   ----------

   function Next (This : Match) return WWChar
   is (This.Text (This.I));

   -----------
   -- Empty --
   -----------

   function Empty (Input : WWString;
                   Start : Positive;
                   Conf  : Configuration)
                   return Match
   is (Length => Input'Length,
       Pos    => Start - Input'First + 1,
       Eaten  => 0,
       Text   => Input,
       Width  => 0,
       Conf   => Conf);
   --  To be used at the very beginning of matching. Pos is normalised so
   --  that matchers can always index Text from 1; the caller still drives
   --  outer iteration in the original index basis using Eaten.

   --------------
   -- No_Match --
   --------------

   function No_Match return Match
   is (Length => 0,
       Pos   => 1,
       Eaten => 0,
       Text => "",
       Width => 0,
       Conf  => (others => <>));
   --  To be used after matching has started

   --------------
   -- Matching --
   --------------

   function Matching (This   : Match;
                      Width  : Natural;
                      Length : Positive) return Match;

   --------------
   -- And_Then --
   --------------

   function And_Then (This : Match;
                      That : Matcher)
                      return Match;

   ----------------
   -- Maybe_Then --
   ----------------

   function Maybe_Then (This           : Match;
                        That           : Matcher)
                        return Match;

   type Alternatives is array (Positive range <>) of Matcher;

   -------------
   -- Or_Else --
   -------------

   function First_Of (This  : Match;
                      Those : Alternatives) return Match;

   ----------------------
   -- Cursor and views --
   ----------------------

   type Cluster_Cursor is record
      Has_Cur : Boolean          := False;
      Cur     : Grapheme_Cluster := (1, 1, 1, 0);
   end record;

   type UTF8_Cluster_Cursor is record
      Has_Cur    : Boolean               := False;
      Cur        : UTF8_Grapheme_Cluster := (1, 1, 1, 0);
      Last_Point : Natural               := 0;
      --  Code-point index in the decoded buffer of the last point covered
      --  by Cur; used to advance to the next cluster in O(1).
   end record;

   type WWString_Access is access constant WWString;

   type Cluster_View is record
      Text : WWString_Access;
      Conf : Configuration;
   end record;

   type Byte_Offsets is array (Positive range <>) of Positive;

   type UTF8_Cluster_View (Points : Natural) is record
      Decoded : WWString     (1 .. Points);
      Starts  : Byte_Offsets (1 .. Points);
      --  Starts (i) is the byte index in the original UTF8_String where the
      --  i-th decoded code point begins.
      Ends    : Byte_Offsets (1 .. Points);
      --  Ends (i) is the byte index in the original UTF8_String of the last
      --  byte of the i-th decoded code point. The byte span of code points
      --  i..j is Starts (i) .. Ends (j).
      Conf    : Configuration;
   end record;

end Umwi;

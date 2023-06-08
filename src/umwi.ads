package Umwi with Preelaborate is

   --  NOTE: this library isn't robust against illegal unicode sequences.
   --  In those cases it will likely report a length different from what
   --  is actually printed to the console.

   Narrow_Context  : Boolean := True;
   --  See Contexts type below. TL;DR, True for Latin, False for CJK locales.

   Honor_Emoji_Selectors : Boolean := False;
   --  To match wcwidth behavior on Linux, used by most programs and terminals,
   --  set this to false. To be Unicode strict, set to True. This allows to
   --  force a 1-wide b/w emoji into a 2-wide color emoji and vice versa.

   Honor_Emoji_Modifiers : Boolean := True;
   --  These change the tone or combine with a previous emoji base. Not all
   --  fonts/terminals do these combinations, and instead show the skin tone
   --  as a square.

   --  Composing Unicode code points are always considered to be of size 0
   --  (they combine with a previous base character to form a graphene
   --  cluster, e.j. 'a' + '´' = 'á'

   Encoding_Error : exception;
   --  Raised by the subprograms below that take a string when there's some
   --  unexpected combo like an emoji modifier without a precedent emoji base.

   type UTF8_String is new String;

   subtype WWChar   is Wide_Wide_Character;
   subtype WWString is Wide_Wide_String;

   type East_Asian_Width is
     (A,  -- Ambiguous. Can take either 1 or 2 em depending on context.
      F,  -- Fullwidth. Occupies 2 em.
      H,  -- Halfwidth. Occupies 1 em.
      N,  -- Neutral. Occupies 1 em.
      Na, -- Narrow. Occupies 1 em.
      W   -- Wide. Occupies 2 em.
     );
   --  https://www.unicode.org/reports/tr11/
   --  https://www.unicode.org/reports/tr44/

   type Contexts is (Narrow, Wide);
   --  In Narrow contexts, an ambiguous symbol will use 1 em. This is the
   --  case of a Western locale. In a CJK locale, an ambiguous symbol would
   --  typically use 2 em.

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

   --  An Emoji Presentation Sequence should use 2 em no mater what their
   --  East_Asian_Width is, see in https://www.unicode.org/reports/tr11/
   --  This is an Emoji_Presentation symbol plus either 16#FE0E# (text mode,
   --  black&white, 1em) or 16#FE0E# (presentation mode, colorful, 2em).
   --  If omitted, a symbol with the Emoji_Presentation property should use
   --  the latter. Not all emojis can be forced into either mode, see the
   --  emoji-variation-sequences.txt Unicode file.

   --  NOTE: at present, Ubuntu terminals do not honor the Text/Presentation
   --  marker for actual width, only for the text/presentation mode. It will
   --  use the proper symbol, but it will always take the width mandated by
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
   --  These are not all the combining characters; see Umwi.Combining

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

   function Emoji_Properties (Symbol : WWChar) return Emoji_Property_Array;
   --  See also Umwi.Emoji

   function Width (Symbol : WWChar) return East_Asian_Width;
   --  See also Umwi.East_Asian_Width

   function Width (Symbol  : WWChar;
                   Context : Contexts := (if Narrow_Context
                                          then Narrow
                                          else Wide))
                   return Widths;

   function Length (Text           : WWString;
                    Context        : Contexts := (if Narrow_Context
                                                  then Narrow
                                                  else Wide);
                    Honor_Selector : Boolean := Honor_Emoji_Selectors;
                    Honor_Modifier : Boolean := Honor_Emoji_Modifiers)
                    return Natural;
   --  This is Length in the sense of fixed-width font slots used. Takes into
   --  account grapheme clusters (considered as one slot). Implements the EBNF
   --  at https://unicode.org/reports/tr51/#EBNF_and_Regex. Displaying engines
   --  that deviate from that EBNF will result in wrong lengths. In addition,
   --  when Honor_Selector, two-point sequences of emoji+selector are
   --  considered. If not Honor_Modifier, the EBNF will not combine skin tones
   --  (Emoji_Modifier code points) and break the sequence at that point. An
   --  emoji matched by the EBNF, no matter how long in actual unicode points,
   --  will occupy 2 slots.

   function Length (Text           : UTF8_String;
                    Context        : Contexts := (if Narrow_Context
                                                  then Narrow
                                                  else Wide);
                    Honor_Selector : Boolean := Honor_Emoji_Selectors;
                    Honor_Modifier : Boolean := Honor_Emoji_Modifiers)
                    return Natural;
   --  Same as above

private

   --  Helper type to implement the recursive parser

   type Match (Length : Natural) is tagged record
      Text  : WWString (1 .. Length); -- Unicode codepoints matched
      Width : Natural;                -- their actual visible width
   end record;
   --  The Text field is not needed, may come in handy for debugging

   -------------
   -- Matched --
   -------------

   function Matched (Width : Natural; Text : WWString) return Match
   is (Length => Text'Length,
       Text   => Text,
       Width  => Width);

   -------------
   -- Matched --
   -------------

   function Matched (Width : Natural; Text : WWChar) return Match
   is (Length => 1,
       Text   => (1 .. 1 => Text),
       Width  => Width);

   --------------
   -- No_Match --
   --------------

   function No_Match return Match is (Length => 0, Text => "", Width => 0);

   ------------
   -- Append --
   ------------

   function Append (This, That : Match) return Match
   is (Length => This.Length + That.Length,
       Text   => This.Text & That.Text,
       Width  => (if This.Width = 1
                  and then That.Length > 0
                  and then That.Text (That.Text'First) = Presentation_Selector
                  then 2
                  else This.Width));

   --------------
   -- And_Then --
   --------------

   function And_Then (This   : Match;
                      Offset : Natural;
                      That   : access function (Offset : Natural) return Match)
                      return Match
   is (if This /= No_Match
       then This.Append (That (Offset + This.Length))
       else No_Match);

   -------------
   -- Or_Else --
   -------------

   function Or_Else (This, That : Match) return Match
   is (if This.Length > 0
       then This
       else That);

end Umwi;

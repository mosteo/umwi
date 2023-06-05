generic
   Narrow_Context  : Boolean;
   --  See Contexts type below. TL;DR, True for Latin, False for CJK locales.

   Honor_Selectors : Boolean;
   --  To match wcwidth behavior on Linux, used by most programs and terminals,
   --  set this to false. To be Unicode strict, set to True
package Umwi is

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

   type Emoji_Properties is
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

   type Emoji_Property_Array is array (Emoji_Properties) of Boolean;

   Text_Selector         : constant WWChar := WWChar'Val (16#FE0E#);
   Presentation_Selector : constant WWChar := WWChar'Val (16#FE0F#);

   function Properties (Symbol : WWChar) return Emoji_Property_Array;

   function Width (Symbol : WWChar) return East_Asian_Width;

   function Width (Symbol  : WWChar;
                   Context : Contexts := (if Narrow_Context
                                          then Narrow
                                          else Wide))
                   return Widths;

   function Width (Text           : WWString;
                   Context        : Contexts := (if Narrow_Context
                                                 then Narrow
                                                 else Wide);
                   Honor_Selector : Boolean := Honor_Selectors)
                   return Natural;

   function Width (Text           : UTF8_String;
                   Context        : Contexts := (if Narrow_Context
                                                 then Narrow
                                                 else Wide);
                   Honor_Selector : Boolean := Honor_Selectors)
                   return Natural;

private

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

end Umwi;
with Umwi.Generated;

package Umwi.Properties with Preelaborate is

   --  This package is stable; use it in preference to Umwi.Generated

   subtype Combining is WWChar with Static_Predicate =>
     Combining in Combining_Blocks | Generated.Combining;

   function Emoji_Properties (Symbol : WWChar) return Emoji_Property_Array
   is (Emoji                 => Symbol in Generated.Emoji,
       Emoji_Presentation    => Symbol in Generated.Emoji_Presentation,
       Emoji_Modifier_Base   => Symbol in Generated.Emoji_Modifier_Base,
       Emoji_Modifier        => Symbol in Generated.Emoji_Modifier,
       Emoji_Component       => Symbol in Generated.Emoji_Component,
       Extended_Pictographic => Symbol in Generated.Extended_Pictographic);

end Umwi.Properties;

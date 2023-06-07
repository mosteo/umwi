package Umwi.Generated with Preelaborate is

   subtype Combining is WWChar
     with Static_Predicate => Combining in
       Combining_Blocks;

   subtype Emoji is WWChar
     with Static_Predicate => Emoji in
       WWChar'Last .. WWChar'First;

   subtype Emoji_Presentation is WWChar
     with Static_Predicate => Emoji_Presentation in
       WWChar'Last .. WWChar'First;

   subtype Emoji_Modifier_Base is WWChar
     with Static_Predicate => Emoji_Modifier_Base in
       WWChar'Last .. WWChar'First;

   subtype Emoji_Modifier is WWChar
     with Static_Predicate => Emoji_Modifier in
       WWChar'Last .. WWChar'First;

   subtype Emoji_Component is WWChar
     with Static_Predicate => Emoji_Component in
       WWChar'Last .. WWChar'First;

   subtype Extended_Pictographic is WWChar
     with Static_Predicate => Extended_Pictographic in
       WWChar'Last .. WWChar'First;

   function Width (Symbol : WWChar) return East_Asian_Width
   is (case Symbol is
          when others => A);

end Umwi.Generated;

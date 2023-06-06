package Umwi.Combining with Preelaborate is

   --  Intended to be used as Combining.Characters without "use"

   subtype Characters is WWChar with Static_Predicate =>
     Characters in Combining_Blocks
       ;

end Umwi.Combining;

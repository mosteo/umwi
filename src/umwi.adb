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
      Prev_Width : Natural := 0; -- Previous character width
      Length     : Integer := 0;
   begin
      for I in Text'Range loop
         declare
            Char : WWChar renames Text (I);
         begin
            if Char = Text_Selector then
               if Honor_Selector and then Prev_Width = 2 then
                  --  We are turning a color emoji into a b/w smaller one
                  Length := Length - 1;
               end if;

            elsif Char = Presentation_Selector then
               if Honor_Selector and then Prev_Width = 1 then
                  --  We are turning a b/w emoji into a color wider one
                  Length := Length + 1;
               end if; ‍

            elsif Char = Zero_Width_Joiner and then I < Text'Last then
               if
               Length := Length - Width (Text (I + 1));
               --  Remove the length that will be added in the next iteration

            elsif Char in Generated.Emoji_Modifier then
               --  These are the skin tones, that sometimes aren't honored and
               --  shown as squares
               if not Honor_Modifier then
                  Length := Length + 1;
               end if;

            elsif Char in Regional_Indicator_Emoji_Component then
               --  These, when isolated, are narrow, and when combined are a
               --  wide flag, so they can be counted independently, and reset
               --  composition.
               Length := Length + Width (Char);

            elsif Char in Zero_Width_Emoji_Component then
               --  These don't use space no matter what
               null;

            elsif Char in Generated.Emoji_Component then
               --  This is an emoji modifier so it shouldn't count, unless we
               --  do not honor them (as some formatters indeed do, printing
               --  them separately) or the preceding one is not an emoji
               if not Honor_Modifier then
                  Length := Length + 1;
               end if;

            elsif Char in Properties.Combining then
               --  This is a combining character that piles on the previous one
               --  If there's no previous character, it shouldn't be printed
               null;

            else
               --  By elimination, it must be a regular character. We aren't
               --  considering undefined code points to be invisible (hopefully
               --  they'll be shown somehow).
               Length := Length + Width (Char, Context);
            end if;

            Prev_Width := Width (Char, Context);

         end;
      end loop;

      if Length < 0 then
         Length := 0;
         --  Could happen with some illegal sequences using joiners and so
      end if;

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

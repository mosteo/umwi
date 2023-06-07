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
      Prev_Width    : Natural := 0;
      Prev_Is_Emoji : Boolean := False;
      --  Width of the previously seen base emoji
   begin
      return Length : Natural := 0 do
         for Char of Text loop
            if Char = Text_Selector and then Prev_Width = 2 then
               --  We are turning a color emoji into a b/w smaller one
               Length := Length - 1;

            elsif Char = Presentation_Selector and then Prev_Width = 1 then
               --  We are turning a b/w emoji into a color wider one
               Length := Length + 1;

            elsif Char in Generated.Emoji then
               --  This is a new emoji, with its own default width (1 or 2)
               Prev_Is_Emoji := True;
               Length        := Length + Width (Char, Context);
               if Honor_Selector then
                  --  Keep track of its width in case it's later modified
                  Prev_Width := Width (Char, Context);
               end if;

            elsif Char in Generated.Emoji_Modifier then
               --  These are the skin tones, that sometimes aren't honored and
               --  shown as squares
               if not Honor_Modifier then
                  Length := Length + 1;
               end if;

            elsif Char in Zero_Width_Emoji_Component then
               --  These don't use space no matter what
               null;

            elsif Char in Generated.Emoji_Component then
               --  This is an emoji modifier so it shouldn't count, unless we
               --  do not honor them (as some formatters indeed do, printing
               --  them separately) or the preceding one is not an emoji
               if not Honor_Modifier or else not Prev_Is_Emoji then
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
               Prev_Is_Emoji := False;
               Length        := Length + 1;
            end if;

         end loop;
      end return;
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

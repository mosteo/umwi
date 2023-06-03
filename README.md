Utilities to get the width in monospace font "characters" of an Unicode code
point. (Not to be confused with the width in encoding bytes of the code point.)

Some characters, even in monospace fonts, take up to two characters for
representation. Read more about it on:

https://www.unicode.org/reports/tr11/

This affects emoji in particular, for historical reasons. Even so, not all
characters that are considered emoji use two spaces.

See, for example:

```
----
-⚽-
----
```

but

```
-----
-©⁉️☄️-
-----
```

Note that not all programs and browsers properly honor spacing even with
monospace fonts when such characters are involved. Fortunately, modern Linux
consoles seem to do the right thing.

The latest Unicode standard defines normatively the East_Asian_Width property,
which helps in determining if a symbol should take one or two slots when rendered in monospace font.

That's purpose of this library: given a code point, it will answer with the
width taken in monospace slots.

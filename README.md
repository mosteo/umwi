 [![Alire](https://img.shields.io/endpoint?url=https://alire.ada.dev/badges/umwi.json)](https://alire.ada.dev/crates/umwi.html)

## Unicode Monospaced Width Information (UMWI)

This is a library to get the width in monospace font "characters" of an Unicode code
point. (Not to be confused with the size in encoding bytes of the code point.)

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

and

```
-----
-©⁉️☄️-
-----
```

(The above may not render properly depending on your setup, but according to
the East Asian Width property these should be properly aligned boxes.)

Not all programs and browsers properly honor spacing even with
monospace fonts when such characters are involved. Fortunately, modern Linux
consoles seem to do the right thing.

The latest Unicode standard defines normatively the East Asian Width property,
which helps in determining if a symbol should take one or two slots when rendered in monospace font.

### Why do I need this

If you're displaying tables to the terminal that may contain emojis you will
likely run into problems if you don't take into account the Asian width of your strings.

### References

- https://www.unicode.org/reports/tr11/ (East Asian Width)
- https://www.unicode.org/reports/tr51/ (Unicode Emoji)
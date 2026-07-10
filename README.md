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

### Grapheme-cluster iteration

In addition to the aggregate `Count` API, `umwi` exposes a public,
O(N) grapheme-cluster iterator usable with Ada's `for ... of` loop.
For each cluster you get its boundary, its display width, and either
its code-point or byte extent:

```ada
type Grapheme_Cluster is record
   First, Last : Positive;  -- code-point indices into the source WWString
   Points      : Positive;  -- number of code points in this cluster
   Width       : Natural;   -- display columns (0, 1 or 2)
end record;

type UTF8_Grapheme_Cluster is record
   First_Byte, Last_Byte : Positive;  -- byte indices into the UTF8_String
   Points                : Positive;
   Width                 : Natural;
end record;

for C of Umwi.Clusters (Some_WWString)    loop ...  --  Grapheme_Cluster
for C of Umwi.Clusters (Some_UTF8_String) loop ...  --  UTF8_Grapheme_Cluster
```

A single-step primitive is also exported:

```ada
function Next_Cluster (Text : WWString;    From : Positive;
                       Conf : Configuration := Default) return Grapheme_Cluster;
function Next_Cluster (Text : UTF8_String; From : Positive;
                       Conf : Configuration := Default)
                       return UTF8_Grapheme_Cluster;
```

Both `Count` and the iterator share the same internal cluster-segmentation
primitive, so sums over the iterator always equal `Count`'s results:

```
sum (C.Width)  of Clusters (T) = Count (T).Width
sum (C.Points) of Clusters (T) = Count (T).Points
       count   of Clusters (T) = Count (T).Clusters
```

For the UTF-8 view, `Text (C.First_Byte .. C.Last_Byte)` slices the original
input safely at cluster boundaries, and concatenating these slices over all
clusters reproduces the input byte for byte.

### Malformed UTF-8 contract

The new grapheme-cluster iterator on `UTF8_String` is best-effort by default:
when `Conf.Reject_Illegal = False`, every byte that does not decode to a valid
UTF-8 code point is treated as a single-byte cluster of width 1, so iteration
always makes progress and never raises on malformed input. When
`Conf.Reject_Illegal = True`, `Encoding_Error` is raised on the first invalid
byte instead.

For backward compatibility the legacy `Count (Text : UTF8_String)` still
raises `Encoding_Error` on any malformed UTF-8 regardless of
`Conf.Reject_Illegal` — switch to the iterator when you need best-effort
behaviour on possibly-broken input.

### References

- https://www.unicode.org/reports/tr11/ (East Asian Width)
- https://www.unicode.org/reports/tr51/ (Unicode Emoji)
- https://www.unicode.org/reports/tr29/ (Grapheme Cluster Boundaries)
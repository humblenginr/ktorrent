Challenge 1: 
So while decoding the metainfo file, I am using the `bencode` package and I am able to get all the information, except `pieces`. 
It is mentioned in the spec that `pieces` is a string consisting of the concatenation of all 20byte SHA1 values, one per piece.

But the thing is, we don't even have to worry about this, because we are just going to send the `info` to the tracker and we need not worry
about decoding what is inside the `pieces` field.

# breeze

A dsl for writing macros in Nim

## rationale

I read a comment by Araq about how karax might be a good fit for the ast nodes in
the compiler and I've always found building the nodes in `macro`-s in Nim tedious.
`breeze` is a karax-like dsl for building nim nodes in macros:

```nim
macro s(b: untyped): untyped =
  var e = newIdentNode(!"e")
  result = buildMacro:
    call:
      dotExpr(e, ident("f"))
      infix(ident("+"), 2, 3)
```

expands to

```nim
nnkCall.newTree(nnkDotExpr.newTree(e, newIdentNode(! "f")),
                nnkInfix.newTree(newIdentNode(! "+"), newLit(2), newLit(3)))
```

It's equivalent to

```nim
macro s(b: untyped): untyped =
  var e = newIdentNode(!"e")
  result = buildMacro:
    call:
      dotExpr:
        e
        ident("f")
      infix:
        ident("+")
        2
        3
```

## functionality

You use it invoking `buildMacro` with a singular child corresponding to the node you want to build

Each child is either of the form 

```nim
node:
  child
  child
```

or 

```nim
node(child, child)
```

They're equivalent in most cases and they usually expand to `nnk<capitalized_node>.newTree(<visited children>)`

Special cases are literals which are expanded to `newLit` and `ident(name)` which are expanded to `newIdentNode`.

You can build dynamically macros (with variables) just by passing them directly,
e.g. 

```nim
var e = newIdentNode(!"f")
result = buildMacro:
  call:
    e
```

expands to

```nim
Call
  Ident !"f"
```




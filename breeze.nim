import macros, strutils, sequtils, tables

const debugMacro = false

proc build(b: NimNode): NimNode

proc buildCall(args: NimNode): seq[NimNode] =
  result = args.mapIt(build(it))

proc buildInline(args: NimNode): seq[NimNode] =
  result = @[]
  var isArg = false
  for child in args:
    if isArg:
      result.add(build(child))
    else:
      isArg = true

proc labelOf(b: NimNode): string =
  assert b.kind in {nnkIdent, nnkAccQuoted}
  if b.kind == nnkAccQuoted:
    result = labelOf(b[0])
  else:
    result = $b.ident

proc buildIdent(b: NimNode): NimNode =
  result = nnkCall.newTree(
    newIdentNode(!"newIdentNode"),
    nnkPrefix.newTree(
      newIdentNode(!"!"),
      newLit($b)))

proc build(b: NimNode): NimNode =
  case b.kind:
  of nnkStmtList:
    result = build(b[0])
  of nnkCall:
    var label = labelOf(b[0])
    case label:
    of "ident":
      result = buildIdent(b[1])
    else:
      var args: seq[NimNode]
      if len(b) == 2:
        args = buildCall(b[1])
      else:
        args = buildInline(b)
      result = nnkCall.newTree(
        nnkDotExpr.newTree(
          newIdentNode(!("nnk$1" % capitalizeAscii(label))),
          newIdentNode(!"newTree")))
      for arg in args:
        result.add(arg)
  of nnkCharLit..nnkUInt64Lit, nnkFloatLit..nnkFloat64Lit, nnkStrLit..nnkTripleStrLit:
    result = nnkCall.newTree(
      newIdentNode(!"newLit"),
      b)
  of nnkIdent:
    if $b == "true" or $b == "false":
      result = nnkCall.newTree(
        newIdentNode(!"newLit"),
        b)
    else:
      result = b
  of nnkAccQuoted:
    result = build(b[0])
  of nnkNilLit:
    result = nil
  else:
    when debugMacro:
      echo treerepr(b)
    else:
      discard

macro buildMacro*(b: untyped): untyped =
  result = build(b)
  when debugMacro:
    echo "build: $1" % repr(result)

# macro s(b: untyped): untyped =
#   var e = newIdentNode(!"e")
#   result = buildMacro:
#     call:
#       dotExpr(e, ident("f"))
#       infix(ident("+"), 2, 3)
#   when debugMacro:
#     echo treerepr(result)

# var e = (f: (proc(x: int) = echo(x)))
# s(2)

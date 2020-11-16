import macros, sequtils

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
  expectKind b, {nnkIdent, nnkAccQuoted}
  if b.kind == nnkAccQuoted:
    result = labelOf(b[0])
  else:
    result = $b

proc buildIdent(b: NimNode): NimNode =
  result = nnkCall.newTree(
    newIdentNode("newIdentNode"), b)

proc build(b: NimNode): NimNode =
  var resultNode = newIdentNode("result")
  var stmtsNode = newIdentNode("stmts")
  var lastNode = newIdentNode("last")
  var x = newIdentNode("x")
  case b.kind:
  of nnkStmtList:
    result = nnkStmtList.newTree()
    for child in b:
      result.add(build(child))
  of nnkVarSection:
    result = b
  of nnkCall:
    var label = labelOf(b[0])
    if label.eqIdent"ident":
      result = buildIdent(newLit($b[1]))
      result = quote:
        `lastNode`.add(`result`)
    else:
      var args: seq[NimNode]
      if len(b) == 2:
        args = buildCall(b[1])
      else:
        args = buildInline(b)
      var callIdent = newIdentNode("nnk" & $label)
      result = nnkCall.newTree(
        nnkDotExpr.newTree(
          callIdent,
          newIdentNode("newTree")))
      result = quote:
        `x` = `result`
        `lastNode`.add(`x`)
      var b = quote:
        `lastNode` = `x`
      result.add(b)
      result.add(args)
      b = quote:
        `lastNode` = `stmtsNode`
      result.add(b)
  of nnkCharLit..nnkUInt64Lit, nnkFloatLit..nnkFloat64Lit, nnkStrLit..nnkTripleStrLit:
    result = nnkCall.newTree(
      newIdentNode("newLit"),
      b)
    result = quote:
      `lastNode`.add(`result`)
  of nnkIdent:
    if $b == "true" or $b == "false":
      result = nnkCall.newTree(
        newIdentNode("newLit"),
        b)
    else:
      result = b
    result = quote:
      `lastNode`.add(`result`)
  of nnkAccQuoted:
    result = build(b[0])
  of nnkNilLit:
    result = nil
    result = quote:
      `lastNode`.add(`result`)
  of nnkIfStmt:
    result = nnkIfStmt.newTree()
    for branch in b:
      if branch.kind == nnkElifBranch:
        result.add(nnkElifbranch.newTree(
          branch[0],
          build(branch[1])))
      else:
        result.add(nnkElse.newTree(
          build(branch[0])))
  of nnkInfix:
    if b[1].kind == nnkStrLit:
      var newLitNode = newIdentNode("newLit")
      result = quote:
        `newLitNode`(`b`)
    else:
      result = b
    result = quote:
      `lastNode`.add(`result`)
  of nnkForStmt:
    result = nnkForStmt.newTree(b[0], b[1], build(b[2]))
  of nnkCaseStmt:
    result = nnkCaseStmt.newTree(b[0])
    for branch in b:
      if branch.kind == nnkOfBranch:
        result.add(nnkOfBranch.newTree(branch[0], build(branch[1])))
      elif branch.kind == nnkElse:
        result.add(nnkElse.newTree(build(branch[0])))
  else:
    result = quote:
      `lastNode`.add(`b`)
    when defined(debugBreeze):
      echo treeRepr(b)

macro buildMacro*(b: untyped): untyped =
  var stmtsNode = newIdentNode("stmts")
  var lastNode = newIdentNode("last")
  var x = newIdentNode("x")
  var resultNode = newIdentNode("result")
  var start = quote:
    var `stmtsNode` = nnkStmtList.newTree()
    var `lastNode` = `stmtsNode`
    var `x`: NimNode
  var finish = quote:
    `resultNode` = `stmtsNode`

  start.add(build(b))
  start.add(finish)
  var empty = newEmptyNode()

  result = nnkCall.newTree(
    nnkPar.newTree(
      nnkLambda.newTree(
        empty,
        empty,
        empty,
        nnkFormalParams.newTree(
          newIdentNode("NimNode")),
        empty,
        empty,
        start)))

  when defined(debugBreeze):
    echo "build:\n", repr(result)

when isMainModule:
  macro s(b: untyped): untyped =
    var e = newIdentNode("e")
    result = buildMacro:
      call:
        dotExpr(e, ident("f"))
        infix(ident("+"), 2, 3)

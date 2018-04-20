include lda

import unittest, sequtils

suite "the nested seq structure":
  test "set the correct offsets and data":
    let s = @[
      @[1, 2, 3],
      @[4, 5],
      @[6, 7, 8, 9],
      @[10]
    ]
    var n = newNestedSeq(4, 10, int)
    var count = 0
    for i, d in s:
      n.offsets[i] = count
      for j, w in d:
        n[i, j] = w
        inc(count)

    check n.offsets == @[0, 3, 5, 9]
    check n.data == toSeq(1 .. 10)

  test "give the correct elements":
    let s = @[
      @[1, 2, 3],
      @[4, 5],
      @[6, 7, 8, 9],
      @[10]
    ]
    var n = newNestedSeq(4, 10, int)
    var count = 0
    for i, d in s:
      n.offsets[i] = count
      for j, w in d:
        n[i, j] = w
        inc(count)

    for i, d in s:
      for j, w in d:
        check n[i, j] == w
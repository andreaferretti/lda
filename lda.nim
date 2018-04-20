import sets, sequtils, sugar, strutils
import random
import random/urandom, random/mersenne
import alea

type
  Matrix* = object
    M*, N*: int
    data*: seq[float32]
  LDAResult* = object
    wt*, dt*: Matrix
  NestedSeq*[A] = object
    offsets: seq[int]
    data: seq[A]

proc zeros*(M, N: int): Matrix =
  Matrix(M: M, N: N, data: newSeq[float32](M * N))

template `[]`(m: Matrix, i, j: int): float32 =
  m.data[j * m.M + i]

template `[]=`(m: var Matrix, i, j: int, val: float32) =
  m.data[j * m.M + i] = val

template inc(m: var Matrix, i, j: int) =
  m.data[j * m.M + i] += 1

template dec(m: var Matrix, i, j: int) =
  m.data[j * m.M + i] -= 1

template `[]`[A](s: NestedSeq[A], i, j: int): A =
  s.data[s.offsets[i] + j]

template `[]=`[A](s: var NestedSeq[A], i, j: int, val: A) =
  s.data[s.offsets[i] + j] = val

proc newNestedSeq(outer, inner: int, A: typedesc): NestedSeq[A] =
  NestedSeq[A](offsets: newSeq[int](outer), data: newSeq[A](inner))

proc like[A](s: NestedSeq[A]): NestedSeq[A] =
  newNestedSeq(s.offsets.len, s.data.len, A)

proc wordSet(docs: seq[seq[string]]): HashSet[string] =
  result.init()
  for doc in docs:
    for word in doc:
      result.incl(word)

proc makeVocab*(docs: seq[seq[string]]): seq[string] =
  toSeq(wordSet(docs).items)

proc makeDocs*(docWords: seq[seq[string]], vocab: seq[string]): NestedSeq[int] =
  var inner = 0
  for d in docWords:
    inner += d.len
  result = newNestedSeq(docWords.len, inner, int)
  inner = 0
  var count = 0
  for i, d in docWords:
    result.offsets[i] = inner
    inner += d.len
    for s in d:
      result.data[count] = vocab.find(s)
      count += 1

proc len*[A](s: NestedSeq[A]): int = s.offsets.len

proc len*[A](s: NestedSeq[A], i: int): int =
  if i + 1 < s.offsets.len:
    s.offsets[i + 1] - s.offsets[i]
  else:
    s.data.len - s.offsets[i]

iterator items[A](s: NestedSeq[A], i: int): A {.inline.} =
  let max = if i + 1 < s.offsets.len:  s.offsets[i + 1] else: s.data.len
  for j in s.offsets[i] ..< max:
    yield s.data[j]

# proc makeDiscrete(v: Vector[float32]): Discrete[int] =
#   new result.values
#   result.values[] = newSeq[(int, float32)](v.len)
#   let sum = v.sum
#   for i in 0 ..< v.len:
#     result.values[i] = (i, v[i] / sum)

proc sample(r: var Rand, probabilities: seq[float32]): int =
  let x = r.rand(max = probabilities[^1])
  for i, p in probabilities:
    if p >= x:
      return i

proc binarySearch(r: var Rand, probabilities: seq[float32]): int =
  let x = r.rand(max = probabilities[^1])
  var b = len(probabilities)
  while result < b:
    var mid = (result + b) div 2
    if probabilities[mid] < x:
      result = mid + 1
    else:
      b = mid

proc rowSum(m: Matrix, i: int): float32 {.inline.} =
  result = 0
  for j in 0 ..< m.N:
    result += m[i, j]

proc lda*(docs: NestedSeq[int], vocabLen: int, K: int, iterations: int): LDAResult =
  var
    # word-topic matrix
    wt = zeros(K, vocabLen)
    # topic assignment list
    ta = like(docs)
    # counts correspond to the number of words assigned to each topic
    # for each document
    dt = zeros(docs.len, K)
    rng = initRand(1234)

  # Random initialization
  for d in 0 ..< docs.len:
    # randomly assign topic to word w
    for w in 0 ..< docs.len(d):
      ta[d, w] = rng.rand(K - 1)
      # extract the topic index, word id and update the corresponding cell
      # in the word-topic count matrix
      let
        ti = ta[d, w]
        wi = docs[d, w]
      wt.inc(ti, wi)

    # count words in document d assigned to each topic t
    for t in 0 ..< K:
      for x in ta.items(d):
        if x == t:
          dt.inc(d, t)

  # Gibbs sampling
  let
    alpha = 50.0 / K.float32
    eta = 0.1
    L = vocabLen.float32

  var probabilities = newSeq[float32](K)

  for _ in 1 .. iterations:
    for d in 0 ..< docs.len:
      for w in 0 ..< docs.len(d):
        let
          t0 = ta[d, w]
          wid = docs[d, w]
        # Remove this particular topic association
        # since we are going to recompute it
        dt.dec(d, t0)
        wt.dec(t0, wid)
        var pSum = 0'f32
        for j in 0 ..< K:
          pSum += (wt[j, wid] + eta) / (wt.rowSum(j) + L * eta) * (dt[d, j] + alpha)
          probabilities[j] = pSum
        # Sample topic from distribution
        let t1 = rng.binarySearch(probabilities)
        # Update counts
        dt.inc(d, t1)
        wt.inc(t1, wid)
        ta[d, w] = t1

  return LDAResult(wt: wt, dt: dt)

# proc sample*(ldaResult: LDAResult, vocab: seq[string], doc = 0, count = 10): string =
#   var
#       rng = wrap(initMersenneTwister(urandom(16)))
#       words = newSeq[string](count)
#   let tDist = makeDiscrete(ldaResult.dt.row(doc))
#   for i in 1 .. count:
#     let
#       t = rng.sample(tDist)
#       wDist = makeDiscrete(ldaResult.wt.row(t))
#       w = rng.sample(wDist)
#     words[i - 1] = vocab[w]
#   return words.join(" ")

proc bestTopic*(ldaResult: LDAResult, doc: int): int =
  result = 0
  var max = -Inf
  for j in 0 ..< ldaResult.dt.N:
    if ldaResult.dt[doc, j] > max:
      result = j
      max = ldaResult.dt[doc, j]

proc bestWords*(ldaResult: LDAResult, vocab: seq[string], topic: int, count = 5): seq[tuple[word: string, score: float32]] =
  var wt = ldaResult.wt
  result = newSeq[tuple[word: string, score: float32]](count)
  for i in 0 ..< count:
    var max = -Inf.float32
    var index = 0
    for j in 0 ..< ldaResult.wt.N:
      if wt[topic, j] > max:
        index = j
        max = wt[topic, j]
    result[i] = (vocab[index], max)
    wt[topic, index] = 0
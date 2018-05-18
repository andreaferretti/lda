# Copyright 2018 UniCredit S.p.A.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
import sets, sequtils, sugar, strutils, random

type
  Matrix* = object
    M*, N*: int
    data*: seq[float32]
  LDAResult* = object
    wt*, dt*: Matrix
  NestedSeq*[A] = object
    offsets: seq[int]
    data: seq[A]

proc zeros(M, N: int): Matrix =
  Matrix(M: M, N: N, data: newSeq[float32](M * N))

template `[]`(m: Matrix, i, j: int): float32 =
  m.data[j * m.M + i]

template `[]=`(m: var Matrix, i, j: int, val: float32) =
  m.data[j * m.M + i] = val

template `[]`[A](s: NestedSeq[A], i, j: int): A =
  s.data[s.offsets[i] + j]

template `[]=`[A](s: var NestedSeq[A], i, j: int, val: A) =
  s.data[s.offsets[i] + j] = val

proc newNestedSeq(outer, inner: int, A: typedesc): NestedSeq[A] =
  NestedSeq[A](offsets: newSeq[int](outer), data: newSeq[A](inner))

proc nestedSeqLike[A](s: NestedSeq[A]): NestedSeq[A] =
  NestedSeq[A](offsets: s.offsets, data: newSeq[A](s.data.len))

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

proc len[A](s: NestedSeq[A], i: int): int =
  if i + 1 < s.offsets.len:
    s.offsets[i + 1] - s.offsets[i]
  else:
    s.data.len - s.offsets[i]

proc binarySearch(r: var Rand, probabilities: seq[float32]): int =
  let x = r.rand(max = probabilities[^1])
  var b = len(probabilities)
  while result < b:
    let mid = (result + b) div 2
    if probabilities[mid] < x:
      result = mid + 1
    else:
      b = mid

proc lda*(docs: NestedSeq[int], vocabLen: int, K: int, iterations: int): LDAResult =
  var
    # word-topic matrix
    wt = zeros(K, vocabLen)
    # topic assignment list
    ta = nestedSeqLike(docs)
    # word-topic row sums
    ws = newSeq[float32](K)
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
        t = ta[d, w]
        wid = docs[d, w]
      dt[d, t] += 1
      wt[t, wid] += 1
      ws[t] += 1

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
        dt[d, t0] -= 1
        wt[t0, wid] -= 1
        ws[t0] -= 1
        var pSum = 0'f32
        for t in 0 ..< K:
          pSum += (wt[t, wid] + eta) / (ws[t] + L * eta) * (dt[d, t] + alpha)
          probabilities[t] = pSum
        # Sample topic from distribution
        let t1 = rng.binarySearch(probabilities)
        # Update counts
        dt[d, t1] += 1
        wt[t1, wid] += 1
        ws[t1] += 1
        ta[d, w] = t1

  return LDAResult(wt: wt, dt: dt)

proc sample*(ldaResult: LDAResult, vocab: seq[string], doc = 0, count = 10): string =
  let K = ldaResult.dt.N
  var
      rng = initRand(1234)
      words = newSeq[string](count)
      tDist = newSeq[float32](K)
      wDist = newSeq[float32](vocab.len)
      sum = 0'f32
  for i in 0 ..< K:
    sum += ldaResult.dt[doc, i]
    tDist[i] = sum
  for i in 1 .. count:
    sum = 0
    let t = rng.binarySearch(tDist)
    for j in 0 ..< vocab.len:
      sum += ldaResult.wt[t, j]
      wDist[j] = sum
    let w = rng.binarySearch(wDist)
    words[i - 1] = vocab[w]
  return words.join(" ")

proc bestTopic*(ldaResult: LDAResult, doc: int): int =
  result = 0
  var max = -Inf
  for t in 0 ..< ldaResult.dt.N:
    if ldaResult.dt[doc, t] > max:
      result = t
      max = ldaResult.dt[doc, t]

proc bestWords*(ldaResult: LDAResult, vocab: seq[string], topic: int, count = 5): seq[tuple[word: string, score: float32]] =
  var wt = ldaResult.wt
  result = newSeq[tuple[word: string, score: float32]](count)
  for i in 0 ..< count:
    var max = -Inf.float32
    var index = 0
    for t in 0 ..< ldaResult.wt.N:
      if wt[topic, t] > max:
        index = t
        max = wt[topic, t]
    result[i] = (vocab[index], max)
    wt[topic, index] = 0
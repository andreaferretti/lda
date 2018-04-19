import sets, sequtils, sugar, strutils
import random
import random/urandom, random/mersenne
import neo, alea

proc wordSet(docs: seq[seq[string]]): HashSet[string] =
  result.init()
  for doc in docs:
    for word in doc:
      result.incl(word)

proc makeVocab*(docs: seq[seq[string]]): seq[string] =
  toSeq(wordSet(docs).items)

proc makeDocs*(docWords: seq[seq[string]], vocab: seq[string]): seq[seq[int]] =
  docWords.map((s: seq[string]) => s.mapIt(vocab.find(it)))

proc makeDiscrete(v: Vector[float]): Discrete[int] =
  new result.values
  result.values[] = newSeq[(int, float)](v.len)
  let sum = v.sum
  for i in 0 ..< v.len:
    result.values[i] = (i, v[i] / sum)

proc normalize(s: var seq[float]) =
  let sum = foldl(s, a + b)
  for i in 0 ..< s.len:
    s[i] /= sum

proc sample(r: var Rand, probabilities: seq[float]): int =
  let x = r.rand(max = 1.0)
  var sum = 0.0
  for i, p in probabilities:
    sum += p
    if sum >= x:
      return i

proc rowSum(m: Matrix[float], i: int): float =
  result = 0
  for j in 0 ..< m.N:
    result += m[i, j]

type LDAResult = object
  wt, dt: Matrix[float]

proc lda*(docs: seq[seq[int]], vocabLen: int, K: int, iterations: int): LDAResult =
  var
    # word-topic matrix
    wt = zeros(K, vocabLen)
    # topic assignment list
    ta = docs.mapIt(repeat(0, len(it)))
    # counts correspond to the number of words assigned to each topic
    # for each document
    dt = zeros(docs.len, K)
    rng = initRand(1234)

  # Random initialization
  for d in 0 ..< docs.len:
    # randomly assign topic to word w
    for w in 0 ..< docs[d].len:
      ta[d][w] = rng.rand(K - 1)
      # extract the topic index, word id and update the corresponding cell
      # in the word-topic count matrix
      let
        ti = ta[d][w]
        wi = docs[d][w]
      wt[ti, wi] = wt[ti, wi] + 1

    # count words in document d assigned to each topic t
    for t in 0 ..< K:
      for x in ta[d]:
        if x == t:
          dt[d, t] = dt[d, t] + 1

  # Gibbs sampling
  let
    alpha = 1.0
    eta = 1.0
    L = vocabLen.float

  var probabilities = newSeq[float](K)

  for _ in 1 .. iterations:
    for d in 0 ..< docs.len:
      for w in 0 ..< docs[d].len:
        let
          t0 = ta[d][w]
          wid = docs[d][w]
        # Remove this particular topic association
        # since we are going to recompute it
        dt[d, t0] = dt[d, t0] - 1
        wt[t0, wid] = wt[t0, wid] - 1
        for j in 0 ..< K:
          probabilities[j] = (wt[j, wid] + eta) / (wt.rowSum(j) + L * eta) * (dt[d, j] + alpha)
        normalize(probabilities)
        # Sample topic from distribution
        let t1 = rng.sample(probabilities)
        # Update counts
        dt[d, t1] = dt[d, t1] + 1
        wt[t1, wid] = wt[t1, wid] + 1
        ta[d][w] = t1

  return LDAResult(wt: wt, dt: dt)

proc sample*(ldaResult: LDAResult, vocab: seq[string], doc = 0, count = 10): string =
  var
      rng = wrap(initMersenneTwister(urandom(16)))
      words = newSeq[string](count)
  let tDist = makeDiscrete(ldaResult.dt.row(doc))
  for i in 1 .. count:
    let
      t = rng.sample(tDist)
      wDist = makeDiscrete(ldaResult.wt.row(t))
      w = rng.sample(wDist)
    words[i - 1] = vocab[w]
  return words.join(" ")

proc bestTopic*(ldaResult: LDAResult, doc: int): int =
  ldaResult.dt.row(doc).maxIndex.i

proc bestWords*(ldaResult: LDAResult, vocab: seq[string], topic: int, count = 5): seq[tuple[word: string, score: float]] =
  var row = ldaResult.wt.row(topic)
  result = newSeq[tuple[word: string, score: float]](count)
  for i in 0 ..< count:
    let index = row.maxIndex
    result[i] = (vocab[index.i], index.val)
    row[index.i] = 0
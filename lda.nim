import sets, sequtils, sugar, strutils
import random/urandom, random/mersenne
import neo, alea

proc wordSet(docs: seq[seq[string]]): HashSet[string] =
  result.init()
  for doc in docs:
    for word in doc:
      result.incl(word)

proc makeVocab(docs: seq[seq[string]]): seq[string] =
  toSeq(wordSet(docs).items)

proc makeDocs(docWords: seq[seq[string]], vocab: seq[string]): seq[seq[int]] =
  docWords.map((s: seq[string]) => s.mapIt(vocab.find(it)))

template `+`[A](v: Vector[A], a: A): Vector[A] =
  v + constantVector(v.len, a)

proc `|/|`[A: SomeFloat](a, b: Vector[A]): Vector[A] =
  assert(a.len == b.len)
  result = a.clone
  for i in 0 ..< a.len:
    result[i] = result[i] / b[i]

proc rowSums[A: SomeFloat](m: Matrix[A]): Vector[A] =
  result = zeros(m.M, A)
  for i in 0 ..< m.M:
    for j in 0 ..< m.N:
      result[i] = result[i] + m[i, j]

proc makeDiscrete(v: Vector[float]): Discrete[int] =
  new result.values
  result.values[] = newSeq[(int, float)](v.len)
  let sum = v.sum
  for i in 0 ..< v.len:
    result.values[i] = (i, v[i] / sum)

type LDAResult = object
  wt, dt: Matrix[float]

proc lda(docs: seq[seq[int]], vocabLen: int, K: int, iterations: int): LDAResult =
  var
    rng = wrap(initMersenneTwister(urandom(16)))
    # word-topic matrix
    wt = zeros(K, vocabLen)
    # topic assignment list
    ta = docs.mapIt(repeat(0, len(it)))
    # counts correspond to the number of words assigned to each topic
    # for each document
    dt = zeros(docs.len, K)

  # Random initialization
  for d in 0 ..< docs.len:
    # randomly assign topic to word w
    for w in 0 ..< docs[d].len:
      ta[d][w] = rng.randomInt(K)
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
        let
          left = (wt.column(wid) + eta) |/| (rowSums(wt) + L * eta)
          right = (dt.row(d) + alpha) / (dt.row(d).sum + K.float * alpha)
          prod = left |*| right
          dist = makeDiscrete(prod)
        # Sample topic from distribution
        let t1 = rng.sample(dist)
        # Update counts
        dt[d, t1] = dt[d, t1] + 1
        wt[t1, wid] = wt[t1, wid] + 1
        ta[d][w] = t1

  return LDAResult(wt: wt, dt: dt)

when isMainModule:
  let
    rawDocs = @[
        "eat turkey on turkey day holiday",
        "i like to eat cake on holiday",
        "turkey trot race on thanksgiving holiday",
        "snail race the turtle",
        "time travel space race",
        "movie on thanksgiving",
        "movie at air and space museum is cool movie",
        "aspiring movie star"
      ]
    docWords = rawDocs.mapIt(it.split(' '))
    vocab = makeVocab(docWords)
    docs = makeDocs(docWords, vocab)
    ldaResult = lda(docs, vocabLen = vocab.len, K = 3, iterations = 1000)
    wt = ldaResult.wt
    dt = ldaResult.dt

  for t in 0 ..< 3:
    echo "TOPIC ", t
    for w in 0 ..< vocab.len:
      if wt[t, w] > 1.0:
        echo vocab[w], " : ", wt[t, w]
    echo "=========="

  for d in 0 ..< docs.len:
    echo rawDocs[d]
    echo dt.row(d).maxIndex

  var
      rng = wrap(initMersenneTwister(urandom(16)))
  # generate something like document 6:
  let tDist = makeDiscrete(dt.row(6))
  for _ in 1 .. 10:
    let t = rng.sample(tDist)
    let wDist = makeDiscrete(wt.row(t))
    let w = rng.sample(wDist)
    echo vocab[w]
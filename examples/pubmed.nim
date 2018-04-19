import sequtils, strutils, parseUtils
import os, parsecsv, streams
import lda

proc simpleTokenizer(s: string): seq[string] =
  result = @[]
  const letters = {'a' .. 'z', 'A' .. 'Z', '0' .. '9'}
  var i = 0
  while i < s.len:
    i += s.skipUntil(letters, start = i)
    var token: string
    i += s.parseWhile(token, letters, start = i)
    if not token.isNil:
      result.add(token)

proc tokenize(s: string): seq[string] =
  simpleTokenizer(s).mapIt(it.toLowerAscii).filterIt(it.len >= 3)

proc readPubMed(path: string): seq[seq[string]] =
  result = @[]
  var
    s = newFileStream(path, fmRead)
    x: CsvParser
  open(x, s, path)
  defer:
    close(x)
  while readRow(x):
    let text = x.row[3]
    result.add(tokenize(text))

proc main() =
  let
    docWords = readPubMed("examples/pubmed.csv")
    vocab = makeVocab(docWords)
    docs = makeDocs(docWords, vocab)
    ldaResult = lda(docs, vocabLen = vocab.len, K = 30, iterations = 1000)

  for t in 0 ..< 3:
    echo "TOPIC ", t
    echo bestWords(ldaResult, vocab, t)

  for d in 0 ..< docs.len:
    echo "> ", docWords[d]
    echo "topic: ", ldaResult.bestTopic(d)

  # echo sample(ldaResult, vocab, doc = 6)

main()
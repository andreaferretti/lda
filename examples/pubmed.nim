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
import sequtils, strutils, parseUtils, tables, sets, sugar
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

proc cleanup(docs: seq[seq[string]]): seq[seq[string]] =
  var counts = newCountTable[string]()
  for doc in docs:
    for word in doc:
      counts.inc(word)
  var frequent = initSet[string]()
  for word, count in counts:
    if count >= 4:
      frequent.incl(word)
  sort(counts) # destructive
  var i = 0
  for word, _ in counts:
    frequent.excl(word)
    i += 1
    if i > 30: break
  return docs.map((s: seq[string]) => s.filterIt(frequent.contains(it))).filterIt(it.len >= 5)

proc main() =
  let
    docWordsRaw = readPubMed("examples/pubmed.csv")
    docWords = cleanup(docWordsRaw)
    vocab = makeVocab(docWords)
    docs = makeDocs(docWords, vocab)
    ldaResult = lda(docs, vocabLen = vocab.len, K = 30, iterations = 1000)

  for t in 0 ..< 30:
    echo "TOPIC ", t
    echo bestWords(ldaResult, vocab, t)

main()
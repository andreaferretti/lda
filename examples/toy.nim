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
import sequtils, strutils
import lda

proc main() =
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

  for t in 0 ..< 3:
    echo "TOPIC ", t
    echo bestWords(ldaResult, vocab, t)

  for d in 0 ..< docs.len:
    echo "> ", rawDocs[d]
    echo "topic: ", ldaResult.bestTopic(d)

  echo sample(ldaResult, vocab, doc = 6)

main()
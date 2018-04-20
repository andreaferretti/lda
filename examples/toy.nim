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
LDA
===

This library implements a form of text clustering and topic modeling called
[Latent Dirichlet Allocation](http://ethen8181.github.io/machine-learning/clustering_old/topic_model/LDA.html).

In order to use it, you have to have a seq of documents, each one being itself
a seq of strings. These documents can then be indexed through the use of a
vocabulary, as follows:

```nim
import sequtils, strutils
import lda

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
```

Once you have the vocabulary `vocab` , which is just the seq of all word appearing
through all documents, and the preoprocessed documents, which are a nested
sequence of integer indices, you can traing the model through Collapsed Gibbs
Sampling using

```nim
let ldaResult = lda(docs, vocabLen = vocab.len, K = 3, iterations = 1000)
```

Here `K` denotes the number of desired topics and `iterations` the number of
rounds in the training phase. The result contains a document/topic matrix
and a word/topic matrix. These can be used to find the most descriptive
words for a topic:

```nim
for t in 0 ..< 3:
  echo "TOPIC ", t
  echo bestWords(ldaResult, vocab, t)
```

or to find the most relevant topics for a document:

```nim
for d in 0 ..< docs.len:
  echo "> ", rawDocs[d]
  echo "topic: ", ldaResult.bestTopic(d)
```

or even to generate text with the same topic distribution as a given document:

```nim
echo sample(ldaResult, vocab, doc = 6)
```

## TODO

* parallel training
* variational Bayes sampling
* modified model to account for stop words
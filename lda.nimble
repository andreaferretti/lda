# Package

version       = "0.1.0"
author        = "Andrea Ferretti"
description   = "Latent Dirichlet allocation"
license       = "Apache2"
skipDirs      = @["examples", "tests"]

# Dependencies

requires "nim >= 0.18.0", "alea >= 0.1.2"

task test, "run tests":
  --path: "."
  --run
  setCommand "c", "tests/test.nim"

task toy, "run toy example":
  --path: "."
  --run
  --define: release
  --gc: markAndSweep
  setCommand "c", "examples/toy.nim"

task pubmed, "run pubmed example":
  --path: "."
  --run
  --define: release
  --gc: none
  setCommand "c", "examples/pubmed.nim"
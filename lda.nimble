# Package

version       = "0.1.0"
author        = "Andrea Ferretti"
description   = "Latent Dirichlet allocation"
license       = "Apache2"

# Dependencies

requires "nim >= 0.18.0", "neo >= 0.1.7", "alea >= 0.1.2"

task example, "run example":
  --path: "."
  --run
  --define: release
  --gc: markAndSweep
  setCommand "c", "lda.nim"
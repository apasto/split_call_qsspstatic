# Split points over multiple input files and calls, join outputs

Define a grid of *receivers* (computation points) for [QSSPSTATIC](https://www.gfz-potsdam.de/en/section/physics-of-earthquakes-and-volcanoes/infrastructure/tool-development-lab/#gfz-collapse-c66638) ([Wang et al., 2017](https://doi.org/10.1093/gji/ggx259.)), and distribute them over separate input files, overcoming the maximum number of 301 receivers (*nrmax*).

## Very minimal documentation (needs to be integrated)

At the moment, usage information is provided in the header of qsspGeneratePositions.m.

It requires:

* a grid definition: longitude and latitude extents and spatial sampling interval
* an inp-file, split at the receiver definition section: the beginning, to be prepended to points, and the part to be appended
* the maximum number of points per file

The required number of inputs file is written, alongside with a shell script to perform serial (semicolon separated) calls to qsspstastic.

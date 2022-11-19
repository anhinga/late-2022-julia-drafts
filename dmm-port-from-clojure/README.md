# Sketching a port from 2016-2018 DMM Clojure implementation (draft)

Preliminary port to Julia while taking into account v0-1 and v0-2 of https://github.com/anhinga/julia-flux-drafts/tree/main/arxiv-1606-09470-section3/May-August-2022

The difference from v0-2 is that we are not immediately seeking to work with Zygote.jl

Instead the plan is to sketch a port from https://github.com/jsa-aerial/DMM and then to lightly upgrade it.

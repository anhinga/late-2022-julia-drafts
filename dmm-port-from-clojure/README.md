# Sketching a port from 2016-2018 DMM Clojure implementation (draft)

Preliminary port to Julia while taking into account v0-1 and v0-2 of https://github.com/anhinga/julia-flux-drafts/tree/main/arxiv-1606-09470-section3/May-August-2022

The difference from v0-2 is that we are not immediately seeking to work with Zygote.jl

Instead the plan is to sketch a port from https://github.com/jsa-aerial/DMM and then to lightly upgrade it.

***

A mutable quick version in the style of [May-August-2022](https://github.com/anhinga/julia-flux-drafts/tree/main/arxiv-1606-09470-section3/May-August-2022)
and not a refined carefully designed [jsa-aerial/DMM](https://github.com/jsa-aerial/DMM)

This is still just a sketch. We'll keep the first iteration type-free (in line with its Clojure prototype).

***

`draft-ops.jl`:

  * function `mult_v_value` - port of `rec-map-mult`
  * function `add_v_values` - port of `rec-map-sum`
  * function `mult_mask_v_value` - port of `rec-map-mult-mask`
  * function `mult_mask_lin_comb` - port of `rec-map-lin-comb`
  
`draft-engine.jl`:

  * function `apply_v_valued_matrix` - port of `apply-matrix`

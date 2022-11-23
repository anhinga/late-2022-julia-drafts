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
  
***

I am pondering this dichotomy in the `up-movement` (section 2.3, page 5 of https://www.cs.brandeis.edu/~bukatin/dmm-notes-2018.pdf):

"We use 6-dimensional tensors as network matrices in our current implementation
of DMMs based on V-values and variadic neurons. (We have also considered
removing the activation function from that and making it a parameter of a
neuron, with a possibility of using a linear combination of activation functions,
which would lead to 4-dimensional tensors as network matrices.)"

I think in a dynamically expanding network where one wants to have a countable
address space for every possible built-in function, the use of a linear combination
might be a nice option. Then one would truly have just one type of neuron,
with the actual behavior being set-up dynamically.

Doing it this way would be an upgrade from the Clojure version.

This would result in a **"superfluid"** version of untyped DMMs,
with neurons really being of a single type (that is, capable of
"morphing" between types).

An even more advanced version would just use a source code of
an activation function as an index, but we are not pursuing that
here: we'll maintain a dictionary of functions (the idea of
using a function itself for the purpose of indexing which has been
adopted in the Clojure implementation does seem suboptimal from
our experience back then).



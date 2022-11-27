include("draft-ops.jl")
include("draft_activations.jl")
include("draft-engine.jl")

# The goal is to port https://github.com/jsa-aerial/DMM/blob/master/examples/dmm/oct_19_2016_experiment.clj with some mild modifications

# This is the initial Project Fluid Aug 27, 2016 experiment of the network creating a wave pattern in its own connectivity matrix

# the network will consist of 4 neurons: "self", "update-1", "update-2", and "update-3".

# Activation functions are "accum_add_args" and 3 constants (that's a change from the Clojure prototype) corresponding to

#=
(def update-1-matrix
  (rec-map-sum {v-accum {:self {:delta {v-identity {:update-1 {:single -1}}}}}}
               {v-accum {:self {:delta {v-identity {:update-2 {:single 1}}}}}}))

(def update-2-matrix
  (rec-map-sum {v-accum {:self {:delta {v-identity {:update-2 {:single -1}}}}}}
               {v-accum {:self {:delta {v-identity {:update-3 {:single 1}}}}}}))

(def update-3-matrix
  (rec-map-sum {v-accum {:self {:delta {v-identity {:update-3 {:single -1}}}}}}
               {v-accum {:self {:delta {v-identity {:update-1 {:single 1}}}}}}))

=#

function update_1(all_inputs)
    return Dict{String, Any}("result"=>...

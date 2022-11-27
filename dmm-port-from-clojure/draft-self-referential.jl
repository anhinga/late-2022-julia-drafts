include("draft-ops.jl")
include("draft-activations.jl")
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

using PrettyPrinting # need something to alleviate inconvenience



function matrix_element(to_neuron, to_input, from_neuron, from_output, value = 1.0)
    Dict{String, Any}(to_neuron=>Dict{String, Any}(to_input=>Dict{String, Any}(from_neuron=>Dict{String, Any}(from_output=>value))))
end

function update_1(all_inputs)
    return Dict{String, Any}("result"=>add_v_values(matrix_element("self", "delta", "update-1", "result", -1.0),
                                                    matrix_element("self", "delta", "update-2", "result")))
end
  
function update_2(all_inputs)
    return Dict{String, Any}("result"=>add_v_values(matrix_element("self", "delta", "update-2", "result", -1.0),
                                                    matrix_element("self", "delta", "update-3", "result")))
end

function update_3(all_inputs)
    return Dict{String, Any}("result"=>add_v_values(matrix_element("self", "delta", "update-3", "result", -1.0),
                                                    matrix_element("self", "delta", "update-1", "result")))
end

#=
  
julia> pprint(update_1(nothing))
Dict("result" => Dict("self" => Dict("delta" => Dict("update-1" => Dict("result" => -1.0),
                                                     "update-2" => Dict("result" => 1.0)))))
=#

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

add_activation(update_1)
add_activation(update_2)
add_activation(update_3)
  
# =======================================================================================================
  
#=
  
(def init-matrix
  {v-accum {:self {:accum {v-accum {:self {:single 1}}}}}})

(def update-1-matrix-hook
  {v-identity {:update-1 {:single {v-identity {:update-1 {:single 1}}}}}})

(def update-2-matrix-hook
  {v-identity {:update-2 {:single {v-identity {:update-2 {:single 1}}}}}})

(def update-3-matrix-hook
  {v-identity {:update-3 {:single {v-identity {:update-3 {:single 1}}}}}})

(def start-update-of-network-matrix
  {v-accum {:self {:delta {v-identity {:update-1 {:single 1}}}}}})
  
BUT HOOKS ARE DIFFERENT IN OUR NEW DISCIPLINE
  
=#
  
init_matrix = Dict{String, Any}("result"=>Dict{String, Any}())

function add_to_init_matrix(x...)
    init_matrix["result"] = add_v_values(init_matrix["result"], matrix_element(x...))
end
    
add_to_init_matrix("self", "accum", "self", "result")
    
add_to_init_matrix("self", "delta", "update-1", "result")
  
add_to_init_matrix("self", ":function", "self", ":function")
  
add_to_init_matrix("update-1", ":function", "update-1", ":function") 
    
add_to_init_matrix("update-2", ":function", "update-2", ":function") 
  
add_to_init_matrix("update-3", ":function", "update-3", ":function") 

#=
julia> pprint(init_matrix)
Dict("result" => Dict("update-3" => Dict(":function" => Dict("update-3" => Dict(":function" => 1.0))),
                      "self" => Dict("accum" => Dict("self" => Dict("result" => 1.0)),
                                     ":function" => Dict("self" => Dict(":function" => 1.0)),
                                     "delta" => Dict("update-1" => Dict("result" => 1.0))),
                      "update-1" => Dict(":function" => Dict("update-1" => Dict(":function" => 1.0))),
                      "update-2" => Dict(":function" => Dict("update-2" => Dict(":function" => 1.0)))))
=#
  
initial_output = Dict{String, Any}()

initial_output["self"] = deepcopy(init_matrix)
  
initial_output["update-1"] = update_1(nothing)["result"]
  
initial_output["update-2"] = update_2(nothing)["result"]

initial_output["update-3"] = update_3(nothing)["result"]
  
#=
julia> pprint(initial_output)
Dict("update-3" => Dict("self" => Dict("delta" => Dict("update-3" => Dict("result" => -1.0),
                                                       "update-1" => Dict("result" => 1.0)))),
     "self" => Dict("result" => Dict("update-3" => Dict(":function" => Dict("update-3" => Dict(":function" => 1.0))),
                                     "self" => Dict("accum" => Dict("self" => Dict("result" => 1.0)),
                                                    ":function" => Dict("self" => Dict(":function" => 1.0)),
                                                    "delta" => Dict("update-1" => Dict("result" => 1.0))),
                                     "update-1" => Dict(":function" => Dict("update-1" => Dict(":function" => 1.0))),
                                     "update-2" => Dict(":function" => Dict("update-2" => Dict(":function" => 1.0))))),
     "update-1" => Dict("self" => Dict("delta" => Dict("update-1" => Dict("result" => -1.0),
                                                       "update-2" => Dict("result" => 1.0)))),
     "update-2" => Dict("self" => Dict("delta" => Dict("update-3" => Dict("result" => 1.0),
                                                       "update-2" => Dict("result" => -1.0)))))
=#

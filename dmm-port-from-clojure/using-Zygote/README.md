### Experiments with using Zygote to compute gradients with the new superfluid architecture

[first-attempt.jl](first-attempt.jl) - the gradients work correctly through things like

```julia
apply_v_valued_matrix(current_output["self"]["result"], current_output, 2)
```

and in this particular case in the `loss5` function this has been a quadratic operation with
non-trivial derivatives both via matrix and via argument, and this has been computed correctly:

```julia
julia> this_grad = gradient(loss5, step4)
loss: 2.0 type of loss: Float64
(Dict{Any, Any}("output" => Dict{Any, Any}("self" => Dict{Any, Any}("result" => Dict{Any, Any}("self" => Dict{Any, Any}("accum" => Dict{Any, Any}("self" => Dict{Any, Any}("result" => 6.0))))))),)
```

However, the derivatives through the up-movement are getting lost; the way I am playing with
functions is too complicated for Zygote, so I should modify this part of the code.

Currently I have the following preliminary sketch

```julia
function up_movement(all_input_trees)
    result = Dict{String, Any}()
    for neuron_name in keys(all_input_trees)
        input_tree = all_input_trees[neuron_name]
        dict_of_functions = input_tree[":function"]
        result[neuron_name] = Dict{String, Any}()
        for k in keys(dict_of_functions) # do I hate doing all this with mutable structures, or what?!
            println("Neuron name: ", neuron_name)
            println("k: ", k)
            summand = mult_v_value(dict_of_functions[k], activation_functions[k](input_tree))
            result[neuron_name] = add_v_values(result[neuron_name], summand)
        end
        result[neuron_name][":function"] = deepcopy(dict_of_functions) # yes, I do hate doing this with mutables
                                                                       # but it is what it is for now
                                                                       # (this order of operations enforces ":function" discipline)
    end
    result
end

```

(Another remark is that when a gradient through a dictionary is "pure zero", what is returned is
`nothing` instead of an empty dictionary - one might need to watch out for that in various situations.) 

---

I narrowed the problem down to the following:

```julia
function loss7(state)    
	#new_state = two_stroke_cycle(state["output"])
	current_output = state["output"]
	new_input = apply_v_valued_matrix(current_output["self"]["result"], current_output, 2)
	l1 = state["output"]["self"]["result"]["self"]["accum"]["self"]["result"]
    l1 = square(l1)
    l = new_input["self"]["accum"]["self"]["accum"]["self"]["result"]
    l = square(l)
	#new_output = up_movement(new_input)
	#l2 = new_output["self"]["result"]["self"]["accum"]["self"]["result"]
    Zygote.@ignore pprintln(new_input["self"])
	new_self = accum_add_args(new_input["self"])
    Zygote.@ignore pprintln(new_self)
	l2 = new_self["result"]["self"]["accum"]["self"]["result"]
	l2 = square(l2)
	l_sum = l + l1 + l2
	Zygote.@ignore println("loss: ", l_sum, " type of loss: ", typeof(l_sum))
    l_sum
end	 	 
```

Here the gradient of `l2` computed via `accum_add_args` is zero, when it should not be.

Note that

```julia
function accum_add_args(all_inputs)
    all_outputs = Dict{String, Any}()
    all_outputs["result"] = add_v_values(all_inputs["accum"], all_inputs["delta"])
    all_outputs
end
```

and

```julia
function add_v_values(a_v_value, b_v_value)
    result = Dict{String, Any}()
    for k in keys(b_v_value)
        if !haskey(a_v_value, k)
            result[k] = deepcopy(b_v_value[k])
        end
    end
    for k in keys(a_v_value)
        if !haskey(b_v_value, k)
            result[k] = deepcopy(a_v_value[k])
        else
            # remaining processing
            a_sub = a_v_value[k]
            b_sub = b_v_value[k]
            if (typeof(a_sub) <: Number) && (typeof(b_sub) <: Number)
                result[k] = a_sub + b_sub
            elseif typeof(a_sub) <: Number
                result[k] = add_v_values(b_sub, Dict{String, Any}(":number"=>a_sub))
            elseif typeof(b_sub) <: Number
                result[k] = add_v_values(a_sub, Dict{String, Any}(":number"=>b_sub))
            else
                result[k] = add_v_values(a_sub, b_sub)
            end
        end
    end	
    result
end
```

This is what's printed

```julia
julia> this_grad = gradient(loss7, step4)
Dict("accum" => Dict("update-3" => Dict(":function" => Dict("update-3" => Dict(":function" => 1.0))),
                     "self" => Dict("accum" => Dict("self" => Dict("result" => 1.0)),
                                    ":function" => Dict("self" => Dict(":function" => 1.0)),
                                    "delta" => Dict("update-3" => Dict("result" => 0.0),
                                                    "update-1" => Dict("result" => 0.0),
                                                    "update-2" => Dict("result" => 1.0))),
                     "update-1" => Dict(":function" => Dict("update-1" => Dict(":function" => 1.0))),
                     "update-2" => Dict(":function" => Dict("update-2" => Dict(":function" => 1.0)))),
     ":function" => Dict("accum_add_args" => 1.0),
     "delta" => Dict("self" => Dict("delta" => Dict("update-3" => Dict("result" => 1.0),
                                                    "update-1" => Dict("result" => 0.0),
                                                    "update-2" => Dict("result" => -1.0)))))
Dict("result" => Dict("update-3" => Dict(":function" => Dict("update-3" => Dict(":function" => 1.0))),
                      "self" => Dict("accum" => Dict("self" => Dict("result" => 1.0)),
                                     ":function" => Dict("self" => Dict(":function" => 1.0)),
                                     "delta" => Dict("update-3" => Dict("result" => 1.0),
                                                     "update-1" => Dict("result" => 0.0),
                                                     "update-2" => Dict("result" => 0.0))),
                      "update-1" => Dict(":function" => Dict("update-1" => Dict(":function" => 1.0))),
                      "update-2" => Dict(":function" => Dict("update-2" => Dict(":function" => 1.0)))))
loss: 3.0 type of loss: Float64
(Dict{Any, Any}("output" => Dict{Any, Any}("self" => Dict{Any, Any}("result" => Dict{Any, Any}("self" => Dict{Any, Any}("accum" => Dict{Any, Any}("self" => Dict{Any, Any}("result" => 6.0))))))),)
```

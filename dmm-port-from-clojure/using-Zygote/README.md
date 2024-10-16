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
functions is too complicated for Zygote, so I should modify this part of the code. _(That conjecture
turned out to be incorrect, the error is in something else.)_

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

---

Also here is a bug report:

`accum_add_args(Dict("accum" => 3.0, "delta" => 5.0))` does not work, because the current implementation
would check `haskey` on a scalar in this case (we are not testing this at the moment, but this needs to be fixed).
_(I filed the first issue in this repository making a note of that.)_

---

But when we try to localize this `accum_add_args` gradient problem, things do work:

```julia
julia> c = Dict("accum" => Dict("update-3" => Dict(":function" => Dict("update-3" => Dict(":function" => 1.0))),
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
Dict{String, Dict{String}} with 3 entries:
  "accum"     => Dict("update-3"=>Dict(":function"=>Dict("update-3"=>Dict(":function"=>1.0))), "self"=>Dict("accum"=>Di…
  ":function" => Dict("accum_add_args"=>1.0)
  "delta"     => Dict("self"=>Dict("delta"=>Dict("update-3"=>Dict("result"=>1.0), "update-1"=>Dict("result"=>0.0), "upd…
  
julia> pprint(accum_add_args(c))
Dict("result" => Dict("update-3" => Dict(":function" => Dict("update-3" => Dict(":function" => 1.0))),
                      "self" => Dict("accum" => Dict("self" => Dict("result" => 1.0)),
                                     ":function" => Dict("self" => Dict(":function" => 1.0)),
                                     "delta" => Dict("update-3" => Dict("result" => 1.0),
                                                     "update-1" => Dict("result" => 0.0),
                                                     "update-2" => Dict("result" => 0.0))),
                      "update-1" => Dict(":function" => Dict("update-1" => Dict(":function" => 1.0))),
                      "update-2" => Dict(":function" => Dict("update-2" => Dict(":function" => 1.0)))))
                      
julia> square(x) = x*x
square (generic function with 1 method)

julia> test_c(x) = square(accum_add_args(x)["result"]["self"]["accum"]["self"]["result"])
test_c (generic function with 1 method)

julia> test_c(c)
1.0

julia> gradient(test_c, c)
(Dict{Any, Any}("accum" => Dict{Any, Any}("self" => Dict{Any, Any}("accum" => Dict{Any, Any}("self" => Dict{Any, Any}("result" => 2.0))))),)                    
```

So the problem is more subtle - some kind of composition in `loss7` and Zygote don't play well together.

---

Computing numerical derivative of `loss7` via

```julia
julia> step4["output"]["self"]["result"]["self"]["accum"]["self"]["result"] += 0.01
1.01

julia> loss7(step4)
Dict("accum" => Dict("update-3" => Dict(":function" => Dict("update-3" => Dict(":function" => 1.01))),
                     "self" => Dict("accum" => Dict("self" => Dict("result" => 1.0201)),
                                    ":function" => Dict("self" => Dict(":function" => 1.01)),
                                    "delta" => Dict("update-3" => Dict("result" => 0.0),
                                                    "update-1" => Dict("result" => 0.0),
                                                    "update-2" => Dict("result" => 1.01))),
                     "update-1" => Dict(":function" => Dict("update-1" => Dict(":function" => 1.01))),
                     "update-2" => Dict(":function" => Dict("update-2" => Dict(":function" => 1.01)))),
     ":function" => Dict("accum_add_args" => 1.0),
     "delta" => Dict("self" => Dict("delta" => Dict("update-3" => Dict("result" => 1.0),
                                                    "update-1" => Dict("result" => 0.0),
                                                    "update-2" => Dict("result" => -1.0)))))
Dict("result" => Dict("update-3" => Dict(":function" => Dict("update-3" => Dict(":function" => 1.01))),
                      "self" => Dict("accum" => Dict("self" => Dict("result" => 1.0201)),
                                     ":function" => Dict("self" => Dict(":function" => 1.01)),
                                     "delta" => Dict("update-3" => Dict("result" => 1.0),
                                                     "update-1" => Dict("result" => 0.0),
                                                     "update-2" => Dict("result" => 0.010000000000000009))),
                      "update-1" => Dict(":function" => Dict("update-1" => Dict(":function" => 1.01))),
                      "update-2" => Dict(":function" => Dict("update-2" => Dict(":function" => 1.01)))))
loss: 3.1013080200000003 type of loss: Float64
3.1013080200000003

julia> step4["output"]["self"]["result"]["self"]["accum"]["self"]["result"] -= 0.02
0.99

julia> loss7(step4)
Dict("accum" => Dict("update-3" => Dict(":function" => Dict("update-3" => Dict(":function" => 0.99))),
                     "self" => Dict("accum" => Dict("self" => Dict("result" => 0.9801)),
                                    ":function" => Dict("self" => Dict(":function" => 0.99)),
                                    "delta" => Dict("update-3" => Dict("result" => 0.0),
                                                    "update-1" => Dict("result" => 0.0),
                                                    "update-2" => Dict("result" => 0.99))),
                     "update-1" => Dict(":function" => Dict("update-1" => Dict(":function" => 0.99))),
                     "update-2" => Dict(":function" => Dict("update-2" => Dict(":function" => 0.99)))),
     ":function" => Dict("accum_add_args" => 1.0),
     "delta" => Dict("self" => Dict("delta" => Dict("update-3" => Dict("result" => 1.0),
                                                    "update-1" => Dict("result" => 0.0),
                                                    "update-2" => Dict("result" => -1.0)))))
Dict("result" => Dict("update-3" => Dict(":function" => Dict("update-3" => Dict(":function" => 0.99))),
                      "self" => Dict("accum" => Dict("self" => Dict("result" => 0.9801)),
                                     ":function" => Dict("self" => Dict(":function" => 0.99)),
                                     "delta" => Dict("update-3" => Dict("result" => 1.0),
                                                     "update-1" => Dict("result" => 0.0),
                                                     "update-2" => Dict("result" => -0.010000000000000009))),
                      "update-1" => Dict(":function" => Dict("update-1" => Dict(":function" => 0.99))),
                      "update-2" => Dict(":function" => Dict("update-2" => Dict(":function" => 0.99)))))
loss: 2.9012920199999996 type of loss: Float64
2.9012920199999996
```

we see that the true value of derivative should be 10, and not 6 (the presence of two paths via two instances of
`current_output` propagates to `l2`). _(It's still unclear what caused the bug, or what might be a workaround.)_

---

Simplyfying further (still have the same bug):

```julia
function copy_accum(all_inputs)
    all_outputs = Dict{String, Any}()
    all_outputs["result"] = deepcopy(all_inputs["accum"])
    all_outputs
end


function loss8(state)    
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
    new_self = copy_accum(new_input["self"])
    Zygote.@ignore pprintln(new_self)
    l2 = new_self["result"]["self"]["accum"]["self"]["result"]
    l2 = square(l2)
    l_sum = l + l1 + l2
    Zygote.@ignore println("loss: ", l_sum, " type of loss: ", typeof(l_sum))
    l_sum
end
```

```julia
julia> loss8(step4)
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
                                     "delta" => Dict("update-3" => Dict("result" => 0.0),
                                                     "update-1" => Dict("result" => 0.0),
                                                     "update-2" => Dict("result" => 1.0))),
                      "update-1" => Dict(":function" => Dict("update-1" => Dict(":function" => 1.0))),
                      "update-2" => Dict(":function" => Dict("update-2" => Dict(":function" => 1.0)))))
loss: 3.0 type of loss: Float64
3.0

julia> gradient(loss8, step4)
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
                                     "delta" => Dict("update-3" => Dict("result" => 0.0),
                                                     "update-1" => Dict("result" => 0.0),
                                                     "update-2" => Dict("result" => 1.0))),
                      "update-1" => Dict(":function" => Dict("update-1" => Dict(":function" => 1.0))),
                      "update-2" => Dict(":function" => Dict("update-2" => Dict(":function" => 1.0)))))
loss: 3.0 type of loss: Float64
(Dict{Any, Any}("output" => Dict{Any, Any}("self" => Dict{Any, Any}("result" => Dict{Any, Any}("self" => Dict{Any, Any}("accum" => Dict{Any, Any}("self" => Dict{Any, Any}("result" => 6.0))))))),)
```

---

**Oct 10-11, 2024 update with Julia 1.10.5 and Julia 1.11.0 and Zygote 0.6.71:**

Uncommenting the last computations in [first-attempt.jl](first-attempt.jl) one gets the following rather than `(nothing,)`:

```
julia> this_grad
(Dict{Any, Any}("output" => Dict{Any, Any}("self" => Dict{Any, Any}("result" => Dict{Any, Any}("self" => Dict{Any, Any}("accum" => Dict{Any, Any}("self" => Dict{Any, Any}("result" => 1.0))))))),)
```

But the gradient in `gradient(loss8, step4)` is still 6.0 and not 10.0

So, this (superficially) looks like some of these problems got fixed since May 2023, but not all of them (a closer investigation is desirable).

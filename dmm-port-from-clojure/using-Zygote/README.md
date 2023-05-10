### Experiments with using Zygote to compute gradients with the new superfluid architecture

[first-attempt.jl](first-attempt.jl) - the gradients work correctly through things like

```julia
apply_v_valued_matrix(current_output["self"]["result"], current_output, 2)
```

and in this particular case in the `loss5` function this has been a quadratic operation with
non-trivial derivatives both via matrix and via argument, and this has been computed correctly.

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

activation_functions = Dict{String, Function}()

function add_activation(f)
    activation_functions[String(Symbol(f))] = f
end

function accum_add_args(all_inputs)
    all_outputs = Dict{String, Any}()
    all_outputs["result"] = add_v_values(all_inputs["accum"], all_inputs["delta"])
    all_outputs
end

add_activation(accum_add_args)

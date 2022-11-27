activation_functions = Dict{String, Function}()

function accum_add_args(all_inputs)
    all_outputs = Dict{String, Any}()
    all_outputs["result"] = add_v_values(all_inputs["accum"], all_inputs["delta"])
    all_outputs
end

activation_functions["accum_add_args"] = accum_add_args

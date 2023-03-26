# superfluid dataflow matrix machines engine

# ops

function mult_v_value(multiplier, v_value)
    result = Dict{String, Any}()
    for k in keys(v_value)
        value = v_value[k]
        if typeof(value) <: Number
            result[k] = multiplier*value
        else
            result[k] = mult_v_value(multiplier, value)
        end
    end
    result
end

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

function mult_mask_v_value(mult_mask, v_value)
    result = Dict{String, Any}()
    for k in keys(mult_mask)
        if haskey(v_value, k)
            value = v_value[k]
            mask = mult_mask[k]
            if (typeof(mask) <: Number) && (typeof(value) <: Number)
                result[k] = mask*value
            elseif typeof(mask) <: Number
                result[k] = mult_v_value(mask, value)
            elseif typeof(value) <: Number
                # result[k] is not created
            else
                result[k] = mult_mask_v_value(mask, value)
            end			
        end
    end
    result
end

function mult_mask_lin_comb(mult_mask, v_value)
    result = Dict{String, Any}()
    for k in keys(mult_mask)
        if haskey(v_value, k)
            value = v_value[k]
            mask = mult_mask[k]
            new_value = 0
            if (typeof(mask) <: Number) && (typeof(value) <: Number)
                new_value = mask*value
            elseif typeof(mask) <: Number
                new_value = mult_v_value(mask, value)
            elseif typeof(value) <: Number
                # new_value unchanged
            else
                new_value = mult_mask_lin_comb(mask, value)
            end			
            # slightly optimized internals of result = add_v_values(result, new_value)
            if typeof(new_value) <: Dict
                if isempty(result) # this is the mild optimization mentioned above
                    result = new_value
                else
                    result = add_v_values(result, new_value) # do I hate doing this in a mutable fashion!
                end
                elseif !iszero(new_value) 
                    result = add_v_values(result, Dict{String, Any}(":number"=>new_value)) # does this create more ":number"=> than the original intent?
            end
        end
    end
    result
end

# activations

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

# draft engine

function apply_v_valued_matrix(v_valued_matrix, v_valued_args, level)
    if iszero(level)
        mult_mask_lin_comb(v_valued_matrix, v_valued_args)
    else
        result = Dict{String, Any}()
        for k in keys(v_valued_matrix)
            result[k] = apply_v_valued_matrix(v_valued_matrix[k], v_valued_args, level-1)
        end
        result
    end
end

# a preliminary sketch of the "superfluid" version of up_movement

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


# self-referential machine


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

add_activation(update_1)
add_activation(update_2)
add_activation(update_3)
  
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
  
initial_output = Dict{String, Any}()

initial_output["self"] = deepcopy(init_matrix)
  
initial_output["update-1"] = deepcopy(update_1(nothing))
  
initial_output["update-2"] = deepcopy(update_2(nothing))

initial_output["update-3"] = deepcopy(update_3(nothing))
  
initial_output["self"][":function"] = Dict{String, Any}("accum_add_args"=>1.0)
  
initial_output["update-1"][":function"] = Dict{String, Any}("update_1"=>1.0)
  
initial_output["update-2"][":function"] = Dict{String, Any}("update_2"=>1.0)

initial_output["update-3"][":function"] = Dict{String, Any}("update_3"=>1.0)
  
function two_stroke_cycle(current_output)
    # down movement
    new_input = apply_v_valued_matrix(current_output["self"]["result"], current_output, 2)
    println("===== NEW INPUT:")
    pprintln(new_input)
    new_output = up_movement(new_input)    
    println("***** NEW OUTPUT:")
    pprintln(new_output)
    Dict("input"=>new_input, "output"=>new_output)
end

# example of use

pprint(initial_output)
step1 = two_stroke_cycle(initial_output)
step2 = two_stroke_cycle(step1["output"])
step3 = two_stroke_cycle(step2["output"])
step4 = two_stroke_cycle(step3["output"])  

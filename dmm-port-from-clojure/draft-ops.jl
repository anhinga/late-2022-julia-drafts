# relevant Julia code from dmm-lite.jl

#=

# overly verbose as a workaround for Zygote.jl defects
function get_N(dict::Dict{String, Float32}, k::String)
    if haskey(dict, k)
	   return dict[k]
	else
	   return zero_value
    end
end

function add_term_to_dict!(dict_to_change::Dict{String, Float32}, multiplier::Float32, dict_as_delta::Dict{String, Float32})
    for k in keys(dict_as_delta)
        dict_to_change[k] = get_N(dict_to_change, k) + multiplier*dict_as_delta[k]
    end
end
=#

# relevant Clojure code from dmm/core.clj

#=
(defn rec-map-op
  ([op unit? n M]
   (if (unit? n)
     M
     (rec-map-op op n M)))
  ([op n M]
   (reduce (fn [M [k v]]
             (let [new-v
                   (cond
                     (map? v) (rec-map-op op n v)
                     (number? v) (op v n)
                     :else 0)]
               (if (nullelt? new-v) M (assoc M k new-v))))
           {} M)))


(defn rec-map-mult [n M]
  (if (zero? n)
    {}
    (rec-map-op * one? n M)))
=#

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

#=
test

julia> a = Dict("a"=>2, "b"=>3.0, "c"=>Dict("u"=>1.0))
Dict{String, Any} with 3 entries:
  "c" => Dict("u"=>1.0)
  "b" => 3.0
  "a" => 2

julia> mult_v_value(5, a)
Dict{String, Any} with 3 entries:
  "c" => Dict{String, Any}("u"=>5.0)
  "b" => 15.0
  "a" => 10

julia> a
Dict{String, Any} with 3 entries:
  "c" => Dict("u"=>1.0)
  "b" => 3.0
  "a" => 2

=#

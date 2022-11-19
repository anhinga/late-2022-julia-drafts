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



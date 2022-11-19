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

# not doing anything special for multiplier equal to 1 unlike the Clojure version (revisit)

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

# relevant Clojure code from dmm/core.clj

#=
(defn rec-map-sum
  ([large-M small-M] ; "large" and "small" express intent
   (reduce (fn [M [k small-v]]
             (let [large-v (get large-M k)
                   l-v (if (not (mORn? large-v)) 0 large-v)
                   s-v (if (not (mORn? small-v)) 0 small-v)
                   new-v
                   (cond
                     (maps? l-v s-v)  (rec-map-sum l-v s-v)
                     (mANDn? l-v s-v) (rec-map-sum l-v (numelt s-v))
                     (mANDn? s-v l-v) (rec-map-sum s-v (numelt l-v))
                     :else (+ l-v s-v))]
               (if (nullelt? new-v) (dissoc M k) (assoc M k new-v))))
           large-M small-M))
  ([rm1 rm2 rm3 & rms]
   (reduce (fn [new-sum y]
             (rec-map-sum new-sum y))
           rm1 (cons rm2 (cons rm3 rms)))))
=#

#=

cases for c = a+b

if only one of a[k] and b[k] exists, that subtree becomes c[k]
if a[k] and b[k] are v-values, c[k] = a[k]+b[k] (sum of v-values)
if a[k] and b[k] are numbers, c[k] = a[k]+b[k] (sum of numbers)
if a[k] is a v-value and b[k] is a number, c[k]=a[k]+Dict(":number"=>b[k])
if a[k] is a number and b[k] is a v-value, c[k]=b[k]+Dict(":number"=>a[k])

=#

# not done; perhaps we should just redo this functionally, per above spec

function add_to_v_value!(dense_v_value, sparse_v_value) # dense and sparse here is informal intent only
    summand = deepcopy(sparse_v_value) # because we might reuse subtrees (that's our penalty for using mutable values at all, too easy to create a bug)
    for k in keys(summand)
        subsparse = summand[k]
        if haskey(dense_v_value, k)
            subdense
        dict_to_change[k] = get_N(dict_to_change, k) + multiplier*dict_as_delta[k]
    end	
end

function add_v_values(dense_v_value, sparse_v_value) # dense and sparse here is informal intent only
    result = deepcopy(dense_v_value)
    add_to_v_value!(result, sparse_v_value)
    result
end

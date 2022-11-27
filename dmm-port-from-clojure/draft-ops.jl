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

# paying some penalty for not using immutable structures with shared substructure, but OK otherwise
# except that it's not purging zeros, unlike the Clojure version (this should probably be done separately anyway)

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

#=
a bit of test (need more)

julia> add_v_values(a, a)
Dict{String, Any} with 3 entries:
  "c" => Dict{String, Any}("u"=>2.0)
  "b" => 6.0
  "a" => 4

julia> a
Dict{String, Any} with 3 entries:
  "c" => Dict("u"=>1.0)
  "b" => 3.0
  "a" => 2

julia> b = mult_v_value(-1, a)
Dict{String, Any} with 3 entries:
  "c" => Dict{String, Any}("u"=>-1.0)
  "b" => -3.0
  "a" => -2

julia> add_v_values(a, b)
Dict{String, Any} with 3 entries:
  "c" => Dict{String, Any}("u"=>0.0)
  "b" => 0.0
  "a" => 0

julia> add_v_values(b, a)
Dict{String, Any} with 3 entries:
  "c" => Dict{String, Any}("u"=>0.0)
  "b" => 0.0
  "a" => 0

julia> d = Dict("u"=>-2.0)
Dict{String, Float64} with 1 entry:
  "u" => -2.0

julia> add_v_values(a, d)
Dict{String, Any} with 4 entries:
  "c" => Dict("u"=>1.0)
  "b" => 3.0
  "u" => -2.0
  "a" => 2

julia> e = Dict("c"=>6.0)
Dict{String, Float64} with 1 entry:
  "c" => 6.0

julia> e = Dict("c"=>6.0)
Dict{String, Float64} with 1 entry:
  "c" => 6.0

julia> add_v_values(a, e)
Dict{String, Any} with 3 entries:
  "c" => Dict{String, Any}(":number"=>6.0, "u"=>1.0)
  "b" => 3.0
  "a" => 2

julia> e=Dict{String, Any}("c"=>6.0)
Dict{String, Any} with 1 entry:
  "c" => 6.0

julia> add_v_values(a, e)
Dict{String, Any} with 3 entries:
  "c" => Dict{String, Any}(":number"=>6.0, "u"=>1.0)
  "b" => 3.0
  "a" => 2
=#

# relevant Clojure code from dmm/core.clj

#=
;;; generalized multiplicative masks and linear combinations

;;; a recurrent map Mask (mult-mask) and a recurrent map Structured
;;; Vector (M) traverse the Mask; for each numerical leaf in the Mask,
;;; if the path corresponding to the leaf exists in the Structured Vector,
;;; take the result of multiplication of that leaf by the rec-map or
;;; number corresponding to that path in the Structured Vector.
;;; Otherwise just drop the path from the result.

;;; note that in the current version if (:number x) is present
;;; in the mult-mask instead of x, it would not work correctly.

;;; further note: meditate whether equality of a multiplier to 1
;;; requires a special consideration

(defn rec-map-mult-mask [mult-mask M]
  (reduce (fn [new-M [k mask]]
            (let [m (get M k)
                  actual-M (if (not (mORn? m)) 0 m)
                  actual-mask (if (not (mORn? mask)) 0 mask)
                  new-v
                    (cond
                      (maps? actual-mask actual-M)
                      (rec-map-mult-mask actual-mask actual-M)

                      (mANDn? actual-M actual-mask)
                      (rec-map-mult actual-mask actual-M) ; leaf works!

                      (mANDn? actual-mask actual-M) 0
                      :else (* actual-M actual-mask))]

              (if (nullelt? new-v) new-M (assoc new-M k new-v))))
          {} mult-mask))
=#

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

#=

some tests

julia> mult_mask_v_value(a, a)
Dict{String, Any} with 3 entries:
  "c" => Dict{String, Any}("u"=>1.0)
  "b" => 9.0
  "a" => 4

julia> a
Dict{String, Any} with 3 entries:
  "c" => Dict("u"=>1.0)
  "b" => 3.0
  "a" => 2

julia> e
Dict{String, Any} with 1 entry:
  "c" => 6.0

julia> mult_mask_v_value(e, a)
Dict{String, Any} with 1 entry:
  "c" => Dict{String, Any}("u"=>6.0)

julia> mult_mask_v_value(a, e)
Dict{String, Any}()

julia> mult_mask_v_value(d, a)
Dict{String, Any}()

julia> f = add_v_values(a, e)
Dict{String, Any} with 3 entries:
  "c" => Dict{String, Any}(":number"=>6.0, "u"=>1.0)
  "b" => 3.0
  "a" => 2

julia> a
Dict{String, Any} with 3 entries:
  "c" => Dict("u"=>1.0)
  "b" => 3.0
  "a" => 2

julia> a["c"]=Dict{String, Any}("u"=>2.5)
Dict{String, Any} with 1 entry:
  "u" => 2.5

julia> a
Dict{String, Any} with 3 entries:
  "c" => Dict{String, Any}("u"=>2.5)
  "b" => 3.0
  "a" => 2

julia> mult_mask_v_value(f, a)
Dict{String, Any} with 3 entries:
  "c" => Dict{String, Any}("u"=>2.5)
  "b" => 9.0
  "a" => 4

julia> mult_mask_v_value(a, f)
Dict{String, Any} with 3 entries:
  "c" => Dict{String, Any}("u"=>2.5)
  "b" => 9.0
  "a" => 4

julia> a["c"]=2.5
2.5

julia> a
Dict{String, Any} with 3 entries:
  "c" => 2.5
  "b" => 3.0
  "a" => 2

julia> mult_mask_v_value(a, f)
Dict{String, Any} with 3 entries:
  "c" => Dict{String, Any}(":number"=>15.0, "u"=>2.5)
  "b" => 9.0
  "a" => 4

julia> mult_mask_v_value(f, a)
Dict{String, Any} with 2 entries:
  "b" => 9.0
  "a" => 4

=#

# relevant Clojure code from dmm/core.clj

#=
;;; generalized linear combination - same as above, but compute the
;;; sum of the resulting vectors corresponding to the leaves in the
;;; Mask.

;;; right now the way it uses rec-map-sum somewhat ignores large-M vs
;;; small-M distinction it should not matter correctness-wise, but
;;; should eventually prompt a meditation efficiency-wise; we did just
;;; ended the practice of adding a non-trivial map to {} interpreted
;;; as a large map, so some progress here.

;;; this function is very similar to rec-map-mult-mask, the only
;;; difference except for its name (and hence recursive call) should
;;; have been that rec-map-sum is used instead of assoc

;;; but rec-map-sum is current only works for maps, which is why part
;;; of its functionality is duplicated here - something to meditate
;;; upon during a code review

(defn rec-map-lin-comb [mult-mask M]
  (reduce (fn [new-M [k mask]]
            (let [m (get M k)
                  actual-M (if (not (mORn? m)) 0 m)
                  actual-mask (if (not (mORn? mask)) 0 mask)
                  v-to-add (cond
                             (maps? actual-mask actual-M)
                             (rec-map-lin-comb actual-mask actual-M)

                             (mANDn? actual-M actual-mask)
                             (rec-map-mult actual-mask actual-M) ; leaf works!

                             (mANDn? actual-mask actual-M) 0
                             :else (* actual-M actual-mask))
                  new-sum (cond
                            (map? v-to-add)
                            (if (= new-M {})
                              v-to-add
                              (rec-map-sum new-M v-to-add))

                            (num-nonzero? v-to-add)
                            (rec-map-sum new-M (numelt v-to-add))

                            :else new-M)]
              new-sum))
          {} mult-mask))
=#

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

#=

a bit of tests

julia> a
Dict{String, Any} with 3 entries:
  "c" => 2.5
  "b" => 3.0
  "a" => 2

julia> mult_mask_lin_comb(a,a)
Dict{String, Any} with 1 entry:
  ":number" => 19.25

julia> f
Dict{String, Any} with 3 entries:
  "c" => Dict{String, Any}(":number"=>6.0, "u"=>1.0)
  "b" => 3.0
  "a" => 2

julia> mult_mask_lin_comb(f,f)
Dict{String, Any} with 1 entry:
  ":number" => 50.0

julia> mult_mask_lin_comb(a,f)
Dict{String, Any} with 2 entries:
  ":number" => 28.0
  "u"       => 2.5

julia> mult_mask_lin_comb(f,a)
Dict{String, Any} with 1 entry:
  ":number" => 13.0

=#

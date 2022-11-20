# relevant Julia code from dmm-lite.jl

#=
mutable struct Neuron
    f::Function
    input_dict::Dict{String, Dict{String, Float32}}
    output_dict::Dict{String, Dict{String, Float32}}
end


#struct DMM_Lite
#    neurons::Dict{String, Neuron}
#    network_matrix::Dict{String, Dict{String, Dict{String, Dict{String, Float32}}}}
#end
	
Neuron(f) = Neuron(f, Dict{String, Dict{String, Float32}}(), Dict{String, Dict{String, Float32}}())

#DMM_Lite() = DMM_Lite(Dict{String, Neuron}(), 
#                      Dict{String, Dict{String, Dict{String, Dict{String, Float32}}}}())

# For some reason, "struct DMM_Lite" representation causes the gradient to be incorrect,
# namely to return "nothing". I don't want to try to debug this, let's just representation
# this via Dict (it is weird that "mutable struct" elsewhere was fine, but not this -
#                TODO: revisit this issue)

DMM_Lite() = Dict("neurons"=>Dict{String, Neuron}(),
                  "network_matrix"=>Dict{String, Dict{String, Dict{String, Dict{String, Float32}}}}(),
                  "fixed_matrix"=>Dict{String, Dict{String, Dict{String, Dict{String, Float32}}}}())

DMM_Lite_ = Dict{String, Dict{String}} # type

function up_movement!(dmm_lite::DMM_Lite_)
    for neuron in values(dmm_lite["neurons"])
	    # println(neuron)
		# println("INPUT DICT: ", neuron.input_dict)
		# println("AFTER FUNCTION APPLICATION: ", neuron.f(neuron.input_dict))
        neuron.output_dict = neuron.f(neuron.input_dict)
    end
end

function down_movement!(dmm_lite::DMM_Lite_)
    for neuron_name in union(keys(dmm_lite["network_matrix"]), keys(dmm_lite["fixed_matrix"]))
        if haskey(dmm_lite["neurons"], neuron_name) # correctness, and there is a problem that if a neuron disappears from a matrix
                                            # altogether, then its input is not updates at all (in reality it should become
                                            # inactive in such a situation, but that's for a subsequent version)
            neuron = dmm_lite["neurons"][neuron_name]
            neuron.input_dict = Dict{String, Dict{String, Float32}}()
            for matrix_name in ["network_matrix", "fixed_matrix"]
                if haskey(dmm_lite[matrix_name], neuron_name)
                    for field_name in keys(dmm_lite[matrix_name][neuron_name])
                        matrix_row = dmm_lite[matrix_name][neuron_name][field_name]
                        if !haskey(neuron.input_dict, field_name)
                            neuron.input_dict[field_name] = Dict{String, Float32}()
                        end
                        for resulting_neuron_name in keys(matrix_row)
                            if haskey(dmm_lite["neurons"], resulting_neuron_name)
                                resulting_neuron = dmm_lite["neurons"][resulting_neuron_name]
                                for resulting_field_name in keys(matrix_row[resulting_neuron_name])
                                    multiplier = matrix_row[resulting_neuron_name][resulting_field_name]
                                    # neuron.input_dict[field_name] += multiplier*resulting_neuron.output_dict[resulting_field_name]
                                    add_term_to_dict!(neuron.input_dict[field_name], multiplier, get_D(resulting_neuron.output_dict, resulting_field_name))
    end end end end end end end end # Clojure style
end

# traditional DMM execution order is counter-intuitive: one starts with down-movement first
# (one starts with linear combination to form neuron inputs, then proceeds)
# this might not matter for DMM Lite, but I'll keep it this way for uniformity

function two_stroke_cycle!(dmm_lite::DMM_Lite_)
    down_movement!(dmm_lite)
    up_movement!(dmm_lite)
end
=#

# relevant Clojure code from dmm/core.clj

#=
;;; apply matrix to vector (mutrix multiplication)

;;; we expect that at level 0, the structures of a matrix row
;;; and argument vector are such that the use of
;;; rec-map-lin-comb makes sense, and that the indexes
;;; of rows have plain mutlilevel structure.

(defn apply-matrix [arg-matrix arg-vector level]
  (if (= level 0)
    (rec-map-lin-comb arg-matrix arg-vector)
    (reduce (fn [new-map [k v]]
              (assoc new-map k (apply-matrix v arg-vector (- level 1))))
      {} arg-matrix)))

;;; current version of down-movement of the two-stroke engine:
;;; computing neuron inputs as linear combinations of neuron outputs.

;;; the addendum to caveat 1 in the deisgn-notes ("caveat 1
;;; continued") means that the "down movement" is just plain matrix
;;; multiplication without any extra frills. The application of the
;;; matrix row to the vector of neuron outputs is
;;; simply "rec-map-lin-comb".

;;; let's say, applying a row to the vector of outputs is level 0, and
;;; applying a map of rows obtaining the map of answer is level 1,
;;; etc. Our current design spec says that the "down movement" is
;;; applying this funcion at level 3.


(defn down-movement [function-named-instance-map-of-outputs]
  (apply-matrix
   (((function-named-instance-map-of-outputs v-accum) :self) :single); current matrix
   function-named-instance-map-of-outputs ; arg-vector
   3))

;;; a sketch of the up-movement pattern for the two-stroke engine.
;;;
;;; (normally a neuron takes a map and produces a map according to
;;; design notes, but the up-movement pattern should work for any set
;;; of functions taking one argument (an empty hash-map is recommended
;;; if one needs to signify absense of meaningful arguments) and
;;; producing one argument)
;;;
;;; there is a map from such functions to (maps from names of their
;;; instances to the arguments the function is to be applied to)
;;;
;;; the result should be a map from such functions to (maps from names
;;; of their instances to the results obtained by the corresponding
;;; function application)


;;; auxiliary pass applying a function to a map from names of
;;; instances to arguments and producing a map from names of instances
;;; to results

(defn apply-to-map-of-named-instances [f named-instance-to-arg-map]
  (reduce (fn [new-ninstance-arg-map [name arg]]
            (assoc new-ninstance-arg-map name (f arg)))
          {} named-instance-to-arg-map))



(defn up-movement [function-named-instance-map]
  (reduce (fn [new-fnamed-imap [f names-to-args-map]]
            (assoc new-fnamed-imap f
                   (apply-to-map-of-named-instances f names-to-args-map)))
          {} function-named-instance-map))
=#

# we must program some versions of down_movement! and up_movement!

# we might use tensor of rank 4 as in dmm-lite.jl or tensor of rank 6 as in dmm/core.clj
# but the implementation of "down_movement" is much prettier in Clojure than in our Julia dmm-lite.jl
# so let's create a better Julia implementation

#= Clojure code for down movement (see above for the comments):

(defn apply-matrix [arg-matrix arg-vector level]
  (if (= level 0)
    (rec-map-lin-comb arg-matrix arg-vector)
    (reduce (fn [new-map [k v]]
              (assoc new-map k (apply-matrix v arg-vector (- level 1))))
      {} arg-matrix)))

(defn down-movement [function-named-instance-map-of-outputs]
  (apply-matrix
   (((function-named-instance-map-of-outputs v-accum) :self) :single); current matrix
   function-named-instance-map-of-outputs ; arg-vector
   3))

Here we have a hardcoded setup that the network matrix sits in the :single output of the neuron :self
It is better to move this information to the implementation of function two_stroke_cycle!
Then down movement will simply be applying the appropriate matrix to the appropriate vector of v-values at level 2 or 3 depending on our choice.

Hence we only need to port apply-matrix
=#

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

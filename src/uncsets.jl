#-----------------------------------------------------------------------
# JuMPeR  --  JuMP Extension for Robust Optimization
# http://github.com/IainNZ/JuMPeR.jl
#-----------------------------------------------------------------------
# Copyright (c) 2016: Iain Dunning
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#-----------------------------------------------------------------------
# src/uncsets.jl
# Defines the AbstractUncertaintySet interface, which controls how
# constraints with uncertain parameters are addressed when solving a
# robust optimization problem.
# Included by src/JuMPeR.jl
#-----------------------------------------------------------------------


"""
    register_constraint(UncSet, RobustModel, idx, prefs)

Called when a RobustModel is being solved. Notifies the `uncset` that it is
responsible for an uncertain constraint belonging to the RobustModel with
index `idx`. `prefs` is a dictionary of keyword arguments passed via the
`solve(RobustModel)` function.
"""
register_constraint(us::AbstractUncertaintySet, rm::Model, idx::Int, prefs::Dict{Symbol,Any}) =
    error("$(typeof(us)) has not implemented register_constraint!")


"""
    setup_set(UncSet, RobustModel, scens_requested, prefs)

Called after all constraints have been registered with the uncertainty sets,
but before any reformulations or cuts have been requested. Examples of work
that could be done here include transforming the uncertainty set somehow, or
building a cutting plane generating model. Will be called once. If the user
has requested that `Scenario`s be generated at optimality, then the
`scens_requested` will be `true` - the uncertainty set may want to generate
the cutting plane model in anticipation of this, even if cutting planes are
not going to be used for solving the problem.
"""
setup_set(us::AbstractUncertaintySet, rm::Model, scens_requested::Bool, prefs) =
    error("$(typeof(us)) has not implemented setup_set!")


"""
    generate_reform(UncSet, Model, RobustModel, idxs)

Called immediately before the main solve loop (where cutting planes are
generated, if required). Can add anything it wants to the deterministic Model,
but is generally intended for replacing the uncertain constraints in `idxs`
with deterministic equivalents. Should return the number of constraints
reformulated.
"""
generate_reform(us::AbstractUncertaintySet, m::Model, rm::Model, idxs::Vector{Int}) =
    error("$(typeof(us)) hasn't implemented generate_reform")


"""
    generate_cut(UncSet, Model, RobustModel, idxs)

Called in the main loop every iteration (continuous variables) or every time
an integer solution is found (discrete variables). Returns a vector of
deterministic constraints which are added to the problem by main solve loop.
Generally intended for generating deterministic versions of the uncertain
constraints in `idxs` as needed.
"""
generate_cut(us::AbstractUncertaintySet, m::Model, rm::Model, idxs::Vector{Int}) =
    error("$(typeof(us)) hasn't implemented generate_cut")


"""
    generate_scenario(UncSet, Model, v::Vector{Float64}, idxs)

If requested by the user, this method will be called at optimality. Returns
a `Nullable{Scenario}` for each constraint, where that `Scenario` corresponds
to the values of the uncertain parameters that reduce slack in the constraint
the most. If there are multiple such sets of values, the uncertainty set can
select  arbitrarily, and if the set cannot provide a scenario it should return
an empty `Nullable{Scenario}`.
"""
generate_scenario(us::AbstractUncertaintySet, m::Model, rm::Model, idxs::Vector{Int}) =
    error("$(typeof(us)) hasn't implemented generate_scenario")


# @addConstraint methods for AbstractUncertaintySets
# These do not need to be implemented for all uncertainty sets - only if
# they make sense for the set.
function JuMP.addConstraint(us::AbstractUncertaintySet, c::UncSetConstraint)
    error("$(typeof(us)) hasn't implemented adding constraints on uncertain parameters.")
end
function JuMP.addConstraint(m::JuMP.AbstractModel, c::Array{UncSetConstraint})
    error("The operators <=, >=, and == can only be used to specify scalar constraints. If you are trying to add a vectorized constraint, use the element-wise dot comparison operators (.<=, .>=, or .==) instead")
end
function JuMP.addVectorizedConstraint(m::JuMP.AbstractModel, v::Array{UncSetConstraint})
    map(c->addConstraint(m,c), v)
end
function JuMP.addConstraint(us::AbstractUncertaintySet, c::UncSetNormConstraint)
    error("$(typeof(us)) hasn't implemented adding constraints on uncertain parameters.")
end
# Sometimes JuMP[eR] can produce UncConstraints that have no variables - these
# are actually UncSetConstraints, but just haven't been recognized as such.
# To avoid the need for all uncertainty sets to be aware of this, we also
# provide fall backs to detect these.
function JuMP.addConstraint(us::AbstractUncertaintySet, c::UncConstraint)
    if length(c.terms.vars) == 0
        # Pure uncertain constraint
        return addConstraint(us, UncSetConstraint(c.terms.constant, c.lb, c.ub))
    end
    # Error, has variables!
    error("Can't add a constraint with decision variables to an uncertainty set!")
end
function JuMP.addVectorizedConstraint(us::AbstractUncertaintySet, v::Array{UncConstraint})
    map(c->addConstraint(us,c), v)
end


# Utility functions for common UncertaintySet operations
include("uncsets_util.jl")

# The default BasicUncertaintySet, which handles explicitly provided sets.
include("uncsets_basic.jl")

# BudgetUncertaintySet, based on the set from the "Price of Robustness"
# paper by Bertsimas and Sim.
include("uncsets_budget.jl")
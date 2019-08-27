# Helper functions for methods based on inner-outer iterations

using LinearAlgebra

export inner_solve;
export InnerSolver;
export NewtonInnerSolver
export PolyeigInnerSolver
export DefaultInnerSolver
export IARInnerSolver
export IARChebInnerSolver
export SGIterInnerSolver
export ContourBeynInnerSolver

"""
    abstract type InnerSolver

Structs inheriting from this type are used to solve inner problems
in an inner-outer iteration.

The `InnerSolver` objects are passed to the NEP-algorithms,
which uses it to dispatch the correct version of the function [`inner_solve`](@ref).
Utilizes existing implementations of NEP-solvers and [`inner_solve`](@ref) acts as a wrapper
to these.

# Example

There is a [`DefaultInnerSolver`](@ref) that dispatches an inner solver based on the
provided NEP.
However, this example shows how you can force [`nlar`](@ref) to use the
[`IARInnerSolver`](@ref) for a PEP.
```julia-repl
julia> nep=nep_gallery("pep0", 100);
julia> λ,v = nlar(nep, inner_solver_method=NEPSolver.IARInnerSolver(), neigs=1, num_restart_ritz_vecs=1, maxit=70, tol=1e-8);
julia> norm(compute_Mlincomb(nep,λ[1],vec(v)))
8.68118417430353e-9
```

See also: [`inner_solve`](@ref), [`DefaultInnerSolver`](@ref), [`NewtonInnerSolver`](@ref),
[`PolyeigInnerSolver`](@ref), [`IARInnerSolver`](@ref), [`IARChebInnerSolver`](@ref),
[`SGIterInnerSolver`](@ref), [`ContourBeynInnerSolver`](@ref)
"""
abstract type InnerSolver end;


"""
    struct DefaultInnerSolver <: InnerSolver

Dispatches a version of [`inner_solve`](@ref) based on the type of the NEP provided.

See also: [`InnerSolver`](@ref), [`inner_solve`](@ref)
"""
struct DefaultInnerSolver <: InnerSolver end;


"""
    struct NewtonInnerSolver
    function NewtonInnerSolver(;tol=1e-13,maxit=80,starting_vector=:Vk,
                               newton_function=augnewton)

Uses a Newton-like method to solve the inner problem, with tolerance,
and maximum number of iterations given by
`tol` and `maxit`. The starting vector can be `:ones`,
`:randn`, or `:Vk`. The value `:Vk` specifies the use
of the super NEP-solver keyword argument (`Vk`).
This is typically the previous iterate in the outer method.

The kwarg `newton_function`, specifies a `Function`
which is called. We support `augnewton`, `newton`, `resinv`
`quasinewton`, `newtonqr`. In principle it can be any
method which takes the same keyword arguments as these methods.


See also: [`InnerSolver`](@ref), [`inner_solve`](@ref)
"""
struct NewtonInnerSolver <: InnerSolver
    tol::Float64
    maxit::Int
    starting_vector::Symbol;
    newton_function::Function;
    function NewtonInnerSolver(;tol=1e-13,maxit=80,starting_vector=:Vk,
                               newton_function=augnewton)
        return new(tol,maxit,starting_vector,newton_function);
    end
end;


"""
    struct PolyeigInnerSolver <: InnerSolver

For polynomial eigenvalue problems.
Uses [`polyeig`](@ref) to solve the inner problem.

See also: [`InnerSolver`](@ref), [`inner_solve`](@ref)
"""
struct PolyeigInnerSolver <: InnerSolver end;


"""
    struct IARInnerSolver
    IARInnerSolver(;tol=1e-13,maxit=80,starting_vector=:ones)

Uses [`iar`](@ref) to solve the inner problem, with tolerance,
and maximum number of iterations given by
`tol` and `maxit`. The starting vector can be `:ones` or
`:randn`.

See also: [`InnerSolver`](@ref), [`inner_solve`](@ref)
"""
struct IARInnerSolver <: InnerSolver
    tol::Float64
    maxit::Int
    starting_vector::Symbol;
    function IARInnerSolver(;tol=1e-13,maxit=80,starting_vector=:ones)
        # Default starting_vector = :ones since we would otherwise
        # get a place with difficult reproducability and hidden.
        return new(tol,maxit,starting_vector);
    end
end;


"""
    struct IARChebInnerSolver <: InnerSolver

Uses [`iar_chebyshev`](@ref) to solve the inner problem.

See also: [`InnerSolver`](@ref), [`inner_solve`](@ref)
"""
struct IARChebInnerSolver <: InnerSolver end;


"""
    struct SGIterInnerSolver <: InnerSolver

Uses [`sgiter`](@ref) to solve the inner problem.

See also: [`InnerSolver`](@ref), [`inner_solve`](@ref)
"""
struct SGIterInnerSolver <: InnerSolver end;


"""
    struct ContourBeynInnerSolver <: InnerSolver

Uses [`contour_beyn`](@ref) to solve the inner problem.

See also: [`InnerSolver`](@ref), [`inner_solve`](@ref)
"""
struct ContourBeynInnerSolver <: InnerSolver end;


"""
    inner_solve(T,T_arit,nep;kwargs...)

Solves the projected linear problem with solver specied with T. This is to be used
as an inner solver in an inner-outer iteration. T specifies which method
to use. The most common choice is [`DefaultInnersolver`](@ref). The function returns
`(λv,V)` where `λv` is an array of eigenvalues and `V` a matrix with corresponding
vectors.
The struct `T_arit` defines the arithmetics used in the outer iteration and should prefereably
also be used in the inner iteration.

Different inner_solve methods take different kwargs. The meaning of
the kwargs are the following:
- `neigs`: Number of wanted eigenvalues (but less or more may be returned)
- `σ`: target specifying where eigenvalues
- `λv`, `V`: Vector/matrix of guesses to be used as starting values
- `j`: the jth eigenvalue in a min-max characterization
- `tol`: Termination tolarance for inner solver
- `inner_logger`: Determines how the inner solves are logged. See [`Logger`](@ref) for further references
"""
function inner_solve(is::DefaultInnerSolver,T_arit::Type,nep::NEPTypes.Proj_NEP;kwargs...)
    if (typeof(nep.orgnep)==NEPTypes.PEP)
        return inner_solve(PolyeigInnerSolver(),T_arit,nep;kwargs...);
    elseif (typeof(nep.orgnep)==NEPTypes.DEP)
        # Should be Cheb IAR
        return inner_solve(IARChebInnerSolver(),T_arit,nep;kwargs...);
    elseif (typeof(nep.orgnep)==NEPTypes.SPMF_NEP) # Default to IAR for SPMF
        return inner_solve(IARInnerSolver(),T_arit,nep;kwargs...);
    else
        return inner_solve(NewtonInnerSolver(),T_arit,nep;kwargs...);
    end
end



function inner_solve(is::NewtonInnerSolver,T_arit::Type,nep::NEPTypes.Proj_NEP;
                     λv=zeros(T_arit,1),
                     V=Matrix{T_arit}(rand(size(nep,1),size(λv,1))),
                     tol=sqrt(eps(real(T_arit))),
                     inner_logger=0,
                     kwargs...)
    @parse_logger_param!(inner_logger)
    for k=1:size(λv,1)
        try
            if (is.starting_vector == :ones)
                v0=ones(size(nep,1));
            elseif (is.starting_vector == :randn)
                v0=randn(size(nep,1));
            elseif (is.starting_vector == :Vk)
                v0=V[:,k]; # Starting vector for projected problem
            end

            projerrmeasure=(λ,v) -> norm(compute_Mlincomb(nep,λ,v))/opnorm(compute_Mder(nep,λ));
            # Compute a solution to projected problem with Newton's method
            λ1,vproj=is.newton_function(
                T_arit,nep,logger=inner_logger,λ=λv[k],
                v=v0,maxit=is.maxit,tol=is.tol,
                errmeasure=projerrmeasure);
            V[:,k]=vproj;
            λv[k]=λ1;
        catch e
            if (isa(e, NoConvergenceException))
                V[:,k] = e.v
                λv[k] = e.λ;
            else
                rethrow(e)
            end
        end
    end
    return λv,V
end


function inner_solve(is::PolyeigInnerSolver,T_arit::Type,nep::NEPTypes.Proj_NEP;kwargs...)
    if (typeof(nep.orgnep)!=NEPTypes.PEP)
        error("Wrong type. PolyeigInnerSolver only handles the PEP type.");
    end
    pep=NEPTypes.PEP(NEPTypes.get_Av(nep.nep_proj))
    return polyeig(T_arit,pep);
end



function inner_solve(is::IARInnerSolver,T_arit::Type,nep::NEPTypes.Proj_NEP;σ=0,neigs=10,inner_logger=0,kwargs...)
    @parse_logger_param!(inner_logger)
    try
        if (is.starting_vector == :ones)
            v0=ones(size(nep,1));
        else
            v0=randn(size(nep,1));
        end
        λ,V=iar(T_arit,nep,σ=σ,neigs=neigs,tol=is.tol,
                maxit=is.maxit,logger=inner_logger,v=v0);
        return λ,V
    catch e
        if (isa(e, NoConvergenceException))
            # If we fail to find the wanted number of eigvals, we can still
            # return the ones we found
            return e.λ,e.v
        else
            rethrow(e)
        end
    end
end



function inner_solve(is::IARChebInnerSolver,T_arit::Type,nep::NEPTypes.Proj_NEP;σ=0,neigs=10,inner_logger=0,kwargs...)
    @parse_logger_param!(inner_logger)
    if isa(nep.orgnep, NEPTypes.DEP)
        AA = get_Av(nep)
        TT = eltype(AA);
        if (TT  <: SubArray) # If it's better to transform to store in Matrix instead
            TT=Matrix{eltype(AA[1])};
        end
        BB = Vector{TT}(undef, size(AA,1)-1)
        for i = 1:(size(AA,1)-1)
            BB[i] = AA[1]\AA[1+i]
        end
        nep = DEP(BB,nep.orgnep.tauv)
    end

    try
        λ,V=iar_chebyshev(T_arit,nep,σ=σ,neigs=neigs,tol=1e-13,maxit=50,logger=inner_logger);
        return λ,V
    catch e
        if (isa(e, NoConvergenceException))
            # If we fail to find the wanted number of eigvals, we can still
            # return the ones we found
            return e.λ,e.v
        else
            rethrow(e)
        end
    end
end



function inner_solve(is::SGIterInnerSolver,T_arit::Type,nep::NEPTypes.Proj_NEP;λv=[0],j=0,inner_logger=0,kwargs...)
    @parse_logger_param!(inner_logger)
    λ,V=sgiter(T_arit,nep,j,logger=inner_logger)
    return [λ],reshape(V,size(V,1),1);
end



function inner_solve(is::ContourBeynInnerSolver,T_arit::Type,nep::NEPTypes.Proj_NEP;σ=0,λv=[0,1],neigs=10,inner_logger=0,kwargs...)
    @parse_logger_param!(inner_logger)
    # Radius  computed as the largest distance σ and λv and a litte more
    radius = maximum(abs.(σ .- λv))*1.5
    neigs = min(neigs,size(nep,1))
    λ,V = contour_beyn(T_arit,nep,neigs=neigs,σ=σ,radius=radius,logger=inner_logger)
    return λ,V
end

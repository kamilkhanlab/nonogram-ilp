import JuMP, GLPK

struct Puzzle
    palette
    sR::Vector{Vector{Int}}
    cR::Vector{<:Vector}
    sC::Vector{Vector{Int}}
    cC::Vector{<:Vector}
end

# constructor for monochrome puzzles
function Puzzle(
    sR::Vector{Vector{Int}},
    sC::Vector{Vector{Int}}
)
    # label the single block color as 1
    palette = 1:1
    cR = [ones(Int, length(s)) for s in sR]
    cC = [ones(Int, length(s)) for s in sC]
    return Puzzle(palette, sR, cR, sC, cC)
end

recover_puzzle_data(p::Puzzle) = p.palette, p.sR, p.cR, p.sC, p.cC

# intermediate quantities and sets described by Khan (2020)
struct AuxPuzzleQuantities
    sigmaR::Array{Int, 2}
    sigmaC::Array{Int, 2}
    fSetR::Array{UnitRange{Int}, 2}
    fSetC::Array{UnitRange{Int}, 2}
    oSetR::Array{UnitRange{Int}, 3}
    oSetC::Array{UnitRange{Int}, 3}
    mSetR::Array{Vector{Int}, 2}
    mSetC::Array{Vector{Int}, 2}
    maxBR::Int
    maxBC::Int
end

function recover_aux_data(p::AuxPuzzleQuantities)
    return (p.sigmaR, p.sigmaC, p.fSetR, p.fSetC,
            p.oSetR, p.oSetC, p.mSetR, p.mSetC,
            p.maxBR, p.maxBC)
end

struct PuzzleSolution
    z::Matrix
    palette
end

function read_puzzle_from_cwc(cwcFilename::String)
    # initialize outside scope of "open"
    nRows = 0
    nColumns = 0
    palette = 1:1
    
    sR = Vector{Int}[]
    cR = deepcopy(sR)
    sC = deepcopy(sR)
    cC = deepcopy(cR)

    # read CWC file and store it in the above matrices
    open(cwcFilename, "r") do io
        nRows = parse(Int, readline(io))
        nColumns = parse(Int, readline(io))
        nColors = parse(Int, readline(io))
        palette = 1:nColors

        sR = [parse.(Int, split(readline(io))) for i in 1:nRows]
        readline(io)
        cR = [parse.(Int, split(readline(io))) for s in sR]
        readline(io)
        sC = [parse.(Int, split(readline(io))) for j in 1:nColumns]
        readline(io)
        cC = [parse.(Int, split(readline(io))) for s in sC]
    end

    return Puzzle(palette, sR, cR, sC, cC)
end

function eval_aux_quantities(puzzle::Puzzle)
    bR = length.(puzzle.sR) # number of blocks in each row
    maxBR = maximum(bR)
    bC = length.(puzzle.sC) # number of blocks in each column
    maxBC = maximum(bC)

    m = length(puzzle.sR) # number of puzzle rows
    n = length(puzzle.sC) # number of puzzle columns
    nColors = length(puzzle.palette)

    sigmaR = zeros(Int, m, maxBR)
    mSetR = Array{Vector{Int}}(undef, m, nColors)
    for (i, cRI) in enumerate(puzzle.cR)
        for t in 1:(bR[i] - 1)
            sigmaR[i,t] = (cRI[t] == cRI[t+1])
        end

        for (p, color) in enumerate(puzzle.palette)
            mSetR[i,p] = [t for (t,c) in enumerate(cRI) if (c == color)]
        end
    end

    sigmaC = zeros(Int, n, maxBC)
    mSetC = Array{Vector{Int}}(undef, n, nColors)
    for (j, cCJ) in enumerate(puzzle.cC)
        for t in 1:(bC[j] - 1)
            sigmaC[j,t] = (cCJ[t] == cCJ[t+1])
        end

        for (p, color) in enumerate(puzzle.palette)
            mSetC[j,p] = [t for (t,c) in enumerate(cCJ) if (c == color)]
        end
    end

    fSetR = Array{UnitRange{Int}}(undef, m, maxBR)
    oSetR = Array{UnitRange{Int}}(undef, m, maxBR, n)
    for (i, sRI) in enumerate(puzzle.sR)
        l = 1
        u = n + 1 - sum(sRI) - sum(sigmaR[i,:])
        for (t, s) in enumerate(sRI)
            fSetR[i,t] = l:u
            for j in 1:n
                oSetR[i,t,j] = intersect(l:u, (j-s+1):j)
            end
            deltaL = s + sigmaR[i,t]
            l += deltaL
            u += deltaL
        end
    end

    fSetC = Array{UnitRange{Int}}(undef, n, maxBC)
    oSetC = Array{UnitRange{Int}}(undef, n, maxBC, m)
    for (j, sCJ) in enumerate(puzzle.sC)
        l = 1
        u = m + 1 - sum(sCJ) - sum(sigmaC[j,:])
        for (t, s) in enumerate(sCJ)
            fSetC[j,t] = l:u
            for i in 1:m
                oSetC[j,t,i] = intersect(l:u, (i-s+1):i)
            end
            deltaL = s + sigmaC[j,t]
            l += deltaL
            u += deltaL
        end
    end
    
    return AuxPuzzleQuantities(
        sigmaR, sigmaC,
        fSetR, fSetC,
        oSetR, oSetC,
        mSetR, mSetC,
        maxBR, maxBC
    )
end

function solve_puzzle(
    puzzle::Puzzle,
    auxQs::AuxPuzzleQuantities;
    optimizer = GLPK.Optimizer,
    solverAttributes = ("msg_lev" => GLPK.GLP_MSG_OFF,),
    verbosity::Int = 1
)
    # recover puzzle data
    (palette, sR, cR, sC, cC) = recover_puzzle_data(puzzle)

    rows = eachindex(sR)
    cols = eachindex(sC)
    colors = eachindex(palette)
    blocksR(i) = eachindex(sR[i])
    blocksC(j) = eachindex(sC[j])
    notLastBlockR(i) = 1:(length(sR[i]) - 1)
    notLastBlockC(j) = 1:(length(sC[j]) - 1)
    
    (sigmaR, sigmaC, fSetR, fSetC,
     oSetR, oSetC, mSetR, mSetC, maxBR, maxBC) = recover_aux_data(auxQs)

    # set up and solve equivalent mixed-integer linear program with JuMP 
    model = JuMP.Model(
        JuMP.optimizer_with_attributes(optimizer,
                                       solverAttributes...))
    
    JuMP.@variable(model, y[rows, 1:maxBR, cols], Bin)
    JuMP.@variable(model, x[cols, 1:maxBC, rows], Bin)

    JuMP.@constraint(model, beginOnceR[i in rows, t in blocksR(i)],
                     sum(y[i,t,j] for j in fSetR[i,t]) == 1)
    
    JuMP.@constraint(model, beginOnceC[j in cols, t in blocksC(j)],
                     sum(x[j,t,i] for i in fSetC[j,t]) == 1)

   
    JuMP.@constraint(model, orderR[i in rows, t in notLastBlockR(i)],
                     sR[i][t] + sigmaR[i,t]
                     + sum(j*y[i,t,j] for j in fSetR[i,t])
                     <= sum(j*y[i,t+1,j] for j in fSetR[i,t+1]))
    
    JuMP.@constraint(model, orderC[j in cols, t in notLastBlockC(j)],
                     sC[j][t] + sigmaC[j,t]
                     + sum(i*x[j,t,i] for i in fSetC[j,t])
                     <= sum(i*x[j,t+1,i] for i in fSetC[j,t+1]))
   
    JuMP.@constraint(model, consistentRC[i in rows, j in cols, p in colors],
                     sum(y[i,t,k] for t in mSetR[i,p] for k in oSetR[i,t,j])
                     == sum(x[j,t,k] for t in mSetC[j,p] for k in oSetC[j,t,i]))
    

    JuMP.optimize!(model)
    yStar = JuMP.value.(y)
    xStar = JuMP.value.(x)
    terminationStatus = JuMP.termination_status(model)

    if verbosity>0
        @show JuMP.solution_summary(model)
    end

    # construct puzzle solution from optimization solution
    zStar = zeros(eltype(palette), length(rows), length(cols))
    for i in rows, j in cols
        for (p, color) in enumerate(palette)
            if 1.0 == sum(yStar[i,t,k]
                         for t in mSetR[i,p] for k in oSetR[i,t,j]; init=0)
                zStar[i,j] = color
            end
        end
    end
    
    return PuzzleSolution(zStar, palette)
end

function solve_puzzle(puzzle::Puzzle; kwargs...)
    auxQuantities = eval_aux_quantities(puzzle)
    return solve_puzzle(puzzle, eval_aux_quantities(puzzle); kwargs...)
end

function Base.show(io::IO, solution::PuzzleSolution)
    issubset(solution.palette, 1:4) ||
        throw(DomainError(:(solution.palette), "colors must be in 1:4"))
    
    printGuide = Dict(0=>"⬜", 1=>"🟩", 2=>"🟦", 3=>"🟪", 4=>"⬛")
    z = solution.z
    
    return begin
        println(io, "")
        for i in 1:size(z, 1)
            for j in 1:size(z, 2)
                print(io, printGuide[z[i,j]])
            end
            println(io, "")
        end
    end
end

puzzle = read_puzzle_from_cwc("23.cwc")
puzzleSolution = solve_puzzle(puzzle)
@show puzzleSolution

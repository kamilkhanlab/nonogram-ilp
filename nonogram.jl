struct PuzzleData
    nRows::Int
    nColumns::Int
    nColors::Int
    sR::Vector{Vector{Int}}
    cR::Vector{Vector{Int}}
    sC::Vector{Vector{Int}}
    cC::Vector{Vector{Int}}
end

struct AuxPuzzleQuantities
    sigmaR::Vector{Vector{Int}}
    sigmaC::Vector{Vector{Int}}
    fSetR::Vector{Vector{UnitRange{Int}}}
    fSetC::Vector{Vector{UnitRange{Int}}}
    oSetR::Vector{Vector{Vector{UnitRange{Int}}}}
    oSetC::Vector{Vector{Vector{UnitRange{Int}}}}
end

function read_puzzle_from_cwc(cwcFilename::String)
    # initialize outside scope of "open"
    nRows = 0
    nColumns = 0
    nColors = 0
    
    sR = Vector{Int}[]
    cR = deepcopy(sR)
    sC = deepcopy(sR)
    cC = deepcopy(cR)

    # read CWC file and store it in the above matrices
    open(cwcFilename, "r") do io
        nRows = parse(Int, readline(io))
        nColumns = parse(Int, readline(io))
        nColors = parse(Int, readline(io))

        sR = [parse.(Int, split(readline(io))) for i in 1:nRows]
        readline(io)
        cR = [parse.(Int, split(readline(io))) for i in sR]
        readline(io)
        sC = [parse.(Int, split(readline(io))) for j in 1:nColumns]
        readline(io)
        cC = [parse.(Int, split(readline(io))) for j in sC]
    end

    return PuzzleData(nRows, nColumns, nColors, sR, cR, sC, cC)
end

function eval_aux_quantities(puzzle::PuzzleData)
    sigmaR = [Int[] for cRI in puzzle.cR]
    for (sigma, c) in zip(sigmaR, puzzle.cR)
        for t in 1:(length(c)-1)
            push!(sigma, c[t] == c[t+1])
        end
        push!(sigma, 0)
    end

    sigmaC = [Int[] for cCJ in puzzle.cC]
    for (sigma, c) in zip(sigmaC, puzzle.cC)
        for t in 1:(length(c)-1)
            push!(sigma, c[t] == c[t+1])
        end
        push!(sigma, 0)
    end

    fSetR = [UnitRange{Int}[] for sRI in puzzle.sR]
    for (fSet, s, sigma) in zip(fSetR, puzzle.sR, sigmaR)
        l = 1
        u = puzzle.nColumns + 1 - sum(s) - sum(sigma)
        for t in eachindex(s)
            push!(fSet, l:u)
            deltaL = s[t] + sigma[t]
            l += deltaL
            u += deltaL
        end
    end

    fSetC = [UnitRange{Int}[] for sCJ in puzzle.sC]
    for (fSet, s, sigma) in zip(fSetC, puzzle.sC, sigmaC)
        l = 1
        u = puzzle.nRows + 1 - sum(s) - sum(sigma)
        for t in eachindex(s)
            push!(fSet, l:u)
            deltaL = s[t] + sigma[t]
            l += deltaL
            u += deltaL
        end
    end

    oSetR = [[UnitRange{Int}[] for s in sRI] for sRI in puzzle.sR]
    for (oSetRI, sRI, fSetRI) in zip(oSetR, puzzle.sR, fSetR)
        for (oSet, s, fSet) in zip(oSetRI, sRI, fSetRI)
            for j = 1:puzzle.nColumns
                push!(oSet, intersect(fSet, (j-s+1):j))
            end
        end
    end

    oSetC = [[UnitRange{Int}[] for s in sCJ] for sCJ in puzzle.sC]
    for (oSetCJ, sCJ, fSetCJ) in zip(oSetC, puzzle.sC, fSetC)
        for (oSet, s, fSet) in zip(oSetCJ, sCJ, fSetCJ)
            for i = 1:puzzle.nRows
                push!(oSet, intersect(fSet, (i-s+1):i))
            end
        end
    end
    
    return AuxPuzzleQuantities(sigmaR, sigmaC, fSetR, fSetC, oSetR, oSetC)
end

puzzle = read_puzzle_from_cwc("1.cwc")
@show puzzle.sR
eval_aux_quantities(puzzle)



struct PortRange
    start::Int
    stop::Int
    r::Bool
end
PortRange(p::Integer) = PortRange(p, -1, false)
PortRange(p::UnitRange) = PortRange(Int(p.start), Int(p.stop), true)

function PortRange(p::AbstractString)
    p = strip(p)
    
    r1 = r"^[0-9][0-9][0-9]$"
    r2 = r"^[0-9][0-9][0-9]-[0-9][0-9][0-9]$"
    
    if occursin(r1, p)
        return PortRange(parse(Int, p), -1, false)
    elseif occursin(r2, p)
        i = findfirst(isequal('-'), p)
        p1 = parse(Int, p[1:(i-1)])
        p2 = parse(Int, p[(i+1):end])
        return PortRange(p1, p2, true)
    else
        throw(ArgumentError(p, "Not a valid port or port range"))
    end
    
end

isrange(p::PortRange) = p.r

function strport(p::PortRange)

    if isrange(p)
        return "$(p.start)-$(p.stop)"
    else
        return "$(p.start)"
    end
end


function portlist(ports::AbstractString)

    ports = strip(ports)
    plst = PortRange[]
    foundsep = false
    if occursin(' ', ports)
        foundsep=true
        for p in split(ports, c, keepempty=false)
            push!(plst, PortRange(strip(p)))
        end
    end
    
    if !foundsep
        push!(plst, PortRange(ports))
    end

    return plst
end

function portlist(ports...)
    plst = PortRange[]
    
    for p in ports
        push!(plst, PortRange(p))
    end
    return plst
end

        
function strportlist(ports::AbstractVector{PortRange})
    plst = ""

    for p1 in ports
        if isrange(p1)
            i1 = p1.start
            i2 = p1.stop
            plst *= " $i1-$i2"
        else
            plst *= " $(p1.start)"
        end
    end
    return plst
end

function checkportlist(scanners, ports::AbstractVector{PortRange})

    scn = [s[1] for s in scanners]
    npp = [s[2] for s in scanners]

    ii = sortperm(scn)
    scn = scn[ii]
    npp = npp[ii]

    for p in ports
        p1 = p.start
        if !isrange(p)
            s = floor(Int, (p1-1)/100)
            if s ∉ scn
                return false
            else
                idxs = findfirst(isequal(s), scn)
                nn = npp[idxs]
                if p1 > s*100 + nn
                    return false
                end
            end
        else
            p2 = p.stop
            s1 = floor(Int, (p1-1)/100)
            s2 = floor(Int, (p2-1)/100)
            for s in s1:s2
                if s ∉ scn
                    return false
                end
            end
            idxs = findfirst(isequal(s2), scn)
            nn = npp[idxs]
            if p2 > s2*100+nn
                return false
            end
            
        end
    end
    return true

end



function defscanlist(scanners, ports::AbstractVector{PortRange})
    scn = [s[1] for s in scanners]
    npp = [s[2] for s in scanners]

    ii = sortperm(scn)
    scn = scn[ii]
    npp = npp[ii]
    
    plst = Int[]
    for p in ports
        if !isrange(p)
            pn = p.start
            s = floor(Int, pn/100)  # Scanner number
            if s ∉ scn  # Not valid scanner
                throw(DomainError(pn, "Port $pn not part of any scanner"))
            end
            idx = pn - 100*s
            if idx > npp[findfirst(isequal(s), scn)]
                throw(BoundsError(pn, "Port $pn not valid for scanner $s"))
            end
            push!(plst, pn)
        else
            pstart = p.start
            pstop = p.stop
            s1 = floor(Int, pstart/100)
            s2 = floor(Int, pstop/100)
            for s in s1:s2
                if s ∉ scn
                    throw(DomainError(s, "Ports $p have scanners not configured!"))
                end
            end

            i = findfirst(isequal(s1), scn)
            if !(1 ≤ (pstart-100*s1) ≤ npp[i])
                throw(BoundsError(pstart, "Illegal port number!"))
            end

            i = findfirst(isequal(s2), scn)
            if !(1 ≤ (pstop-100*s2) ≤ npp[i])
                throw(BoundsError(pstart, "Illegal port number!"))
            end
                
            if s2 != s1
                append!(plst, pstart:(s1*100+npp[i]))
                for s in (s1+1):(s2-1)
                    i = findfirst(isequal(s), scn)
                    append!(plst, (s*100) .+ (1:npp[i]))
                end
                i = findfirst(isequal(s2), scn)
                append!(plst, (s2*100+1):pstop)
            else
                i = findfirst(isequal(s2), scn)
                append!(plst, pstart:pstop)
            end
        end
    end

    return plst
    
end




struct PortRange
    "Initial port in the range or the value of the port for single ports"
    start::Int
    "End port in the range"
    stop::Int
    "Is this a range (`true`) or a single port (`false`)"
    r::Bool
end
PortRange(p::Integer) = PortRange(p, -1, false)
PortRange(p::UnitRange) = PortRange(Int(p.start), Int(p.stop), true)

"""
`PortRange(p::AbstractString)`
`PortRange(p::Integer)`
`PortRange(p::UnitRange)`

Creates a `PortRange` object that handles continuous ranges of ports in multiple scanners.

In the DTC Initium, up to 8 scanners can be used simultaneously. 
Each scanner can hav 8, 16, 32 or 64 pressure ports. 
Since the total number ports can be large, when specifying which ports
should be used ranges are a necessity. 

The DTC Initium uses the following convention to name pressure ports:

 * XYZ
 * X is the number of the slot where the scanner is connected (1-8)
 * YZ is the number of the port where 1 ≤ YZ ≤ N where N is the total number of ports in the scanner
 * A range is given by ABC-XYZ
 * If X is different from A, then all ports between ABC and XYZ are included

As an example, consider that 8 scanners with 64 ports are used. 
In this case the port range 228-547 consists of the following pressure ports

 * 228-264: ports 28-64 in the scanner located in slot 2
 * 301-364: ports 28-64 in the scanner located in slot 3
 * 401-464: ports 28-64 in the scanner located in slot 4
 * 501-547: ports 28-64 in the scanner located in slot 5

It should be noted that *just a `PortRange` object does not specify the exact ports that 
are used*. There is need for context: the exact scanners that are connected to the 
DTC Initum.

The function [`strport`](@ref) returns a string that represents the port range and
can be used in DTC Initium commands.

## Examples
```jldoctest
julia> PortRange("101-353") # 101-353
PortRange(101, 353, true)

julia> PortRange(101:353) # 101-353
PortRange(101, 353, true)

julia> PortRange(412) # 412
PortRange(412, -1, false)
```



"""
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

"Is the [`PortRange`](@ref) object a range (`true`) or a single port (`false`)"
isrange(p::PortRange) = p.r

"""
`strport(p::PortRange)`

Creates the corresponding string of the [`PortRange`](@ref) object.

## Example
```jldoctest
julia> strport(PortRange(101:353)) # 101-353
"101-353"
```
"""
function strport(p::PortRange)

    if isrange(p)
        return "$(p.start)-$(p.stop)"
    else
        return "$(p.start)"
    end
end

"""
`portlist(ports::AbstractString)`
`portlist(ports...)`

Creates a vector of [`PortRange`](@ref) objects.

The input can be a string with ranges and single ports separated by
spaces (`' '`) or commas (`','`).

A single string or multiple arguments can be passed to this function. 
In the second case, the arguments should be compatible with the
constructors available to [`PortRange`](@ref).

## Examples
```jldoctest
julia> portlist("401-464", 505:543)
2-element Vector{PortRange}:
 PortRange(401, 464, true)
 PortRange(505, 543, true)

julia> portlist("401-464", 505:543, 555)
3-element Vector{PortRange}:
 PortRange(401, 464, true)
 PortRange(505, 543, true)
 PortRange(555, -1, false)

julia> portlist("101-234 245-264 ,, 301-325, 401-464")
4-element Vector{PortRange}:
 PortRange(101, 234, true)
 PortRange(245, 264, true)
 PortRange(301, 325, true)
 PortRange(401, 464, true)
```
"""
function portlist(ports::AbstractString)

    ports = replace(strip(ports), "," => " ")
    
    plst = PortRange[]
    c = ' '
    if occursin(c, ports)
        for p in split(ports, c, keepempty=false)
            push!(plst, PortRange(strip(p)))
        end
    else
        push!(plst, PortRange(strip(ports)))
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


"""
`strportlist(ports::AbstractVector{PortRange})`

Translates a vector of [`PortRange`](@ref) to a string that can be used
as an argument to the DTC Initium command SD3. 

This function is called by function [`SD3`](@ref) to add pressure channels
to the [`Initium`](@ref) device.

## Example
```jldoctest
julia> plst = portlist("101-234 245-264 ,, 301-325, 401-464")
4-element Vector{PortRange}:
 PortRange(101, 234, true)
 PortRange(245, 264, true)
 PortRange(301, 325, true)
 PortRange(401, 464, true)

julia> import DTCInitium: strportlist

julia> strportlist(plst)
" 101-234 245-264 301-325 401-464"
```
"""
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

"""
`checkportlist(scanners, ports::AbstractVector{PortRange})`

Check if a set of port ranges (argument `ports`) are compatible with the
scanners configured.

This will depend on which scanners are connected to the DTC Initium and
the number of pressure ports on each scanner.

## Example
```jldoctest
julia> scanners = [(1,64,1), (2,64,1), (3,64,1), (4,64,1)]; # 4 scanners with 64 channels.

julia> checkportlist(scanners, portlist("101-464"))
true

julia> checkportlist(scanners, portlist("101-564"))
false

```
"""
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


"""
`defscanlist(scanners, ports::AbstractVector{PortRange})`

Return the list of pressure ports in a vector of [`PortRange`](@ref) objects.

## Example
```jldoctest
julia> scanners = [(1,64,1), (2,64,1), (3,64,1), (4,64,1)];

julia> defscanlist(scanners, portlist("101-104 131-134 315-320"))
14-element Vector{Int64}:
 101
 102
 103
 104
 131
 132
 133
 134
 315
 316
 317
 318
 319
 320
```
"""
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


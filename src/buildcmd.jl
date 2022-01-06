

"""
`scannerlist((scn, npp, lrn), lst...)`

Define scanner list. Scanner list is used by the `SD1` command (see [`SD1cmd`](@ref) and [`SD1`](@ref)) to define which scanners are available to the user. 

The arguments of the function are tuples composed of the following parameters:

 * `scn` Integer or Integer range specifying the scanners used
 * `npp` Number of pressure ports in the scanner
 * `lrn` Logical Range number. I don't really understand this. Just use `1`

# Examples

```julia-repl
julia> scannerlist((1:2, 64, 1), (3:4, 32, 1), (5,16,2))
5-element Vector{Tuple{Int64, Int64, Int64}}:
 (1, 64, 1)
 (2, 64, 1)
 (3, 32, 1)
 (4, 32, 1)
 (5, 16, 2)
```

"""
function scannerlist((scn, npp, lrn), lst...)

    nscanners = length(scn)
    scnlst = Tuple{Int,Int,Int}[]
        
    for scanner in scn
        if scanner < 1 || scanner > 8
            throw(BoundsError(scanner, "Only scanners 1-8 are possible"))
        end
        if npp ∉ (16,32,64)
            throw(BoundsError(npp, "Only ESP with 16, 32 or 64 possible"))
        end
        push!(scnlst, (scanner, npp, lrn))
    end

    for s in lst
        scn = s[1]
        npp = s[2]
        lrn = s[3]
        nscanners += length(scn)
        if nscanners > 8
            throw(BoundsError(nscanners, "Maximum of 8 scanners is possible"))
        end
        for scanner in scn
            if scanner < 1 || scanner > 8
                throw(BoundsError(scanner, "Only scanners 1-8 are possible"))
            end
            if npp ∉ (16,32,64)
                throw(BoundsError(npp, "Only ESP with 16, 32 or 64 possible"))
            end
            push!(scnlst, (scanner, npp, lrn))
        end
    end

    return scnlst
end

"""
`SD1cmd(scnlst; crs="111")`

Implements the `SD1` command which configures the scanners connected to the DTC Initium.
This function actually creates a `String` containing the command to be sent to the DTC Inicit. Usually, to actually send the command, this function is called by the [`SD1`](@ref) function.

The `scnlst` parameter should be created with the [`scannerlist`](@ref)  function.

# Examples

```julia-repl
julia> scnlst = scannerlist((1:8,64,1))  # Use eight scanners with 64 pressure ports
8-element Vector{Tuple{Int64, Int64, Int64}}:
 (1, 64, 1)
 (2, 64, 1)
 (3, 64, 1)
 (4, 64, 1)
 (5, 64, 1)
 (6, 64, 1)
 (7, 64, 1)
 (8, 64, 1)

julia> SD1cmd(scnlst)
"SD1 111 (1,64,1) (2,64,1) (3,64,1) (4,64,1) (5,64,1) (6,64,1) (7,64,1) (8,64,1);"

```
"""
function SD1cmd(scnlst; crs="111")

    cmd = "SD1 $crs"

    for (scn,npp,lrn) in scnlst
        cmd *= " ($scn,$npp,$lrn)"
    end
    cmd *= ";"
    return cmd
end

"""
`daqparams(;stbl=1, nfr=64, nms=1, msd=100, trm=0, scm=1, ocf=2)`

Creates a dictionary with data acquisition setup parameters to be used by the [`SD2`](@ref) command that configures data acquisition. This function creates arguments that can be used the the `SD2cmd` function.


Parameters
 * `stbl` Chooses a DA Setup table. Should be an integer 1-5
 * `nfr` Integer that specifies the number of samples that should be averaged to create a measurement set.
 * `nms` Default number of pressure measurement sets that should be acquired. 0 if continuous data acquisition is desired.
 * `msd`  Delay between each pressure set. If 0, the scanners will acquire pressure as fast as possible
 * `trm` Trigger mode.
     - 0 no trigger
     - 1 Initial measurement is triggered
     - 2 Each pressure measurement is triggered
 * `scm` Defines scam modes. Just use 1. See the manual for further information
 * `ocf` Output format for the measurement. Just use 2 in general
     - 1 Raw measurements
     - 2 Receive pressure measurements in EU units
     - 3 EU press-sets and ez-set and temp-sets

# Example

```julia-repl
julia> daqparams()
Dict{Symbol, Int64} with 9 entries:
  :frd   => 0
  :scm   => 1
  :ocf   => 2
  :nfrez => 64
  :nms   => 1
  :trm   => 0
  :nfr   => 64
  :msd   => 100
  :stbl  => 1

```

"""
function daqparams(;stbl=1, nfr=64, nms=1, msd=100, trm=0, scm=1, ocf=2)
    if !(1 ≤ stbl ≤ 5)
        throw(BoundsError(stbl, "Scan table limited to 1-5!"))
    end

    if length(nfr) == 2
        nfrez = nfr[2]
        nfr = nfr[1]
    else
        nfrez = nfr
    end
    

    if !(1 ≤ nfr ≤ 127)
        throw(BoundsError(nfr, "nfr should range from 1-127"))
    end
    
    if !(1 ≤ nfrez ≤ 127)
        throw(BoundsError(nfr, "nfrez should range from 1-127"))
    end

    if !(0 ≤ nms ≤ 65000)
        throw(BoundsError(nfr, "nms should range from 0-65000"))
    end

    if !(0 ≤ msd ≤ 600_000)
        throw(BoundsError(nfr, "msd should range from 0-600_000"))
    end

    if !(0 ≤ trm ≤ 2)
        throw(BoundsError(nfr, "trm should be 0, 1 or 2"))
    end
    if !(0 ≤ scm ≤ 1)
        throw(BoundsError(nfr, "scm should be 0 or 1"))
    end
    if !(1 ≤ ocf ≤ 3)
        throw(BoundsError(ocf, "trm should be 1, 2 or 3"))
    end

    frd = 0  # Unused

    return Dict(:stbl=>stbl, :nfr=>nfr, :nfrez=>nfrez, :frd=>frd, :nms=>nms,
                :msd=>msd, :trm=>trm, :scm=>scm, :ocf=>ocf)
    
end

"""
`SD2cmd(p; crs="111")`

This function will actually create the command `String` that should be sent to the DTC Initium. The parameter `p` is usually created by function [`daqparams`](@ref). The user will usually use function [`SD2`](@ref) that actually communicates with the DTC Initium.

# Example

```julia-repl
julia> p = daqparams()
Dict{Symbol, Int64} with 9 entries:
  :frd   => 0
  :scm   => 1
  :ocf   => 2
  :nfrez => 64
  :nms   => 1
  :trm   => 0
  :nfr   => 64
  :msd   => 100
  :stbl  => 1

julia> SD2cmd(p)
"SD2 111 1 (64-64 0) (1 100) (0 1) 2;"

```
"""
function SD2cmd(p; crs="111")

    #cmd = "SD2 $crs $(p[:stbl]) ($(p[:nfr])-$(p[:nfrez]) $(p[:frd])) ($(p[:nms]) $(p[:msd])) ($(p[:trm]) $(p[:scm])) $(p[:ocf]);"
    cmd = "SD2 $crs $(p[:stbl]) ($(p[:nfr]) $(p[:frd])) ($(p[:nms]) $(p[:msd])) ($(p[:trm]) $(p[:scm])) $(p[:ocf]);"
    
end


                   
"""
`SD3cmd(stbl, plst; crs="111")`

Creates the String that can be sent to the DTC Initium with information specifying 
which pressure ports should be acquired. 

The syntax of the port list `plst` is described in the user manual but there are auxiliary functions that help with this task. See [`PortRange`](@ref), [`strport`](@ref), [`portlist`](@ref), [`strportlist`](@ref) for further information.

Usually, this function is called by function [`SD3`](@ref) and [`addinputs`](@ref). 
"""
SD3cmd(stbl, plst; crs="111") = "SD3 $crs $stbl,$plst;"


"""
`SD5cmd(stbl, actx; crs="111")`

Implements the `SD5` command. This command does a lot of things but for now, only the control option is implemented (`stbl`=-1). 

The default mode of operation uses `actx`=1. In this case, on each measurement, both the pressure and the temperature are measured simultaneously. If high speed is necessary, the temperature can be measured only once (at the beginning) and this is done setting `actx=0`. Positive values greater than 1 of `actx` specify the intermittent rate at which 
temp-sets should be acquired.

Again, this function only creates the String of the command. This function is usually called by [`SD5`](@ref).

"""
function SD5cmd(stbl, actx; crs="111")

    if stbl != -1
        throw(DomainError(stbl, "Control form of SD5 implemented only: stbl = -1!"))
    end
    if actx < 0
        throw(DomainError(actx, "Non-negative integer is acceptable only!"))
    end
    
    return "SD5 $crs -1 $actx;"
end

"""
`PC4cmd(unx, fct=0; lrn=1)`

Create command to change pressure units. There are predefined units for `unx` in 1-12. If `unx` is 0 or 13, a unit conversion factor from psi is employed.

This function is usually called by [`PC4`](@ref).
"""
function PC4cmd(unx, fct=0; lrn=1)

    if unx==0 || unx==13
        if fct ≤ 0 
            throw(DomainError(unx, "For specifying unit conversion factors, unx should be either 0 or 13! and fct should be positive"))
        end
    elseif 1 ≤ unx ≤ 12
        fct = 0
    else
        throw(DomainError(unx, "unx should be 0-13!"))
    end
    return "PC4 $lrn $unx $fct;"
end

"""
`CV1cmd(valpos, puldur)`

Create String command to set calibration valve position for all scanners.
"""
function CV1cmd(valpos, puldur)

    if valpos != 0 || valpos != 1
        throw(DomainError(valpos, "Valve position should be either 0 (RUNPOS) or 1 (CALPOS)"))
    end

    if !(0 ≤ puldur ≤ 199)
        throw(DomainError(puldur, "Pulse duration should be 0-199"))
    end

    return "CV1 $valpos, $puldur;"
end

"""
`CP1cmd(puldur)`

Create String command to set pneumatic pressure calibration valve mode.
"""
function CP1cmd(puldur)
    if puldur < 0 || puldur > 30
        throw(DomainError(puldur, "PULSE duration should be between 0 and 30"))
    end
    return "CP1 $puldur;"
end

"""
`CP2cmd(stbtim)`

Create String command to set the delay time the Initium will wait for pressure to stabilize before reading any data.
"""
function CP2cmd(stbtim)
    if stbtim < 1 || stbtim > 199
        throw(DomainError(stbtim, "Calibration stabilization time should be 1-199 seconds!"))
    end
    return "CP2 $stbtim;"
end



"""
`CA2cmd(lrn=1)`

Creates command String to perform zero pressure calibration.
"""
CA2cmd(lrn=1) = "CA2 $lrn;"


OP2cmd(stbl, ports; crs="111") = "OP2 $crs $(-stbl) $ports;"

OP3cmd(stbl, ports; crs="111") = "OP3 $crs $stbl $ports;"

OP5cmd(stbl; crs="111") = "OP5 $crs $stbl;"

"""
`AD0cmd()`

Creates String command that stops high-speed data acquisition. The command [`AD0`](@ref) is usually used since it actually communicates with the DTC Initium.
"""
AD0cmd() = "AD0;"

"""
`AD2cmd(stbl, nms)`

Creates command to start data acquisition run.

"""
function AD2cmd(stbl, nms)

    if !(1 ≤ stbl ≤ 5)
        throw(DomainError(stbl, "stbl should be 1-5"))
    end

    if !(0 ≤ nms ≤ 65_000)
        throw(DomainError(nms, "nms should be 0-65000"))
    end

    return "AD2 $stbl $nms;"
end

function AD2cmd(stbl)
    if !(1 ≤ stbl ≤ 5)
        throw(DomainError(stbl, "stbl should be 1-5"))
    end
    return "AD2 $stbl;"

end


LA1cmd(port; crs="111") = "LA1 $crs $port;"

LA4cmd(;crs="111") = "LA4 $crs;"

    

function sendcommand!(io, cmd, buf, nbytes)
    println(io, cmd)
    readbytes!(io, buf, nbytes)
end




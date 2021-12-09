

# Implements the DTC Initium commands

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

function SD1cmd(scnlst; crs="111")

    cmd = "SD1 $crs"

    for (scn,npp,lrn) in scnlst
        cmd *= " ($scn,$npp,$lrn)"
    end
    cmd *= ";"
    return cmd
end

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
                   
function SD2cmd(p; crs="111")

    cmd = "SD2 $crs $(p[:stbl]) ($(p[:nfr])-$(p[:nfrez]) $(p[:frd])) ($(p[:nms]) $(p[:msd])) ($(p[:trm]) $(p[:scm])) $(p[:ocf]);"
    
end


                   
function portlist(ports...)
    plst = ""

    for p in ports
        p1 = PortRange(p)
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


function defscanlist(scanners, ports...)
    scn = [s[1] for s in scanners]
    npp = [s[2] for s in scanners]

    ii = sortperm(scn)
    scn = scn[ii]
    npp = npp[ii]
    
    plst = Int[]
    for p1 in ports
        p = PortRange(p1)
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

SD3cmd(stbl, plst; crs="111") = "SD3 $crs $stbl,$plst;"

function SD5cmd(stbl; crs="111")
    if !(0≤stbl≤5)
        throw(DomainError(stbl, "Coefficient form of SD5: 0 ≤ stbl ≤ 5!"))
    end
                  
    return  "SD5 $crs $stbl;"
end

function SD5cmd(stbl, actx; crs="111")

    if stbl != -1
        throw(DomainError(stbl, "Control form of SD5: stbl = -1!"))
    end
    return "SD5 $crs -1 $actx;"
end

function PC4cmd(unx; lrn=1)
    if !(1 ≤ unx ≤ 12)
        throw(DomainError(unx, "Possible units should be 1-12."))
    end
    return "PC4 $lrn $unx;"
end

function PC4cmd(unx, fct; lrn=1)
    if unx != 0 || unx != 13
        throw(DomainError(unx, "For specifying unit conversion factors, unx should be either 0 or 13!"))
    end

    fct1 = float(fct)
    if fct1 ≤ 0
        throw(DomainError(fct, "Unit conversion factor should be a positive number!"))
    end

    return "PC4 $lrn $unx $fct1;"
end

function CV1cmd(valpos, puldur)

    if valpos != 0 || valpos != 1
        throw(DomainError(valpos, "Valve position should be either 0 (RUNPOS) or 1 (CALPOS)"))
    end

    if !(0 ≤ puldur ≤ 199)
        throw(DomainError(puldur, "Pulse duration should be 0-199"))
    end

    return "CV1 $valpos, $puldur;"
end

function CP1cmd(puldur)
    if puldur < 0 || puldur > 30
        throw(DomainError(puldur, "PULSE duration should be between 0 and 30"))
    end
    return "CP1 $puldur;"
end

function CP2cmd(stbtim)
    if stbtim < 1 || stbtim > 199
        throw(DomainError(stbtim, "Calibration stabilization time should be 1-199 seconds!"))
    end
    return "CP2 $stbtim;"
end

CA2cmd(lrn=1) = "CA2 $lrn;"


OP2cmd(stbl, ports; crs="111") = "OP2 $crs $(-stbl) $ports;"

OP3cmd(stbl, ports; crs="111") = "OP3 $crs $stbl $ports;"

OP5cmd(stbl; crs="111") = "OP5 $crs $stbl;"


AD0cmd() = "AD0;"

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




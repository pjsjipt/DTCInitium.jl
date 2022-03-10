"""
    `opensock(ipaddr, port, timeout)`
    `opensock(fun, ipaddr, port, timeout)`
    `opensock(fun, dev, timeout)`

Opens a TCP socket to a DTC Initium at ip address `ipaddr` and port `port`. 
The user can also specify the timeout.

There are versions that accept a function as the first argument and opens calls the
function and closes the port. It is not very useful since when the DTC Initium closes
the port it loses current configurations.


"""
function opensock(ipaddr::IPv4, port=8400, timeout=5)
        
    sock = TCPSocket()
    t = Timer(_ -> close(sock), timeout)
    try
        connect(sock, ipaddr, port)
    catch e
        error("Could not connect to $ipaddr ! Turn on the device or set the right IP address!")
    finally
        close(t)
    end
    
    return sock
end


function opensock(fun::Function, ipaddr::IPv4, port=8400, timeout=5)
    
    io = opensock(ipaddr, port, timeout)
    try
        fun(io)
    finally
        close(io)
    end
    
end

opensock(fun::Function, dev::Initium, timeout=5) =
    opensock(fun, ipaddr(dev), portnum(dev), timeout)



"""
`SD1(dev, scnlst)`

Implements the `SD1` command which configures the scanners connected to the DTC Initium.
This function actually calls [`SD1cmd`](@ref) to build the command message. 

The `scnlst` is vector of `Tuple{Int, Int, Int}` where the first element of the tuple 
corresponds to the number of the connection where the scanner is located, the second
element is the number of pressure ports available and the third member of the tuple
is the logical range number (see the manual for further information).

```
"""
function SD1(dev::Initium, scnlst)

    io = socket(dev)
    isopen(io) || throw(ArgumentError("Socket not open!"))

    scn = Tuple{Int,Int,Int}[]
    #scn = scanners(dev)

    #if length(scn) > 0
    #    throw(ArgumentError("Scanners have already been added!"))
    #end
    
    for s in scnlst
        push!(scn, s)
    end
    
    cmd = SD1cmd(scn, crs=getcrs(dev))
    println(io, cmd)
    resp = read(io, 8)
    
    ispackerr(resp)  && throw(DTCInitiumError(resperr(resp)))
    
    return respconf(resp)
end

"""
`SD2(dev;  stbl=1, nfr=64, nms=1, msd=100, trm=0, scm=1, ocf=2)`



This function will configures the data acquisition parameters. The parameters are described below. For further information, see the user manual.

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

"""
function SD2(dev::Initium; stbl=1, nfr=64, nms=1, msd=100, trm=0, scm=1, ocf=2)

    io = socket(dev)
    isopen(io) || throw(ArgumentError("Socket not open!"))

    params = setdaqparams(stbl=stbl, nfr=nfr, nms=nms, msd=msd, trm=trm, scm=scm, ocf=ocf)
    cmd = SD2cmd(params, crs=getcrs(dev))

    println(io, cmd)
    resp = read(io, 8)
    ispackerr(resp) && throw(DTCInitiumError(resperr(resp)))

    dev.params = params

    dev.isconfigured = true
    
    return respconf(resp)
                 
end


"""
    `SD3(dev, stbl, ports)`

Configures the ports that should be used during data acquisition. Different port 
configurations can be used, one for each `stbl` configured. This is useful where different measurements sets are necessary. 

The ports are specified as a vector of [`PortRange`](@ref) objects. They can also be 
specified as text ranges ("101-164") or `UnitRange{Int}` (101:164).

There are 8 scanner connections on the DTC Initium. The ports are specified by numbers
where de hundreds digit corresponds to the connection where scanner is located on the 
DTC Initium. To refer to the first 32 ports on the second scanner, use "201-232". 
If multiple scanners are specified, and all ports should be used, something
like "101-864" should work where all ports in 8 scanners are specified. 

The function tries to check  if the specified ports are compatible with the scanners
specified in the [`SD1`](@ref) command ([`checkportlist`](@ref) ). 

To get a vector with all port numbers configured, use function [`defscanlist`](@ref).


For further information, see the User Manual.

"""
function SD3(dev::Initium, stbl, ports::AbstractVector{PortRange})

    if !checkportlist(scanners(dev), ports)
        throw(ArgumentError("Invalid pressure ports"))
    end


    io = socket(dev)
    isopen(io) || throw(ArgumentError("Socket not open!"))
    
    pcmd = strportlist(ports)

    cmd = SD3cmd(stbl, pcmd, crs=getcrs(dev))

    println(io, cmd)
    resp = read(io, 8)
    ispackerr(resp) && throw(DTCInitiumError(resperr(resp)))

    return respconf(resp)
                 
end

SD3(dev::Initium, stbl, ports...) = SD3(dev, stbl, portlist(ports...))

"""
`SD5(dev, actx)`

Implements the `SD5` command. This command does a lot of things but for now, only the control option is implemented (it calls [`SD5cmd`](@ref) with `stbl`=-1). 

The default mode of operation uses `actx`=1. In this case, on each measurement, both the pressure and the temperature are measured simultaneously. If high speed is necessary, the temperature can be measured only once (at the beginning) and this is done setting `actx=0`. Positive values greater than 1 of `actx` specify the intermittent rate at which 
temp-sets should be acquired.


"""
function SD5(dev::Initium, actx)

    stbl = -1
    io = socket(dev)

    isopen(io) || throw(ArgumentError("Socket not open!"))

    cmd = SD5cmd(stbl, actx, crs=getcrs(dev))

    println(io, cmd)
    resp = read(io, 8)
    ispackerr(resp) && throw(DTCInitiumError(resperr(resp)))

    dev.actx = actx
    
    return respconf(resp)
    
end


"""
`PC4(unx, fct=0; lrn=1)`

Change pressure units. There are predefined units for `unx` in 1-12. If `unx` is 0 or 13, a unit conversion factor from psi is employed specified by parameter `fct`. 

| unx | Unit |   factor  |
| --- | ---- | --------- |
| 0   | user |  ?        |
| 1   | psi  | 1.0       |
| 2   | inH2O| 27.673    |
| 3   | Pa   | 6894.757  |   
| 4   | kG/m2| 703.0696  |
| 5   | G/cm2| 70.30696  |
| 6   | ATM  | 0.068046  |
| 7   | mmHg | 51.71493  |
| 8   | mmH2O| 703.08    |
| 9   | bar  | 0.0689475 |
| 10  | kPa  | 6.894757  |
| 11  | mBar | 68.94757  |
| 12  | PSF  | 144.0     |
| 13  | user |   ?       |
"""
function PC4(dev, unx, fct=0; lrn=1)

    cmd = PC4cmd(unx, fct, lrn=lrn)

    io = socket(dev)
    isopen(io) || throw(ArgumentError("Socket not open!"))
    
    println(io, cmd)
    resp = read(io, 8)
    ispackerr(resp) && throw(DTCInitiumError(resperr(resp)))
    
    return respconf(resp)
    
end

"""
    `CA2(dev)`

Perform a zero calibration, basically measure the pressure and use it as a reference.
If the DTC Initium is provided with the appropriate pressure connections, the scanners
can be zeroed while measuring.

"""
function CA2(dev; lrn=1)
    cmd = CA2cmd(lrn)

    io = socket(dev)
    isopen(io) || throw(ArgumentError("Socket not open!"))
    
    println(io, cmd)
    resp = read(io, 8)
    ispackerr(resp) && throw(DTCInitiumError(resperr(resp)))
    
    return respconf(resp)
    
end


"""
    `AD0(dev)`

Stop data acquisition.
"""
function AD0(dev)
    cmd = AD0cmd()

    io = socket(dev)
    isopen(io) || throw(ArgumentError("Socket not open!"))

    # This is kind of tricky.
    # There might be more frames already coming in.
    # so will will try to read every packet until we get a confirmatio/error packet
    
    println(io, cmd)
    resp = UInt8[]
    
    while true
        resp = readresponse(io)
        rtype = resptype(resp)

        if rtype==4 || rtype==128
            break
        end
        
    end
    
    
    ispackerr(resp) && throw(DTCInitiumError(resperr(resp)))
    
    return respconf(resp)
end

"""
    `AD2(dev, stbl, nms)`

Acquire data using `stbl`. If `nms` is not provided it will use 
the default value specified in the [`SD2`](@ref) command. This function acquires
all responses sequentially and therefore it can use any value of `ocf` (see [`SD2`](@ref))

"""
function AD2(dev, stbl, nms=-1)

    if stbl < 1 || stbl > 5
        throw(DomainError(stbl, "STBL should be between 1 and 5!"))
    end

    params = daqparams(dev)
    if !haskey(params, stbl)
        throw(DomainError(stbl, "STBL $stbl is not yet configured!"))
    end
    
    if nms < 0
        cmd = AD2cmd(stbl)
    else
        cmd = AD2cmd(stbl, nms)
    end
    println(cmd)
    io = socket(dev)
    isopen(io) || throw(ArgumentError("Socket not open!"))
    println(io, cmd)

    resp = Vector{UInt8}[]
    t1 = time_ns()
    t2 = UInt64(0)
    while true
        r = readresponse(io)
        rtype = resptype(r)
        t2 = time_ns()
        if rtype==4 || rtype==128
            break
        end
       
        push!(resp, r)
    end
    return resp, Float64(t2-t1)/1e6
end

"""
    `readresponse(io)`

Reads a response from the DTC Initium. It is capable of reading any type of response.
It will just return the bytes acquired, no processing or parsing is done.
"""
function readresponse(io)
    # Read header
    hdr = read(io, 8)
    msglen = resplen(hdr)
    if msglen > 8
        rest = read(io, msglen-8)
        return [hdr;rest]
    else
        return  hdr
    end
    
end
readresponse(dev::Initium) = readresponse(socket(dev))


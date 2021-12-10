
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




function SD1(dev::Initium)

    io = socket(dev)
    isopen(io) || throw(ArgumentError("Socket not open!"))
    
    cmd = SD1cmd(scanners(dev), crs=getcrs(dev))
    println(io, cmd)
    resp = read(io, 8)
    
    ispackerr(resp)  && throw(DTCInitiumError(resperr(resp)))
    
    return respconf(resp)
end

function SD2(dev::Initium; stbl=1, nfr=64, nms=1, msd=100, trm=0, scm=1, ocf=2)

    io = socket(dev)
    isopen(io) || throw(ArgumentError("Socket not open!"))

    params = daqparams(stbl=stbl, nfr=nfr, nms=nms, msd=msd, trm=trm, scm=scm, ocf=ocf)
    cmd = SD2cmd(params, crs=getcrs(dev))

    println(io, cmd)
    resp = read(io, 8)
    ispackerr(resp) && throw(DTCInitiumError(resperr(resp)))

    daqparams(dev)[stbl] = params
   
    return respconf(resp)
                 
end

function SD3(dev::Initium, stbl, ports::Vector{PortRange})

    if !checkportlist(scanners(dev), ports)
        thrown(ArgumentError("Invalid pressure ports"))
    end


    io = socket(dev)
    isopen(io) || throw(ArgumentError("Socket not open!"))
    
    pcmd = strportlist(ports...)

    cmd = SD3cmd(stbl, pcmd, crs=getcrs(dev))

    println(io, cmd)
    resp = read(io, 8)
    ispackerr(resp) && throw(DTCInitiumError(resperr(resp)))

    dev.chans[stbl] = ports
    
    return respconf(resp)
                 
end


function PC4(dev, unx, fct=0; lrn=1)

    cmd = PC4cmd(unx, fct, lrn=lrn)

    io = socket(dev)
    isopen(io) || throw(ArgumentError("Socket not open!"))
    
    println(io, cmd)
    resp = read(io, 8)
    ispackerr(resp) && throw(DTCInitiumError(resperr(resp)))
    
    return respconf(resp)
    
end


function genericesponse(io)

    b1 = read(io, 8)
    plen = resplen(b1)

    if b1[2] == 4 || b1[2] == 128
        return respconf(b1)
    elseif b1[2] == 8
        return respsinglevali(b1)
    elseif b1[2] == 9
        return respsinglevalf(b1)
    elseif ispackstreamdata(b1)
        
    end
    
        
end

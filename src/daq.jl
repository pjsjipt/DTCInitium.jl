
#import AbstractDAQ.daqaddinput

function addinput(dev::Initium, ports::AbstractVector{PortRange})
    stbl = dev.stbl
    SD3(dev, stbl, ports)
end


addinput(dev::Initium, ports::AbstractString) = addinput(dev, portlist(ports))
addinput(dev::Initium, ports...) = addinput(dev, portlist(ports...))

        
    

#import AbstractDAQ.daqconfig
function daqconfig(dev::Initium; freq, nsamples=0, avg=1, trigger=0)

    ms = Int(1000/freq)
    stbl = dev.stbl

    nfr = avg
    nms = nsamples
    msd = ms
    SD2(dev, stbl=stbl, nfr=nfr, nms=nsamples, msd=ms, trm=trigger, scm=1, ocf=2)
    

end

function readpacket!(io, buf)

    readbytes!(io, buf, 8)
    msglen = resplen(buf)

    if msglen > 8
        buf2 = @view buf[9:end]
        readbytes!(io, buf2, msglen-8)
    end
    return resptype(buf)
end

function read_scanner(dev; stbl=1)

    io = socket(dev)
    isopen(io) || throw(ArgumentError("Socket not open!"))
    
    par = daqparams(dev)[stbl]
    
    nsamples = par[:nms]
    tsk = dev.task
    
    resizebuffer!(tsk, nsamples)

    tsk.idx = 0
    tsk.nread = 0
    
    cmd = AD2cmd(stbl)
    println(io, cmd)
    idx = incidx!(tsk)
    t0 = time_ns()
    ptype = readpacket!(io, buffer(tsk,idx))
    t1 = time_ns()
    tn = t1
    #if ptype == 4 || ptype == 128  # Confirmation or error
    for i in 2:nsamples
        idx = incidx!(tsk)
        ptype = readpacket!(io, buffer(tsk, idx))
        tn = time_ns()
    end
    idx = incidx!(tsk)
    readpacket!(io, buffer(tsk, idx))

    return t0, t1, tn
end

    
        

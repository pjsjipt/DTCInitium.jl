
function AbstractDAQ.daqaddinput(dev::Initium, ports...; stbl=1)
    plst = portlist(ports...)
    SD3(dev, stbl, plst)
end

function AbstractDAQ.daqconfig(dev::Initium; freq=1, nsamples=0, avg=1, trigger=0, stbl=1)
    
    ms = Int(1000/freq)
    nfr = avg
    nms = nsamples
    msd = ms
    SD2(dev, stbl=stbl, nfr=nfr, nms=nsamples, msd=ms, trm=trigger, scm=1, ocf=2)

end

function readresponse!(io, buf)

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
    
    par = daqparams(dev, stbl)

    # Only EU units without temp-sets
    if par[:ocf] != 2
        error("Paramater ocf should be 2!")
    end
     
    tsk = dev.task

    nsamples = par[:nms]
    
    if nsamples > 0
        resizebuffer!(tsk, nsamples, dec=false)
    end
    
    initbuffer!(tsk)

    tsk.isreading = true
    
    cmd = AD2cmd(stbl)
    println(io, cmd)
    t0 = time_ns()
    b = nextbuffer!(tsk)
    ptype = readresponse!(io, b)
    t1 = time_ns()
    settiming!(tsk, t0, t1, 1)
    # Check to see if everything went well
    rtype = resptype(b)
    if rtype==4 || rtype == 128 || tsk.stop
        tsk.isreading = false
        tsk.nread = 0
        tsk.idx = 0
        initbuffer!(tsk)
        return
    end
    
    tsk.nread += 1
    tn = t1
    #if ptype == 4 || ptype == 128  # Confirmation or error
    stopped = false
    if nsamples == 0
        nn = 65000
    else
        nn = nsamples
    end
    
    for i in 2:nn
        b = nextbuffer!(tsk) 
        ptype = readresponse!(io, b)
        tn = time_ns()
        rtype = resptype(b)
        if rtype==4 || rtype == 128 || tsk.stop
            # We don't need to store this packet!
            rewindbuffer!(tsk)
            stopped = true
            break
        end
        settiming!(tsk, t1, tn, i-1)
    end

    tsk.isreading = false
    
    if !stopped
        # Got here without the break. Normal operation. 
        # Read the end buffer
        b = readresponse(io)
    end

    return
end

function read_pressure(dev)
    tsk  = dev.task
    #if tsk.pnext 

end


function AbstractDAQ.daqacquire(dev::Initium)

    clearbuffer!(dev.task)
    
end

AbstractDAQ.numchannels(dev::Initium, stbl=1) = dev.chans[stbl].nchans

    
"""

"""
daqchannels(dev::Initium, stbl=1) = dev.chans[stbl].channels


function AbstractDAQ.daqaddinput(dev::Initium, ports...; stbl=1)
    plst = portlist(ports...)
    SD3(dev, stbl, plst)
end

function AbstractDAQ.daqconfig(dev::Initium; freq=1, nsamples=0, avg=1, trigger=0, stbl=1)
    
    ms = round(Int, 1000/freq)
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

function readscanner!(dev, stbl=1)

    io = socket(dev)
    isopen(io) || throw(ArgumentError("Socket not open!"))
    
    par = daqparams(dev, stbl)

    # Only EU units without temp-sets
    if par[:ocf] != 2
        error("Paramater ocf should be 2!")
    end
     
    tsk = dev.task
    buf = dev.buffer
    nsamples = par[:nms]
    
    if nsamples > capacity(buf)
        resize!(buf, nsamples)
    end
    
    cleartask!(tsk)
    empty!(buf)
    
    tsk.isreading = true

    cmd = AD2cmd(stbl)
    println(io, cmd)

    t0 = time_ns()

    b = nextbuffer(buf)
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
    i = 1
    while true
        # Test if daq is non continuous and we have already read nsamples
        i += 1
        if (nsamples > 0 && i > nsamples)
            break
        end

        # Check if we should stop reading
        if tsk.stop
            stopped = true
            break
        end
        
        # Read packet
        b = nextbuffer(buf) 
        ptype = readresponse!(io, b)
        tn = time_ns()
        rtype = resptype(b)
        # Is packet error or confirmation - daq has ended
        if rtype==4 || rtype == 128 
            # We don't need to store this packet!
            pop!(b)
            stopped = true
            break
        end
        tsk.nread += 1
        # Set timing stuff
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

function readpressure(dev, stbl=1)
    tsk  = dev.task
    buf = dev.buffer

    nt = length(buf)
    nch = numchannels(dev, stbl=stbl)

    P = Matrix{Float32}(undef, nch, nt)
    idx = (1:nch*4) .+ 24
    for i in 1:nt
        P[:,i] .= ntoh.(reinterpret(Float32,buf[i][idx]))
    end

    return P
    
end

AbstractDAQ.isreading(dev::Initium) = dev.task.isreading
AbstractDAQ.samplesread(dev::Initium) = dev.task.nread


function AbstractDAQ.daqacquire(dev::Initium; stbl=1)

    readscanner!(dev, stbl)
    fs = samplingfreq(dev.task)
    P = readpressure(dev, stbl)

    return P, fs
end

function AbstractDAQ.daqstart(dev::Initium, usethread=false; stbl=1)
    if isreading(dev)
        error("DTC Initium already reading!")
    end

    if usethread
        tsk = Threads.@spawn readscanner!(dev, stbl)
    else
        tsk = @async readscanner!(dev, stbl)
    end

    dev.task.task = tsk
end

function AbstractDAQ.daqread(dev::Initium; stbl=1)
    sleep(0.1)
    while isreading(dev)
        sleep(0.1)
    end
    fs = samplingfreq(dev.task)
    P = readpressure(dev, stbl)

    return P, fs
end

function AbstractDAQ.daqstop(dev::Initium)
    tsk = dev.task

    tsk.stop = true
    AD0(dev)
    
end


AbstractDAQ.numchannels(dev::Initium; stbl=1) = dev.chans[stbl].nchans

    
"""

"""
AbstractDAQ.daqchannels(dev::Initium, stbl=1) = dev.chans[stbl].channels

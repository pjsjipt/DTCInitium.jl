
function AbstractDAQ.daqaddinput(dev::Initium, ports...; stbl=-1)
    if stbl < 1
        stbl = dev.stbl
    end
    
    plst = portlist(ports...)
    SD3(dev, stbl, plst)
end

function AbstractDAQ.daqconfigdev(dev::Initium; stbl=-1, kw...)
    if stbl < 1
        stbl = dev.stbl
    end
    
    k = keys(kw)
    p = dev.params[stbl]
    if :nfr ∈ k
        nfr = kw[:nfr]
        if nfr < 1 || nfr > 127
            throw(DomainError(nfr, "nfr range is 1-127!"))
        end
    else
        nfr = p[:nfr]
    end

    if :nms ∈ k
        nms = kw[:nms]
        if !(0 ≤ nms ≤ 65_000)
            throw(DomainError(nms, "nms range is 0-65_000!"))
        end
    else
        nms = p[:nms]
    end

    if :msd ∈ k
        msd = kw[:msd]
        if !(0 ≤ msd ≤ 600_000)
            throw(DomainError(msd, "msd range is 0-600_000!"))
        end
    else
        msd = p[:msd]
    end

    if :trm ∈ k
        trm = kw[:trm]
        if trm < 0 && trm > 2
            throw(DomainError(trm, "trm should be 0, 1 or 2!"))
        end
    else
        trm = p[:trm]
    end
            
    scm = 1
    ocf = 2

    SD2(dev, stbl=stbl, nfr=nfr, nms=nms, msd=msd, trm=trm, scm=scm, ocf=ocf)
    updateconf!(dev, stbl=stbl)
end

            
    
function AbstractDAQ.daqconfig(dev::Initium; stbl=-1, kw...)
    if stbl < 1
        stbl = dev.stbl
    end

    p = dev.params[stbl]
    
    if haskey(kw, :avg)
        nfr = kw[:avg]
    else
        nfr = p[:nfr]
    end

    if haskey(kw, :nms) && haskey(kw, dt)
        error("Parameters `freq` and `dt` can not be specified simultaneously!")
    elseif haskey(kw, :freq) || haskey(kw, :dt)
        if haskey(kw, :freq)
            freq = kw[:freq]
            msd = round(Int, 1000/freq)
        elseif haskey(kw, :dt)
            dt = kw[:dt]
            msd = round(Int, 1000*dt)
        else
            msd = p[:msd]
        end
    end

    if haskey(kw, :nsamples) && haskey(kw, :time)
        error("Parameters `nsamples` and `time` can not be specified simultaneously!")
    elseif haskey(kw, :nsamples) || haskey(kw, :time)
        if haskey(kw, :nsamples)
            nms = kw[:nsamples]
        else haskey(kw, :time)
            tt = kw[:time]
            # If actx = 0: dt ≈ 2.5 (better check these values)
            # if actx = 1: dt ≈ 8 (fastest ?  daq when with nfr=1)
            dt0 = 3.0 # Approximate fastest data acquisition
            dt1 = 6.0  # Better check this
            dt_temp = dt1 - dt0
            dt2 = (dev.actx==0) ? (nfr*dt0) : (nfr*dt0 + dt_temp)
            dt = max(dt2, msd)
            nms = round(Int, time * 1000 / dt)
        end
    else
        nms = p[:nms]
    end

    if haskey(kw, :trigger)
        trm = kw[:trigger]
    end

    daqconfigdev(dev, stbl=stbl, nfr=nfr, nms=nms, msd=msd, trm=trm, scm=1, ocf=2)

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

function readscanner!(dev, stbl=-1)
    if stbl < 1
        stbl = dev.stbl
    end

    io = socket(dev)
    isopen(io) || throw(ArgumentError("Socket not open!"))
    
    par = dev.params[stbl]

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
        cleartask!(tsk)
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
    
    if stopped
        # Got here without the break. Normal operation. 
        # Read the end buffer
        while true
            sleep(0.5)
            b = readresponse(io)
            rtype = resptype(b)
            if rtype == 4 || rtype == 128
                break
            end
        end
        
    else
        sleep(0.1)
        b = readresponse(io)
    end
    
    return
end

function readpressure(dev, stbl=-1)
    if stbl < 1
        stbl = dev.stbl
    end
    
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


function AbstractDAQ.daqacquire(dev::Initium; stbl=-1)
    if stbl < 1
        stbl = dev.stbl
    end

    readscanner!(dev, stbl)
    fs = samplingfreq(dev.task)
    P = readpressure(dev, stbl)

    return P, fs
end

function AbstractDAQ.daqstart(dev::Initium, usethread=false; stbl=-1)
    if stbl < 1
        stbl = dev.stbl
    end
    
    if isreading(dev)
        error("DTC Initium already reading!")
    end

    if usethread
        tsk = Threads.@spawn readscanner!(dev, stbl)
    else
        tsk = @async readscanner!(dev, stbl)
    end

    dev.task.task = tsk
    return tsk
end

function AbstractDAQ.daqread(dev::Initium; stbl=-1)
    if stbl < 1
        stbl = dev.stbl
    end

    # If we are doing continuous data acquisition, we first need to stop it
    if dev.params[stbl][:nms] == 0
        # Stop reading!
        daqstop(dev)
    end

    # Wait for the task to end (if it was started
    if !istaskdone(dev.task.task) && istaskstarted(dev.task.task)
        wait(dev.task.task)
    end
    
    # Read the pressure and the sampling frequency
    fs = samplingfreq(dev.task)
    P = readpressure(dev, stbl)

    return P, fs
end

function AbstractDAQ.daqstop(dev::Initium)
    tsk = dev.task
    # If DTC is scanning, we need to stop it
    if !istaskdone(tsk.task) && istaskstarted(tsk.task)
        tsk.stop = true
        AD0(dev)
        wait(tsk.task)
    end
    dev.task.stop = false
    dev.task.isreading = false
end


function AbstractDAQ.numchannels(dev::Initium; stbl=-1)
    if stbl < 1
        stbl = dev.stbl
    end

    return dev.chans[stbl].nchans
end
    
"""

"""
function AbstractDAQ.daqchannels(dev::Initium, stbl=-1)
    if stbl < 1
        stbl = dev.stbl
    end

    dev.chans[stbl].channels
end

function AbstractDAQ.daqzero(dev::Initium; lrn=1, time=15)

    CA2(dev; lrn=lrn)

    sleep(time)
end

    

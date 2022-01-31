
"""
`daqaddinput(dev::Initium, ports...)`

Add channels to the Initium.

After adding scanners, the channels that should be acquired must be specified. 
The ports can be specified as ranges, or individual channels. See [`portlist`](@ref) 
for mor information


## Examples

```julia-repl
julia> daqaddinput(dev, 101:104, 106)
0

julia> daqaddinput(dev, 101:104, 201:204, "301-304")
0

julia> numchannels(dev)
12
```
"""
function AbstractDAQs.daqaddinput(dev::Initium, ports...)
    stbl = dev.stbl
    plst = portlist(ports...)
    SD3(dev, stbl, plst)
end


"""
`daqconfigdev(dev::Initium; kw...)`

Configures data acquisition for the the DTC Initium. 

This method configures data acquisition using the parameters and terminology found
in the DTC Initium's user manual. For a more generic interface, check out
[`daqconfig`](@dev).

The exact details for daq configuration in this case can be found under the command SD2 in the user manual.

The following parameters can be configured

 * `nfr` Number of frames that will be averaged (1-127)
 * `nms` Number of pressure samples that should be read. 0-65000. Use 0 for continuous reading.
 * `msd` Time interval in ms between pressure samples. If reading takes longer, a longer period of time will be used.
 * `trm` Trigger
    - 0 for internal software trigger
    - 1 for triggering only the initial measurement
    - 2 for triggering each measurement

There are other parameters that can be configured but they are not 
used in this interface.

```julia-repl
julia> daqconfigdev(dev, nfr=1, nms=2000, msd=0)

julia> daqconfigdev(dev, nfr=1, nms=2000, msd=0) # Acquire 2000 points as fas as possible

julia> daqconfigdev(dev, nfr=1, nms=10, msd=20) # Acquire 10 points every 20 ms

julia> daqconfigdev(dev, nfr=10, nms=10, msd=200) # Acquire 10 points every 200 ms. Average 10 pressure measurements before outputing data
```
"""
function AbstractDAQs.daqconfigdev(dev::Initium; kw...)
    stbl = dev.stbl
    
    k = keys(kw)
    p = dev.params
    if :nfr ∈ k
        nfr = kw[:nfr]
        if nfr < 1 || nfr > 127
            throw(DomainError(nfr, "nfr range is 1-127!"))
        end
    elseif haskey(p, :nfr)
        nfr = p[:nfr]
    else
        nfr = 1
    end

    if :nms ∈ k
        nms = kw[:nms]
        if !(0 ≤ nms ≤ 65_000)
            throw(DomainError(nms, "nms range is 0-65_000!"))
        end
    elseif haskey(p, :nms)
        nms = p[:nms]
    else
        nms = 1
    end

    if :msd ∈ k
        msd = kw[:msd]
        if !(0 ≤ msd ≤ 600_000)
            throw(DomainError(msd, "msd range is 0-600_000!"))
        end
    elseif haskey(p, :msd)
        msd = p[:msd]
    else
        msd = 100
    end

    if :trm ∈ k
        trm = kw[:trm]
        if trm < 0 && trm > 2
            throw(DomainError(trm, "trm should be 0, 1 or 2!"))
        end
    elseif haskey(p, :trm)
        trm = p[:trm]
    else
        trm = 0
    end
            
    scm = 1
    ocf = 2

    SD2(dev, stbl=stbl, nfr=nfr, nms=nms, msd=msd, trm=trm, scm=scm, ocf=ocf)
    updateconf!(dev)
end

            
    
function AbstractDAQs.daqconfig(dev::Initium; kw...)
    stbl = dev.stbl

    p = dev.params
    
    if haskey(kw, :avg)
        nfr = kw[:avg]
    else
        nfr = p[:nfr]
    end

    if haskey(kw, :nms) && haskey(kw, dt)
        error("Parameters `rate` and `dt` can not be specified simultaneously!")
    elseif haskey(kw, :rate) || haskey(kw, :dt)
        if haskey(kw, :rate)
            rate = kw[:rate]
            msd = round(Int, 1000/rate)
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
"""
`readscanner!(dev)`

Actually execute a data acquisition on the channels specified
by [`daqaddinput`](@ref) with daq configuration specified by [`daqconfig`](@ref) or
[`daqconfigdev`](@ref).

This function will initiate data acquisition and store the data in the
 daq buffer (`dev.buffer`). This function will also measure the time taken 
to read data. Data is retrieved using function [`readpressure`](@ref).

This function is usually not called directly. Methods [`daqacquire`](@ref) and 
[`daqread`](@ref) should be used.
"""
function readscanner!(dev)
    stbl = dev.stbl

    io = socket(dev)
    isopen(io) || throw(ArgumentError("Socket not open!"))
    
    par = dev.params

    # Only EU units without temp-sets
    if par[:ocf] != 2
        error("Paramater ocf should be 2!")
    end
     
    tsk = dev.task
    buf = dev.buffer
    nsamples = par[:nms]
    
    
    if nsamples > capacity(buf)
        resize!(buf, min(nsamples,100))
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
            pop!(buf)
            stopped = false
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

"""
`readpressure(dev)`

Retrieve pressure measurements stored in the buffer. 

The DTC Initium is large-endian. This function allocates memory for the output. It 
*does not* empty the buffer.

This function is usually not called directly. Methods [`daqacquire`](@ref) and 
[`daqread`](@ref) should be used.
"""
function readpressure(dev)
    stbl = dev.stbl
    tsk  = dev.task
    buf = dev.buffer

    nt = length(buf)
    nch = numchannels(dev)

    P = Matrix{Float32}(undef, nch, nt)
    idx = (1:nch*4) .+ 24
    for i in 1:nt
        P[:,i] .= ntoh.(reinterpret(Float32,buf[i][idx]))
    end

    return P
    
end

AbstractDAQs.isreading(dev::Initium) = dev.task.isreading
AbstractDAQs.samplesread(dev::Initium) = dev.task.nread


function AbstractDAQs.daqacquire(dev::Initium)
    stbl = dev.stbl
    numchannels(dev) == 0 && error("No channels configured for stbl=$stbl!")

    readscanner!(dev)
    fs = samplingrate(dev.task)
    P = readpressure(dev)

    return P, fs
end

function AbstractDAQs.daqstart(dev::Initium, usethread=false)
    stbl = dev.stbl
    numchannels(dev) == 0 && error("No channels configured for stbl=$stbl!")
    
    if isreading(dev)
        error("DTC Initium already reading!")
    end

    if usethread
        tsk = Threads.@spawn readscanner!(dev)
    else
        tsk = @async readscanner!(dev)
    end

    dev.task.task = tsk
    return tsk
end

function AbstractDAQs.daqread(dev::Initium)
    stbl = dev.stbl

    # If we are doing continuous data acquisition, we first need to stop it
    if dev.params[:nms] == 0
        # Stop reading!
        daqstop(dev)
    end

    # Wait for the task to end (if it was started
    if !istaskdone(dev.task.task) && istaskstarted(dev.task.task)
        wait(dev.task.task)
    end
    
    # Read the pressure and the sampling frequency
    fs = samplingrate(dev.task)
    P = readpressure(dev)

    return P, fs
end

function AbstractDAQs.daqstop(dev::Initium)
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


AbstractDAQs.numchannels(dev::Initium) = dev.chans.nchans
    
"""

"""
AbstractDAQs.daqchannels(dev::Initium) = dev.chans.channels


function AbstractDAQs.daqzero(dev::Initium; lrn=1, time=15)
    CA2(dev; lrn=lrn)
    sleep(time)
end

    

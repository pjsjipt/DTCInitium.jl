using Dates
"""
`daqaddinput(dev::Initium, ports...; names="P")`

Add channels to the [`Initium`](@ref).

After adding scanners, the channels that should be acquired must be specified. 
The ports can be specified as ranges, or individual channels. See [`portlist`](@ref).

The pressure ports have, each, string names that can be specified with the `names`
keyword argument. If `names` is a single string, it will append this string to the
beginning of the port number. The other option is to provide exact names for each 
pressure port.

For more information see [`addpressports`](@ref). 


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
function DAQCore.daqaddinput(dev::Initium, ports...; names="P")
    stbl = dev.stbl
    plst = portlist(ports...)
    addpressports(dev, plst; names=names)
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
function DAQCore.daqconfigdev(dev::Initium; kw...)
    stbl = dev.stbl
    
    k = keys(kw)

    if :actx ∈ k
        actx = kw[:actx]
        actx < 0 && throw(DomainError(actx, "actx ≥ 0"))
        setfastdaq!(dev, actx)
    end
    
    if :nfr ∈ k
        nfr = kw[:nfr]
        if nfr < 1 || nfr > 127
            throw(DomainError(nfr, "nfr range is 1-127!"))
        end
    elseif ihaskey(dev, "nfr")
        nfr = iparam(dev, "nfr")
    else
        nfr = 1
    end

    if :nms ∈ k
        nms = kw[:nms]
        if !(0 ≤ nms ≤ 65_000)
            throw(DomainError(nms, "nms range is 0-65_000!"))
        end
    elseif ihaskey(dev, "nms")
        nms = iparam(dev, "nms")
    else
        nms = 1
    end

    if :msd ∈ k
        msd = kw[:msd]
        if !(0 ≤ msd ≤ 600_000)
            throw(DomainError(msd, "msd range is 0-600_000!"))
        end
    elseif haskey(dev, "msd")
        msd = iparam(dev, "msd")
    else
        msd = 100
    end

    if :trm ∈ k
        trm = kw[:trm]
        if trm < 0 && trm > 2
            throw(DomainError(trm, "trm should be 0, 1 or 2!"))
        end
    elseif ihaskey(dev, "trm")
        trm = iparam(dev, "trm")
    else
        trm = 0
    end
            
    scm = 1
    ocf = 2

    SD2(dev, stbl=stbl, nfr=nfr, nms=nms, msd=msd, trm=trm, scm=scm, ocf=ocf)
end

            
"""
`daqconfig(dev::Initium; kw...)`

Configures the DTC Initium data acquisition parameters such as sampling rate (or period)
and number of samples (or total sampling time).

**This function is not recommended** since for fast data acquisition, the sampling rate
depends on the number of channels and other parameters. This is still an ongoing work.

PLEASE USE THE FUNCTION [`daqconfigdev`](@ref) and check the manual if in doubt.

"""    
function DAQCore.daqconfig(dev::Initium; kw...)
    stbl = dev.stbl

    
    if haskey(kw, :avg)
        nfr = kw[:avg]
    else
        nfr = iparam(dev, "nfr")
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
            msd = iparam(dev, "msd")
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
        nms = iparam(dev, "nms")
    end

    if haskey(kw, :trigger)
        trm = kw[:trigger]
    end

    daqconfigdev(dev, stbl=stbl, nfr=nfr, nms=nms, msd=msd, trm=trm, scm=1, ocf=2)

end

"""
`readresponse!(io, buf)`

Reads a response into a buffer.

It first reads the 8 byte response and then, if necessary, reads the rest of the response.
The buffer should be large enough!
"""
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
    

    # Only EU units without temp-sets
    if iparam(dev, "ocf") != 2
        error("Paramater ocf should be 2!")
    end
     
    tsk = dev.task
    buf = dev.buffer
    nsamples = iparam(dev, "nms")
    
    
    if nsamples > capacity(buf)
        resize!(buf, min(nsamples,100))
    end
    
    cleartask!(tsk)
    empty!(buf)

    tsk.isreading = true
    tsk.time = now()
    cmd = AD2cmd(stbl, nsamples)
    println(io, cmd)
    
    t0 = time_ns()
    t1 = t0
    b = nextbuffer(buf)
    try
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
    catch e
        throw(e)
    end
    
    
    tsk.nread += 1
    tn = t1
    #if ptype == 4 || ptype == 128  # Confirmation or error
    stopped = false
    i = 1
    ok = true
    exthrown = false  # No exception (Ctrl-C) thrown!
    while true
        # Test if daq is non continuous and we have already read nsamples
        try
            i += 1
            if (nsamples > 0 && i > nsamples)
                break
            end
            
            # Check if we should stop reading
            if tsk.stop
                stopped = true
                ok = false
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
                ok = false
                break
            end
            tsk.nread += 1
            # Set timing stuff
            settiming!(tsk, t1, tn, i-1)
        catch e
            if isa(e, InterruptException)
                # Ctrl-C captured!
                # We want to stop the data acquisition safely and rethrow it
                AD0(dev) # Send stop command
                tsk.stop = true # Next iteration we treat this as a stop command
                exthrown = true # But we will let the code know that Ctrl-C was pressed
            else
                throw(e) # Some other error. Let someone else handle it
            end
        end
        
    end

    tsk.isreading = false
    
    if stopped
        # Got here without the break. Normal operation. 
        # Read the end buffer
        sleep(0.5)
        while true
            sleep(0.5)
            b = readresponse(io)
            rtype = resptype(b)
            if rtype == 4 || rtype == 128
                break
            end
        end
        if exthrown  # Ctrl-C was pressed
            throw(InterruptException)
        end
    elseif ok
        sleep(0.5)
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

"Is the DTC Initium reading data?"
DAQCore.isreading(dev::Initium) = dev.task.isreading
"How many samples has the DTC Initium read?"
DAQCore.samplesread(dev::Initium) = dev.task.nread

export meastime, measdata, measinfo, samplingrate

"""
`daqacquire(dev::Initium)`

Acquire data synchronously from the DTC Initium using the present configurations.

"""
function DAQCore.daqacquire(dev::Initium)
    stbl = dev.stbl
    numchannels(dev) == 0 && error("No channels configured for stbl=$stbl!")
    readscanner!(dev)
    fs = samplingrate(dev.task)
    P = readpressure(dev)
    t = dev.task.time
    S = DaqSamplingRate(fs, size(P,2), t)
    return MeasData(devname(dev), devtype(dev), S, P, dev.chans)
end

"""
`daqstart(dev::Initium)`

Start asynchronous data acquisition. If the [`Initium`](@ref) object was created with
`usethread == true`, a thread (using `@spawn`) will be used to carry out the data 
acquisition. Otherwise, green threads are used (`@async`). 

Remember: to use threads, julia should be started with the appropriate options.
"""
function DAQCore.daqstart(dev::Initium)
    stbl = dev.stbl
    numchannels(dev) == 0 && error("No channels configured for stbl=$stbl!")
    
    if isreading(dev)
        error("DTC Initium already reading!")
    end

    if dev.usethread
        tsk = Threads.@spawn readscanner!(dev)
    else
        tsk = @async readscanner!(dev)
    end

    dev.task.task = tsk
    return tsk
end

"""
`daqread(dev::Initium)`

Read data from DTC Initium. If batch acquisition is used, this function will block and
wait for data acquisition job to end. If continuous data acquisition is used, the function
will stop the data acquisition before reading what has been acquired.

In the future, the function `daqpeek` will be implemented that can read some of the available data without interrupting the data acquisition.
"""
function DAQCore.daqread(dev::Initium)
    stbl = dev.stbl

    # If we are doing continuous data acquisition, we first need to stop it
    if iparam(dev, "nms") == 0
        # Stop reading!
        daqstop(dev)
    end

    # Wait for the task to end (if it was started
    #if !istaskdone(dev.task.task) && istaskstarted(dev.task.task)
        wait(dev.task.task)
    #end
    
    # Read the pressure and the sampling frequency
    fs = samplingrate(dev.task)
    P = readpressure(dev)
    t = dev.task.time
    S = DaqSamplingRate(fs, size(P,2), t)
    return MeasData(devname(dev), devtype(dev), S, P, dev.chans)
end


"""
`daqstop(dev::Initium)`

Stop asynchronous data acquisition.
"""
function DAQCore.daqstop(dev::Initium)
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

"Returns the number of channels available"
DAQCore.numchannels(dev::Initium) = numchannels(dev.chans)
    
"Returns the names of the channels available"
DAQCore.daqchannels(dev::Initium) = daqchannels(dev.chans)

"Perform a zero calibration"
function DAQCore.daqzero(dev::Initium; lrn=1, time=15)
    CA2(dev; lrn=lrn)
    sleep(time)
end



function reconnect(dev::Initium)
    close(dev.sock)

    sleep(11) # Initium requires this waiting period before reconnecting

    sock = opensock(dev.ipaddr, dev.port)

    # Add the scanners
    
end

"""
`daqunits(dev::Initium, unit=3)`

Configure Initium pressure units. The Initium interface allows
for different scanners to use different units using the LRN, logical
range number. But this driver specifies that a single unit is used!

## Parameters
 * `dev`: `Initium` device
 * `unit`: `Integer` 0-13 specifying the unit. If 0 or 13, use the fctr factor that converts to psi. Else see table below. The default value is 3 and corresponds to Pascal.

## Unit table
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
function DAQCore.daqunits(dev::Initium, unit=3)
    
    (1 ≤ unit ≤ 12) || throw(DomainError(unit, "Unit should be between 1 and 12"))

    PC4(dev, unit, 0, lrn=1)

    iparam!(dev.conf, "unit"=>unit)
    dev.unit = unit
    return
end


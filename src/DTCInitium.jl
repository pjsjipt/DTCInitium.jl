module DTCInitium

using Sockets
using AbstractDAQs


export Initium, SD1, SD2, SD3, SD5, PC4, CA2, AD0, AD2, socket
export readresponse, readresponse!
export scannerlist, SD1cmd, daqparams, setparams, SD2cmd
export addscanners
export daqaddinput, daqconfig, daqacquire, daqconfig, daqconfigdev
export daqstart, daqread, daqstop, daqzero
export daqchannels, numchannels, samplesread, isreading
export dtcsetstbl!, setfastdaq!

export DAQTask



include("ports.jl")

mutable struct DTCChannels
    "Number of channels"
    nchans::Int
    "List of port ranges"
    plst::Vector{PortRange}
    "Channels availables"
    channels::Vector{Int}
    channames::Vector{String}
    chanidx::Dict{String,Int}
end

"""
`DTCChannels()`

Stores information on available ports.

The ports available in the DTC Initium can be specified as range or 
a sequence of ranges. Check command SD3 in the user's manual. 

"""
DTCChannels() = DTCChannels(0, PortRange[], Int[], String[], Dict{String,Int}())



mutable struct Initium <: AbstractPressureScanner
    "IP address of the device"
    ipaddr::IPv4
    "TCP/IP port, 8400"
    port::Int32
    "Device name"
    devname::String
    "Socket used to communicate with Initium"
    sock::TCPSocket
    "Cluster/Rack/slot"
    crs::String
    "Attached scanners"
    scanners::Vector{Tuple{Int,Int,Int}}
    "Active data acquisition setup table"
    stbl::Int
    "Intermittency of temp-sets"
    actx::Int
    "DAQ Task handler - stores binary data"
    task::DAQTask
    "Buffer to store acquired data"
    buffer::CircMatBuffer{UInt8}
    "Data acquisition parameters"
    params::Dict{Symbol,Int}
    "Channels configured"
    chans::DTCChannels
    "Device configuration"
    conf::DAQConfig
    "Devices with `stbl` configured"
    stbldev::Dict{Int, Initium}
    "Have channels been added to device?"
    haschans::Bool
    "Has data acquisition been configured?"
    isconfigured::Bool
    usethread::Bool
    unit::Int
end


"""
`Initium(devname, ip; stbl=1, crs="111")`
`Initium(devname, scanners...; ip=ip stbl=1, crs="111", 
    npp=64, lrn=1, bufsize, addallports)`
`Initium(devname, ip, stbl)`

Create a device that communicates with the DTC Initium.

The first constructor just establishes the communication with the 
DTC Initium but has no configuration. 

A more typical use is to add scanners, initialize buffers, and add all 
possible pressure ports. The second constructor above does just that.

The DTC Initium can hold 5 different configurations. Usually a single 
configuration is used. In some situations, more than one configuration 
can be useful and a "sub-device" can be created for another DA setup table
(stbl) using the third constructor above. 

## Description of the paramteters

 * `devname` String containing the device name. The device name is used to reference individual devices.
 * `ip` String with ip address of the DTC Initium
 * `stbl` Integer 1-5 that selects the DA Setup table to be used
 * `crs` Not used, exists for compatibility with othe Pressure Systems devices
 * `npp` Default number of pressure ports per scanner. Used as a default values
 * `lrn` Logical range number (see manual for further information)
 * `bufsize` Length of buffer that can store pressure data
 * `addallports` Boolean that specifies if all available pressure ports should be added to the device
 * `scanners` Scanners connected to the system. See method [`addscanners`](@ref) for detailed information on the format used. But if integers or integer ranges are used, parameters `npp` and `lrn` are used as default values.

## Examples

Basic low level example:

```julia-repl
julia> dev = Initium("press", "192.168.129.7", stbl=1)
DTC Initium
    IP: 192.168.129.7
    stbl: 1
    Scanners:


julia> addscanners(dev, 1:4)

julia> print(dev)
DTC Initium
    IP: 192.168.129.7
    stbl: 1
    Scanners:
        1: npp=64, lrn=1
        2: npp=64, lrn=1
        3: npp=64, lrn=1
        4: npp=64, lrn=1

julia> numchannels(dev)
0

julia> daqaddinput(dev, 101:464)
0

julia> numchannels(dev)
256
```

```julia-repl
julia> # Let's do the same thing more conveniently...

julia> dev = Initium("press", 1:4, stbl=1, addallports=true)
DTC Initium
    IP: 192.168.129.7
    stbl: 1
    Scanners:
        1: npp=64, lrn=1
        2: npp=64, lrn=1
        3: npp=64, lrn=1
        4: npp=64, lrn=1


julia> numchannels(dev)
256
```

```julia-repl

julia> # Let's do the same thing more conveniently...

julia> dev1 = Initium("otherconfig", dev, 2)
DTC Initium
    IP: 192.168.129.7
    stbl: 2
    Scanners:
        1: npp=64, lrn=1
        2: npp=64, lrn=1
        3: npp=64, lrn=1
        4: npp=64, lrn=1


julia> numchannels(dev1)
0

julia> daqaddinput(dev1, 101:116, 201:216)
0

julia> numchannels(dev1)
32
```


Now we will create another device for anothe
"""
function Initium(devname::String, ip::String; stbl=1, crs="111", usethread=true)

    if !(1 ≤ stbl ≤ 5)
        error("DA Setup table (`stbl`) should be 1-5!")
    end
    
    ip1 = IPv4(ip)
    port = 8400
    sock = opensock(ip1, port)

    try
        tsk = DAQTask()

        ipars = Dict{String,Int}("stbl"=>stbl, "actx"=>1)
        fpars = Dict{String,Float64}()
        spars = Dict{String,String}()
        conf = DAQConfig(ipars, fpars, spars ;devname=devname,
                         model="DTCInitium", sn="", tag="", ip=ip)
        
        scanners = Tuple{Int,Int,Int}[]
        buffer = CircMatBuffer{UInt8}()
        params = Dict{Symbol,Int}()
        chans = DTCChannels()
        stbldev = Dict{Int,Initium}()
        
        dev = Initium(ip1, port, devname, sock, crs, scanners, stbl, 1, tsk,
                      buffer, params, chans, conf, stbldev,
                      false, false, usethread, 3)
        dev.stbldev[stbl] = dev
        return dev
    catch e
        isopen(sock) && close(sock)
        throw(e)
    end
    
end

function Initium(devname::String, scanners...; stbl=1, 
                 ip="192.168.129.7", crs="111", npp=64, lrn=1,
                 bufsize=65_000, addallports=true, usethread=true, unit=3)

    if !(1 ≤ stbl ≤ 5)
        error("DA Setup table (`stbl`) should be 1-5!")
    end

    sock = TCPSocket()
    
    try
        dev = Initium(devname, ip; crs=crs, stbl=stbl,
                      usethread=usethread)
        sock = socket(dev)
        addscanners(dev, scanners...; npp=npp, lrn=lrn, unit=unit)
        # Allocate buffer
        nchans = availablechans(dev)
        w = 24 + nchans*4  # Maximum number of bytes per frame
        resize!(dev.buffer, w, bufsize)

        # Default data acquisition parameters
        SD2(dev, stbl=stbl)
        updateconf!(dev)
        
        if addallports
            # Add all possible pressure ports 
            addallpressports(dev)
        end

        return dev
    catch e
        isopen(sock) && close(sock)
        throw(e)
    end
    
end


function Initium(devname::String, dev::Initium, stbl::Int)
    if !(1 ≤ stbl ≤ 5)
        error("DA Setup table (`stbl`) should be 1-5!")
    end
    
    if haskey(dev.stbldev, stbl)
        # This subdevice has already been created!
        # Just return it!
        return dev.stbldev[stbl]
    end
    conf = DAQConfig(devname=devname, ip=daqdevip(dev),
                     model = daqdevmodel(dev), sn=daqdevserialnum(dev),
                     tag=daqdevtag(dev))
    conf.ipars["stbl"] = stbl
    conf.ipars["actx"] = dev.actx
    
    newdev = Initium(dev.ipaddr, dev.port, devname, dev.sock, dev.crs,
                     dev.scanners, stbl, dev.actx, dev.task,
                     dev.buffer, Dict{Symbol,Int}(), DTCChannels(),
                     conf, dev.stbldev, false, false, dev.usethread, dev.unit)
    dev.stbldev[stbl] = newdev
    # Get a default configuration
    SD2(newdev, stbl=stbl)
    return newdev
end

function Base.show(io::IO, dev::Initium)
    println(io, "DTC Initium")
    println(io, "    Dev Name: $(devname(dev))")
    println(io, "    IP: $(string(dev.ipaddr))")
    println(io, "    stbl: $(dev.stbl)")
    println(io, "    Scanners:")
    for s in dev.scanners
        snum = s[1]
        npp = s[2]
        lrn = s[3]
        println(io, "        $snum: npp=$npp, lrn=$lrn")
    end
    
end

"""
`updateconf!(dev)`

The configuration of a `DTCInitium` device is stored in the `params` field of 
an `Initium` object and other fields (such as `actx` or `stbl`). 
This function updates the `conf::DAQConfig` field so that 
the actual configuration can be stored in HDF5 files. 
"""    
function updateconf!(dev)
    stbl = dev.stbl

    p1 = dev.params
    p = dev.conf
    ipars = p.ipars
    ipars["stbl"] = stbl
    ipars["nfr"] = p1[:nfr]
    ipars["nms"] = p1[:nms]
    ipars["msd"] = p1[:msd]
    ipars["trm"] = p1[:trm]
    ipars["scm"] = p1[:scm]
    ipars["ocf"] = p1[:ocf]
    ipars["actx"] = dev.actx
    return
    
end

"""
`setfastdaq!(dev, actx=1)`

When measuring pressure with the DTC Initium, individual temperature of the 
pressure sensors are used to correct the pressure. In the default configuration, 
each time a pressure is read, so is the temperature. While this can be more accurate
it has a cost: it takes time to read each temperature. 

To achieve a higher sampling rate, the temperature of each pressure port doesn't have
to be read for every pressure sample. If `actx=0`, it is read only at the beginning.
When `actx > 1`, this parameter will acquire the temperature intermittently 
(once every  `actx` pressure samples are read).
"""
function setfastdaq!(dev::Initium, actx=1)

    SD5(dev, actx)
    # This is a global parameter! Should update ALL subdevices!
    for (stbl, xdev) in dev.stbldev
        xdev.actx = actx
        xdev.conf.ipars["actx"] = actx
    end
    return
end

"""
`addpressports(dev, plst; names="P")`

Add pressure port defined by `plst`. See [`PortRange`](@ref) and 
[`portlist`](@ref) to see how `plst` is defined. 

To give specific names to the pressure ports, use argument `names`:
 * String or symbol: The string will be preppended to the channel number
 * Vector: specific names to each pressure channel.

"""
function addpressports(dev, plst::AbstractVector{PortRange}; names="P")

    chans = defscanlist(scanners(dev), plst)
    # Check if there are ports in plst previously added:
    if length(intersect(chans, dev.chans.channels)) > 0
        throw(ArgumentError("Some ports have already been added!"))
    end
    
    SD3(dev, dev.stbl, plst)

    # Get channels names and numbers
    if isa(names, AbstractString) || isa(names, Symbol)
        chs = string.(names, chans)
    elseif isa(names, AbstractVector)
        length(chans) != length(names) && throw(ArgumentError("If `names` is a vector it should have the length of the number of channels"))
        chs = string.(names)
    else
        throw(ArgumentError("`names` should be either a string, a symbol or a vector"))
    end

    # Add the new channels to dev.chans
    nch = length(chans)
    dev.chans.nchans = length(chans)
    dev.chans.plst =  plst
    dev.chans.channels = chans
    dev.chans.channames = chs
    for i in 1:nch
        chname = chs[i]
        dev.chans.chanidx[chname] = i
    end
    
    dev.haschans = true
    
end

"""
`addallpressports(dev)`

Use every available pressure port when acquiring data. This is a convenience function
that can be used instead of [`daqaddinput`](@ref)  if every available pressure port
should be acquired. 
"""
function addallpressports(dev)
    
    plst = PortRange[]

    for (s,n,l) in dev.scanners
        p1 = s*100 + 1
        p2 = s*100 + n
        push!(plst, PortRange(p1,p2,true))
    end
    addpressports(dev, plst; names="P")
end

    
"Total number of available channels in the scanners"
availablechans(dev::Initium) = availablechans(dev.scanners)


Base.open(dev::Initium) = dev.sock = opensock(ipaddr(dev), portnum(dev))
Base.close(dev::Initium) = close(dev.sock)


"""
`addscanners(dev::Initium, lst...; npp=64, lrn=1)`

Add scanners to the DTC Initium device. Before any channels can be added, 
the scanners should be added. This function calls [`scannerlist`](@ref)
 to create a list of scanners attached to the DTC Initium.

 * `dev::Initium` Device to which the scanners should be added
 * `lst...` Sequence of scanners to be added (see details and [`scannerlist`](@ref))
 * `npp` Default number of pressure ports per scanner
 * `lrn` Default logical range number.

Each scanner attached to the DTC Initium is specified by the slot it is connected to 
(1-8), the number of pressure ports and the logical range number. 

Often, similar scanners (same number of pressure ports) are attached and the default 
values of number of pressure ports can be specified by argument `npp`. The same goes for
argument `lrn`

## Examples

```julia-repl
julia> using DTCInitium

julia> dev = Initium("press", "192.168.129.7", stbl=1)
DTC Initium
    IP: 192.168.129.7
    stbl: 1
    Scanners:


julia> addscanners(dev, 1:2, (3,64,1), (4,64,1))

julia> print(dev)
DTC Initium
    IP: 192.168.129.7
    stbl: 1
    Scanners:
        1: npp=64, lrn=1
        2: npp=64, lrn=1
        3: npp=64, lrn=1
        4: npp=64, lrn=1

julia> close(dev)

julia> dev = Initium("press", "192.168.129.7", stbl=1)
DTC Initium
    IP: 192.168.129.7
    stbl: 1
    Scanners:


julia> addscanners(dev, 1:4)

julia> print(dev)
DTC Initium
    IP: 192.168.129.7
    stbl: 1
    Scanners:
        1: npp=64, lrn=1
        2: npp=64, lrn=1
        3: npp=64, lrn=1
        4: npp=64, lrn=1
```


"""
function addscanners(dev::Initium, lst...; npp=64, lrn=1, unit=3)
    
    scnlst = scannerlist(lst...; npp=npp, lrn=lrn)

    !isopen(socket(dev)) && open(dev)
    try
        SD1(dev, scnlst)
        dev.scanners = scnlst
        # Set buffer width size
        nchans = availablechans(scnlst)
        w = 24 + nchans*4  # Maximum number of bytes per frame
        dev.buffer.width = w
        if unit < 1 || unit > 12
            unit = 3 # Pa
        end
        
        # Set the default unit to Pascal (3)
        
        for lrn in unique([s[3] for s in scnlst])  
            PC4(dev, unit, 0, lrn=lrn)
        end
        dev.unit=unit
        
    catch e
        if isa(e, DTCInitiumError)
            close(dev.sock)
            throw(e)
        else
            throw(e)
        end
    end
    
    return 
end


"Return crs parameter"
getcrs(dev::Initium) = dev.crs

"Return list of scanners attached to the DTC Initium"
scanners(dev::Initium) = dev.scanners

"Return the socket used to communicate with the DTC Initium"
socket(dev::Initium) = dev.sock

"Return configuration parameters"
daqparam(dev::Initium) = dev.params

"Return IPv4 address"
ipaddr(dev::Initium) = dev.ipaddr

"Return TCP/IP port number used by the DTC Initium"
portnum(dev::Initium) = dev.port


include("errorcodes.jl")
include("packets.jl")
include("buildcmd.jl")
include("commands.jl")
include("daq.jl")

end

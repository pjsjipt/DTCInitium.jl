module DTCInitium

using Sockets
using AbstractDAQ


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

struct DTCChannels
    nchans::Int
    plst::Vector{PortRange}
    channels::Vector{Int}
end
DTCChannels() = DTCChannels(0, PortRange[], Int[])



mutable struct Initium <: AbstractPressureScanner
    "IP address of the device"
    ipaddr::IPv4
    "TCP/IP port, 8400"
    port::Int32
    "Socket used to communicate with Initium"
    sock::TCPSocket
    "Cluster/Rack/slot"
    crs::String
    "Attached scanners"
    scanners::Vector{Tuple{Int,Int,Int}}
    "Active Setup table"
    stbl::Int
    "Intermittency of temp-sets"
    actx::Int
    "DAQ Task handler - stores binary data"
    task::DAQTask
    buffer::CircMatBuffer{UInt8}
    params::Dict{Symbol,Int}
    chans::DTCChannels
    conf::DAQConfig
    stbldev::Dict{Int, Initium}
end


function Initium(devname::String, ip::String; stbl=1, crs="111")

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
        
        dev = Initium(ip1, port, sock, crs, Tuple{Int,Int,Int}[], stbl, 1, tsk,
                      CircMatBuffer{UInt8}(), Dict{Symbol,Int}(),
                      DTCChannels(), conf, Dict{Int,Initium}())
        dev.stbldev[stbl] = dev
        return dev
    catch e
        isopen(sock) && close(sock)
        throw(e)
    end
    
end

function Initium(devname::String, scanners...; stbl=1, 
                 ip="192.168.129.7", crs="111", npp=64, lrn=1,
                 bufsize=65_000, addallports=true)

    if !(1 ≤ stbl ≤ 5)
        error("DA Setup table (`stbl`) should be 1-5!")
    end

    sock = TCPSocket()
    
    try
        dev = Initium(devname, ip; crs=crs, stbl=stbl)
        sock = socket(dev)
        addscanners(dev, scanners...; npp=npp, lrn=lrn)
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
    
    newdev = Initium(dev.ipaddr, dev.port, dev.sock, dev.crs,
                     dev.scanners, stbl, dev.actx, dev.task,
                     dev.buffer, Dict{Symbol,Int}(), DTCChannels(), conf, dev.stbldev)
    dev.stbldev[stbl] = newdev
    # Get a default configuration
    SD2(newdev, stbl=stbl)
    return newdev
end

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


function setfastdaq!(dev::Initium, actx=1)

    SD5(dev, actx)
    # This is a global parameter! Should update ALL subdevices!
    for (stbl, xdev) in dev.stbldev
        xdev.conf.ipars["actx"] = actx
    end
    return
end


function addallpressports(dev)
    stbl = dev.stbl
    
    plst = PortRange[]

    for (s,n,l) in dev.scanners
        p1 = s*100 + 1
        p2 = s*100 + n
        push!(plst, PortRange(p1,p2,true))
    end
    SD3(dev, stbl, plst)

    chans = defscanlist(dev.scanners, plst)
    dev.chans = DTCChannels(length(chans), plst, chans)
end

    
"Total number of available channels in the scanners"
availablechans(dev::Initium) = availablechans(dev.scanners)


Base.open(dev::Initium) = dev.sock = opensock(ipaddr(dev), portnum(dev))
Base.close(dev::Initium) = close(dev.sock)


function addscanners(dev::Initium, lst...; npp=64, lrn=1)
    
    scnlst = scannerlist(lst...)

    !isopen(socket(dev)) && open(dev)
    try
        SD1(dev, scnlst)
        dev.scanners = scnlst
        # Set the default unit to Pascal (3)
        for lrn in unique([s[3] for s in scnlst])  
            PC4(dev, 3, 0, lrn=lrn)
        end
        
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


getcrs(dev::Initium) = dev.crs
scanners(dev::Initium) = dev.scanners
socket(dev::Initium) = dev.sock
daqparam(dev::Initium) = dev.params

ipaddr(dev::Initium) = dev.ipaddr
portnum(dev::Initium) = dev.port


include("errorcodes.jl")
include("packets.jl")
include("buildcmd.jl")
include("commands.jl")
include("daq.jl")

end

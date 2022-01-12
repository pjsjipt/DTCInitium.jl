module DTCInitium

using Sockets
using AbstractDAQ


export Initium, SD1, SD2, SD3, SD5, PC4, CA2, AD0, AD2, socket
export readresponse, readresponse!
export scannerlist, SD1cmd, daqparams, setparams, SD2cmd
export addscanners
export daqaddinput, daqconfig, daqacquire, daqconfig, daqconfigdev
export daqstart, daqread, daqstop
export daqchannels, samplesread, isreading
export dtcsetstbl!, setfastdaq!

export DAQTask



include("ports.jl")

struct DTCChannels
    nchans::Int
    plst::Vector{PortRange}
    channels::Vector{Int}
end

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
    params::Dict{Int,Dict{Symbol,Int32}}
    chans::Dict{Int,DTCChannels}
end


function Initium(ip::String; crs="111")
    
    ip1 = IPv4(ip)
    port = 8400
    sock = opensock(ip1, port)

    try
        tsk = DAQTask()
        dev = Initium(ip1, port, sock, crs, Tuple{Int,Int,Int}[], 1, 1, tsk,
                      CircMatBuffer{UInt8}(), 
                      Dict{Int,Dict{Symbol,Int32}}(), Dict{Int,Vector{DTCChannels}}())
        dtcsetstbl!(dev, 1)
        return dev
    catch e
        isopen(sock) && close(sock)
        throw(e)
    end
    
end

function Initium(scanners...; ip="192.168.129.7", crs="111", npp=64, lrn=1,
                 bufsize=65_000, addallports=true)
    sock = TCPSocket()
    
    try
        dev = Initium(ip, crs=crs)
        sock = socket(dev)
        addscanners(dev, scanners...; npp=npp, lrn=lrn)
        # Allocate buffer
        nchans = availablechans(dev)
        w = 24 + nchans*4  # Maximum number of bytes per frame
        resize!(dev.buffer, w, bufsize)

        dtcsetstbl!(dev, 1)
        
        # Default data acquisition parameters
        for stbl in 1:5
            SD2(dev, stbl=stbl)
        end
        
        if addallports
            # Add all possible pressure ports 
            for stbl in 1:5
                addallpressports(dev, stbl)
            end
        end

            
        return dev
    catch e
        isopen(sock) && close(sock)
        throw(e)
    end
    
end


function dtcsetstbl!(dev::Initium, stbl)
    if 1 ≤ stbl ≤ 5
        dev.stbl = stbl
    end
    return stbl
end

function setfastdaq!(dev::Initium, fast=true)

    actx = fast ? 0 : 1
    SD5(dev, actx)
end


function addallpressports(dev, stbl=-1)
    # Negative stbl: use value dev.stbl
    if stbl < 1
        stbl = dev.stbl
    end
        if  stbl > 5
        throw(ArgumentError("stbl should be between 1 and 5. Got $stbl!"))
    end
    
    plst = PortRange[]

    for (s,n,l) in dev.scanners
        p1 = s*100 + 1
        p2 = s*100 + n
        push!(plst, PortRange(p1,p2,true))
    end
    SD3(dev, stbl, plst)

    chans = defscanlist(dev.scanners, plst)
    dev.chans[stbl] = DTCChannels(length(chans), plst, chans)
end

    
"Total number of available channels in the scanners"
availablechans(dev::Initium) = availablechans(dev.scanners)

#defscanlist(dev::Initium, stbl=1) = defscanlist(scanners(dev), dev.chans[stbl])


import Base.open
open(dev::Initium) = dev.sock = opensock(ipaddr(dev), portnum(dev))

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
function daqparam(dev::Initium, stbl=-1)
    if stbl < 1
        stbl = dev.stbl
    end
    return dev.params[stbl]
end

ipaddr(dev::Initium) = dev.ipaddr
portnum(dev::Initium) = dev.port


include("errorcodes.jl")
include("packets.jl")
include("buildcmd.jl")
include("commands.jl")
include("daq.jl")

end

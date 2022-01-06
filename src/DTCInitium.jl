module DTCInitium
using AbstractDAQ
using Sockets

export Initium, SD1, SD2, SD3, SD5, PC4, CA2, AD0, AD2, socket
export readresponse
export scannerlist, SD1cmd, daqparams, SD2cmd
export addscanners
export daqaddinput, daqconfig, daqacquire, daqacquire!, daqconfig
export daqstart, daqread, daqread!, daqstop
export daqchannels

abstract type AbstractPressureScanner <: AbstractDaqDevice end


include("ports.jl")


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
    scanners::Vector{Tuple{Int32,Int32,Int32}}
    "Active Setup table"
    stbl::Int
    "Intermittency of temp-sets"
    actx::Int
    "DAQ Task handler - stores binary data"
    task::DAQTask{UInt8}
    params::Dict{Int,Dict{Symbol,Int32}}
    chans::Dict{Int,Vector{PortRange}}
end

function Initium(ip="192.168.129.7"; crs="111")
    
    ip1 = IPv4(ip)
    port = 8400
    sock = opensock(ip1, port)

    try
        tsk = DAQTask{UInt8}()
        setminbufsize!(tsk, 65_000)
        dev = Initium(ip1, port, sock, crs, Tuple{Int32,Int32,Int32}[], 1, 1, tsk, Dict{Int,Dict{Symbol,Int32}}(), Dict{Int,Vector{PortRange}}())
        return dev
    catch e
        isopen(sock) && close(sock)
        throw(e)
    end
    
end

import Base.open
open(dev::Initium) = dev.sock = opensock(ipaddr(dev), portnum(dev))

function addscanners(dev::Initium, (scn,npp,lrn), lst...)
    
    scnlst = scannerlist((scn,npp,lrn), lst...)
    
    nchans = sum(s[2] for s in scnlst)
    
    dev.scanners = scnlst
    nb = 24 + nchans*4  # Maximum number of bytes per frame
    return nb
    resizebuffer!(dev.task, minbufsize(dev.task), nb)

    !isopen(socket(dev)) && open(dev)
    try
        SD1(dev)
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
    

    return dev
end


getcrs(dev::Initium) = dev.crs
scanners(dev::Initium) = dev.scanners
socket(dev::Initium) = dev.sock
daqparams(dev::Initium) = dev.params
ipaddr(dev::Initium) = dev.ipaddr
portnum(dev::Initium) = dev.port
setstbl!(dev::Initium, stbl)= dev.stbl = stbl


include("errorcodes.jl")
include("packets.jl")
include("buildcmd.jl")
include("commands.jl")
include("daq.jl")

end

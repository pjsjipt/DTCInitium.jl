module DTCInitium
using AbstractDAQ
using Sockets

export Initium, SD1, SD2, SD3, SD5
export daqaddinput, daqconfig, daqacquire, daqacquire!, daqconfig
export daqstart, daqread, daqread!, daqstop

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
    "DAQ Task handler - stores binary data"
    task::DAQTask{UInt8}
    params::Dict{Int,Dict{Symbol,Int32}}
    chans::Dict{Int,Vector{PortRange}}
end

function Initium(i="192.168.128.9"; crs="111")

    ip1 = IPV4(ip)
    sock = opensock(ip1, port)
    tsk = DAQTask{UInt8}()
    setminbufsize!(tsk, 65_000)
    dev = Initium(ip1, 8400, sock, crs, Vector{Tuple{Int32,Int32,Int32}}[], 1, tsk, Dict{Int,Dict{symbol,Int32}}(), Dict{Int,Vector{PortRange}}())
    return dev
end


function addscanners(dev::Initium, (scn,npp,lrn), lst...)
    
    scnlst = scannerlist((scn,npp,lrn), lst...)

    nchans = sum(s[2] for s in scnlst)

    
    nb = 24 + nchans*4  # Maximum number of bytes per frame
    resizebuffer!(dev.task, minbufsize(dev.task), nb)
    
    params = Dict{Int,Dict{Symbol,Int32}}()
    chans = Dict{Int,Vector{PortRange}}()
    dev = Initium(ip1, port, sock, crs, scnlst, 1, tsk, params, chans)
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
#daqports(dev::Initium) = dev.
ipaddr(dev::Initium) = dev.ipaddr
portnum(dev::Initium) = dev.port
setstbl!(dev::Initium, stbl)= dev.stbl = stbl


include("errorcodes.jl")
include("packets.jl")
include("buildcmd.jl")
include("commands.jl")
include("daq.jl")

end

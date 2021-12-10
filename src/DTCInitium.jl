module DTCInitium
using AbstractDAQ
using Sockets

export Initium, SD1, SD2, SD3, SD5


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
    "DAQ Task handler"
    task::DAQTask
    params::Dict{Int,Dict{Symbol,Int32}}
    chans::Dict{Int,Vector{PortRange}}
end


function Initium(ip, (scn,npp,lrn), lst...; crs="111")
    scnlst = scannerlist((scn,npp,lrn), lst...)
    ip1 = IPv4(ip)
    port = 8400

    sock = opensock(ip1, port)
    
    nchans = sum(s[2] for s in scnlst)
    
    tsk = DAQTask(24 + nchans*4, 100_000)
    
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


include("errorcodes.jl")
include("packets.jl")
include("buildcmd.jl")
include("commands.jl")
include("daq.jl")

end

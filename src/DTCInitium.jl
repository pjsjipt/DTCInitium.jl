module DTCInitium
using AbstractDAQ
using Sockets

export Initium, SD1, SD2, SD3, SD5


abstract type AbstractPressureScanner <: AbstractDaqDevice end



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
    task::DAQTask{Initium}
    daqparams::Dict{Symbol,Int32}
end


function Initium(ip, (scn,npp,lrn), lst...; crs="111")
    scnlst = scannerlist((scn,npp,lrn), lst...)
    ip1 = IPv4(ip)
    port = 8400

    sock = opensock(ip1, port)
    
    nchans = sum(s[2] for s in scnlst)
    
    tsk = DAQTask{Initium}(false, false, false, 0, 0,
                           zeros(UInt8, 24 + nchans*4, 100_000), 100_000, Task(()->1))
    daqparams = Dict{Symbol,Int32}()
    dev = Initium(ip1, port, sock, crs, scnlst, 1, tsk, daqparams)
    try
        SD1(dev)
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

ipaddr(dev::Initium) = dev.ipaddr
portnum(dev::Initium) = dev.port


struct PortRange
    start::Int
    stop::Int
    r::Bool
end
PortRange(p::Integer) = PortRange(p, -1, false)
PortRange(p::UnitRange) = PortRange(Int(p.start), Int(p.stop), true)

function PortRange(p::AbstractString)
    p = strip(p)
    
    r1 = r"^[0-9][0-9][0-9]$"
    r2 = r"^[0-9][0-9][0-9]-[0-9][0-9][0-9]$"
    
    if occursin(r1, p)
        return PortRange(parse(Int, p), -1, false)
    elseif occursin(r2, p)
        i = findfirst(isequal('-'), p)
        p1 = parse(Int, p[1:(i-1)])
        p2 = parse(Int, p[(i+1):end])
        return PortRange(p1, p2, true)
    else
        throw(ArgumentError(p, "Not a valid port or port range"))
    end
    
end

isrange(p::PortRange) = p.r

function strport(p::PortRange)

    if isrange(p)
        return "$(p.start)-$(p.stop)"
    else
        return "$(p.start)"
    end
end


struct DATable
    stbl::Int
    daqparams::Dict{Symbol,Int}
    scanlist::Vector{PortRange}
    ports::Vector{Int}
end

include("errorcodes.jl")
include("packets.jl")
include("buildcmd.jl")
include("commands.jl")
include("daq.jl")

end

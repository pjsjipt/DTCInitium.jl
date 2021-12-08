module DTCInitium
using AbstractDAQ
using Sockets
abstract type AbstractPressureScanner <: AbstractDAQ end



mutable struct DTCIDevice <: AbstractPressureScanner
    "IP address of the device"
    ipaddr::IPv4
    "TCP/IP port, 8400"
    port::Int32
    "Cluster/Rack/slot"
    crs::String
    "Attached scanners"
    scanners::Vector{Tuple{Int32,Int32,Int32}}
    "Active Setup table"
    stbl::Int
    "DAQ Task handler"
    task::DAQTask{DTCIDevice}
    daqparams::Dict{Symbol,Int32}
end


    

end

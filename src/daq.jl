
import AbstractDAQ.daqaddinput

function daqaddinput(dev::Initium, ports::AbstractVector{PortRange})

    stbl = dev.stbl

    SD3(dev, stbl, ports)
end

daqaddinput(dev::Initium, ports::AbstractString) = daqaddinput(dev, portlist(ports))
daqaddinput(dev::Initium, ports...) = daqaddinput(dev, portlist(ports...))

        
    
    

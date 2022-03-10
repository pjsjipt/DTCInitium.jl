
"""
Error codes defined by DTC Initium. 
"""
const errorcodes = Dict(-3 =>"Illegal Command ID", 
                        -5 =>"Parameter Is Missing", 
                        -6 =>"Value Too Low", 
                        -7 =>"Value Too High", 
                        -10 =>"Upper Val < Low Val", 
                        -11 =>"Bad Name For Parameter", 
                        -12=>"Need Integer Number", 
                        -13=>"Need Float Point", 
                        -14=>"Illegal CRS Number", 
                        -18=>"Bad Sensor Port Number", 
                        -19=>"Bad Upper Port Number", 
                        -20=>"Upper Port Number < Lower Number", 
                        -21=>"Bad Scanner Number", 
                        -25=>"Bad Upper Scanner Number", 
                        -27=>"Bad Logical Range", 
                        -32=>"Too Many Parameters", 
                        -39=>"Non-Vol. Mem. Error", 
                        -53=>"No Module This CRS", 
                        -68=>"Port Not Defined in Scan Table", 
                        -69=>"Port Not Defined", 
                        -75=>"SDU Table Not Defined", 
                        -80=>"DATA Not Acquired", 
                        -82=>"Data Acquisition Aborted", 
                        -230=>"Module Not Ready")


struct DTCInitiumError <: Exception
    "Code of the error"
    val::Int
    "Error message"
    msg::String
end

"""
`DTCInitiumError(val::Integer)`

Creates an exception with an error code and corresponding message. 

Not all errors are documented. In this case the message is "Unknown Error".


"""
DTCInitiumError(msg::String) = DTCInitiumError(0, msg)
function DTCInitiumError(val::Integer)
    if haskey(errorcodes, val)
        DTCInitiumError(val, errorcodes[val])
    else
        DTCInitiumError(val, "Unknown Error")
    end
end

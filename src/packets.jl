export DTCRespHeader, DTCRespStream, parseresponse, xcommand


"Read response code from a packet header"
respcode(resp) = resp[1]
"Read response type from a packet header"
resptype(resp) = resp[2]
"Read response message length from a packet header"
resplen(resp) = 256*resp[3] + resp[4]

"Read confirmation response. Usually zero. Could be a warning (positive number)"
respconf(resp) = ntoh(reinterpret(Int32, resp[5:8])[1])
"Read error code in error responses (type 128)"
resperr(resp) = ntoh(reinterpret(Int32, resp[5:8])[1])
function respdata(resp)
    nrows = 256*resp[5] + resp[6]
    ncols = 256*resp[7] + resp[8]
    return nrows, ncols
end

"Read 4 byte integer response from type 8 messages"
respsinglevali(resp) = ntoh(reinterpret(Int32, resp[5:8])[1])
"Read 4 byte float response from type 9 messages"
respsinglevalf(resp) = ntoh(reinterpret(Float32, resp[5:8])[1])

"Is the packet a confirmation packet?"
ispackconf(resp) = resptype(resp) == 4
"Is the packet an error packet?"
ispackerr(resp) = resptype(resp) == 128

"Is the packet a single value packet?"
ispacksingleval(resp) = resptype(resp) ∈ (8,9)
"Is the packet a single integer value packet?"
ispacksinglevali(resp) = resptype(resp) == 8
"Is the packet a single float value packet?"
ispacksinglevalf(resp) = resptype(resp) == 9

"Is the packet a stream data packet?"
ispackstreamdata(resp) = resptype(resp) ∈ (15, 17, 19)
"Is the packet a stream data packet with 4-byte IEEE floats?"
ispackstreamfloat(resp) = resptype(resp) == 19
"Is the packet a stream data packet with raw 2-byte binary numbers?"
ispackstreambin2(resp) = resptype(resp) == 16
"Is the packet a stream data packet with raw 3-byte binary numbers?"
ispackstreambin3(resp) = resptype(resp) == 17


"Return the number of rows of array data packet"
strpacknum(resp) = Int(ntoh(reinterpret(UInt16, resp[5:6])[1]))
"Return the number of columns of array data packet"
strpacklen(resp) = Int(ntoh(reinterpret(UInt16, resp[7:8])[1]))

"Is the packet an array data packet with 4-byte IEEE floating point numbers?"
ispackarray(resp) = resptype(resp) == 33

"Is the packet a valid packet type?"
ispacktypevalid(resp) = resptype(resp) ∈ (4, 8, 9, 16, 17, 19, 33, 128)


function readpackarray(resp)

    ispackarray(resp) || error("Not a Binary Array Data Responso (type = 33)!")
    nrows, ncols = respdata(resp)

    # The data array is row major so we will return the transpose:
    
    data = zeros(Float32, ncols, nrows)
    cnt = 8
    for i in 1:nrows
        for k in 1:ncols
            data[k,i] = ntoh(reinterpret(Float32, resp[cnt .+ (1:4)])[1])
            cnt += 4
        end
    end
    return data

end


"Read 8 byte header from socket"
function readdtcheader!(io, buf::AbstractVector{UInt8})

    readbytes!(io, buf, 8)

    return resptype(resp)
end

struct DTCRespHeader
    code::UInt8
    type::UInt8
    msglen::UInt16
end

DTCRespHeader(b::AbstractVector{UInt8}) = DTCRespHeader(respcode(b), resptype(b), resplen(b))



dtcrespconf(h::DTCRespHeader, b::AbstractVector{UInt8}) = respconf(b)


dtcresperror(h::DTCRespHeader, b::AbstractVector{UInt8}) = resperror(b)


function dtcrespvalue(::Type{Int32}, h::DTCRespHeader, b::AbstractVector{UInt8})
    
    val = respsinglevali(b)

    return val
end

function dtcrespvalue(::Type{Float32}, h::DTCRespHeader, b::AbstractVector{UInt8})
    
    val = respsinglevalf(b)
    
    return val
end


dtcresparray(h::DTCRespHeader, b::AbstractVector{UInt}) = readpackarray(b)


@enum DtcResponses::UInt8 DTC_CONF=4 DCT_IVAL=8 FDTC_FVAL=9 DTC_ISTREAM=16 DTC_ISTREAM3=17  DTC_FSTREAM=19 DTC_ARRAY=33 DTC_ERROR=128



struct DTCRespStream{T}
    idx::Int
    len::Int
    iutyp::Int
    stbl::Int
    nfr::Int
    cnvt::Int
    seq::Int
    values::Vector{T}
end

function DTCRespStream(::Type{Int16}, h::DTCRespHeader, b::AbstractVector{UInt8})
    
    idx, nvals = respdata(b)

    iutyp = Int(b[12])
    stbl = Int(b[13])
    nfr = Int(b[14])
    cnvt = Int(b[23])
    seq = Int(b[24])
    cnt = 25
    values = zeros(Int32,nvals)
    for i in 1:nvals
        values[i] = Int32(b[cnt]*Int16(256) + b[cnt+1])
        cnt += 2
    end
    return DTCRespStream{Int32}(idx, nvals, iutyp, stbl, nfr, cnvt, seq, values)
end

function DTCRespStream(::Type{Float32}, h::DTCRespHeader, b::AbstractVector{UInt8})

    idx, nvals = respdata(b)

    iutyp = b[12]
    stbl = b[13]
    nfr = b[14]
    cnvt = b[23]
    seq = b[24]

    cnt = 24
    values = zeros(Float32,nvals)
    for i in 1:nvals
        values[i] = reinterpret(Float32, b[cnt .+ 4:-1:1])[1]
        cnt += 4
    end
    return DTCRespStream{Float32}(idx, nvals, iutyp, stbl, nfr, cnvt, seq, values)
end

primitive type Int24 <: Signed 24 end

function DTCRespStream(::Type{Int24}, h::DTCRespHeader, b::AbstractVector{UInt8})

    idx, nvals = respdata(b)

    iutyp = b[12]
    stbl = b[13]
    nfr = b[14]
    cnvt = b[23]
    seq = b[24]

    cnt = 25
    values = zeros(Int32,nvals)
    for i in 1:nvals
        values[i] = Int32((b[cnt]*256 + b[cnt+1])*256 + b[cnt+2])
        cnt += 3
    end
    return DTCRespStream{Int32}(idx, nvals, iutyp, stbl, nfr, cnvt, seq, values)
end
                              

function xcommand(io::TCPSocket, cmd)
    println(io, cmd)
    sleep(0.2)

    bv = Vector{UInt8}[]

    while true
        b = readresponse(io)
        push!(bv, b)

        rtype = resptype(b)
        if rtype ∉ (16,17,19) 
            break
        end
    end
    return bv
    
end

function parseresponse(b::AbstractVector{UInt8})
        
    h = DTCRespHeader(b)

    # Parse response:
    if h.type == 4 # Confirmation byte
        return  h, dtcrespconf(h, b)
    elseif h.type == 128
        return h, dtcresperror(h, 8)
    elseif h.type == 8
        return h, dtcrespvalue(Int32, h, b)
    elseif h.type == 9
        return h, dtcrespvalue(Float32, h, b)
    elseif h.type == 33
        return h, dtcresparray(h, b)
    elseif h.type == 16
        return h, DTCRespStream(Int16, h, b)
    elseif h.type == 17
        return h, DTCRespStream(Int24, h, b)
    elseif h.type == 19
        return h, DTCRespStream(Float32, h, b)
    else
        # Unknownd
        error("Initium response type $(h.type). Unknown type!")
    end
        
end



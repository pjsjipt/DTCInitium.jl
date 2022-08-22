

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



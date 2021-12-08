


respcode(resp) = resp[1]
resptype(resp) = resp[2]
resplen(resp) = 256*resp[3] + resp[4]

respconf(resp) = ntoh(reinterpret(Int32, resp[5:8])[1])
resperr(resp) = ntoh(reinterpret(Int32, resp[5:8])[1])
function respdata(resp)
    nrows = 256*resp[5] + resp[6]
    ncols = 256*resp[7] + resp[8]
    return nrows, ncols
end

respsinglevali(resp) = ntoh(reinterpret(Int32, resp[5:8])[1])
respsinglevalf(resp) = ntoh(reinterpret(Float32, resp[5:8])[1])

ispackconf(resp) = resptype(resp) == 4
ispackerr(resp) = resptype(resp) == 128

ispacksingleval(resp) = resptype(resp) ∈ (8,9)
ispacksinglevali(resp) = resptype(resp) == 8
ispacksinglevalf(resp) = resptype(resp) == 9

ispackstreamdata(resp) = resptype(resp) ∈ (15, 17, 19)
ispackstreamfloat(resp) = resptype(resp) == 19
ispackstreambin2(resp) = resptype(resp) == 16
ispackstreambin3(resp) = resptype(resp) == 17

ispackarray(resp) = resptype(resp) == 33

ispacktypevalid(resp) = resptype(resp) ∈ (4, 8, 9, 16, 17, 19, 33, 128)





function readdtcheader!(io, buf::AbstractVector{UInt8})

    readbytes!(io, buf, 8)

    return resptype(resp)
end



--[[
    ROUTER — pengganti isi gamingexperienc.lua

    Loader yang sudah terobfuscate tetap memanggil URL ini, jadi buyer TIDAK perlu
    mengganti loadstring apa pun. Menambah dunia baru cukup satu baris di daftar,
    tanpa obfus ulang dan tanpa loader kedua.

    KUNCINYA PlaceId, BUKAN GameId.
    GaG2 (97598239454123) dan Fall Harvest (129343810645058) berbagi universeId
    yang sama -- 10200395747 -- sehingga game.GameId identik untuk keduanya dan
    tidak bisa membedakan dunia sama sekali.
]]

local HttpService = game:GetService("HttpService")

-- Daftar dunia -> URL script. Ini satu-satunya berkas yang perlu kamu sunting
-- saat menambah dunia baru.
local DAFTAR_URL = "https://raw.githubusercontent.com/mozenian/muje/main/games.lua"

local function gagal(pesan)
    warn("[Router] " .. pesan)
end

-- Cache raw.githubusercontent bisa menahan perubahan beberapa menit. Parameter
-- acak membuat tiap peluncuran menarik versi terbaru.
local function ambil(url)
    local req = (type(request) == "function" and request) or (type(http_request) == "function" and http_request) or (type(syn) == "table" and type(syn.request) == "function" and syn.request)
    
    local ok, isi = pcall(function()
        local pemisah = string.find(url, "?", 1, true) and "&" or "?"
        local targetUrl = url .. pemisah .. "r=" .. tostring(math.random(1, 1e9))
        
        if req then
            -- Bypass Anti-Cheat dengan native request
            local res = req({Url = targetUrl, Method = "GET"})
            return res.Body
        else
            -- Fallback
            return game:HttpGet(targetUrl)
        end
    end)
    
    if not ok then return nil, tostring(isi) end
    return isi
end

local sumberDaftar, errDaftar = ambil(DAFTAR_URL)
if not sumberDaftar then
    return gagal("Gagal mengambil daftar dunia: " .. tostring(errDaftar))
end

local muat, errMuat = loadstring(sumberDaftar)
if not muat then
    return gagal("Daftar dunia tidak bisa di-compile: " .. tostring(errMuat))
end

local okJalan, Games = pcall(muat)
if not okJalan or type(Games) ~= "table" then
    return gagal("Daftar dunia tidak mengembalikan tabel")
end

local URL = Games[game.PlaceId]
if not URL then
    -- Sengaja diberi pesan, bukan diam. Kalau nanti Roblox menambah world baru,
    -- gejalanya jadi jelas ("belum terdaftar") alih-alih script yang diam saja.
    return gagal("PlaceId " .. tostring(game.PlaceId) .. " belum terdaftar di daftar dunia")
end

local sumberScript, errScript = ambil(URL)
if not sumberScript then
    return gagal("Gagal mengambil script untuk place ini: " .. tostring(errScript))
end

-- Penjaga file terpotong.
--
-- Kejadian nyata: gamingexperienc3.lua ter-upload hanya 74.392 dari 95.731 byte
-- dan terputus di tengah kata ("loo alih-alih "loot"). Yang muncul cuma
-- "malformed string" di baris 1722 -- terbaca seperti bug kode, padahal kodenya
-- benar dan uploadnya yang gagal. Butuh pembongkaran panjang untuk menemukannya.
--
-- Tiap script kaitun diakhiri penanda ini. Kalau penandanya tidak ada, berkasnya
-- pasti belum lengkap, dan lebih baik bilang begitu sejak awal.
if not string.find(sumberScript, "@MOZEFRAME-EOF@", 1, true) then
    return gagal(string.format(
        "BERKAS TERPOTONG -- upload ulang script ini.\n" ..
        "  URL    : %s\n" ..
        "  Diterima: %d byte, tanpa penanda akhir berkas.\n" ..
        "  Ini kegagalan upload, BUKAN kesalahan kode.",
        tostring(URL), #sumberScript))
end

local jalankan, errCompile = loadstring(sumberScript)
if not jalankan then
    return gagal("Script tidak bisa di-compile: " .. tostring(errCompile))
end

jalankan()

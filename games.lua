--[[
    DAFTAR DUNIA -> SCRIPT

    Dibaca oleh router di gamingexperienc.lua. Menambah dunia baru = tambah satu
    baris di sini. Tidak perlu obfus ulang, tidak perlu loader baru, dan buyer
    tidak perlu mengganti loadstring mereka.

    KUNCINYA PlaceId, BUKAN GameId. Seluruh dunia di bawah ini berbagi universeId
    10200395747, jadi game.GameId identik untuk semuanya dan tidak bisa membedakan
    apa pun.

    PENTING -- SATU DUNIA PUNYA BANYAK PLACE.
    Grow a Garden 2 berjalan di beberapa shard (🌶 🌱 🍅). Saat pemain masuk ke
    place utama, game MENGARAHKAN sendiri ke salah satu shard, sehingga PlaceId
    akhirnya berbeda dari yang dituju. Kalau shard-nya tidak terdaftar di sini,
    router tidak menemukan entri dan script tidak jalan sama sekali -- akun diam
    tanpa pesan. Karena itu SEMUA shard harus dipetakan, bukan hanya place utama.

    Daftar place terkini bisa diambil dengan:
        curl "https://develop.roblox.com/v1/universes/10200395747/places?limit=100"
]]

-- Script kaitun PINDAH ke server private (repo "bot"), tidak lagi di GitHub
-- publik. Server hanya menyerahkannya untuk key yang sah, jadi mengosongkan
-- GitHub tidak membuat siapa pun kehilangan akses -- yang hilang cuma
-- kemampuan orang asing MEMBACA source-nya.
--
-- Key ikut tiap permintaan. Diambil dari config web dulu (panel key), lalu
-- MuzeKey.txt sebagai cadangan -- itu yang membuat user VIP (master key di
-- MuzeKey.txt) tetap dapat script walau config-nya kosong.
local HttpService = game:GetService("HttpService")
local function ambilKey()
    local k = ""
    pcall(function()
        local cfg = getgenv().MuzeAutoBuyConfig
        if cfg and cfg.PanelKey then k = cfg.PanelKey end
    end)
    if k == "" then
        pcall(function()
            if isfile and readfile and isfile("MuzeKey.txt") then
                k = readfile("MuzeKey.txt")
            end
        end)
    end
    return (string.gsub(k or "", "^%s*(.-)%s*$", "%1"))
end

local API = "https://mozeframe.my.id/api/script?key=" .. HttpService:UrlEncode(ambilKey()) .. "&f="
local GAG2 = API .. "w1"
local FALL = API .. "w2"

--[[
    BUKAN "shard". Nama itu keliru dan sempat menyesatkan.

    Terbaca dari ReplicatedStorage.SharedModules.Environment.places, tiap place
    punya PERAN sendiri -- game mengarahkan pemain ke salah satunya berdasarkan
    keadaan akun, bukan membagi beban:

        Primary            97598239454123   pemain normal
        BotUser            73504898027860   KARANTINA AKUN TERDETEKSI BOT
        FirstSession       77085202503540   sesi pertama
        NewUser            133438856880402  pemain baru
        FallHarvest        126987765280963  Fall Harvest normal
        FallHarvestBotUser 129343810645058  KARANTINA BOT untuk Fall Harvest
        PetHunt            112469282445074
        PetHuntFallHarvest 137395689498699

    Semuanya tetap dipetakan di bawah: script harus jalan di mana pun akun
    mendarat, termasuk di place karantina.

    Cara memeriksa akun sedang di mana:
        require(game.ReplicatedStorage.SharedModules.Environment).placeType
        require(game.ReplicatedStorage.SharedModules.Environment).isBotContainmentPlace
]]
local Games = {
    -- ---- Grow a Garden 2 ----
    [97598239454123]  = GAG2,   -- Primary       (pemain normal)
    [73504898027860]  = GAG2,   -- BotUser       (karantina bot)
    [77085202503540]  = GAG2,   -- FirstSession
    [133438856880402] = GAG2,   -- NewUser

    -- ---- Fall Harvest (World 2, hanya bisa dimasuki dari GaG2) ----
    [126987765280963] = FALL,   -- FallHarvest        (pemain normal)
    [129343810645058] = FALL,   -- FallHarvestBotUser (karantina bot)

    -- ---- SENGAJA TIDAK DIPETAKAN ----
    -- [107289568786498] Grow a Garden [Staging]  -- place pengembang, bukan untuk bot
    -- [112469282445074] PetHunt                  -- minigame, belum ada script-nya
    -- [137395689498699] PetHuntFallHarvest       -- idem. Environment.isPetHuntPlace
    --                                               menandainya, dan di sana tombol
    --                                               teleport Seeds/Sell diblokir game.
    --
    -- Dibiarkan kosong dengan sengaja: router akan memberi peringatan
    -- "PlaceId ... belum terdaftar" alih-alih menjalankan script yang salah dunia.
}

return Games

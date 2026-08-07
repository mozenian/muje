-- =========================================================
-- MOZE HUB — PASAR SETAN
-- place 108679402300081
--
-- Angka dan nama di berkas ini DIUKUR dari game, bukan dikira-kira:
--   GameConfig.Forage  -> PromptMaxDistance=6, PromptHoldDuration=0.5,
--                         RespawnCooldown=30, SpawnFolder="SpawnBahan"
--   workspace.SpawnBahan -> 81 Part bernama "Spawn_<ItemId>", atribut ItemId,
--                         ProximityPrompt "Ambil" ada di Part anak bernama Grip
--   GameConfig.Items   -> 6 bahan ber-flag forage beserta minLevel-nya
--
-- Yang BELUM diukur ditandai jelas di tabnya masing-masing. Tidak ada satu pun
-- remote yang ditembak dengan argumen tebakan di sini.
-- =========================================================

-- Penanda build, dicetak saat start dan tampil di tab Info.
--
-- Ada karena pernah terjadi: pemungutan diperbaiki di berkas lokal, lalu
-- dilaporkan "masih tidak collect" -- padahal jalur produksinya, saat diuji
-- langsung di game, berhasil dalam 56 ms. Tanpa penanda ini tidak ada cara
-- membedakan "perbaikannya gagal" dari "yang jalan masih salinan lama".
-- Cocokkan angka di bawah dengan yang tercetak di konsol SEBELUM menyimpulkan
-- apa pun. Aturan yang sama berlaku di hwid_bot.py.
local BUILD = "2026-08-07h"
print("[MOZE PASAR SETAN] BUILD " .. BUILD .. " | pungut=per-jenis | noclip=HRP | ambil=0stud+ulang | saklar-fitur-ikut-tersimpan")

local Fluent = loadstring(game:HttpGet(
    "https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua?t=" .. tostring(os.time())))()

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local LocalPlayer       = Players.LocalPlayer

-- Ditaruh DI SINI, bukan di bagian Masak seperti sebelumnya.
--
-- teleportKe() memakainya jauh di atas titik itu, dan `local` yang dideklarasikan
-- belakangan TIDAK terlihat oleh fungsi di atasnya -- yang terbaca justru global
-- bernilai nil, dan errornya baru muncul saat tombol ditekan. luac -p tidak bisa
-- melihat ini; yang menangkapnya pemeriksa urutan definisi.
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

-- =========================================================
-- KONFIGURASI
-- =========================================================
local Config = {
    -- Bahan yang dipungut. Default HANYA yang bisa diambil di Lv1 -- memilih
    -- bahan di atas level akun membuat bot terbang ke seberang peta lalu
    -- ditolak server, dan dari layar itu terlihat seperti script macet.
    Bahan = { Dupa = true, Kemenyan = true, JamurKuburan = true, Melati = true,
              Gagak = false, KepitingSungai = false },

    -- Prioritas: makin tinggi angkanya, makin duluan dikerjakan.
    --
    -- Angka bawaan mengikuti contohmu (kumpul 5, tanam 4, masak 3). Yang sama
    -- angkanya bergantian menurut siapa yang minta duluan, jadi kalau mau
    -- urutannya pasti, beri angka yang berbeda.
    Prioritas = {
        kumpul = 5, tanam = 4, masak = 3, panen = 2, potong = 2,
        siram = 1, toko = 1,
    },
    BatasGiliran     = 20,  -- detik; pemegang yang lebih lama dari ini dicabut paksa
    BatasAntre       = 30,  -- detik; yang menunggu lebih lama dari ini menyerah dulu
    JedaKumpulAntre  = 0.6, -- detik; jeda supaya yang berangka tinggi sempat ikut antre

    -- Mode gerak. Terbang lagi jadi bawaannya sesuai permintaan; dua lainnya
    -- tinggal dinyalakan kalau mau.
    ModePasif  = false,  -- kamu yang jalan, script cuma menyapu
    ModeJalan  = false,  -- script berjalan sendiri pakai MoveTo
    JedaSapu   = 0.8,    -- detik antar sapuan saat mode pasif

    -- Dua angka ini disalin dari pola instantSweep di still.lua, dan keduanya
    -- ada alasannya: cooldown per prompt mencegah bahan yang sama ditembaki
    -- terus, dan jeda antar prompt mencegah satu sapuan mengirim puluhan
    -- tembakan dalam satu frame. Menembak beruntun itu yang membuat SELURUH
    -- pemungutan berhenti diterima di percobaan sebelumnya.
    CooldownPrompt   = 2,
    JedaAntarPrompt  = 0.05,

    BatasJalan = 25,     -- detik maksimum menuju satu bahan sebelum menyerah

    -- Jangkauan sapuan.
    --
    -- TERUKUR 2026-08-07: pemungutan BERHASIL. Gagak 14 -> 15, satu tembakan,
    -- jarak 3 stud, MaxActivationDistance dibiarkan asli (6).
    --
    -- Yang selama ini rusak bukan jaraknya, melainkan cara mengukur berhasil.
    -- Aku menunggu part-nya lenyap; part itu bernama "Grip" dan memang TIDAK
    -- pernah lenyap -- ia cuma visual yang menetap di spawn. Barangnya masuk ke
    -- Backpack sebagai Tool dengan jumlah di namanya ("Gagak x15"). Jadi tiap
    -- pungutan yang berhasil dulu tercatat gagal, dan itu memicu tembakan
    -- beruntun yang akhirnya membuat semua pungutan ditolak.
    --
    -- Menaikkan MaxActivationDistance sudah tidak dipakai: dari klien ia tidak
    -- mengubah apa pun di server, dan sekarang terbukti tidak diperlukan.
    JangkauSapu = 6,     -- dipakai sebagai batas awal saja; yang menentukan
                         -- tetap MaxActivationDistance asli tiap prompt
    TungguPrompt    = 1.5, -- detik menunggu WorldItemCuller menyalakan prompt
    BatasVerifikasi = 3,   -- detik; terukur barang masuk 55 ms s/d >2,5 detik

    JedaAmbil   = 0.6,   -- detik antar pungutan; hold prompt-nya sendiri 0.5
    JarakAmbil  = 0,     -- stud; menempel ke barangnya supaya jarak tidak pernah
                         -- jadi alasan penolakan. Terbang berhenti di 2 stud
                         -- (mustahil pas 0 sambil bergerak), lalu CFrame
                         -- menempelkan sisanya.
    SnapKeBarang = true, -- tempelkan CFrame ke titik barang tiap percobaan
    BatasAmbil   = 8,    -- detik bertahan di satu barang sebelum menyerah
    JedaCoba     = 0.8,  -- detik antar percobaan di barang yang sama
    RadiusCari  = 800,   -- stud; terukur, seluruh 81 bahan ada dalam radius ini
    MaksPerPutaran = 40, -- pindai ulang setelah sekian pungutan

    -- Terbang, bukan teleport lompat. Teleport jarak jauh dalam satu frame itu
    -- pola yang paling gampang ditandai; ini bergerak dengan kecepatan terbatas.
    Kecepatan   = 160,   -- stud/detik

    -- NOCLIB saat terbang. Tabrakan karakter dimatikan, jadi rintangan tidak
    -- lagi menahan -- dan karena itu tidak perlu lagi naik melewati atapnya.
    -- Terbang rendah juga jauh kurang kentara daripada melayang 25 stud di atas
    -- pasar.
    Noclip = true,
    TinggiTerbang = 6,   -- ketinggian melayang di atas bahan saat memungut
    -- Terukur: 46 kursi di peta, puncak tertinggi Y=112, tanah ~113. Naik 25
    -- stud di atas titik tertinggi rute membuat seluruh perjalanan lewat di
    -- atas semuanya, bukan menembusnya.
    -- Hanya dipakai kalau Noclip DIMATIKAN. Dengan noclip nyala, rute jadi garis
    -- lurus ke sasaran -- tidak ada gunanya memanjat kalau tembok tidak menahan.
    TinggiJelajah = 25,
    JarakLangsung = 30,
    -- Detik tanpa kemajuan sebelum dianggap tersangkut. Rute tiga kaki dengan
    -- timeout penuh bisa memakan 29 detik per bahan yang terhalang; ini
    -- memotongnya jadi beberapa detik lalu lanjut ke bahan berikutnya.
    BatasMandek = 2.5,

    -- Masak. Menu default MATI semua: memasak menghabiskan bahan, dan tidak boleh
    -- ada yang terpakai tanpa kamu memilihnya sendiri.
    Menu = { Bakar = false, Rebus = false, TumisKamboja = false,
             SateKepiting = false, PisangRebus = false },
    JedaMasak  = 3,   -- detik; server membalas "Sabar dulu..." kalau terlalu rapat
    JedaPotong = 4,

    -- Titik jangkar untuk memuat area bahan dari jauh.
    --
    -- Diambil dari posisi bahan yang terukur (contoh jamur di 1850,110,374).
    -- Dipakai saat SpawnBahan kosong karena kamu sedang di zona lain.
    TitikPasar = Vector3.new(1850, 110, 374),
    NamaTitikPasar = "area pasar",

    -- Kebun. Jarak tanam terukur dari posisi Tanam yang terekam: titik-titiknya
    -- berjarak ~4-5 stud, jadi 5 dipakai sebagai jarak minimum antar tanaman.
    JarakTanam = 5,
    JedaKebun  = 0.8,
    JedaSiram  = 30,
    -- Siram butuh MENGHADAP tanamannya -- terbukti lewat percobaan terkendali
    -- pada tanaman yang sama, karakter tidak dipindah, hanya diputar:
    --     membelakangi, 4x tembak -> AirSisa=0,  Wet=false
    --     menghadap,    4x tembak -> AirSisa=95, Wet=true
    --
    -- Jangkauannya ikut diukur dengan cara yang sama:
    --     11 stud -> KENA        18, 18, 19 stud -> tidak kena
    -- Jadi batas aslinya antara 11 dan 18. Dipakai 10, bukan 11: di ambang
    -- persis, satu tembakan yang meleset tidak terlihat sebagai kesalahan --
    -- ia hanya "tidak tersiram", dan mendekat itu murah.
    JarakSiram = 10,
    SpamSiram  = 6,
    MaksTanamPerPutaran = 12,

    -- Toko. Semua default MATI: membeli menghabiskan Koin dan Shard, dan tidak
    -- boleh ada yang terpakai tanpa kamu memilihnya sendiri.
    Beli = { BibitKamboja = false, BibitMelati = false, BibitPisang = false,
             Pengelaris = false, Payung = false, PetGagak = false, OwlStaff = false },
    -- Toko gaib (Pria Misterius). Semua mati bawaannya: barangnya dibayar Coin
    -- dan sebagian mahal, jadi jangan ada yang terbeli tanpa kamu memilihnya.
    Gaib = {
        RamuanHoki = false, SandalAngin = false, MinyakJelangkung = false,
        KemenyanPerak = false, CoinPasarSetan = false, AirKembang = false,
        ArangKeramat = false,
    },

    JedaBeli = 1.5,
    JedaTokoIdle = 15,  -- terukur: restock tiap ~80 detik, jadi tidak perlu rapat

    -- Teleport bawaan game. Nama tujuan HURUF KECIL -- terbukti dari balasan
    -- TeleportGoto: "kios" dikenal, "Kios"/"KIOS"/"kiosk" tidak.
    --
    -- Ditulis sebagai DAFTAR kandidat, bukan satu nama. Yang sudah terbukti cuma
    -- "kios"; "pasar" dan "lahan" ikut dari kunci TeleportInfo tapi belum pernah
    -- kulihat diterima, jadi script mencoba berurutan sampai ada yang dikenal.
    -- Percobaan yang salah nama tidak berefek apa pun.
    TujuanPasar = { "pasar", "market", "pasarsetan" },
    TujuanLahan = { "lahan", "kebun", "plot" },
    TujuanDesa  = { "desa", "village" },
    TeleportOtomatis = true,
    -- Klaim otomatis. Lahan membuka teleport "lahan", lapak membuka "kios" --
    -- keduanya lewat ProximityPrompt "Klaim", bukan remote.
    AutoKlaim = true,

    -- Saklar fitur ikut tersimpan, atas permintaan.
    --
    -- Aku sempat sengaja mengecualikannya: berkas config yang bisa menyalakan
    -- bot sendiri begitu script dieksekusi itu perilaku yang mengagetkan. Itu
    -- keputusan pemilik script, bukan aku, dan sekarang tersimpan penuh.
    --
    -- Pengaman yang tersisa: MulaiOtomatis. Kalau dimatikan, keadaan saklar
    -- tetap tersimpan dan tetap terlihat di UI, tapi tidak ada yang berjalan
    -- sebelum kamu menekannya sendiri.
    Fitur = {
        kumpul = false, masak = false, potong = false,
        panen = false, tanam = false, siram = false, toko = false,
    },
    MulaiOtomatis = true,
}

-- =========================================================
-- SIMPAN CONFIG — folder workspace executor
-- =========================================================
--
-- Ditulis ke workspace/MozeHub/pasarsetan.json. "workspace" di sini folder
-- milik executor, bukan workspace-nya Roblox: writefile selalu berakar di situ.
--
-- Yang disimpan HANYA Config. Saklar fitur (Auto Kumpul, Auto Masak, dan
-- kawan-kawan) sengaja TIDAK ikut: berkas config yang bisa menyalakan bot
-- sendiri begitu script dijalankan itu perilaku yang mengagetkan, dan fitur
-- berisiko di proyek ini selalu default mati.
local HttpService = game:GetService("HttpService")
local BERKAS_FOLDER = "MozeHub"
local BERKAS_CONFIG = BERKAS_FOLDER .. "/pasarsetan.json"

-- Tidak semua executor punya berkas. Kalau tidak ada, script tetap jalan penuh
-- -- cuma tanpa simpanan. Diam-diam gagal di sini berarti pengguna mengira
-- setelannya tersimpan padahal tidak.
local function bisaBerkas()
    return type(writefile) == "function" and type(readfile) == "function"
       and type(isfile) == "function"
end

-- Bentuk yang aman di-JSON.
--
-- Vector3 TIDAK bisa di-JSONEncode -- HttpService melemparkan error pada
-- userdata. Config.TitikPasar adalah Vector3, jadi ini bukan kasus teoretis:
-- sebelum ini SELURUH penyimpanan mati diam-diam, karena pcall menelan error
-- encode-nya dan pemantau tidak pernah sampai ke tahap menulis. Berkasnya ada
-- di folder, isinya tidak pernah berubah, dan tidak ada satu pun pesan.
--
-- Vector3 diubah jadi tabel bertanda supaya bisa dipulihkan utuh; tipe lain
-- yang tidak dikenal DILEWATI, bukan dipaksa jadi string.
local function keJson(nilai)
    local t = typeof(nilai)
    if t == "Vector3" then
        return { __v3 = { nilai.X, nilai.Y, nilai.Z } }
    elseif t == "table" then
        local keluar = {}
        for k, v in pairs(nilai) do
            local hasil = keJson(v)
            if hasil ~= nil then keluar[k] = hasil end
        end
        return keluar
    elseif t == "number" or t == "string" or t == "boolean" then
        return nilai
    end
    return nil
end

local function dariJson(nilai)
    if type(nilai) == "table" then
        if type(nilai.__v3) == "table" and #nilai.__v3 == 3 then
            return Vector3.new(nilai.__v3[1], nilai.__v3[2], nilai.__v3[3])
        end
        local keluar = {}
        for k, v in pairs(nilai) do keluar[k] = dariJson(v) end
        return keluar
    end
    return nilai
end

local function simpanConfig()
    if not bisaBerkas() then return false, "executor tanpa writefile" end
    if type(isfolder) == "function" and not isfolder(BERKAS_FOLDER) then
        pcall(makefolder, BERKAS_FOLDER)
    end
    local ok, isi = pcall(function() return HttpService:JSONEncode(keJson(Config)) end)
    if not ok then return false, "gagal encode: " .. tostring(isi) end
    local ok2, err = pcall(writefile, BERKAS_CONFIG, isi)
    return ok2, ok2 and "tersimpan" or ("gagal tulis: " .. tostring(err))
end

-- Nilai tersimpan ditimpakan ke Config, tapi HANYA kunci yang memang sudah ada
-- dan tipenya sama.
--
-- Ini bukan kehati-hatian berlebihan: berkas dari versi lama bisa memuat kunci
-- yang sudah dihapus, dan menyalin mentah-mentah akan menghidupkan kembali
-- setelan yang tidak dipakai siapa pun. Tabel disalin per kunci, bukan
-- ditukar utuh, supaya kunci BARU yang belum ada di berkas lama tetap memakai
-- bawaannya alih-alih hilang jadi nil.
local function muatConfig()
    if not bisaBerkas() then return false, "executor tanpa readfile" end
    if not isfile(BERKAS_CONFIG) then return false, "belum ada simpanan" end
    local ok, isi = pcall(readfile, BERKAS_CONFIG)
    if not ok then return false, "gagal baca" end
    local ok2, mentah = pcall(function() return HttpService:JSONDecode(isi) end)
    if not ok2 or type(mentah) ~= "table" then return false, "berkas rusak" end
    local data = dariJson(mentah)

    local dipakai = 0
    for k, v in pairs(data) do
        local lama = Config[k]
        if lama ~= nil and type(lama) == type(v) then
            if type(v) == "table" then
                for k2, v2 in pairs(v) do
                    if lama[k2] == nil or type(lama[k2]) == type(v2) then
                        lama[k2] = v2
                        dipakai = dipakai + 1
                    end
                end
            else
                Config[k] = v
                dipakai = dipakai + 1
            end
        end
    end
    return true, dipakai .. " setelan dimuat"
end

-- Bawaan dibekukan SEBELUM berkas dimuat, supaya Reset punya sesuatu untuk
-- dikembalikan. Salinan dalam: kalau dangkal, mengubah Config.Bahan ikut
-- mengubah bawaannya dan Reset jadi tidak melakukan apa-apa.
local function salinDalam(t)
    if type(t) ~= "table" then return t end
    local k = {}
    for a, b in pairs(t) do k[a] = salinDalam(b) end
    return k
end
local BAWAAN = salinDalam(Config)

local statusSimpan = select(2, muatConfig())

-- Perubahan apa pun ikut tersimpan, tanpa harus menempel ke tiap OnChanged.
--
-- Sengaja memantau isi Config, bukan menyadap tiap tombol: elemen UI di berkas
-- ini ada puluhan, dan satu saja yang lupa dipasangi berarti setelan yang
-- diam-diam tidak tersimpan -- persis jenis bug yang sulit dilihat. Memantau
-- sumbernya menangkap semuanya, termasuk perubahan yang tidak datang dari klik.
task.spawn(function()
    local terakhir
    while true do
        local ok, isi = pcall(function() return HttpService:JSONEncode(keJson(Config)) end)
        if not ok then
            -- Ditampilkan, bukan didiamkan. Kegagalan encode yang tak terlihat
            -- itu persis yang membuat penyimpanan mati tanpa siapa pun tahu.
            statusSimpan = "GAGAL encode — lapor ke pembuat"
        end
        if ok and isi ~= terakhir then
            if terakhir ~= nil or not (bisaBerkas() and isfile(BERKAS_CONFIG)) then
                local ok2, pesan = simpanConfig()
                statusSimpan = ok2 and ("tersimpan " .. os.date("%H:%M:%S")) or pesan
            end
            terakhir = isi
        end
        task.wait(0.5)
    end
end)

-- Nama yang dipakai server. Kunci di kiri = ItemId asli, jangan diubah.
local NAMA_BAHAN = {
    Dupa           = "Dupa (Lv1)",
    Kemenyan       = "Kemenyan (Lv1)",
    JamurKuburan   = "Jamur Kuburan (Lv1)",
    Melati         = "Melati (Lv1)",
    Gagak          = "Gagak (Lv2)",
    KepitingSungai = "Kepiting Sungai (Lv3)",
}
local URUT_BAHAN = { "Dupa", "Kemenyan", "JamurKuburan", "Melati", "Gagak", "KepitingSungai" }

local MIN_LEVEL = {
    Dupa = 1, Kemenyan = 1, JamurKuburan = 1, Melati = 1,
    Gagak = 2, KepitingSungai = 3,
}

-- =========================================================
-- STATUS
-- =========================================================
local Status = {
    kumpul = false, masak = false, potong = false,
    panen = false, tanam = false, siram = false, toko = false,
    dipungut = 0, dipanen = 0, ditanam = 0, dibeli = 0,
    mandek = false,
    terakhir = "-",
    masakInfo = "-",
    kebunInfo = "-",
    tokoInfo = "-",
    mulai = os.time(),
}

-- Selama UI dibangun, handler toggle TIDAK boleh menjalankan loop.
--
-- Fluent memanggil OnChanged sekali saat elemen dibuat. Karena Default kini
-- dibaca dari config, elemen yang tersimpan menyala akan memicu handler-nya
-- saat itu juga -- fiturnya jalan sebelum tab lain bahkan selesai dibuat, dan
-- MulaiOtomatis jadi saklar yang tidak berarti apa-apa. Penjaga ini menunda
-- semuanya sampai pemulihan yang terkendali di akhir berkas.
local siapUI = false

-- =========================================================
-- GILIRAN — siapa yang memegang karakter
-- =========================================================
--
-- Angka prioritas saja tidak cukup: tujuh loop berjalan sendiri-sendiri, jadi
-- tanpa wasit mereka saling menarik karakter ke arah berbeda dan yang terlihat
-- cuma bot bergetar di tempat. Wasit ini memberi karakter kepada SATU fitur pada
-- satu waktu, dan yang angkanya paling tinggi dapat giliran duluan.
--
-- Dipegang per satuan kerja -- satu pungutan, satu tanam, satu panen -- bukan
-- per putaran penuh. Kalau dipegang seputaran, fitur berangka tinggi yang selalu
-- punya kerjaan akan membuat yang lain tidak pernah jalan sama sekali.
local antreGiliran = {}
local pemegang, pemegangSejak = nil, 0

local function prioritas(fitur)
    return tonumber(Config.Prioritas[fitur]) or 0
end

local function lepasGiliran(fitur)
    if pemegang == fitur then pemegang = nil end
    antreGiliran[fitur] = nil
end

-- Menunggu TANPA memegang giliran.
--
-- Menunggu bukan bekerja. Terukur: masak berangka 10 yang gagal klaim lapak
-- menahan giliran sekitar 23 detik tiap putaran -- terbang mencoba klaim, lalu
-- wait(3), lalu wait(8) -- dan kumpul berangka 4 cuma dapat 4 pungutan dalam 2
-- menit karenanya, padahal satu pungutan sebenarnya cuma butuh 1 detik.
--
-- Semua jeda backoff di dalam loop memakai ini, bukan task.wait langsung.
local function tungguLepas(fitur, detik)
    lepasGiliran(fitur)
    task.wait(detik)
end

-- Adakah fitur NYALA yang angkanya lebih tinggi, entah sedang antre atau belum?
local function adaLebihTinggiNyala(fitur)
    for f, aktif in pairs(Status) do
        if aktif == true and Config.Prioritas[f] and prioritas(f) > prioritas(fitur) then
            return true
        end
    end
    return false
end

-- Mengembalikan true kalau giliran didapat. false berarti fiturnya dimatikan
-- atau kelamaan menunggu -- pemanggilnya harus berhenti, bukan lanjut jalan.
local function mintaGiliran(fitur, batasTunggu)
    antreGiliran[fitur] = true
    local mulai = tick()
    while Status[fitur] do
        -- Pemegang yang tidak melepas -- misalnya loop-nya error di tengah --
        -- dicabut paksa. Tanpa ini satu kesalahan membekukan semua fitur lain.
        if pemegang and tick() - pemegangSejak > Config.BatasGiliran then
            pemegang = nil
        end
        if not pemegang then
            local menang = fitur
            for f in pairs(antreGiliran) do
                if Status[f] and prioritas(f) > prioritas(menang) then menang = f end
            end

            -- Jeda pengumpulan sebelum yang berangka rendah boleh menang.
            --
            -- Tanpa ini, yang MINTA duluan menang walau angkanya paling kecil --
            -- terbukti di uji: masak (3) jalan sebelum kumpul (5) hanya karena
            -- loop-nya menyala lebih dulu, dan itu persis yang terjadi di
            -- produksi. Jeda ini memberi yang berangka lebih tinggi kesempatan
            -- ikut antre. Kalau ternyata ia memang sedang tidak butuh -- misalnya
            -- sedang menunggu respawn 30 detik -- ia tidak akan ikut antre, dan
            -- yang rendah tetap jalan setelah jeda ini lewat. Jadi bukan
            -- penguncian: yang berangka kecil tidak akan kelaparan.
            local sabar = adaLebihTinggiNyala(fitur)
                and (tick() - mulai) < Config.JedaKumpulAntre

            if menang == fitur and not sabar then
                pemegang, pemegangSejak = fitur, tick()
                antreGiliran[fitur] = nil
                return true
            end
        end
        if tick() - mulai > (batasTunggu or Config.BatasAntre) then break end
        task.wait(0.2)
    end
    antreGiliran[fitur] = nil
    return false
end

local function levelSekarang()
    local ls = LocalPlayer:FindFirstChild("leaderstats")
    local lv = ls and ls:FindFirstChild("Lv")
    return lv and lv.Value or 0
end

local function karakter()
    local c = LocalPlayer.Character
    local hrp = c and c:FindFirstChild("HumanoidRootPart")
    local hum = c and c:FindFirstChildOfClass("Humanoid")
    return c, hrp, hum
end

local function lapor(teks)
    Status.terakhir = teks
    print("[PasarSetan] " .. teks)
end

-- =========================================================
-- GERAK
-- =========================================================
-- Paksa server memuat wilayah di sekitar sebuah titik.
--
-- Game ini memakai StreamingEnabled=true: klien HANYA memegang bagian dunia yang
-- dekat pemain. Terukur saat berdiri di desa, 6.900 stud dari pasar --
-- workspace.SpawnBahan benar-benar KOSONG, bukan tersembunyi. Objeknya tidak ada.
--
-- Akibatnya dua-duanya penting:
--   * Memindai bahan dari zona lain selalu menghasilkan nol, dan itu BUKAN tanda
--     bahannya habis.
--   * Terbang jauh tanpa memuat dulu berarti melintasi ruang tanpa lantai --
--     karakter jatuh menembus dunia.
--
-- Terukur: memanggil ini dari desa menarik 8 bahan masuk dalam 0,35 detik, tanpa
-- memindahkan karakter sama sekali.
local function muatWilayah(posisi, batas)
    local ok = pcall(function()
        LocalPlayer:RequestStreamAroundAsync(posisi, batas or 8)
    end)
    return ok
end

-- Teleport BAWAAN GAME, bukan terbang sendiri.
--
--     TeleportGoto:InvokeServer("kios")   -> {ok=false, reason="Kamu belum punya lapak"}
--     TeleportGoto:InvokeServer("Kios")   -> {ok=false, reason="Tujuan tidak dikenal"}
--
-- Dua balasan itu yang membuktikan konvensinya: nama tujuan HURUF KECIL, sama
-- seperti kunci di TeleportInfo. Diukur tanpa memindahkan karakter sama sekali --
-- "kios" kebetulan sedang tidak tersedia, jadi ia menolak dengan alasan yang
-- berbeda dan itu sudah cukup membuktikan namanya dikenal.
--
-- Dipakai menggantikan penerbangan jarak jauh. Jarak desa ke pasar terukur 6.700
-- stud; menempuhnya sendiri berarti melintasi wilayah yang streaming-nya belum
-- menyusul, dan itu risiko yang tidak perlu diambil kalau game-nya sendiri
-- menyediakan pintunya.
local function teleportKe(kandidat, label)
    local tolak = nil
    for _, tujuan in ipairs(kandidat) do
        local ok, res = pcall(function()
            return Remotes.TeleportGoto:InvokeServer(tujuan)
        end)
        if ok and type(res) == "table" then
            if res.ok then
                lapor("Teleport ke " .. (label or tujuan))
                task.wait(1.5)   -- beri waktu streaming menyusul
                return true, tujuan
            end
            -- "Tujuan tidak dikenal" berarti nama itu salah -- coba kandidat
            -- berikutnya. Alasan LAIN berarti namanya benar tapi memang ditolak,
            -- dan mencoba nama lain tidak akan menolong.
            if res.reason ~= "Tujuan tidak dikenal" then
                return false, tostring(res.reason)
            end
            tolak = tostring(res.reason)
        end
    end
    return false, tolak or "tidak ada tujuan yang dikenal"
end

-- Zona yang dibutuhkan tiap fitur.
--
-- Terukur dari dua kali pengamatan di tempat berbeda:
--   di "desa"  -> lahanku termuat, SpawnBahan 0
--   di "pasar" -> SpawnBahan 81, lahanku TIDAK termuat
-- Jadi mengumpul dan berkebun tidak bisa jalan bersamaan; keduanya di ujung peta
-- yang berlawanan, 6.750 stud.
--
-- Toko TIDAK ada di sini dengan sengaja: terukur ShopBuy dari pasar, 110 stud
-- dari NPC mana pun dan NPC tokonya sendiri belum termuat, tetap ditolak dengan
-- "Koin tidak cukup" -- alasan SALDO, bukan jarak. Jadi membeli bisa dari mana
-- saja dan tidak perlu ikut berebut zona.
local ZONA_FITUR = {
    kumpul = "pasar",
    masak  = "pasar",   -- kios ada di KiosAktif, di area pasar
    potong = "pasar",
    panen  = "lahan",
    tanam  = "lahan",
    siram  = "lahan",
}

-- Siapa yang sedang aktif dan butuh zona apa.
local function zonaAktif()
    local butuh = {}
    for fitur, zona in pairs(ZONA_FITUR) do
        if Status[fitur] then butuh[zona] = (butuh[zona] or 0) + 1 end
    end
    local daftar = {}
    for z in pairs(butuh) do daftar[#daftar + 1] = z end
    table.sort(daftar)
    return daftar
end

-- Teleport hanya boleh kalau tidak ada fitur lain yang butuh zona berbeda.
--
-- Tanpa penjagaan ini, menyalakan Auto Kumpul dan Auto Panen bersamaan membuat
-- keduanya saling melempar bolak-balik tiap beberapa detik: satu teleport ke
-- pasar, yang lain langsung menariknya ke lahan, dan tidak satu pun sempat
-- mengerjakan apa pun.
local function bolehTeleport(zonaku)
    for _, z in ipairs(zonaAktif()) do
        if z ~= zonaku then return false, z end
    end
    return true
end

-- Lahan milik sendiri.
--
-- Versi sebelumnya mencocokkan atribut "Owner" pada plot. Atribut itu TIDAK ADA
-- -- terukur, plot hanya punya "Level" -- jadi fungsi ini selalu mengembalikan
-- nil dan seluruh fitur kebun diam tanpa pesan error. Itu penyebab "bibitnya
-- tidak tertanam di lahan".
--
-- Dua penanda yang benar-benar ada, dipakai berurutan:
--   1. TextLabel "Nama" di plot berisi username ("mozereroll2"; plot kosong
--      berisi "Kosong"). Ini yang dipakai game untuk papan namanya sendiri.
--   2. Cadangan: tanaman di dalamnya beratribut OwnerId = UserId. Berguna kalau
--      papan namanya belum termuat, tapi gagal untuk lahan yang masih kosong --
--      karena itu ia cadangan, bukan yang utama.

local function lahanSaya()
    local root = workspace:FindFirstChild("LahanPlot")
    for _, p in ipairs(root and root:GetChildren() or {}) do
        local nama = p:FindFirstChild("Label")
        nama = nama and nama:FindFirstChild("Nama", true)
        if nama and nama:IsA("TextLabel") and nama.Text == LocalPlayer.Name then
            return p
        end
    end
    for _, p in ipairs(root and root:GetChildren() or {}) do
        local tn = p:FindFirstChild("Tanaman")
        for _, t in ipairs(tn and tn:GetChildren() or {}) do
            if tostring(t:GetAttribute("OwnerId")) == tostring(LocalPlayer.UserId) then
                return p
            end
        end
    end
    return nil
end

local function punyaLahan()
    return lahanSaya() ~= nil
end

local function punyaKios()
    local ka = workspace:FindFirstChild("KiosAktif")
    return ka ~= nil and ka:FindFirstChild("Kios_" .. LocalPlayer.Name) ~= nil
end

local function infoTeleport()
    local ok, res = pcall(function() return Remotes.TeleportInfo:InvokeServer() end)
    if ok and type(res) == "table" then return res end
    return nil
end

-- Lepas paksa dari kursi.
--
-- Terukur 46 Seat di peta ini, puncaknya Y=112 -- persis setinggi tanah tempat
-- bahan tumbuh, jadi jalur terbang lurus pasti melewatinya. Begitu tersangkut,
-- server MENGELAS HumanoidRootPart ke kursi; BodyVelocity melawan weld itu dan
-- tidak akan pernah menang, jadi bot menggantung selamanya di satu titik.
-- Weld-nya yang harus dibuang, bukan kecepatannya yang dinaikkan.
local function lepasDuduk()
    local _, hrp, hum = karakter()
    if not hum then return false end
    if not hum.Sit and not hum.SeatPart then return false end

    local kursi = hum.SeatPart
    -- Sit=false itu jalur utamanya dan berlaku di mana pun. Pembuangan weld di
    -- bawah cuma jaring kedua, untuk kasus kursi yang tidak melepas begitu saja.
    hum.Sit = false

    if kursi then
        -- Dicari berdasarkan APA yang disambungkannya, bukan namanya.
        --
        -- Roblox memang menamainya "SeatWeld", tapi aku belum pernah melihat
        -- satu pun kursi terisi di game ini untuk memastikannya -- dan kalau
        -- game-nya memakai nama lain, pencarian berbasis nama diam-diam gagal
        -- persis pada kasus yang mau diperbaiki.
        for _, w in ipairs(kursi:GetChildren()) do
            if w:IsA("Weld") or w:IsA("WeldConstraint") then
                local a = (w:IsA("Weld") and w.Part1) or w.Part1
                local b = (w:IsA("Weld") and w.Part0) or w.Part0
                if a == hrp or b == hrp then w:Destroy() end
            end
        end
    end
    hum.Jump = true
    if hrp then hrp.CFrame = hrp.CFrame + Vector3.new(0, 4, 0) end
    lapor("Lepas dari kursi")
    return true
end

-- Jaring pengaman: kalau sempat terduduk di antara dua pemeriksaan, event ini
-- yang menangkapnya. Dipasang ulang tiap respawn -- Humanoid-nya objek baru.
local function pasangAntiDuduk()
    local _, _, hum = karakter()
    if not hum or hum:GetAttribute("_antiduduk") then return end
    hum:SetAttribute("_antiduduk", true)
    hum.Seated:Connect(function(duduk)
        if duduk and (Status.kumpul or Status.potong) then
            task.defer(lepasDuduk)
        end
    end)
end

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    pasangAntiDuduk()
end)
task.spawn(pasangAntiDuduk)

-- Noclip: mematikan tabrakan seluruh bagian karakter.
--
-- HARUS dipasang ulang tiap frame. Roblox mengembalikan CanCollide sendiri saat
-- karakter menyentuh sesuatu atau bagian tubuh diganti, jadi menyetelnya sekali
-- di awal penerbangan akan luntur di tengah jalan -- tepat saat menembus sesuatu.
-- HumanoidRootPart WAJIB ikut dimatikan.
--
-- Terukur: di R15 game ini, HRP adalah SATU-SATUNYA part yang CanCollide=true --
-- 16 part lainnya sudah false sejak awal. Versi sebelumnya justru mengecualikan
-- HRP, jadi noclip-nya tidak mematikan apa pun dan sama sekali tidak menembus.
-- Alasan lama ("nanti jatuh menembus lantai") tidak berlaku: tabrakan
-- dikembalikan saat noclip dilepas, dan selama terbang posisi dikendalikan
-- sendiri. Sesudah dimatikan, engine TIDAK menyalakannya lagi (diamati 1 detik).
local aslinyaNabrak = setmetatable({}, { __mode = "k" })

local function pasangNoclip(aktif)
    local c = karakter()
    if not c then return end
    if aktif then
        -- Dicatat dulu baru dimatikan, supaya yang dipulihkan nanti PERSIS yang
        -- tadinya menabrak. Menyalakan semuanya saat lepas akan membuat lengan
        -- dan kaki ikut menabrak -- itu bukan keadaan aslinya.
        for _, d in ipairs(c:GetDescendants()) do
            if d:IsA("BasePart") and d.CanCollide then
                aslinyaNabrak[d] = true
                d.CanCollide = false
            end
        end
    else
        for d in pairs(aslinyaNabrak) do
            if d.Parent then d.CanCollide = true end
        end
        table.clear(aslinyaNabrak)
    end
end

-- Penerbangan satu ruas, tanpa perutean. Dipakai pergiKe() untuk tiap kaki.
local function terbangKe(sasaran, batasDetik)
    local _, hrp = karakter()
    if not hrp then return false end

    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(1, 1, 1) * 1e5
    bv.P = 5000
    bv.Parent = hrp

    local bg = Instance.new("BodyGyro")
    bg.MaxTorque = Vector3.new(1, 1, 1) * 1e5
    bg.P = 5000
    bg.Parent = hrp

    local batas = tick() + (batasDetik or 12)
    local sampai = false

    -- Deteksi TIDAK MAJU, bukan sekadar menunggu waktu habis.
    --
    -- Kalau jalurnya terhalang tembok atau pohon, BodyVelocity terus mendorong ke
    -- rintangan itu dan jaraknya berhenti mengecil. Versi sebelumnya baru
    -- menyerah setelah timeout penuh -- dan karena rutenya tiga kaki, satu bahan
    -- yang terhalang bisa memakan 29 detik sebelum dilewati. Dari layar itu
    -- terlihat persis seperti bot menggantung.
    local jarakTerbaik = math.huge
    local mandekSejak = tick()

    while tick() < batas do
        local _, h, hum = karakter()
        if not h then break end
        -- Diperiksa tiap frame, bukan sekali di awal: tersangkutnya terjadi DI
        -- TENGAH penerbangan, bukan sebelum berangkat.
        if hum and (hum.Sit or hum.SeatPart) then
            lepasDuduk()
        end
        if Config.Noclip then pasangNoclip(true) end
        local selisih = sasaran - h.Position
        local jarak = selisih.Magnitude
        if jarak <= math.max(Config.JarakAmbil, 2) then sampai = true break end

        if jarak < jarakTerbaik - 2 then
            jarakTerbaik = jarak
            mandekSejak = tick()
        elseif tick() - mandekSejak > Config.BatasMandek then
            -- Satu dorongan ke atas sebelum menyerah: kebanyakan sangkutan cuma
            -- pagar atau tepi meja setinggi beberapa stud.
            h.CFrame = h.CFrame + Vector3.new(0, 8, 0)
            jarakTerbaik = math.huge
            mandekSejak = tick()
            if Status.mandek then
                lapor("Tersangkut — dilewati")
                break
            end
            Status.mandek = true
        end

        bv.Velocity = selisih.Unit * math.min(Config.Kecepatan, jarak * 3)
        bg.CFrame = CFrame.new(h.Position, sasaran)
        RunService.Heartbeat:Wait()
    end

    Status.mandek = false
    bv:Destroy()
    bg:Destroy()
    if Config.Noclip then pasangNoclip(false) end
    return sampai
end

-- Rute tiga kaki: NAIK dulu, jelajah di atas, baru TURUN di tujuan.
--
-- Versi lama terbang lurus dari titik ke titik, dan karena bahan tumbuh di
-- ketinggian yang sama dengan kursi, garis lurus itu menyapu setiap kursi di
-- antaranya. Naik dulu membuat seluruh perjalanan melewatinya dari atas.
-- Ketinggiannya RELATIF terhadap titik berangkat dan tujuan, bukan angka mati --
-- tanah di peta ini tidak rata.
local function pergiKe(posisi, batasDetik)
    local _, hrp = karakter()
    if not hrp then return false end

    local tujuan = posisi + Vector3.new(0, Config.TinggiTerbang, 0)
    local mendatar = (Vector3.new(tujuan.X, 0, tujuan.Z) - Vector3.new(hrp.Position.X, 0, hrp.Position.Z)).Magnitude

    -- Dekat, ATAU noclip nyala: garis lurus saja.
    --
    -- Rute tiga kaki itu untuk menghindari rintangan. Dengan noclip tidak ada
    -- yang menahan, jadi memanjat 25 stud cuma memperlambat -- dan terbang
    -- rendah jauh kurang kentara daripada melayang tinggi di atas pasar.
    if Config.Noclip or mendatar <= Config.JarakLangsung then
        return terbangKe(tujuan, batasDetik)
    end

    -- Tujuan dimuat DULU. Tanpa ini, penerbangan jarak jauh berakhir di ruang
    -- yang belum ada lantainya dan karakter jatuh menembus dunia.
    muatWilayah(posisi)

    local jelajahY = math.max(hrp.Position.Y, tujuan.Y) + Config.TinggiJelajah
    local naik  = Vector3.new(hrp.Position.X, jelajahY, hrp.Position.Z)
    local silang = Vector3.new(tujuan.X, jelajahY, tujuan.Z)

    if not terbangKe(naik, 6) then return false end
    if not terbangKe(silang, batasDetik or 15) then return false end
    return terbangKe(tujuan, 8)
end

-- Klaim lapak / lahan.
--
-- Bukan lewat remote -- terukur, tidak ada satu pun remote bernuansa claim.
-- Yang ada ProximityPrompt "Klaim" / "Klaim Lapak" pada anak workspace.KiosPlot.
--
-- Ini juga yang MEMBUKA teleport: selama belum punya lapak, TeleportGoto("kios")
-- menolak dengan "Kamu belum punya lapak" -- terukur, dan itulah cara aku tahu
-- nama tujuannya benar tanpa memindahkan karakter.
local function klaimKosong(namaFolder, label)
    local folder = workspace:FindFirstChild(namaFolder)
    if not folder then return false, namaFolder .. " belum termuat" end

    local _, hrp = karakter()
    if not hrp then return false, "karakter belum siap" end

    local terdekat, jmin
    for _, d in ipairs(folder:GetDescendants()) do
        if d:IsA("ProximityPrompt") and d.Enabled then
            local teks = string.lower((d.ActionText or "") .. " " .. (d.ObjectText or ""))
            if string.find(teks, "klaim", 1, true) or string.find(teks, "claim", 1, true) then
                local part = d.Parent
                if part and part:IsA("BasePart") then
                    local j = (part.Position - hrp.Position).Magnitude
                    if not jmin or j < jmin then jmin, terdekat = j, d end
                end
            end
        end
    end
    if not terdekat then return false, "tidak ada " .. label .. " kosong di sekitar" end

    local part = terdekat.Parent
    if jmin > 8 then
        if not pergiKe(part.Position) then return false, "gagal mencapai " .. label end
    end

    -- Satu tembakan, pola yang sama dengan pemungutan bahan.
    pcall(fireproximityprompt, terdekat)
    task.wait(1.5)
    return true, "prompt klaim ditembak"
end


-- =========================================================
-- KUMPUL BAHAN
-- =========================================================
-- ItemId dibaca dari ATRIBUT, bukan dari nama objek.
--
-- Nama objeknya memang "Spawn_<ItemId>", tapi atributnya yang dipakai server
-- sendiri. Kalau suatu saat penamaannya berubah, atribut ini tetap benar.
-- Masih ada isinya, atau sudah dipanen dan sedang menunggu respawn?
--
-- TERUKUR, dan ini sumber keluhan "muter sana sini tapi jarang memungut":
-- spawn yang baru dipanen TETAP menampilkan visual dan label, jadi dari layar
-- terlihat persis sama dengan yang masih berisi. Yang membedakan cuma
-- AmbilPrompt-nya: kosong = Enabled false selama 30 detik.
--
-- Tiga keadaan, dan ketiganya harus dibedakan:
--   prompt ada + hidup  -> berisi, hampiri
--   prompt ada + mati   -> KOSONG, jangan dihampiri; dulu tetap dihampiri lalu
--                          menunggu 1,5 detik sia-sia sebelum menyerah
--   prompt tidak ada    -> belum termuat (WorldItemCuller membuang BahanVisual
--                          untuk yang jauh). Isinya belum diketahui, jadi tetap
--                          dihampiri -- mendekat sendiri yang memuatnya.
local function adaIsinya(part)
    local vis = part:FindFirstChild("BahanVisual")
    local grip = vis and vis:FindFirstChild("Grip")
    local prompt = grip and grip:FindFirstChildWhichIsA("ProximityPrompt")
    if not prompt then return true end
    return prompt.Enabled
end

local function daftarBahan()
    local folder = workspace:FindFirstChild("SpawnBahan")
    if not folder then return {} end

    local _, hrp = karakter()
    if not hrp then return {} end

    local hasil = {}
    for _, part in ipairs(folder:GetChildren()) do
        if part:IsA("BasePart") then
            local id = part:GetAttribute("ItemId")
            if id and Config.Bahan[id] then
                local jarak = (part.Position - hrp.Position).Magnitude
                if jarak <= Config.RadiusCari then
                    hasil[#hasil + 1] = { part = part, id = id, jarak = jarak }
                end
            end
        end
    end
    table.sort(hasil, function(a, b) return a.jarak < b.jarak end)
    return hasil
end

local function promptDari(part)
    -- Prompt-nya ada di Part anak bernama "Grip", bukan di part utamanya.
    for _, d in ipairs(part:GetDescendants()) do
        if d:IsA("ProximityPrompt") then return d end
    end
end

-- Cooldown per prompt. Kunci lemah, jadi prompt yang sudah hilang tidak menahan
-- entrinya di memori.
local jedaPrompt = setmetatable({}, { __mode = "k" })

-- Menembak SEKALI, tanpa tahan, tanpa beruntun.
--
-- Bentuknya menyusul instantSweep di still.lua, dan itu disengaja: versi
-- sebelumnya menembak 5-8 kali beruntun per bahan DITAMBAH InputHoldBegin/End,
-- dan sesudah beberapa lusin tembakan begitu, SELURUH pemungutan berhenti
-- diterima -- termasuk dari jarak 3 stud dengan prompt yang masih asli. Pola di
-- still.lua justru menghindari keduanya, dan catatannya menyebut sendiri
-- "no burst" beserta cooldown 2 detik per prompt.
-- Nama TAMPILAN bahan, diambil dari Label spawn-nya sendiri.
--
-- Ini perlu karena ItemId tidak sama dengan nama Tool: ItemId "Melati" tapi
-- Tool-nya "Bunga Melati x116", ItemId "JamurKuburan" tapi Tool-nya "Jamur
-- Kuburan x30". Label BillboardGui memuat nama yang persis sama dengan Tool.
local function namaTampilan(part)
    local lb = part:FindFirstChild("Label")
    local tx = lb and lb:FindFirstChildWhichIsA("TextLabel")
    if tx and tx.Text ~= "" then return tx.Text end
    return tostring(part:GetAttribute("ItemId"))
end

-- Jumlah SATU jenis barang, dibaca dari nama Tool ("Gagak x15").
--
-- Sengaja per jenis, bukan total semua Tool. Total ikut naik saat masakan
-- matang atau panen masuk, jadi pungutan yang sebenarnya gagal bisa terbaca
-- berhasil -- itu terlihat waktu diukur: satu "keberhasilan" tercatat dari
-- jarak 11 stud, padahal batas prompt-nya 6.
local function jumlahItem(nama)
    local p = Players.LocalPlayer
    local pola = "^" .. nama:gsub("%W", "%%%0") .. " x(%d+)$"
    for _, wadah in ipairs({ p:FindFirstChild("Backpack"), p.Character }) do
        if wadah then
            for _, t in ipairs(wadah:GetChildren()) do
                if t:IsA("Tool") then
                    if t.Name == nama then return 1 end
                    local n = t.Name:match(pola)
                    if n then return tonumber(n) end
                end
            end
        end
    end
    return 0
end

local function tembakPrompt(part, paksa)
    local prompt = promptDari(part)
    if not prompt or not part.Parent then return false end

    -- Cooldown melindungi SAPUAN dari menembaki bahan yang sama berulang tanpa
    -- henti. Untuk sasaran yang sedang kita hampiri sendiri ia justru
    -- menghalangi: percobaan kedua di tempat yang sama akan ditolak sebelum
    -- sempat menembak. `paksa` melewatinya -- jeda antar percobaan sudah diatur
    -- pemanggilnya lewat JedaCoba, jadi ini tetap bukan tembakan beruntun.
    local kini = os.clock()
    if not paksa then
        local lalu = jedaPrompt[prompt]
        if lalu and (kini - lalu) < Config.CooldownPrompt then return false end
    end
    jedaPrompt[prompt] = kini

    -- Prompt yang jauh DIMATIKAN oleh WorldItemCuller (LocalScript milik game),
    -- lalu dinyalakan lagi sesudah kita dekat. Menembak saat mati terbukti
    -- tidak menghasilkan apa-apa, jadi ditunggu -- bukan dipaksa Enabled = true,
    -- karena memaksa dari klien tidak mengubah keadaan di server.
    if not prompt.Enabled then
        local t0 = os.clock()
        repeat task.wait(0.1) until prompt.Enabled or os.clock() - t0 > Config.TungguPrompt
        if not prompt.Enabled then return false end
    end

    -- Jangan coba di luar jangkauan ASLI prompt-nya: tembakan yang pasti gagal
    -- tetap memakan jatah cooldown 2 detik, jadi ia justru memblokir percobaan
    -- yang seharusnya berhasil. Diukur dari Grip -- di situ prompt-nya menempel,
    -- dan itu yang dipakai server, bukan titik tengah spawn.
    local _, hrp = karakter()
    local titik = prompt.Parent:IsA("BasePart") and prompt.Parent.Position or part.Position
    if hrp and (titik - hrp.Position).Magnitude > prompt.MaxActivationDistance then
        jedaPrompt[prompt] = nil
        return false
    end

    -- Ditunggu sampai jumlahnya benar-benar naik, bukan dijeda tetap.
    --
    -- Terukur: barang masuk ke Backpack antara 55 ms sampai lebih dari 2,5
    -- detik. Jeda tetap 0,15 detik -- yang dipakai versi sebelumnya -- membuat
    -- pungutan yang LAMBAT terbaca gagal, lalu cooldown 2 detik memblokir
    -- percobaan berikutnya. Itulah "kadang tidak bekerja"-nya. Karena keluar
    -- lebih awal begitu naik, yang cepat tetap dibayar 55 ms saja.
    local nama = namaTampilan(part)
    local sebelum = jumlahItem(nama)
    pcall(fireproximityprompt, prompt)

    local batas = os.clock() + Config.BatasVerifikasi
    repeat
        task.wait(0.05)
        if jumlahItem(nama) > sebelum then
            Status.dipungut = Status.dipungut + 1
            return true
        end
    until os.clock() > batas
    return false
end

-- Menyapu semua bahan terpilih yang sedang dalam jangkauan, tanpa berhenti.
-- Dipanggil terus selama berjalan, jadi apa pun yang terlewati ikut terpungut.
local function sapuSekitar(lv)
    local _, hrp = karakter()
    if not hrp then return 0 end
    local folder = workspace:FindFirstChild("SpawnBahan")
    if not folder then return 0 end

    local dapat = 0
    for _, part in ipairs(folder:GetChildren()) do
        if not Status.kumpul then break end
        if part:IsA("BasePart") and part.Parent then
            local id = part:GetAttribute("ItemId")
            if id and Config.Bahan[id] then
                if (part.Position - hrp.Position).Magnitude <= Config.JangkauSapu then
                    if tembakPrompt(part) then
                        dapat = dapat + 1
                        lapor("Ambil " .. id .. " (total " .. Status.dipungut .. ")")
                    end
                    -- Jeda kecil ANTAR prompt, bukan beruntun tanpa napas.
                    -- still.lua memakai 0,05 detik di antara tembakan; tanpa itu
                    -- satu sapuan mengirim puluhan tembakan dalam satu frame.
                    task.wait(Config.JedaAntarPrompt)
                end
            end
        end
    end
    return dapat
end

local function ambilSatu(entri, lv)
    if not entri.part.Parent then return false end     -- keburu diambil orang lain

    if Config.ModeJalan then
        -- JALAN, bukan terbang.
        --
        -- MoveTo memakai penggerak Humanoid seperti pemain sungguhan: kecepatan
        -- wajar, menapak tanah, animasi jalan hidup. Yang terbang itu versi
        -- sebelumnya, dan dari luar bedanya kentara.
        local _, hrp, hum = karakter()
        if not (hrp and hum) then return false end

        local batas = tick() + Config.BatasJalan
        local jarakTerbaik, mandekSejak = math.huge, tick()
        while tick() < batas and Status.kumpul do
            if not entri.part.Parent then break end
            local jarak = (entri.part.Position - hrp.Position).Magnitude
            if jarak <= math.max(Config.JarakAmbil, 2) then break end

            -- Disapu SAMBIL berjalan, bukan setelah sampai. Itu inti mode ini:
            -- yang kebetulan terlewati ikut terpungut tanpa memutar jalan.
            sapuSekitar(lv)

            if jarak < jarakTerbaik - 2 then
                jarakTerbaik, mandekSejak = jarak, tick()
            elseif tick() - mandekSejak > Config.BatasMandek * 2 then
                lapor("Jalan tersendat — dilewati")
                break
            end

            hum:MoveTo(entri.part.Position)
            task.wait(0.35)
        end
    else
        if not pergiKe(entri.part.Position) then return false end
    end

    if not entri.part.Parent then return true end

    -- BERTAHAN sampai benar-benar dapat, baru pindah.
    --
    -- Sebelumnya satu tembakan lalu jalan terus, apa pun hasilnya. Sekarang
    -- dicoba berulang di tempat sampai jumlah di Backpack naik, atau sampai
    -- BatasAmbil habis.
    --
    -- Catatan penting soal "tunggu sampai barangnya hilang": TIDAK BISA. Part
    -- yang dipegang prompt bernama Grip dan terukur TIDAK pernah hilang saat
    -- dipungut -- ia cuma visual yang menetap. Yang naik adalah jumlah di nama
    -- Tool, dan itu yang dipakai di sini.
    local _, hrp = karakter()
    local batas = tick() + Config.BatasAmbil
    local ok = false
    local coba = 0

    repeat
        coba = coba + 1

        -- Menempel ke barangnya, 0 stud. Dua alasan:
        --   1. Jarak prompt 6 stud milik server; berdiri tepat di titiknya
        --      membuat jaraknya tidak pernah jadi alasan penolakan.
        --   2. KEPITING SUNGAI ada DI DALAM AIR. Karakter mengambang naik
        --      sendiri karena daya apung, jadi terbang biasa selalu berhenti di
        --      atas permukaan dan promptnya di luar jangkauan. Menempelkan CFrame
        --      tiap percobaan menahan posisi itu melawan apungnya.
        if Config.SnapKeBarang and hrp and entri.part.Parent then
            pcall(function() hrp.CFrame = CFrame.new(entri.part.Position) end)
        end

        ok = tembakPrompt(entri.part, true)   -- true = abaikan cooldown, ini sasaran kita
        if not ok then task.wait(Config.JedaCoba) end
    until ok or tick() > batas or not Status.kumpul

    if ok then
        lapor("Ambil " .. entri.id .. " (total " .. Status.dipungut .. ")")
    else
        lapor(entri.id .. " tidak terambil setelah " .. coba .. " percobaan — dilewati")
    end
    task.wait(Config.JedaAmbil)
    return ok
end

local function loopKumpul()
    while Status.kumpul do
        local ok, err = pcall(function()
            local lv = levelSekarang()

            -- Saringan level DIHAPUS atas permintaan.
            --
            -- Sebelumnya bahan di atas level akun disaring di sini, dan itulah
            -- yang membuat Kepiting Sungai (minLevel 3) mustahil dipungut di
            -- akun Lv2 — bukan gagal saat dicoba, melainkan tidak pernah dicoba
            -- sama sekali, sehingga dari layar terlihat seperti fitur mati.
            -- Sekarang semua yang kamu centang dihampiri; kalau server memang
            -- menolak, penolakannya terlihat apa adanya di log.

            -- MODE PASIF: script tidak memindahkan karakter sama sekali.
            --
            -- Kamu jalan sendiri seperti main biasa; script cuma menyapu apa pun
            -- yang masuk jangkauan. Tidak ada terbang, tidak ada MoveTo, tidak
            -- ada teleport otomatis -- kalau bahannya tidak termuat, itu karena
            -- kamu memang belum ke sana, dan itu keputusanmu.
            if Config.ModePasif then
                local folder = workspace:FindFirstChild("SpawnBahan")
                local ada = folder and #folder:GetChildren() or 0
                if ada == 0 then
                    lapor("Menunggu — belum ada bahan termuat di sekitarmu")
                    task.wait(3)
                    return
                end

                local dapat = sapuSekitar(lv)
                local _, hrp = karakter()
                local terdekat = math.huge
                for _, part in ipairs(folder:GetChildren()) do
                    if part:IsA("BasePart") and hrp then
                        local id = part:GetAttribute("ItemId")
                        if id and Config.Bahan[id] then
                            terdekat = math.min(terdekat, (part.Position - hrp.Position).Magnitude)
                        end
                    end
                end
                if dapat == 0 then
                    lapor(terdekat < math.huge
                        and string.format("Menyapu… terdekat %d stud (jangkauan %d)",
                                          math.floor(terdekat), Config.JangkauSapu)
                        or "Menyapu… tidak ada bahan terpilih di sekitar")
                end
                task.wait(Config.JedaSapu)
                return
            end

            local daftar = {}
            for _, e in ipairs(daftarBahan()) do
                daftar[#daftar + 1] = e
            end

            if #daftar == 0 then
                -- DIBEDAKAN, karena tindak lanjutnya berbeda.
                --
                -- SpawnBahan kosong = wilayahnya belum dimuat klien (kamu ada di
                -- zona lain), bukan bahannya habis. Menunggu 30 detik untuk
                -- "respawn" di keadaan ini berarti menunggu selamanya.
                local folder = workspace:FindFirstChild("SpawnBahan")
                if folder and #folder:GetChildren() == 0 then
                    -- Teleport bawaan game DULU, baru streaming manual sebagai
                    -- cadangan. Menempuh 6.700 stud sendiri itu pilihan terakhir,
                    -- bukan pertama -- game-nya menyediakan pintu ke sana.
                    local boleh, bentrok = bolehTeleport("pasar")
                    if not boleh then
                        lapor("Bahan ada di pasar, tapi fitur lain sedang butuh zona \""
                              .. bentrok .. "\". Matikan salah satu.")
                        task.wait(8)
                        return
                    end
                    if Config.TeleportOtomatis then
                        local ok2, sebab = teleportKe(Config.TujuanPasar, "pasar")
                        if not ok2 then
                            lapor("Teleport ke pasar ditolak: " .. tostring(sebab))
                        end
                    end
                    if #(workspace.SpawnBahan:GetChildren()) == 0 then
                        lapor("Area bahan belum dimuat — menarik dari " .. Config.NamaTitikPasar)
                        muatWilayah(Config.TitikPasar)
                        task.wait(2)
                    end
                    if #(workspace.SpawnBahan:GetChildren()) == 0 then
                        lapor("Masih kosong. Pakai tombol Teleport di tab Info, "
                              .. "atau dekati area pasar sendiri.")
                        task.wait(5)
                    end
                    return
                end

                -- Keadaan ketiga: bahannya ADA dan cocok, tapi seluruhnya di luar
                -- radius cari. Ini yang terjadi kalau kamu berdiri di desa --
                -- terukur 6.745 stud ke area pasar, sementara radius maksimum di
                -- panel cuma 1.200. Menyuruh menunggu respawn di sini keliru:
                -- yang kurang jaraknya, bukan bahannya.
                local terdekat = math.huge
                local _, hrp2 = karakter()
                for _, part in ipairs(folder:GetChildren()) do
                    if part:IsA("BasePart") and hrp2 then
                        local id = part:GetAttribute("ItemId")
                        if id and Config.Bahan[id] then
                            terdekat = math.min(terdekat, (part.Position - hrp2.Position).Magnitude)
                        end
                    end
                end

                if terdekat < math.huge and terdekat > Config.RadiusCari then
                    lapor(string.format(
                        "Bahan terdekat %d stud — di luar radius %d. Pakai tombol "
                        .. "\"Terbang ke area pasar\" di tab Info, atau dekati sendiri.",
                        math.floor(terdekat), Config.RadiusCari))
                    task.wait(5)
                    return
                end

                lapor("Bahan termuat tapi tidak ada yang cocok pilihanmu — menunggu respawn (30 dtk)")
                for _ = 1, 30 do
                    if not Status.kumpul then return end
                    task.wait(1)
                end
                return
            end

            lapor(#daftar .. " bahan dalam radius, terdekat " .. math.floor(daftar[1].jarak) .. " stud")

            -- Terdekat dipilih ULANG tiap kali, bukan sekali di awal.
            --
            -- Ini yang membuat rutenya terlihat acak: daftar diurutkan sekali
            -- dari titik berangkat, lalu disusuri apa adanya. Begitu terbang ke
            -- bahan pertama, posisi berubah dan urutan sisanya sudah tidak
            -- berlaku — bahan 2 stud di sebelah bisa dilewati demi bahan 300
            -- stud yang kebetulan lebih dekat DARI TITIK AWAL. Memilih ulang
            -- tiap langkah membuat rutenya benar-benar terdekat-dulu.
            local sisa = {}
            for _, e in ipairs(daftar) do sisa[#sisa + 1] = e end

            for _ = 1, math.min(#sisa, Config.MaksPerPutaran) do
                if not Status.kumpul then return end

                local _, hrpKini = karakter()
                if not hrpKini then return end

                -- Terisi DIUTAMAKAN, tapi tidak pernah dibuang.
                --
                -- Versi sebelumnya membuang yang promptnya mati. Itu terlalu
                -- keras: WorldItemCuller juga mematikan prompt sesaat setelah
                -- wilayahnya baru dimuat, jadi bahan yang SEBENARNYA berisi dan
                -- ada 3 stud di sebelah bisa ikut terbuang -- lalu script
                -- terbang ke bahan 200 stud. Itu persis "masih ngambil yang jauh
                -- padahal ada yang dekat".
                --
                -- Sekarang dua putaran: cari terdekat yang jelas berisi dulu;
                -- kalau tidak ada satu pun, baru terdekat apa adanya.
                local pilih, idx = nil, nil
                for lapis = 1, 2 do
                    for k, e in ipairs(sisa) do
                        if lapis == 2 or adaIsinya(e.part) then
                            local j = (e.part.Position - hrpKini.Position).Magnitude
                            if not pilih or j < pilih.jarak then
                                pilih, idx = { part = e.part, id = e.id, jarak = j }, k
                            end
                        end
                    end
                    if pilih then break end
                end
                if not pilih then break end
                table.remove(sisa, idx)

                -- Giliran diminta PER BAHAN, bukan per putaran. Satu putaran
                -- bisa 40 bahan; menahannya seputaran berarti fitur lain tidak
                -- pernah kebagian selama masih ada yang bisa dipungut.
                if not mintaGiliran("kumpul") then return end
                ambilSatu(pilih, lv)
                lepasGiliran("kumpul")
            end
        end)
        if not ok then lapor("Error: " .. tostring(err)) end
        task.wait(0.5)
    end
end

-- =========================================================
-- MASAK
-- =========================================================
-- Menu dan bahannya DISALIN dari GameConfig.Cooking.Stove.Menus, dan id-nya
-- adalah argumen yang benar-benar dikirim game -- terekam dari panggilan asli:
--     CookStove:InvokeServer("Bakar")   -> {ok=true}
--     CookStove:InvokeServer("ngawur")  -> {ok=false, reason="Menu tidak ada"}
local MENU = {
    { id = "Bakar",        label = "Sate Gagak",       bahan = "DagingGagak x1",            waktu = 60 },
    { id = "Rebus",        label = "Jamur Rebus",      bahan = "JamurKuburan x1",           waktu = 60 },
    { id = "TumisKamboja", label = "Tumis Kamboja",    bahan = "Kamboja x1",                waktu = 90 },
    { id = "SateKepiting", label = "Sate Kepiting",    bahan = "KepitingSungai x3 + Dupa x1", waktu = 90 },
    { id = "PisangRebus",  label = "Pisang Raja Rebus", bahan = "Pisang x1",                waktu = 90 },
}

local function laporMasak(teks)
    Status.masakInfo = teks
    print("[PasarSetan][masak] " .. teks)
end

local function pollAntrean()
    local ok, hasil = pcall(function() return Remotes.CookQueuePoll:InvokeServer() end)
    if ok and type(hasil) == "table" and hasil.ok then return hasil end
    return nil
end

local function slotKosong(q)
    local maks = q.maxQueue or 3
    local terpakai = 0
    for i = 1, maks do
        local s = q.slots and q.slots[i]
        if s and s.active then terpakai = terpakai + 1 end
    end
    return maks - terpakai
end

local function loopMasak()
    while Status.masak do
        if not mintaGiliran("masak") then break end
        local ok, err = pcall(function()
            -- Lapak WAJIB ada sebelum masak: alat masak berada di dalam kiosmu
            -- sendiri, dan tanpa lapak teleport "kios" juga tertutup.
            if Config.AutoKlaim and not punyaKios() then
                local ok2, sebab = klaimKosong("KiosPlot", "lapak")
                laporMasak("Klaim lapak: " .. tostring(sebab))
                tungguLepas("masak", 3)
                if not punyaKios() then tungguLepas("masak", 8) return end
                laporMasak("Lapak didapat")
            end

            local q = pollAntrean()
            if not q then laporMasak("Antrean tidak terbaca") return end

            local kosong = slotKosong(q)
            if kosong <= 0 then
                laporMasak("Antrean penuh (" .. (q.maxQueue or 3) .. "), menunggu")
                return
            end

            for _, m in ipairs(MENU) do
                if not Status.masak then return end
                if Config.Menu[m.id] and kosong > 0 then
                    local ok2, res = pcall(function()
                        return Remotes.CookStove:InvokeServer(m.id)
                    end)
                    -- res.ok DIPERIKSA, bukan sekadar "pcall berhasil".
                    -- Remote ini selalu membalas tabel; pcall yang lolos hanya
                    -- berarti panggilannya sampai, bukan bahwa masaknya diterima.
                    if ok2 and type(res) == "table" and res.ok then
                        kosong = kosong - 1
                        laporMasak("Masak " .. m.label)
                    elseif ok2 and type(res) == "table" then
                        laporMasak(m.label .. " ditolak: " .. tostring(res.reason))
                    else
                        laporMasak(m.label .. " error: " .. tostring(res))
                    end
                    task.wait(Config.JedaMasak)
                end
            end
        end)
        lepasGiliran("masak")
        if not ok then laporMasak("Error: " .. tostring(err)) end
        task.wait(3)
    end
end

-- Potong gagak: prompt di kios SENDIRI.
--
-- workspace.KiosAktif berisi kios seluruh pemain server (terukur 19 kios), jadi
-- mencari "Pemotongan" pertama yang ketemu akan menekan alat milik orang lain.
local function promptPotong()
    local ka = workspace:FindFirstChild("KiosAktif")
    local kios = ka and ka:FindFirstChild("Kios_" .. LocalPlayer.Name)
    if not kios then return nil, "kios sendiri tidak ketemu" end
    local alat = kios:FindFirstChild("AlatMasak")
    local potong = alat and alat:FindFirstChild("Pemotongan")
    if not potong then return nil, "alat Pemotongan tidak ada" end
    for _, d in ipairs(potong:GetDescendants()) do
        if d:IsA("ProximityPrompt") then return d end
    end
    return nil, "prompt tidak ada di Pemotongan"
end

local function loopPotong()
    while Status.potong do
        if not mintaGiliran("potong") then break end
        local ok, err = pcall(function()
            local prompt, sebab = promptPotong()
            if not prompt then laporMasak("Potong: " .. tostring(sebab)) tungguLepas("potong", 5) return end

            local part = prompt.Parent
            if part and part:IsA("BasePart") then
                local _, hrp = karakter()
                if hrp and (part.Position - hrp.Position).Magnitude > 8 then
                    pergiKe(part.Position)
                end
            end

            -- HoldDuration 1 detik: prompt ditahan, bukan ditembak sekali.
            for _ = 1, 3 do
                if not Status.potong then return end
                pcall(fireproximityprompt, prompt)
                task.wait(1.2)
            end
        end)
        lepasGiliran("potong")
        if not ok then laporMasak("Potong error: " .. tostring(err)) end
        task.wait(Config.JedaPotong)
    end
end

-- =========================================================
-- KEBUN
-- =========================================================
-- Signature-nya terekam dari permainanmu sendiri, bukan ditebak:
--     Tanam:FireServer(Vector3)                  -- titik di lahan
--     Panen:FireServer(Part<Melati_Tanaman>)     -- instance tanamannya
--     Siram:FireServer()                         -- tanpa argumen
--
-- Ketiganya RemoteEvent, jadi tidak ada nilai balik yang bisa diperiksa.
-- Keberhasilan diukur dari perubahan isi folder Tanaman, bukan dari "pcall lolos".
local function laporKebun(teks)
    Status.kebunInfo = teks
    print("[PasarSetan][kebun] " .. teks)
end

-- Lahan dikenali dari atribut Owner, bukan dari yang terdekat.
--
-- Ada 24 lahan di peta dan tetangga bisa berdiri lebih dekat daripada lahanmu
-- sendiri -- memilih yang terdekat berarti menanam di kebun orang.

local function tanamanku(lahan)
    local folder = lahan and lahan:FindFirstChild("Tanaman")
    local hasil = {}
    for _, d in ipairs(folder and folder:GetChildren() or {}) do
        if d:IsA("BasePart") and tostring(d:GetAttribute("OwnerId")) == tostring(LocalPlayer.UserId) then
            hasil[#hasil + 1] = d
        end
    end
    return hasil
end

local function pegangAlat(nama)
    local _, _, hum = karakter()
    if not hum then return nil end
    local c = LocalPlayer.Character
    local dipegang = c and c:FindFirstChildOfClass("Tool")
    if dipegang and string.find(dipegang.Name, nama, 1, true) then return dipegang end

    for _, t in ipairs(LocalPlayer.Backpack:GetChildren()) do
        if t:IsA("Tool") and string.find(t.Name, nama, 1, true) then
            pcall(function() hum:EquipTool(t) end)
            local batas = tick() + 2
            while tick() < batas do
                if t.Parent == c then return t end
                task.wait(0.05)
            end
            return t.Parent == c and t or nil
        end
    end
    return nil
end

local function loopPanen()
    while Status.panen do
        if not mintaGiliran("panen") then break end
        local ok, err = pcall(function()
            local lahan = lahanSaya()
            if not lahan then
                -- Teleport bawaan game, bukan menyuruh pemain jalan sendiri.
                local boleh, bentrok = bolehTeleport("lahan")
                if not boleh then
                    laporKebun("Lahan butuh zona \"lahan\", tapi fitur lain sedang di \""
                               .. bentrok .. "\". Matikan salah satu.")
                    tungguLepas("panen", 8) return
                end
                if Config.TeleportOtomatis then
                    teleportKe(Config.TujuanLahan, "lahan")
                    task.wait(1)
                    lahan = lahanSaya()
                end
                if not lahan then
                    laporKebun("Lahanmu belum termuat — pakai tombol Teleport ke lahan")
                    tungguLepas("panen", 5) return
                end
            end

            local siap = {}
            for _, t in ipairs(tanamanku(lahan)) do
                -- Ready itu atribut milik server. Menebak dari Fase atau Sisa
                -- berarti menembak Panen pada tanaman yang belum matang.
                if t:GetAttribute("Ready") == true then siap[#siap + 1] = t end
            end

            if #siap == 0 then
                local semua = tanamanku(lahan)
                local sisaTercepat = math.huge
                for _, t in ipairs(semua) do
                    sisaTercepat = math.min(sisaTercepat, tonumber(t:GetAttribute("Sisa")) or math.huge)
                end
                laporKebun(string.format("%d tanaman, belum ada yang siap%s", #semua,
                    sisaTercepat < math.huge and string.format(" (tercepat %ds lagi)", math.floor(sisaTercepat)) or ""))
                tungguLepas("panen", 10)
                return
            end

            for _, t in ipairs(siap) do
                if not Status.panen then return end
                if (t.Position - select(2, karakter()).Position).Magnitude > 12 then
                    pergiKe(t.Position)
                end
                pcall(function() Remotes.Panen:FireServer(t) end)
                task.wait(Config.JedaKebun)
                if not t.Parent then
                    Status.dipanen = Status.dipanen + 1
                    laporKebun("Panen " .. tostring(t:GetAttribute("PlantKey")) .. " (total " .. Status.dipanen .. ")")
                end
            end
        end)
        lepasGiliran("panen")
        if not ok then laporKebun("Error: " .. tostring(err)) end
        task.wait(1)
    end
end

local function loopTanam()
    while Status.tanam do
        if not mintaGiliran("tanam") then break end
        local ok, err = pcall(function()
            local lahan = lahanSaya()
            if not lahan then
                local boleh, bentrok = bolehTeleport("lahan")
                if not boleh then
                    laporKebun("Lahan butuh zona \"lahan\", tapi fitur lain sedang di \""
                               .. bentrok .. "\". Matikan salah satu.")
                    tungguLepas("tanam", 8) return
                end
                if Config.TeleportOtomatis then
                    teleportKe(Config.TujuanLahan, "lahan")
                    task.wait(1)
                    lahan = lahanSaya()
                end
                if not lahan then
                    laporKebun("Lahanmu belum termuat — pakai tombol Teleport ke lahan")
                    tungguLepas("tanam", 5) return
                end
            end

            if Config.AutoKlaim and not punyaLahan() then
                local ok2, sebab = klaimKosong("LahanPlot", "lahan")
                laporKebun("Klaim lahan: " .. tostring(sebab))
                tungguLepas("tanam", 3)
                if not punyaLahan() then tungguLepas("tanam", 8) return end
                laporKebun("Lahan didapat")
                lahan = lahanSaya()
            end

            local bibit = pegangAlat("Bibit")
            if not bibit then
                laporKebun("Tidak ada bibit di tas — beli dulu di toko")
                tungguLepas("tanam", 8)
                return
            end

            local pembatas = lahan:FindFirstChild("Pembatas")
            if not pembatas then laporKebun("Batas lahan tidak ketemu") tungguLepas("tanam", 5) return end
            local okB, cf, ukuran = pcall(function() return pembatas:GetBoundingBox() end)
            if not okB then laporKebun("Batas lahan tidak terbaca") tungguLepas("tanam", 5) return end

            local ada = tanamanku(lahan)
            local sebelum = #ada

            -- Titik dicoba dari petak jaring, dan yang terlalu dekat dengan
            -- tanaman lama dilewati. Jarak antar tanaman terukur ~4-5 stud dari
            -- posisi Tanam yang terekam, jadi 5 dipakai sebagai jarak minimum.
            local lebar, panjang = ukuran.X / 2 - 3, ukuran.Z / 2 - 3
            local ditanam = 0
            for x = -lebar, lebar, Config.JarakTanam do
                for z = -panjang, panjang, Config.JarakTanam do
                    if not Status.tanam then return end
                    if ditanam >= Config.MaksTanamPerPutaran then break end

                    local titik = cf.Position + Vector3.new(x, 0, z)
                    local bentrok = false
                    for _, t in ipairs(ada) do
                        if (Vector3.new(t.Position.X, 0, t.Position.Z)
                            - Vector3.new(titik.X, 0, titik.Z)).Magnitude < Config.JarakTanam then
                            bentrok = true break
                        end
                    end

                    if not bentrok then
                        pcall(function() Remotes.Tanam:FireServer(titik) end)
                        task.wait(Config.JedaKebun)
                        local kini = tanamanku(lahan)
                        if #kini > #ada then
                            ada = kini
                            ditanam = ditanam + 1
                            Status.ditanam = Status.ditanam + 1
                            laporKebun("Tanam di petak (total " .. Status.ditanam .. ")")
                        end
                        if not pegangAlat("Bibit") then
                            laporKebun("Bibit habis")
                            return
                        end
                    end
                end
            end

            if ditanam == 0 then
                laporKebun(string.format("Lahan penuh atau bibit tidak terpakai (%d tanaman)", sebelum))
                tungguLepas("tanam", 10)
            end
        end)
        lepasGiliran("tanam")
        if not ok then laporKebun("Error: " .. tostring(err)) end
        task.wait(2)
    end
end

local function loopSiram()
    while Status.siram do
        if not mintaGiliran("siram") then break end
        local ok, err = pcall(function()
            local lahan = lahanSaya()
            if not lahan then tungguLepas("siram", 5) return end

            local kering = {}
            for _, t in ipairs(tanamanku(lahan)) do
                if t:GetAttribute("Wet") ~= true then kering[#kering + 1] = t end
            end
            if #kering == 0 then laporKebun("Semua tanaman sudah basah") tungguLepas("siram", 15) return end

            if not pegangAlat("Penyiram") then
                laporKebun("PenyiramTanaman tidak ada di tas")
                tungguLepas("siram", 10)
                return
            end

            local _, hrp = karakter()
            if not hrp then return end
            table.sort(kering, function(a, b)
                return (a.Position - hrp.Position).Magnitude < (b.Position - hrp.Position).Magnitude
            end)

            local disiram = 0
            for _, t in ipairs(kering) do
                if not Status.siram then return end
                if not t.Parent then break end

                local _, h = karakter()
                if not h then break end
                if (t.Position - h.Position).Magnitude > Config.JarakSiram then
                    pergiKe(t.Position)
                    _, h = karakter()
                    if not h then break end
                end

                -- MENGHADAP tanamannya, dan itu bukan hiasan.
                --
                -- Diuji terkendali di lahan sungguhan pada tanaman yang sama:
                --     membelakangi -> 4x Siram -> AirSisa=0,  Wet=false
                --     menghadap    -> 4x Siram -> AirSisa=95, Wet=true
                -- Jadi server memilih sasaran dari arah pandang, bukan dari jarak
                -- saja. Y disamakan supaya karakter tidak menunduk/mendongak --
                -- yang menentukan arah mendatarnya.
                h.CFrame = CFrame.new(h.Position,
                    Vector3.new(t.Position.X, h.Position.Y, t.Position.Z))
                task.wait(0.25)

                -- Di-spam, karena satu tembakan yang jatuh tepat saat karakter
                -- masih berputar sering tidak terhitung.
                for _ = 1, Config.SpamSiram do
                    if not Status.siram or not t.Parent then break end
                    if t:GetAttribute("Wet") == true then break end
                    pcall(function() Remotes.Siram:FireServer() end)
                    task.wait(0.25)
                end

                if t:GetAttribute("Wet") == true then
                    disiram = disiram + 1
                    laporKebun(string.format("Siram %d/%d (%s)", disiram, #kering,
                        tostring(t:GetAttribute("PlantKey"))))
                end
            end

            if disiram == 0 then
                laporKebun(#kering .. " kering tapi tidak ada yang tersiram — cek air penyiram")
                tungguLepas("siram", 10)
            end
        end)
        lepasGiliran("siram")
        if not ok then laporKebun("Siram error: " .. tostring(err)) end
        task.wait(Config.JedaSiram)
    end
end

-- =========================================================
-- TOKO
-- =========================================================
-- Terekam dari pembelianmu sendiri:
--     ShopBuy:InvokeServer("BibitMelati")  -> {ok=true}
--     ShopBuy:InvokeServer("ngawur")       -> {ok=false, reason="Item tidak ada"}
--     ShopPoll:InvokeServer()              -> {ok, coins, level, stock, quota, owned, restockIn}
--
-- quota per barang: {BatasHari=50, BatasKiriman=5, SisaHari=N, SisaKiriman=M}
-- Toko gaib. Id-nya TERUKUR dari GaibShopPoll (bidang Id/Display/Price/Desc);
-- yang belum pernah terlihat di rotasi ikut dicantumkan karena GaibBuy sudah
-- mengakui id-nya sah -- penolakannya soal jarak, bukan soal barang.
local URUT_GAIB = {
    { id = "RamuanHoki",       label = "Ramuan Hoki",        efek = "muncul di slot rotasi" },
    { id = "SandalAngin",      label = "Sandal Angin — 50",  efek = "Lari +40% selama 10 menit" },
    { id = "MinyakJelangkung", label = "Minyak Jelangkung — 60", efek = "Pungut bahan 2x selama 10 menit" },
    { id = "KemenyanPerak",    label = "Kemenyan Perak — 100",   efek = "+1 Serpihan tiap melayani, sampai pagi" },
    { id = "CoinPasarSetan",   label = "Coin Pasar Setan — 200", efek = "koin kuno, disimpan" },
    { id = "AirKembang",       label = "Air Kembang",        efek = "muncul di slot rotasi" },
    { id = "ArangKeramat",     label = "Arang Keramat",      efek = "muncul di slot rotasi" },
}

local BARANG = {
    { id = "BibitKamboja", label = "Bibit Kamboja x5", harga = 1,     mata = "Shard" },
    { id = "BibitMelati",  label = "Bibit Melati x5",  harga = 2,     mata = "Shard" },
    { id = "BibitPisang",  label = "Bibit Pisang x5",  harga = 3,     mata = "Shard" },
    { id = "Pengelaris",   label = "Dupa Pemikat",     harga = 50,    mata = "Coin" },
    { id = "Payung",       label = "Payung Daun",      harga = 750,   mata = "Coin" },
    { id = "PetGagak",     label = "Pet Gagak",        harga = 3000,  mata = "Coin" },
    { id = "OwlStaff",     label = "Tongkat Burung Hantu", harga = 35000, mata = "Coin" },
}

local function laporToko(teks)
    Status.tokoInfo = teks
    print("[PasarSetan][toko] " .. teks)
end

-- Saldo Shard tidak ada di leaderstats maupun balasan ShopPoll.
-- Terukur: ia atribut Count pada Tool "Serpihan Arwah" di tas.
local function saldoShard()
    for _, t in ipairs(LocalPlayer.Backpack:GetChildren()) do
        if t:GetAttribute("IsShard") == true then
            return tonumber(t:GetAttribute("Count")) or 0
        end
    end
    local c = LocalPlayer.Character
    for _, t in ipairs(c and c:GetChildren() or {}) do
        if t:IsA("Tool") and t:GetAttribute("IsShard") == true then
            return tonumber(t:GetAttribute("Count")) or 0
        end
    end
    return 0
end

-- Posisi Pria Misterius. Dicari lewat prompt-nya, bukan lewat nama Model:
-- prompt "Bicara" itu yang terukur ada, dan namanya tidak ikut berubah walau
-- model NPC-nya diganti.
local function cariPriaMisterius()
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("ProximityPrompt") and d.ObjectText == "Pria Misterius" then
            local par = d.Parent
            if par and par:IsA("BasePart") then return par.Position end
            if par then
                local bp = par:FindFirstChildWhichIsA("BasePart", true)
                if bp then return bp.Position end
            end
        end
    end
end

local function pollToko()
    local ok, hasil = pcall(function() return Remotes.ShopPoll:InvokeServer() end)
    if ok and type(hasil) == "table" and hasil.ok then return hasil end
    return nil
end

local function loopToko()
    while Status.toko do
        if not mintaGiliran("toko") then break end
        local ok, err = pcall(function()
            local q = pollToko()
            if not q then laporToko("Toko tidak terbaca") tungguLepas("toko", 5) return end

            local shard = saldoShard()
            local dibeli, alasan = 0, nil

            for _, b in ipairs(BARANG) do
                if not Status.toko then return end
                if Config.Beli[b.id] then
                    local kuota = (q.quota or {})[b.id]
                    local stok = (q.stock or {})[b.id]

                    -- Kuota diperiksa DULU, sebelum menembak remote.
                    --
                    -- SisaKiriman habis berarti harus menunggu restock, bukan
                    -- kesalahan. Menembaknya terus cuma memancing "Sabar dulu..."
                    -- dan menutupi penolakan yang sebenarnya berarti.
                    if kuota and (kuota.SisaKiriman or 0) <= 0 then
                        alasan = b.label .. ": jatah kiriman habis, restock "
                                 .. math.floor(q.restockIn or 0) .. "s"
                    elseif kuota and (kuota.SisaHari or 0) <= 0 then
                        alasan = b.label .. ": jatah harian habis"
                    elseif stok and stok <= 0 then
                        alasan = b.label .. ": stok kosong"
                    else
                        local punya = (b.mata == "Shard") and shard or (q.coins or 0)
                        if punya < b.harga then
                            alasan = string.format("%s: %s kurang (%d/%d)",
                                b.label, b.mata, punya, b.harga)
                        else
                            local ok2, res = pcall(function()
                                return Remotes.ShopBuy:InvokeServer(b.id)
                            end)
                            -- res.ok DIPERIKSA. Remote ini selalu membalas tabel;
                            -- pcall yang lolos cuma berarti panggilannya sampai.
                            if ok2 and type(res) == "table" and res.ok then
                                dibeli = dibeli + 1
                                Status.dibeli = Status.dibeli + 1
                                laporToko("Beli " .. b.label .. " (total " .. Status.dibeli .. ")")
                                if b.mata == "Shard" then shard = shard - b.harga end
                            elseif ok2 and type(res) == "table" then
                                alasan = b.label .. " ditolak: " .. tostring(res.reason)
                            else
                                alasan = b.label .. " error: " .. tostring(res)
                            end
                            task.wait(Config.JedaBeli)
                        end
                    end
                end
            end

            -- ---------- Toko Gaib (Pria Misterius) ----------
            --
            -- Toko TERPISAH dari ShopPoll, dan itu sebabnya Ramuan Hoki tidak
            -- pernah muncul di sini: ia tidak pernah ada di ShopPoll sama
            -- sekali. Stoknya berputar -- dua slot "anchor" tetap, dua slot
            -- "rotasi" berganti -- jadi yang dicentang belum tentu ada hari ini.
            --
            -- TERUKUR: GaibBuy:InvokeServer(id) -> {ok, reason}
            --   ("RamuanHoki")   -> ok=false, "Terlalu jauh dari Pria Misterius"
            --   ("__tidak_ada__")-> ok=false, "Sabar dulu..."   (kena jeda)
            -- Penolakan pertama itu justru bukti id-nya SAH: yang ditolak
            -- jaraknya, bukan barangnya. Karena itu harus didekati dulu.
            local adaGaib = false
            for _, v in pairs(Config.Gaib) do if v then adaGaib = true break end end

            if adaGaib then
                local okG, qg = pcall(function() return Remotes.GaibShopPoll:InvokeServer() end)
                if okG and type(qg) == "table" then
                    local stok = {}
                    for _, v in pairs(qg) do
                        if type(v) == "table" then
                            for _, it in pairs(v) do
                                if type(it) == "table" and it.Id then stok[it.Id] = it end
                            end
                        end
                    end

                    local mau = {}
                    for id, nyala in pairs(Config.Gaib) do
                        local it = nyala and stok[id]
                        if it and (tonumber(it.Left) or 0) > 0 then mau[#mau + 1] = it end
                    end

                    if #mau == 0 then
                        laporToko("Toko gaib: tidak ada pilihanmu di rotasi sekarang")
                    else
                        -- Didekati dulu, kalau tidak SEMUA pembelian ditolak
                        -- dengan "Terlalu jauh dari Pria Misterius".
                        local npc = cariPriaMisterius()
                        if not npc then
                            laporToko("Toko gaib: Pria Misterius belum termuat")
                        else
                            pergiKe(npc)
                            for _, it in ipairs(mau) do
                                if not Status.toko then return end
                                local ok2, res = pcall(function()
                                    return Remotes.GaibBuy:InvokeServer(it.Id)
                                end)
                                if ok2 and type(res) == "table" and res.ok then
                                    Status.dibeli = Status.dibeli + 1
                                    laporToko("Gaib: beli " .. tostring(it.Display))
                                else
                                    laporToko("Gaib " .. tostring(it.Display) .. ": "
                                        .. tostring(type(res) == "table" and res.reason or res))
                                end
                                task.wait(Config.JedaBeli)
                            end
                            dibeli = dibeli + #mau
                        end
                    end
                end
            end

            if dibeli == 0 then
                laporToko(alasan or "Tidak ada barang dipilih")
                task.wait(Config.JedaTokoIdle)
            end
        end)
        lepasGiliran("toko")
        if not ok then laporToko("Error: " .. tostring(err)) end
        task.wait(2)
    end
end

-- =========================================================
-- GUI
-- =========================================================
-- Palet diambil dari :root index.html, bukan dikira-kira.
local WEB = {
    bg       = Color3.fromRGB(2, 6, 23),      -- --bg-color   #020617
    surface  = Color3.fromRGB(30, 41, 59),    -- --surface-1
    primary  = Color3.fromRGB(239, 68, 68),   -- --primary    #ef4444
    accent   = Color3.fromRGB(249, 115, 22),  -- --accent     #f97316
    teks     = Color3.fromRGB(248, 250, 252), -- --text-main
    redup    = Color3.fromRGB(148, 163, 184), -- --text-muted
    sukses   = Color3.fromRGB(16, 185, 129),  -- --success
}

local Window = Fluent:CreateWindow({
    Title = "Moze Hub — Pasar Setan",
    SubTitle = "by Moze",
    TabWidth = 150,
    Size = UDim2.fromOffset(580, 460),
    -- Acrylic = false. Inilah sumber blur yang kamu keluhkan -- bukan bawaan
    -- Fluent, tapi karena versi sebelumnya menyalakannya. Terukur: Fluent.Acrylic
    -- dan Fluent.UseAcrylic default-nya sudah false.
    Acrylic = false,
    Theme = "Darker",   -- paling dekat dengan latar hampir-hitam webmu
    MinimizeKey = Enum.KeyCode.LeftControl,
})

pcall(function() Fluent:ToggleAcrylic(false) end)

-- Warna aksen bawaan tema Darker, terukur dari GUI-nya: RGB(72,138,182).
local AKSEN_FLUENT = Color3.fromRGB(72, 138, 182)

local function miripWarna(a, b)
    return math.abs(a.R - b.R) < 0.04
       and math.abs(a.G - b.G) < 0.04
       and math.abs(a.B - b.B) < 0.04
end

-- Menyapu GUI dan mengganti aksen Fluent dengan merah webmu.
--
-- Diulang berkala, bukan sekali. Terukur: dari 3 elemen yang diwarnai, 2
-- bertahan setelah minimize-maximize dan 1 dipulihkan library ke warna aslinya.
-- Fluent menulis ulang warna saat elemen berubah keadaan, jadi sapuan sekali
-- akan luntur sebagian tanpa ada yang tahu kenapa.
local function terapkanTemaWeb()
    local gui = Fluent.GUI
    if not gui then return 0 end
    local n = 0
    for _, d in ipairs(gui:GetDescendants()) do
        if d:IsA("GuiObject") and miripWarna(d.BackgroundColor3, AKSEN_FLUENT) then
            d.BackgroundColor3 = WEB.primary; n = n + 1
        elseif d:IsA("UIStroke") and miripWarna(d.Color, AKSEN_FLUENT) then
            d.Color = WEB.primary; n = n + 1
        elseif (d:IsA("TextLabel") or d:IsA("TextButton")) and miripWarna(d.TextColor3, AKSEN_FLUENT) then
            d.TextColor3 = WEB.primary; n = n + 1
        elseif d:IsA("ImageLabel") and miripWarna(d.ImageColor3, AKSEN_FLUENT) then
            d.ImageColor3 = WEB.primary; n = n + 1
        end
    end
    return n
end

local Tabs = {
    Kumpul = Window:AddTab({ Title = "Kumpul Bahan", Icon = "leaf" }),
    Masak  = Window:AddTab({ Title = "Masak",        Icon = "flame" }),
    Toko   = Window:AddTab({ Title = "Toko",         Icon = "shopping-cart" }),
    Kebun  = Window:AddTab({ Title = "Kebun",        Icon = "sprout" }),
    Info   = Window:AddTab({ Title = "Info",         Icon = "info" }),
}

-- ---------- Tab Kumpul ----------
Tabs.Kumpul:AddParagraph({
    Title = "Cara kerjanya",
    Content = "Memindai workspace.SpawnBahan, terbang ke bahan terdekat, lalu menekan "
           .. "prompt \"Ambil\". Jarak prompt 6 stud dan hold 0,5 detik — keduanya "
           .. "angka milik server, bukan setelan script.",
})

for _, id in ipairs(URUT_BAHAN) do
    Tabs.Kumpul:AddToggle("bahan_" .. id, {
        Title = NAMA_BAHAN[id],
        Default = Config.Bahan[id] or false,
    }):OnChanged(function(v)
        Config.Bahan[id] = v
    end)
end

Tabs.Kumpul:AddToggle("Noclip", {
    Title = "Noclip saat terbang",
    Description = "Mematikan tabrakan karakter selama terbang. Dengan ini rutenya "
               .. "garis lurus dan rendah — tidak perlu memanjat 25 stud melewati atap.",
    Default = Config.Noclip,
}):OnChanged(function(v) Config.Noclip = v end)

Tabs.Kumpul:AddSlider("Kecepatan", {
    Title = "Kecepatan terbang (stud/detik)",
    Default = Config.Kecepatan, Min = 40, Max = 300, Rounding = 0,
}):OnChanged(function(v) Config.Kecepatan = v end)

Tabs.Kumpul:AddToggle("ModePasif", {
    Title = "Mode pasif — kamu yang jalan",
    Description = "Script tidak memindahkan karakter sama sekali. Kamu main biasa, "
               .. "ia menyapu bahan yang masuk jangkauan. Matikan kalau mau script "
               .. "yang mencari sendiri.",
    Default = Config.ModePasif,
}):OnChanged(function(v) Config.ModePasif = v end)

Tabs.Kumpul:AddToggle("ModeJalan", {
    Title = "Mode jalan (bukan terbang)",
    Description = "Berjalan seperti pemain biasa dan menyapu bahan yang terlewati "
               .. "sepanjang jalan. Matikan kalau mau terbang seperti sebelumnya.",
    Default = Config.ModeJalan,
}):OnChanged(function(v) Config.ModeJalan = v end)

Tabs.Kumpul:AddSlider("JangkauSapu", {
    Title = "Jangkauan sapu (stud)",
    Description = "Batas asli server 6 stud. Apakah menaikkannya berhasil BELUM "
               .. "terbukti — uji jarak jauhku tidak sah karena kendali jarak "
               .. "dekatnya ikut gagal saat itu. Naikkan bertahap dan lihat "
               .. "sendiri hasilnya.",
    Default = Config.JangkauSapu, Min = 6, Max = 40, Rounding = 0,
}):OnChanged(function(v) Config.JangkauSapu = v end)

Tabs.Kumpul:AddSlider("JedaAmbil", {
    Title = "Jeda antar ambil (detik)",
    Description = "Terlalu cepat membuat pungutan tidak terhitung server.",
    Default = Config.JedaAmbil, Min = 0.3, Max = 3, Rounding = 1,
}):OnChanged(function(v) Config.JedaAmbil = v end)

Tabs.Kumpul:AddSlider("RadiusCari", {
    Title = "Radius cari (stud)",
    Description = "Terukur: seluruh 81 titik spawn ada dalam 800 stud.",
    Default = Config.RadiusCari, Min = 100, Max = 1200, Rounding = 0,
}):OnChanged(function(v) Config.RadiusCari = v end)

Tabs.Kumpul:AddToggle("AutoKumpul", { Title = "Auto Kumpul Bahan", Default = Config.Fitur.kumpul })
    :OnChanged(function(v)
        Status.kumpul = v
        Config.Fitur.kumpul = v
        if v then
            Status.mulai = os.time()
            if siapUI then task.spawn(loopKumpul) end
            Fluent:Notify({ Title = "Kumpul jalan", Content = "Memindai bahan…", Duration = 3 })
        else
            lapor("Dihentikan")
        end
    end)

-- ---------- Tab yang belum siap ----------
-- Ditulis apa adanya, bukan dibiarkan kosong atau diisi tombol yang tidak
-- melakukan apa-apa. Tombol yang terlihat bekerja padahal tidak itu jauh lebih
-- membingungkan daripada tab yang jujur mengaku belum siap.
local BELUM = "Belum aktif.\n\nMekanismenya sudah terpetakan, tapi bentuk argumen "
           .. "remote-nya belum diukur — dan menembaknya dengan tebakan berarti "
           .. "fitur yang gagal diam-diam. Pencatat sudah terpasang di klien; "
           .. "begitu kamu melakukan aksinya sekali secara manual, argumennya "
           .. "terekam dan tab ini diisi."

Tabs.Masak:AddParagraph({
    Title = "Cara kerjanya",
    Content = "Antrean dibaca lewat CookQueuePoll, slot kosong diisi CookStove. "
           .. "Balasannya {ok, reason} dan SELALU diperiksa — server menolak dengan "
           .. "alasan yang jelas, dan alasan itu ditampilkan apa adanya, bukan "
           .. "ditelan lalu diulang terus.",
})

for _, m in ipairs(MENU) do
    Tabs.Masak:AddToggle("menu_" .. m.id, {
        Title = m.label .. "  (" .. m.bahan .. ", " .. m.waktu .. "s)",
        Default = Config.Menu[m.id] or false,
    }):OnChanged(function(v) Config.Menu[m.id] = v end)
end

Tabs.Masak:AddToggle("AutoMasak", { Title = "Auto Masak", Default = Config.Fitur.masak })
    :OnChanged(function(v)
        Status.masak = v
        Config.Fitur.masak = v
        if v then if siapUI then task.spawn(loopMasak) end else laporMasak("Dihentikan") end
    end)

Tabs.Masak:AddToggle("AutoPotong", {
    Title = "Auto Potong Gagak",
    Description = "Menekan prompt Pemotongan di kios sendiri. Gagak → DagingGagak.",
    Default = Config.Fitur.potong,
}):OnChanged(function(v)
    Status.potong = v
    Config.Fitur.potong = v
    if v then if siapUI then task.spawn(loopPotong) end else laporMasak("Potong dihentikan") end
end)

Tabs.Masak:AddSlider("JedaMasak", {
    Title = "Jeda antar perintah masak (detik)",
    Description = "Server membalas \"Sabar dulu...\" kalau terlalu rapat.",
    Default = Config.JedaMasak, Min = 1, Max = 10, Rounding = 1,
}):OnChanged(function(v) Config.JedaMasak = v end)

local ParaMasak = Tabs.Masak:AddParagraph({ Title = "Antrean", Content = "…" })
task.spawn(function()
    while true do
        if Status.masak or Status.potong then
            local q = pollAntrean()
            if q then
                local baris = {}
                for i = 1, (q.maxQueue or 3) do
                    local s = q.slots and q.slots[i]
                    baris[#baris + 1] = s and string.format("%d. %s — %ds lagi", i,
                        tostring(s.display), math.max(0, math.floor(s.remaining or 0)))
                        or (i .. ". kosong")
                end
                ParaMasak:SetDesc(table.concat(baris, "\n") .. "\n\n" .. Status.masakInfo)
            else
                ParaMasak:SetDesc("Gagal membaca antrean.\n\n" .. Status.masakInfo)
            end
        end
        task.wait(2)
    end
end)

Tabs.Toko:AddParagraph({
    Title = "Cara kerjanya",
    Content = "Kuota dan stok diperiksa DULU lewat ShopPoll, baru membeli. Jatah "
           .. "kiriman habis bukan kesalahan — itu tinggal menunggu restock, dan "
           .. "menembak terus hanya memancing penolakan yang menutupi alasan asli.",
})

for _, b in ipairs(BARANG) do
    Tabs.Toko:AddToggle("beli_" .. b.id, {
        Title = string.format("%s — %d %s", b.label, b.harga, b.mata),
        Default = Config.Beli[b.id] or false,
    }):OnChanged(function(v) Config.Beli[b.id] = v end)
end

Tabs.Toko:AddParagraph({
    Title = "Toko Gaib — Pria Misterius",
    Content = "Toko TERPISAH dari yang di atas, dan itu sebabnya Ramuan Hoki "
           .. "tidak pernah muncul di daftar sebelumnya — ia memang tidak ada di "
           .. "ShopPoll sama sekali.\n\nStoknya berputar: dua slot tetap, dua slot "
           .. "berganti. Yang kamu centang tapi tidak ada di rotasi hari ini akan "
           .. "dilewati, bukan dipaksa beli.\n\nTerukur: pembelian ditolak dengan "
           .. "\"Terlalu jauh dari Pria Misterius\" kalau berdiri jauh, jadi script "
           .. "mendekatinya dulu. Semuanya dibayar Coin.",
})

for _, g in ipairs(URUT_GAIB) do
    Tabs.Toko:AddToggle("gaib_" .. g.id, {
        Title = g.label,
        Description = g.efek,
        Default = Config.Gaib[g.id] or false,
    }):OnChanged(function(v) Config.Gaib[g.id] = v end)
end

Tabs.Toko:AddToggle("AutoBeli", { Title = "Auto Beli", Default = Config.Fitur.toko })
    :OnChanged(function(v)
        Status.toko = v
        Config.Fitur.toko = v
        if v then if siapUI then task.spawn(loopToko) end else laporToko("Dihentikan") end
    end)

Tabs.Toko:AddSlider("JedaBeli", {
    Title = "Jeda antar pembelian (detik)",
    Default = Config.JedaBeli, Min = 0.5, Max = 5, Rounding = 1,
}):OnChanged(function(v) Config.JedaBeli = v end)

local ParaToko = Tabs.Toko:AddParagraph({ Title = "Stok & kuota", Content = "…" })
task.spawn(function()
    while true do
        if Status.toko then
            local q = pollToko()
            if q then
                local baris = { string.format("Koin %s · Shard %d · restock %ds",
                    tostring(q.coins), saldoShard(), math.floor(q.restockIn or 0)) }
                for _, b in ipairs(BARANG) do
                    if Config.Beli[b.id] then
                        local kt = (q.quota or {})[b.id]
                        baris[#baris + 1] = string.format("%s: stok %s%s", b.label,
                            tostring((q.stock or {})[b.id] or "-"),
                            kt and string.format(" · sisa kiriman %s/%s · hari %s/%s",
                                tostring(kt.SisaKiriman), tostring(kt.BatasKiriman),
                                tostring(kt.SisaHari), tostring(kt.BatasHari)) or "")
                    end
                end
                baris[#baris + 1] = Status.tokoInfo
                ParaToko:SetDesc(table.concat(baris, "\n"))
            else
                ParaToko:SetDesc("Toko tidak terbaca.\n" .. Status.tokoInfo)
            end
        end
        task.wait(3)
    end
end)

Tabs.Kebun:AddParagraph({
    Title = "Cara kerjanya",
    Content = "Lahanmu dikenali dari atribut Owner, bukan dari yang terdekat — ada 24 "
           .. "lahan dan tetangga bisa berdiri lebih dekat. Panen hanya menyentuh "
           .. "tanaman ber-Ready=true milikmu sendiri.",
})

Tabs.Kebun:AddToggle("AutoPanen", { Title = "Auto Panen", Default = Config.Fitur.panen })
    :OnChanged(function(v)
        Status.panen = v
        Config.Fitur.panen = v
        if v then if siapUI then task.spawn(loopPanen) end else laporKebun("Panen dihentikan") end
    end)

Tabs.Kebun:AddToggle("AutoTanam", {
    Title = "Auto Tanam",
    Description = "Butuh bibit di tas. Bibit dibeli di toko.",
    Default = Config.Fitur.tanam,
}):OnChanged(function(v)
    Status.tanam = v
    Config.Fitur.tanam = v
    if v then if siapUI then task.spawn(loopTanam) end else laporKebun("Tanam dihentikan") end
end)

Tabs.Kebun:AddToggle("AutoSiram", {
    Title = "Auto Siram",
    Description = "Menyiram saat ada tanaman dengan Wet=false.",
    Default = Config.Fitur.siram,
}):OnChanged(function(v)
    Status.siram = v
    Config.Fitur.siram = v
    if v then if siapUI then task.spawn(loopSiram) end else laporKebun("Siram dihentikan") end
end)

Tabs.Kebun:AddSlider("JarakTanam", {
    Title = "Jarak antar tanaman (stud)",
    Description = "Terukur ~4-5 stud dari posisi tanam yang terekam.",
    Default = Config.JarakTanam, Min = 3, Max = 10, Rounding = 0,
}):OnChanged(function(v) Config.JarakTanam = v end)

local ParaKebun = Tabs.Kebun:AddParagraph({ Title = "Kebun", Content = "…" })
task.spawn(function()
    while true do
        local lahan = lahanSaya()
        if lahan then
            local semua = tanamanku(lahan)
            local siap, kering = 0, 0
            for _, t in ipairs(semua) do
                if t:GetAttribute("Ready") == true then siap = siap + 1 end
                if t:GetAttribute("Wet") ~= true then kering = kering + 1 end
            end
            ParaKebun:SetDesc(string.format(
                "Lahan %s · %d tanaman\nSiap panen: %d · Kering: %d\nDitanam %d · Dipanen %d\n%s",
                lahan.Name, #semua, siap, kering, Status.ditanam, Status.dipanen, Status.kebunInfo))
        else
            ParaKebun:SetDesc("Lahanmu belum termuat.\nDekati kebunmu — game ini memakai streaming.")
        end
        task.wait(2)
    end
end)

-- ---------- Tab Info ----------
-- Urutan yang disarankan, dan alasannya. Bukan penjadwal otomatis -- yang
-- memutuskan tetap kamu; ini memberi tahu apa yang saling menghalangi.
--
-- Dasarnya pengukuran, bukan selera:
--   * mengumpul di "pasar", berkebun di "lahan", 6.750 stud berlawanan
--   * alat masak ada di dalam kios sendiri, dan kios ada di area pasar
--   * membeli TIDAK butuh jarak sama sekali -- ShopBuy dari 110 stud dan NPC
--     tokonya belum termuat pun ditolaknya karena saldo, bukan jarak
local FITUR = {
    { fitur = "kumpul", nama = "Kumpul", zona = "pasar", alasan = "pungut bahan di area pasar" },
    { fitur = "tanam",  nama = "Tanam",  zona = "lahan", alasan = "butuh bibit dari toko" },
    { fitur = "masak",  nama = "Masak",  zona = "pasar", alasan = "butuh lapak; antreannya jalan sendiri" },
    { fitur = "panen",  nama = "Panen",  zona = "lahan", alasan = "hanya yang Ready=true" },
    { fitur = "potong", nama = "Potong", zona = "pasar", alasan = "di kios yang sama dengan masak" },
    { fitur = "siram",  nama = "Siram",  zona = "lahan", alasan = "harus menghadap tanamannya" },
    { fitur = "toko",   nama = "Toko",   zona = "-",     alasan = "lewat remote, tidak perlu pindah" },
}

Tabs.Info:AddParagraph({
    Title = "Prioritas — makin tinggi makin duluan",
    Content = "Tujuh fitur berebut satu karakter. Yang angkanya paling tinggi "
        .. "dapat giliran duluan; sisanya menunggu sampai satuan kerjanya "
        .. "selesai — satu pungutan, satu tanam, satu panen — lalu giliran "
        .. "dinilai ulang.\n\nAngka sama berarti bergantian menurut siapa yang "
        .. "minta duluan. Kalau mau urutannya pasti, beri angka yang berbeda.",
})

for _, p in ipairs(FITUR) do
    Tabs.Info:AddSlider("prio_" .. p.fitur, {
        Title = p.nama,
        Description = p.zona == "-" and p.alasan or ("[" .. p.zona .. "] " .. p.alasan),
        Default = Config.Prioritas[p.fitur], Min = 0, Max = 10, Rounding = 0,
    }):OnChanged(function(v) Config.Prioritas[p.fitur] = v end)
end

local ParaPrioritas = Tabs.Info:AddParagraph({ Title = "Urutan & bentrok", Content = "…" })

-- Dideklarasikan di sini walau baru diisi di bawah: pemantau di bawah ini
-- menyentuhnya tiap 2 detik, dan tanpa deklarasi ia jadi global yang tidak
-- terlihat pemeriksa urutan.
local ParaConfig
task.spawn(function()
    while true do
        local baris, aktifZona = {}, {}
        for _, z in ipairs(zonaAktif()) do aktifZona[#aktifZona + 1] = z end
        local bentrok = #aktifZona > 1

        -- Diurutkan menurut ANGKA, bukan urutan tetap seperti sebelumnya.
        -- Yang seri diurut menurut nama supaya daftarnya tidak berkedip-kedip
        -- tiap 2 detik hanya karena pairs() mengembalikan urutan berbeda.
        local urut = {}
        for _, p in ipairs(FITUR) do urut[#urut + 1] = p end
        table.sort(urut, function(a, b)
            local pa, pb = prioritas(a.fitur), prioritas(b.fitur)
            if pa ~= pb then return pa > pb end
            return a.nama < b.nama
        end)

        for i, p in ipairs(urut) do
            local nyala = Status[p.fitur] == true
            local catatan = p.alasan
            if pemegang == p.fitur then
                catatan = "SEDANG JALAN"
            elseif nyala and antreGiliran[p.fitur] then
                catatan = "menunggu giliran"
            elseif nyala and bentrok and p.zona ~= "-" then
                catatan = "BENTROK — zona aktif: " .. table.concat(aktifZona, " + ")
            end
            baris[#baris + 1] = string.format("%s %d. %s [%s] · %s — %s",
                nyala and "●" or "○", i, p.nama, tostring(prioritas(p.fitur)), p.zona, catatan)
        end

        if bentrok then
            table.insert(baris, 1, "⚠ Dua zona aktif sekaligus. Teleport ditahan supaya "
                .. "keduanya tidak saling melempar; matikan salah satu.")
        end
        table.insert(baris, "")
        table.insert(baris, string.format("Lahan: %s · Lapak: %s · BUILD %s",
            punyaLahan() and "punya" or "BELUM", punyaKios() and "punya" or "BELUM", BUILD))
        table.insert(baris, "Config: " .. BERKAS_CONFIG .. " — " .. tostring(statusSimpan))
        if ParaConfig then
            ParaConfig:SetDesc(string.format(
                "Berkas: %s\nKeadaan: %s\nPenyimpan berkas: %s",
                BERKAS_CONFIG, tostring(statusSimpan),
                bisaBerkas() and "tersedia" or "TIDAK ADA — executor ini tanpa writefile"))
        end

        ParaPrioritas:SetDesc(table.concat(baris, "\n"))
        task.wait(2)
    end
end)

-- =========================================================
-- CONFIG — simpan & reset
-- =========================================================
ParaConfig = Tabs.Info:AddParagraph({ Title = "Config", Content = "…" })

Tabs.Info:AddToggle("MulaiOtomatis", {
    Title = "Mulai otomatis saat dijalankan",
    Description = "Fitur yang tersimpan menyala langsung berjalan begitu script "
               .. "dieksekusi. Matikan kalau kamu ingin menekannya sendiri dulu.",
    Default = Config.MulaiOtomatis,
}):OnChanged(function(v) Config.MulaiOtomatis = v end)

Tabs.Info:AddButton({
    Title = "Simpan Config",
    Description = "Tulis setelan sekarang juga ke " .. BERKAS_CONFIG,
    Callback = function()
        local ok, pesan = simpanConfig()
        statusSimpan = ok and ("tersimpan " .. os.date("%H:%M:%S")) or pesan
        Fluent:Notify({
            Title = ok and "Config tersimpan" or "Gagal menyimpan",
            Content = ok and BERKAS_CONFIG or tostring(pesan),
            Duration = 5,
        })
    end,
})

Tabs.Info:AddButton({
    Title = "Reset Config",
    Description = "Kembalikan SEMUA setelan ke bawaan, lalu simpan",
    Callback = function()
        -- Fitur yang sedang jalan dimatikan dulu. Menukar setelan di bawah kaki
        -- loop yang sedang bekerja -- radius, jarak, daftar bahan -- membuatnya
        -- memakai campuran nilai lama dan baru di tengah satu putaran.
        for _, f in ipairs({ "kumpul", "masak", "potong", "panen", "tanam", "siram", "toko" }) do
            Status[f] = false
        end

        -- Isi tabel yang SAMA, bukan menukar tabelnya. Seluruh script memegang
        -- rujukan ke tabel Config ini; menggantinya dengan tabel baru membuat
        -- semua pemegang lama menunjuk ke setelan yang sudah tidak dipakai.
        for k in pairs(Config) do Config[k] = nil end
        for k, v in pairs(salinDalam(BAWAAN)) do Config[k] = v end

        local ok, pesan = simpanConfig()
        statusSimpan = ok and ("direset " .. os.date("%H:%M:%S")) or pesan
        Fluent:Notify({
            Title = "Config direset",
            Content = "Semua setelan kembali ke bawaan dan semua fitur dimatikan. "
                   .. "Tampilan slider baru ikut setelah script dijalankan ulang.",
            Duration = 7,
        })
    end,
})

local ParaStatus = Tabs.Info:AddParagraph({ Title = "Status", Content = "…" })

-- Teleport bawaan game menggantikan penerbangan jarak jauh.
--
-- Versi sebelumnya terbang 6.700 stud dicicil per 400 stud sambil memaksa
-- streaming tiap potong. Itu bekerja, tapi tidak ada gunanya melakukan sendiri
-- apa yang sudah disediakan game -- dan tiap ruas yang ditempuh manual menambah
-- satu peluang jatuh menembus dunia.
local function tombolTeleport(judul, kandidat, label)
    Tabs.Info:AddButton({
        Title = judul,
        Description = "Memakai teleport bawaan game (TeleportGoto).",
        Callback = function()
            task.spawn(function()
                local ok, sebab = teleportKe(kandidat, label)
                Fluent:Notify({
                    Title = ok and ("Sampai di " .. label) or "Teleport gagal",
                    Content = ok and "Tunggu sebentar sampai area termuat."
                                 or ("Ditolak: " .. tostring(sebab)),
                    Duration = 6,
                })
            end)
        end,
    })
end

tombolTeleport("Teleport ke pasar", Config.TujuanPasar, "pasar")
tombolTeleport("Teleport ke lahan", Config.TujuanLahan, "lahan")
tombolTeleport("Teleport ke desa",  Config.TujuanDesa,  "desa")

Tabs.Info:AddButton({
    Title = "Cek tujuan teleport yang tersedia",
    Description = "Membaca TeleportInfo — tidak memindahkan apa pun",
    Callback = function()
        local info = infoTeleport()
        if not info then
            Fluent:Notify({ Title = "Gagal", Content = "TeleportInfo tidak terbaca", Duration = 5 })
            return
        end
        local f = {}
        for k, v in pairs(info) do
            if type(v) ~= "table" and typeof(v) ~= "Vector3" then
                f[#f + 1] = tostring(k) .. "=" .. tostring(v)
            end
        end
        table.sort(f)
        Fluent:Notify({ Title = "TeleportInfo", Content = table.concat(f, "  "), Duration = 10 })
    end,
})

Tabs.Info:AddButton({
    Title = "Hitung ulang bahan di peta",
    Description = "Memindai SpawnBahan dan melaporkan sebarannya",
    Callback = function()
        local per, total = {}, 0
        local folder = workspace:FindFirstChild("SpawnBahan")
        for _, p in ipairs(folder and folder:GetChildren() or {}) do
            local id = p:GetAttribute("ItemId")
            if id then per[id] = (per[id] or 0) + 1; total = total + 1 end
        end
        local baris = {}
        for _, id in ipairs(URUT_BAHAN) do
            baris[#baris + 1] = id .. "=" .. (per[id] or 0)
        end
        Fluent:Notify({
            Title = total .. " bahan di peta",
            Content = table.concat(baris, "  "),
            Duration = 8,
        })
    end,
})

task.spawn(function()
    while true do
        local lv = levelSekarang()
        local ls = LocalPlayer:FindFirstChild("leaderstats")
        local koin = ls and ls:FindFirstChild("Koin")
        local lama = os.time() - Status.mulai
        ParaStatus:SetDesc(string.format(
            "Lv %d · Koin %s\nDipungut sesi ini: %d\nJalan: %02d:%02d\nTerakhir: %s",
            lv, koin and tostring(koin.Value) or "?", Status.dipungut,
            math.floor(lama / 60), lama % 60, Status.terakhir))
        task.wait(1)
    end
end)

Window:SelectTab(1)

-- =========================================================
-- LOGO SAAT MINIMIZE
-- =========================================================
-- Fluent hanya MENYEMBUNYIKAN jendelanya saat minimize -- terukur:
-- Window.Minimized jadi true dan Window.Root.Visible jadi false, tanpa
-- meninggalkan apa pun di layar. Di HP itu berarti tidak ada jalan kembali
-- selain menekan tombol keyboard yang tidak ada.
--
-- Polanya menyusul script.txt: ImageButton yang bisa digeser, dan menekannya
-- memunculkan jendela lagi.
local LogoGui = Instance.new("ScreenGui")
LogoGui.Name = "MozeMinimizedLogo"
LogoGui.ResetOnSpawn = false
LogoGui.IgnoreGuiInset = true
LogoGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
LogoGui.DisplayOrder = 10000
pcall(function()
    LogoGui.Parent = game:GetService("CoreGui")
end)
if not LogoGui.Parent then
    LogoGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

local Logo = Instance.new("ImageButton")
Logo.Name = "Logo"
Logo.Size = UDim2.new(0, 62, 0, 62)
Logo.Position = UDim2.new(0, 24, 0.5, -31)
Logo.Image = "rbxassetid://104624206636533"
Logo.BackgroundColor3 = WEB.surface
Logo.BackgroundTransparency = 0.1
Logo.BorderSizePixel = 0
Logo.AutoButtonColor = false
Logo.Visible = false
Logo.ZIndex = 10005
Logo.Parent = LogoGui

local sudut = Instance.new("UICorner")
sudut.CornerRadius = UDim.new(0, 14)
sudut.Parent = Logo

local garis = Instance.new("UIStroke")
garis.Color = WEB.primary
garis.Thickness = 1.5
garis.Transparency = 0.35
garis.Parent = Logo

-- Memunculkan jendela lagi, lalu MEMERIKSA bahwa ia benar-benar muncul.
--
-- Versi sebelumnya cuma `pcall(function() Window:Maximize() end)`. Kalau
-- Maximize gagal atau tidak ada, pcall menelan kegagalannya diam-diam dan
-- logonya jadi tombol yang tidak melakukan apa pun -- terkunci di layar
-- minimize tanpa jalan kembali. Itu keluhan "tombol UI tidak bisa diklik
-- setelah minimize".
--
-- Sekarang tiga jalan dicoba berurutan, dan hasilnya diperiksa: kalau jendela
-- masih tersembunyi, akarnya dipaksa terlihat sendiri.
local function munculkanJendela()
    pcall(function() Window:Maximize() end)
    task.wait(0.06)

    local akar = rawget(Window, "Root") or Window.Root
    local masihSembunyi = (Window.Minimized == true)
        or (typeof(akar) == "Instance" and akar:IsA("GuiObject") and akar.Visible == false)

    if masihSembunyi then
        pcall(function() Window.Minimized = false end)
        pcall(function() akar.Visible = true end)
    end

    -- Apa pun jalannya, logonya harus hilang begitu jendelanya kembali.
    if not masihSembunyi or Window.Minimized ~= true then
        Logo.Visible = false
    end
    pcall(terapkanTemaWeb)
end

-- Geser + klik, mengikuti pola script.txt.
--
-- Bedanya dengan versi sebelumnya: pelepasan dipantau lewat UserInputService,
-- bukan MouseButton1Click. Di HP, sentuhan yang bergeser satu-dua piksel sering
-- tidak menghasilkan MouseButton1Click sama sekali -- logonya ditekan, tidak
-- terjadi apa-apa, dan itu terasa persis seperti tombol rusak.
do
    local UIS = game:GetService("UserInputService")
    local menggeser, bergerak, awalInput, awalPos = false, false, nil, nil

    Logo.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            menggeser, bergerak = true, false
            awalInput, awalPos = input.Position, Logo.Position
        end
    end)

    UIS.InputChanged:Connect(function(input)
        if menggeser and (input.UserInputType == Enum.UserInputType.MouseMovement
                          or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - awalInput
            -- Ambang 6 piksel: di bawah itu dianggap tangan yang bergetar saat
            -- menekan, bukan niat menggeser.
            if d.Magnitude > 6 then bergerak = true end
            if bergerak then
                Logo.Position = UDim2.new(awalPos.X.Scale, awalPos.X.Offset + d.X,
                                          awalPos.Y.Scale, awalPos.Y.Offset + d.Y)
            end
        end
    end)

    UIS.InputEnded:Connect(function(input)
        if not menggeser then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            menggeser = false
            if not bergerak then task.spawn(munculkanJendela) end
        end
    end)
end

-- Keadaan minimize diikuti dengan MEMANTAU, bukan dengan menimpa Window:Minimize.
--
-- Tombol pintas (LeftControl) ditangani di dalam Fluent sendiri, jadi menimpa
-- metodenya hanya menangkap sebagian jalan -- yang lewat tombol keyboard akan
-- terlewat, dan logonya tidak muncul persis saat paling dibutuhkan.
task.spawn(function()
    local sebelumnya = nil
    while LogoGui.Parent do
        local kini = Window.Minimized == true
        if kini ~= sebelumnya then
            sebelumnya = kini
            Logo.Visible = kini
            if not kini then terapkanTemaWeb() end
        end
        task.wait(0.3)
    end
end)

-- Sapuan tema diulang: Fluent menulis ulang warna aksen saat elemen berubah
-- keadaan, jadi sapuan sekali akan luntur sebagian.
task.spawn(function()
    while true do
        pcall(terapkanTemaWeb)
        task.wait(2)
    end
end)

-- =========================================================
-- PEMULIHAN SAKLAR TERSIMPAN
-- =========================================================
--
-- Dijalankan PALING AKHIR, sesudah seluruh tab dan seluruh loop terdefinisi.
-- Sebelum titik ini `siapUI` masih false, jadi tidak ada satu pun fitur yang
-- sempat berjalan setengah jalan saat UI masih dibangun.
siapUI = true

do
    local LOOP = {
        kumpul = loopKumpul, masak = loopMasak, potong = loopPotong,
        panen = loopPanen, tanam = loopTanam, siram = loopSiram, toko = loopToko,
    }
    local hidup = {}

    if Config.MulaiOtomatis then
        for _, f in ipairs({ "kumpul", "masak", "potong", "panen", "tanam", "siram", "toko" }) do
            if Config.Fitur[f] and LOOP[f] then
                Status[f] = true
                task.spawn(LOOP[f])
                hidup[#hidup + 1] = f
            end
        end
        if #hidup > 0 then Status.mulai = os.time() end
    else
        -- Saklarnya tetap tersimpan dan tetap terlihat menyala di UI; yang
        -- ditahan hanya jalannya. Status disamakan supaya panel tidak
        -- menampilkan fitur "hidup" yang sebenarnya tidak berjalan.
        for f in pairs(Config.Fitur) do Status[f] = false end
    end

    Fluent:Notify({
        Title = "Moze Hub — Pasar Setan",
        Content = #hidup > 0
            and ("Dilanjutkan dari config: " .. table.concat(hidup, ", "))
            or (Config.MulaiOtomatis
                and "Siap. Tidak ada fitur tersimpan dalam keadaan menyala."
                or "Siap. Mulai otomatis dimatikan — nyalakan fiturnya sendiri."),
        Duration = 6,
    })
end

-- @MOZEFRAME-EOF@

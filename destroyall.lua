local Workspace = game:GetService("Workspace")

local function destroyAllPlantsEverywhere()
    local gardens = Workspace:FindFirstChild("Gardens")
    if not gardens then
        warn("Folder 'Gardens' tidak ditemukan di Workspace!")
        return
    end

    for _, plot in pairs(gardens:GetChildren()) do
        local plantsFolder = plot:FindFirstChild("Plants")
        
        if plantsFolder then
            for _, plant in pairs(plantsFolder:GetChildren()) do
                pcall(function()
                    plant:Destroy()
                end)
            end
        end
    end
    
    print("Semua tanaman di semua garden telah dihapus (Client-Side).")
end

destroyAllPlantsEverywhere()

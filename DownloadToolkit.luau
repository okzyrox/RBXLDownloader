--/ Services
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local net = require("@lune/net")
local task = require("@lune/task")
local process = require("@lune/process")

--/ Vars
local AssetUrl = "https://assetdelivery.roblox.com/v1/asset/?id=%s"

local DebugPrints = false
local DownloadLocation = ""

--/ Func

local function dprint(...)
    if not DebugPrints then
        return
    end
    print(...)
end

local function GetFileName(Path)
    local filename, extension = Path:match("^.+/(.+)%.(.+)$")
    
    return filename
end


--/ Meshes
local function GetMeshes(Instance)
    local Meshes = {}
    for _, Object in pairs(Instance:GetChildren()) do
        if Object:IsA("MeshPart") then
            table.insert(Meshes, Object)
        elseif Object:IsA("Model") then
            for _, MeshPart in pairs(Object:GetChildren()) do
                if MeshPart:IsA("MeshPart") then
                    table.insert(Meshes, MeshPart)
                end
            end
        end
    end
    return Meshes
end

local function SaveMeshXMLs(FolderName, Tbl)
    if not fs.isDir(DownloadLocation .. "MeshXMLs") then
        fs.writeDir(DownloadLocation .. "MeshXMLs")
    end
    for _, Mesh in pairs(Tbl) do
        if not fs.isFile(DownloadLocation .. "MeshXMLs/" .. FolderName .. "/" .. Mesh.Name .. ".rbxmx") then
            dprint("Mesh " .. Mesh.Name .. " is already saved as xml")
            continue
        end
        local MeshData = roblox.serializeModel({Mesh}, true)
        fs.writeFile(DownloadLocation .. "MeshXMLs/" .. FolderName .. "/" .. Mesh.Name .. ".rbxmx", MeshData)
    end
end

local function SaveMeshModels(FolderName, Tbl)
    local CompletedDownloads = 0
    local TotalDownloads = #Tbl
    if not fs.isDir(DownloadLocation .. "RawMeshes") then
        fs.writeDir(DownloadLocation .. "RawMeshes")
    end
    for _, Mesh in pairs(Tbl) do
        --print("Getting raw mesh for " .. Mesh.Name)
        print("Downloaded: " .. CompletedDownloads .. "/" .. TotalDownloads .. " (" .. Mesh.Name .. ")")
        if not Mesh.MeshId then
            dprint("Mesh " .. Mesh.Name .. " does not have a MeshId - skipping")
            continue
        end
        if fs.isFile(DownloadLocation .. "RawMeshes/" .. FolderName .. "/" .. Mesh.Name .. ".mesh") then
            dprint("Mesh " .. Mesh.Name .. " already downloaded")
            CompletedDownloads = CompletedDownloads + 1
            continue
        end
        local AssetId = string.gsub(tostring(Mesh.MeshId), "rbxassetid://", "")
        local RawMesh = net.request({ --BinaryString
            url = string.format(AssetUrl, AssetId),
            method = "Get"
        })
        local MeshBinary = RawMesh["body"]

        fs.writeFile(DownloadLocation .. "RawMeshes/" .. FolderName .. "/" .. Mesh.Name .. ".mesh", MeshBinary)
        CompletedDownloads = CompletedDownloads + 1
        task.wait(1) -- Im assuming theres some ratelimiting
        -- so we do a 1sec delay just in case
        -- i havent gotten any even when bulk downloading all of them but still
    end
end

--/ Begin

local GamePath = ""
local ServerStorageFolderName = ""

if not (#process.args > 0) then
    print("Usage: GetMeshes.luau <path to game.rbxl> <name of ServerStorage folder to check>")
    error("No arguments provided")
elseif process.args[1] == nil then
    print("Usage: GetMeshes.luau <path to game.rbxl> <name of ServerStorage folder to check>")
    error("No path provided")
elseif process.args[2] == nil then
    print("Usage: GetMeshes.luau <path to game.rbxl> <name of ServerStorage folder to check>")
    error("No ServerStorage folder name provided")
elseif process.args[3] == nil then
    GamePath = process.args[1]
    ServerStorageFolderName = process.args[2]
else
    GamePath = process.args[1]
    ServerStorageFolderName = process.args[2]
    if process.args[3] == "true" then
        DebugPrints = true
        print("Debug prints enabled")
    else
        DebugPrints = false
    end
end

if not fs.isFile(GamePath) then
    error("Game file does not exist")
end

DownloadLocation = "Downloads/" .. GetFileName(GamePath)
print("Loading game file")
local file = fs.readFile(GamePath)
local game = roblox.deserializePlace(file)
print("Game file loaded")
task.wait(2)
local ServerStorage = game:GetService("ServerStorage")

if not fs.isDir("Downloads") then
    fs.writeDir("Downloads")
end

if not fs.isDir(DownloadLocation) then
    fs.writeDir(DownloadLocation)
end

DownloadLocation = DownloadLocation .. "/"

-- Get Anomalies
local ObjectSearchLocation = ServerStorage:FindFirstChild(ServerStorageFolderName)
if ObjectSearchLocation == nil then
    error("Object search location was not found")
end

local ObjectMeshes = {}
local MeshCount = {}
-- `Object` is a model, containing meshes
for _, Object: Instance in pairs(ObjectSearchLocation:GetChildren()) do
    ObjectMeshes[Object.Name] = {}
    MeshCount[Object.Name] = 0
    dprint("Getting meshes for " .. Object.Name)
    for _, Mesh in pairs(GetMeshes(Object)) do
        table.insert(ObjectMeshes[Object.Name], Mesh)
        MeshCount[Object.Name] = MeshCount[Object.Name] + 1
    end
    dprint("Found " .. MeshCount[Object.Name] .. " meshes for " .. Object.Name)
end

for ObjectName, ObjectMeshList in pairs(ObjectMeshes) do
    if not fs.isDir(DownloadLocation .. "MeshXMLs/" .. ObjectName) then
        fs.writeDir(DownloadLocation .. "MeshXMLs/" .. ObjectName)
    end
    if not fs.isDir(DownloadLocation .. "RawMeshes/" .. ObjectName) then
        if #ObjectMeshList == 0 then
            dprint("Anomaly " .. ObjectName .. " has no meshes")
            continue
        end
        fs.writeDir(DownloadLocation .. "RawMeshes/" .. ObjectName)
    end

    dprint("Writing meshes for " .. ObjectName)
    SaveMeshXMLs(ObjectName, ObjectMeshList)
    print("Downloading Meshes for " .. ObjectName)
    SaveMeshModels(ObjectName, ObjectMeshList)
    
end

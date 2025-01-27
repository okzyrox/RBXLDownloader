--// Author: okzyrox
--/ Date: 2025/01/27

--// Services
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local net = require("@lune/net")
local task = require("@lune/task")
local process = require("@lune/process")

--/ Vars
local AssetUrl = "https://assetdelivery.roblox.com/v1/asset/?id=%s"
local DebugPrints = false
local DownloadLocation = ""
local AssetsKinds = { Mesh = "mesh", Texture = "png", Animation = "rbxm" }
local GamePath = ""
local ServerStorageFolderName = ""
local DefaultWaitTime = 1
local OnlyDoThis = nil

--/ Functions

local function dprint(...)
	if not DebugPrints then
		return
	end
	print(...)
end

local function DownloadAsset(id)
	dprint("Asset: " .. id)
	id = tostring(id):gsub("rbxassetid://", "")
	local RawAsset = net.request({
		url = string.format(AssetUrl, id),
		method = "Get",
	})
	return RawAsset.body
end

local function SaveAsset(folder, assetSaveName, data, ext)
	if not fs.isDir(folder) then
		fs.writeDir(folder)
	end
	assetSaveName = assetSaveName:gsub("http://www.roblox.com/asset/?id=", "", 1)
    local location = folder .. "/" .. assetSaveName .. "." .. ext
    dprint("Saving asset to: " .. location .. " as " .. assetSaveName)
	if fs.isFile(location) then
		dprint("File at: " .. location ..  " already exists, skipping")
		return
	end
	fs.writeFile(location, data)
end

-- Objects

local function ExtractMeshes(instance)
	local Meshes = {}
	for _, child in pairs(instance:GetChildren()) do
		if child:IsA("MeshPart") then
			table.insert(Meshes, child)
		elseif child:IsA("Model") then
			for _, m in pairs(child:GetChildren()) do
				if m:IsA("MeshPart") then
					table.insert(Meshes, m)
				end
			end
		end
	end
	return Meshes
end

--/ Processing

local function ProcessMesh(objectName, meshObj)
	if fs.isDir(DownloadLocation .. "Meshes/" .. objectName) then
		if fs.isFile(DownloadLocation .. "Meshes/" .. objectName .. "/" .. meshObj.Name) then
			print("Mesh at: " .. DownloadLocation .. "Meshes/" .. objectName .. "/" .. meshObj.Name .. " already exists, skipping")
			return
		end
	else
		fs.writeDir(DownloadLocation .. "Meshes/" .. objectName)
	end
	local folder = DownloadLocation .. "Meshes/" .. objectName .. "/" .. meshObj.Name
	local data = DownloadAsset(meshObj.MeshId)
	SaveAsset(folder, meshObj.Name, data, AssetsKinds.Mesh)
	local meshXml = roblox.serializeModel({ meshObj }, true)
	if fs.isFile(DownloadLocation .. "MeshXMLs/" .. objectName .. "/" .. meshObj.Name .. ".rbxmx") then
		print("Mesh XML at: " .. DownloadLocation .. "MeshXMLs/" .. objectName .. "/" .. meshObj.Name .. ".rbxmx" .. " already exists, skipping")
	else
		SaveAsset(DownloadLocation .. "MeshXMLs/" .. objectName, meshObj.Name, meshXml, "rbxmx")
	end
	if meshObj.TextureID and meshObj.TextureID ~= "" then
		local tid = tostring(meshObj.TextureID):gsub("rbxassetid://", "")
		tid = tid:gsub("http://www.roblox.com/asset/", "")
		tid = tid:gsub("?id=", "")
		--print(tid)
		if fs.isFile(folder .. "/Textures/" .. tid .. ".png") then
			print("Texture at: " .. folder .. "/Textures/" .. tid .. ".png" .. " already exists, skipping")
			return
		end
		local tdata = DownloadAsset(tid)
		SaveAsset(folder .. "/Textures", tid, tdata, AssetsKinds.Texture)
		task.wait(DefaultWaitTime)
	end
end

local function ProcessAnimation(objectName, animObj)
	local animName = (animObj.Name and animObj.Name ~= "") and animObj.Name or "Animation"
	if fs.isFile(DownloadLocation .. "Animations/" .. objectName .. "/" .. animName .. ".rbxm") then
		print("Animation at: " .. DownloadLocation .. "Animations/" .. objectName .. "/" .. animName .. ".rbxm" .. " already exists, skipping")
		return
	end
	local data = DownloadAsset(animObj.AnimationId)
	SaveAsset(DownloadLocation .. "Animations/" .. objectName, animName, data, AssetsKinds.Animation)
	task.wait(DefaultWaitTime)
end

local function ProcessTexture(objectName, texObj)
	local tid = texObj.TextureId or texObj.TextureID
	if fs.isFile(DownloadLocation .. "Textures/" .. objectName .. "/" .. texObj.Name .. ".png") then
		print("Texture at: " .. DownloadLocation .. "Textures/" .. objectName .. "/" .. texObj.Name .. ".png" .. " already exists, skipping")
		return
	end
	if tid and tid ~= "" then
        tid = tostring(tid):gsub("rbxassetid://", "")
        tid = tid:gsub("http://www.roblox.com/asset/", "") -- hacky method due to how gsub works
		tid = tid:gsub("?id=", "")
		local data = DownloadAsset(tid)
		SaveAsset(DownloadLocation .. "Textures/" .. objectName, tid, data, AssetsKinds.Texture)
		task.wait(DefaultWaitTime)
	end
end

--/ Begin

if not (#process.args > 0) then
	print("------------------------------")
	print("   RBXL Downloader")
	print("   Usage: DownloadToolkit.luau <path to game.rbxl> <ServerStorage folder> [debug=bool] [waitTime=number] [only=string]")
	print("   Anything in square brackets is optional.")
	print("   Default wait time is 1 second")
	print("   'only' is used to only download a specific object by name (in the event you need to redownload it)")
	print("------------------------------")
	return
elseif process.args[1] == nil then
	print("Usage: DownloadToolkit.luau <path to game.rbxl> <ServerStorage folder> [debug=bool] [waitTime=number]")
	error("No path provided")
elseif process.args[2] == nil then
	print("Usage: DownloadToolkit.luau <path to game.rbxl> <ServerStorage folder> [debug=bool] [waitTime=number]")
	error("No ServerStorage folder name provided")
elseif process.args[3] == nil or process.args[4] == nil or process.args[5] == nil then
	GamePath = process.args[1]
	ServerStorageFolderName = process.args[2]
else
	GamePath = process.args[1]
	ServerStorageFolderName = process.args[2]
	print("Config:")
	print("------------------------------")
	if process.args[3] == "true" then
		DebugPrints = true
		print("Debug prints enabled")
	end
	if process.args[4] then
		DefaultWaitTime = tonumber(process.args[4])
		print("Default wait time set to: " .. DefaultWaitTime)
	end
	if process.args[5] then
		OnlyDoThis = process.args[5]
		print("Only downloading: " .. OnlyDoThis)
	end
	print("------------------------------")
end

if not fs.isFile(GamePath) then
	error("Game file does not exist")
end

local function GetFileName(path)
	local filename, ext = path:match("^.+/(.+)%.(.+)$")
	return filename
end

DownloadLocation = "Downloads/" .. GetFileName(GamePath)
if not fs.isDir("Downloads") then
	fs.writeDir("Downloads")
end
if not fs.isDir(DownloadLocation) then
	fs.writeDir(DownloadLocation)
end
DownloadLocation = DownloadLocation .. "/"
print("Loading Game file")
local file = fs.readFile(GamePath)
local game = roblox.deserializePlace(file)
print("Game file loaded")
print("------------------------------")
task.wait(1)

local ServerStorage = game:GetService("ServerStorage")
local ObjectSearchLocation = ServerStorage:FindFirstChild(ServerStorageFolderName)
if not ObjectSearchLocation then
	error("Object search location was not found")
end

local function SearchAssets()
	for _, Object in pairs(ObjectSearchLocation:GetChildren()) do
		if OnlyDoThis then
			if Object.Name ~= OnlyDoThis then
				continue
			end
		end
		local meshList = ExtractMeshes(Object)
		if #meshList > 0 then
			for _, meshObj in pairs(meshList) do
				ProcessMesh(Object.Name, meshObj)
			end
		end
		for _, child in pairs(Object:GetChildren()) do
			if child:IsA("Animation") and child.AnimationId then
				if fs.isFile(DownloadLocation .. "Animations/" .. Object.Name .. "/" .. child.Name .. ".rbxm") then
					print("Animation at: " .. DownloadLocation .. "Animations/" .. Object.Name .. "/" .. child.Name .. ".rbxm" .. " already exists, skipping")
					continue
				end
				ProcessAnimation(Object.Name, child)
			elseif (child:IsA("Decal") or child:IsA("Texture")) and (child.TextureId or child.TextureID) then
				if fs.isFile(DownloadLocation .. "Textures/" .. Object.Name .. "/" .. child.Name .. ".png") then
					print("Texture at: " .. DownloadLocation .. "Textures/" .. Object.Name .. "/" .. child.Name .. ".png" .. " already exists, skipping")
					continue
				end
				ProcessTexture(Object.Name, child)
			end
		end
	end
end

SearchAssets()
print("------------------------------")
print("Finished Execution")

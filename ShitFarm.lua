
-- Added Play AIlment pizza_party salon school camping bored ride and walk.
print("🔄Dehashing Remotes Please Wait")

local Fsys = require(game.ReplicatedStorage:WaitForChild("Fsys")).load

-- Get the init function from RouterClient
local initFunction = Fsys("RouterClient").init

-- Folder containing the remotes to track
local remoteFolder = game.ReplicatedStorage:WaitForChild("API")

-- A flag to ensure we print only once during the initial scan
local printedOnce = false

-- Function to inspect upvalues and identify remotes
local function inspectUpvalues()
    local remotes = {}  -- Table to collect remotes

    for i = 1, math.huge do
        local success, upvalue = pcall(getupvalue, initFunction, i)
        if not success then
            break
        end
        
        -- If the upvalue is a table, let's check its contents
        if typeof(upvalue) == "table" then
            for k, v in pairs(upvalue) do
                -- Check for RemoteEvents, RemoteFunctions, BindableEvents, and BindableFunctions
                if typeof(v) == "Instance" then
                    if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") or v:IsA("BindableEvent") or v:IsA("BindableFunction") then
                        -- Log the key, type of value, and value
                        table.insert(remotes, {key = k, remote = v})
                        -- If it's the first time scanning, print remote information
                        if not printedOnce then
                            print("Dehashing in Progress")
                            print("[]")
                            print("[]")
                            print("[]")
						    print("[]")
						    print("[]")
							print("[]")
                        end
                    end
                end
            end
        end
    end

    return remotes
end

-- Function to rename remotes based on their key
local function rename(remote, key)
    local nameParts = string.split(key, "/")  -- Split the key by "/"
    if #nameParts > 1 then
        local remotename = table.concat(nameParts, "/", 1, 2)  -- Join the first two parts
        remote.Name = remotename
    else
        warn("Invalid key format for remote: " .. key)  -- Notify if the key format is incorrect
    end
end

-- Function to rename all existing remotes in the folder
local function renameExistingRemotes()
    local remotes = inspectUpvalues()

    -- Rename all collected remotes based on the key
    for _, entry in ipairs(remotes) do
        rename(entry.remote, entry.key)
    end
end

-- Function to display dehashed message
local function displayDehashedMessage()
    local uiElement = game:GetService("Players").LocalPlayer.PlayerGui.HintApp.LargeTextLabel
    uiElement.Text = "Remotes has been Dehashed!"
    uiElement.TextColor3 = Color3.fromRGB(0, 255, 0)  -- Set text color to green
    wait(3)
    uiElement.Text = ""
    uiElement.TextColor3 = Color3.fromRGB(255, 255, 255)  -- Reset text color to default (white)
end

-- Monitor for new remotes added to the folder
local function monitorForNewRemotes()
    remoteFolder.ChildAdded:Connect(function(child)
        if child:IsA("RemoteEvent") or child:IsA("RemoteFunction") or child:IsA("BindableEvent") or child:IsA("BindableFunction") then
            print("New remote added: " .. child:GetFullName())
            -- Check and rename the new remote
            local remotes = inspectUpvalues()
            for _, entry in ipairs(remotes) do
                rename(entry.remote, entry.key)
            end
        end
    end)
end

-- Coroutine for periodic check without freezing
local function periodicCheck()
    while true do
        task.wait(10)  -- Check every 10 seconds (can adjust based on your needs)
        -- Scan and rename existing remotes periodically
        pcall(renameExistingRemotes)
    end
end

-- Start the periodic check in a coroutine (non-blocking)
coroutine.wrap(periodicCheck)()

-- Initial scan and rename for all existing remotes (print once)
renameExistingRemotes()

-- Display dehashed message
displayDehashedMessage()

-- Set the flag to prevent printing more than once
printedOnce = true

print("Script initialized and monitoring remotes.")


print("✅Dehashed Remotes ready to Load Script!")


-- This script automates the process of handling pet and player ailments in Adopt Me.
-- It listens for ailments, teleports the player and pet to the correct location,
-- and performs actions to fix the ailment before teleporting them back.

-- --- MODULES & SERVICES ---
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local task = task

-- Declare module variables as nil initially
local AilmentsManager = nil
local InteriorsM = nil
local ClientDataModule = nil

-- The 'require' function is the correct way to load a ModuleScript.
-- It will automatically wait for the module to be replicated and loaded
-- before returning the module's contents. This prevents the "not a valid member" error.
local success, err = pcall(function()
	AilmentsManager = require(ReplicatedStorage.new.modules.Ailments.AilmentsClient)
	InteriorsM = require(ReplicatedStorage.ClientModules.Core.InteriorsM.InteriorsM)
	ClientDataModule = require(ReplicatedStorage.ClientModules.Core.ClientData)
end)

if not success then
	warn("Failed to load required modules. Script will not function correctly.", err)
	return
end

-- --- CONSTANTS & CONFIGURATION ---
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local AilmentPlatform = nil

-- Ailment to Location mapping.
local LOCATION_MAPPING = {
	["dirty"] = "far_away_platform", -- Will now activate a bathtub
	["hungry"] = "far_away_platform", -- Will now activate a food bowl
	["sleepy"] = "far_away_platform", -- Will now activate a crib
	["thirsty"] = "far_away_platform", -- Will now activate a water bowl
	["sick"] = "housing", -- Teleport to housing first to handle
	["play"] = "far_away_platform",
	["camping"] = "MainMap",
	["bored"] = "MainMap",
	["beach_party"] = "MainMap",
	["ride"] = "far_away_platform",
	["walk"] = "far_away_platform",
	["school"] = "School",
	["pizza_party"] = "PizzaShop", -- Corrected from "pizza" to "pizza_party"
	["salon"] = "Salon",
	["toilet"] = "far_away_platform",
}

-- Mapping of static map ailments to their exact target parts
local STATIC_MAP_TARGETS = {
	camping = "StaticMap.Campsite.CampsiteOrigin",
	bored = "StaticMap.Park.BoredAilmentTarget",
	beach_party = "StaticMap.Beach.BeachPartyAilmentTarget",
}

-- NEW: Mapping of interior-specific ailments to their required furniture.
local AILMENT_FURNITURE_MAPPING = {
    ["school"] = "SchoolRefresh2023DefaultChair2",
    ["pizza_party"] = "PizzaShopChair",
    ["salon"] = "ColoredHairSprayWashBasin",
}

-- Define common teleport settings.
-- Note: We will use a *minimal* settings table for 'housing' teleport
-- based on the MagicHouseDoorInteractions module.
local commonTeleportSettings = {
	fade_in_length = 0.5, -- Duration of the fade-in effect (seconds)
	fade_out_length = 0.4, -- Duration of the fade-out effect (seconds)
	fade_color = Color3.new(0, 0, 0), -- Color to fade to (black in this case)

	-- Callback function executed just before the player starts teleporting.
	player_about_to_teleport = function() print("Player is about to teleport...") end,
	-- Callback function executed once the teleportation process is fully completed.
	teleport_completed_callback = function()
		print("Teleport completed callback.")
		task.wait(0.2) -- Small wait after teleport for stability
	end,
	player_to_teleport_to = nil,

	anchor_char_immediately = true, -- Whether to anchor the character right away
	post_character_anchored_wait = 0.5, -- Wait time after character is anchored
	
	move_camera = true, -- Whether the camera should move with the player

	-- These properties are part of the settings table expected by enter_smooth.
	door_id_for_location_module = nil,
	exiting_door = nil,
}

-- --- REMOTE EVENTS & FUNCTIONS ---
local ToolEquipRemote = ReplicatedStorage:WaitForChild("API"):WaitForChild("ToolAPI/Equip")
local PetObjectCreateRemote = ReplicatedStorage:WaitForChild("API"):WaitForChild("PetObjectAPI/CreatePetObject")
local HoldBabyRemote = ReplicatedStorage:WaitForChild("API"):WaitForChild("AdoptAPI/HoldBaby")
local BuyItemRemote = ReplicatedStorage:WaitForChild("API"):WaitForChild("ShopAPI/BuyItem")
local UnequipRemote = ReplicatedStorage:WaitForChild("API"):WaitForChild("ToolAPI/Unequip")
local EjectBabyRemote = ReplicatedStorage:WaitForChild("API"):WaitForChild("AdoptAPI/EjectBaby")
local activateFurniture = ReplicatedStorage:WaitForChild("API"):WaitForChild("HousingAPI/ActivateFurniture")
local setDoorLockedRemote = ReplicatedStorage:WaitForChild("API"):WaitForChild("HousingAPI/SetDoorLocked")

-- --- GLOBAL STATE ---
local isProcessingAilment = false
local ailmentsToProcess = {}
local activeAilments = {}
local impendingAilments = {}

-- A set to keep track of ailments already in the queue to prevent duplicates.
local queuedAilments = {}

-- --- HELPER FUNCTIONS ---
local function getAilmentIdFromInstance(ailmentInstance)
	if not ailmentInstance or type(ailmentInstance) ~= "table" then
		return "UNKNOWN_INSTANCE"
	end
	if ailmentInstance.kind then
		return tostring(ailmentInstance.kind)
	end
	return "UNKNOWN_AILMENT_NAME_FALLBACK"
end

local function formatAilmentDetails(ailmentInstance)
	local details = {}
	if ailmentInstance and type(ailmentInstance) == "table" then
		if type(ailmentInstance.get_progress) == "function" then
			table.insert(details, "Progress: " .. string.format("%.2f", ailmentInstance:get_progress()))
		elseif ailmentInstance.progress then
			table.insert(details, "Progress: " .. string.format("%.2f", ailmentInstance.progress))
		end
	end
	if #details > 0 then
		return " (" .. table.concat(details, ", ") .. ")"
	else
		return ""
	end
end

local function getEntityDisplayInfo(entityRef)
	if not entityRef then return "Unknown Entity", "N/A" end
	if not entityRef.is_pet then
		return LocalPlayer.Name .. "'s Baby", tostring(LocalPlayer.UserId)
	else
		local myInventory = ClientDataModule.get("inventory")
		if myInventory and myInventory.pets and myInventory.pets[entityRef.pet_unique] then
			return tostring(myInventory.pets[entityRef.pet_unique].id), tostring(entityRef.pet_unique)
		else
			return "Pet (Unknown Name)", tostring(entityRef.pet_unique)
		end
	end
end

local function createEntityReference(player, isPet, petUniqueId)
	return {
		player = player,
		is_pet = isPet,
		pet_unique = petUniqueId
	}
end

local function formatTimeRemaining(seconds)
	if not seconds or seconds < 0 then return "N/A" end
	local minutes = math.floor(seconds / 60)
	local remainingSeconds = math.floor(seconds % 60)
	if minutes > 0 then
		return string.format("%dm %02ds", minutes, remainingSeconds)
	else
		return string.format("%ds", remainingSeconds)
	end
end

-- A function to wait for the client data to be available
local function waitForData()
	local data = ClientDataModule.get_data()
	while not data do
		task.wait(0.5)
		data = ClientDataModule.get_data()
	end
	return data
end

-- Function to create a temporary platform for teleporting
local function createAilmentPlatform()
	if AilmentPlatform and AilmentPlatform.Parent then
		warn("'AilmentPlatform' already exists. Skipping creation.")
		return
	end
	
	AilmentPlatform = Instance.new("Part")
	AilmentPlatform.Name = "AilmentPlatform"
	AilmentPlatform.Anchored = true
	AilmentPlatform.CanCollide = true
	AilmentPlatform.Transparency = 0 -- Not transparent
	AilmentPlatform.Size = Vector3.new(2048, 4, 2048) -- Updated size to match Roblox Studio baseplate
	AilmentPlatform.CFrame = CFrame.new(-100000, 1000, -100000) -- Fix: CFrame should have a capital 'F'
	AilmentPlatform.Color = Color3.fromRGB(80, 200, 120) -- Greenish color
	AilmentPlatform.Parent = Workspace
	
	print("✅Created 'AilmentPlatform' at", AilmentPlatform.CFrame:GetComponents())
	print("✅Platform size updated to: " .. tostring(AilmentPlatform.Size))
end

-- Function to destroy the temporary platform
local function destroyAilmentPlatform()
	if AilmentPlatform and AilmentPlatform.Parent then
		AilmentPlatform:Destroy()
		AilmentPlatform = nil
	end
end

-- Define a function to recursively search for an item.
local function findDeep(parent, objectName)
	for _, child in ipairs(parent:GetChildren()) do
		if child.Name == objectName then
			return child
		end
		
		if child:IsA("Folder") or child:IsA("Model") then
			local foundItem = findDeep(child, objectName)
			if foundItem then
				return foundItem
			end
		end
	end
	return nil
end

-- New helper function to get the first pet model in the workspace.
local function getFirstPetModel()
	local petsFolder = Workspace:WaitForChild("Pets", 5)
	if petsFolder then
		local allPets = petsFolder:GetChildren()
		for _, petChild in ipairs(allPets) do
			if petChild:IsA("Model") then
				return petChild
			end
		end
	end
	warn("Could not find any pet model in the 'Pets' folder.")
	return nil
end

-- Teleports the player and pet to a specified CFrame.
local function safeTeleportToCFrame(targetCFrame)
	local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
	local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
	local petModel = getFirstPetModel()

	humanoidRootPart.CFrame = targetCFrame
	if petModel and petModel:FindFirstChild("PrimaryPart") then
		petModel.PrimaryPart.CFrame = targetCFrame
	end
end

-- Function to lock the house door.
local function lockDoor()
	local args = { true }
	local success, result = pcall(function()
		return setDoorLockedRemote:InvokeServer(unpack(args))
	end)
	
	if success then
		print("✅Successfully called SetDoorLocked to lock the door.")
	else
		warn("❌Failed to call SetDoorLocked:", result)
	end
end

-- The new, crucial function for cleaning up after an ailment is complete.
local function cleanupAilment(ailmentEntry)
	local ailmentId = ailmentEntry.StoredAilmentId
	
	if ailmentId == "walk" then
		print("Cleaning up after 'walk' ailment by ejecting the baby.")
		local petModel = ailmentEntry.petModel
		if petModel and petModel:IsA("Model") then
			pcall(EjectBabyRemote.FireServer, EjectBabyRemote, petModel)
		end
	elseif ailmentId == "ride" then
		print("Cleaning up after 'ride' ailment by unequipping the stroller.")
		local itemId = ailmentEntry.unequipItemId
		if itemId then
			pcall(UnequipRemote.InvokeServer, UnequipRemote, itemId)
		end
	end
end

-- Handles the 'sick' ailment, which involves buying and creating healing apples
-- and a sequence of teleports.
local function handleSickAilment(ailmentData)
	print("Beginning to handle 'sick' ailment.")

	-- --- DIRECT TELEPORT TO HOUSING (Replicating MagicHouseDoorInteractions Call) ---
	local destinationId = "housing"
	local doorIdForTeleport = "MainDoor"

	-- Create a *minimal* settings table for the teleport, as seen in MagicHouseDoorInteractions
	local teleportSettings = {
		house_owner = LocalPlayer,
	}

	-- Wait for house interior to stream.
	local waitBeforeTeleport = 10
	print(string.format("\nWaiting %d seconds for house interior to stream before teleport...", waitBeforeTeleport))
	task.wait(waitBeforeTeleport)

	print("\n--- Initiating Direct Teleport to Housing (Replicating MagicHouseDoorInteractions Call) ---")
	print("Attempting to trigger automatic door teleport to destination:", destinationId)
	print("Using door ID:", doorIdForTeleport)
	print("Using minimal settings table with house_owner:", tostring(teleportSettings.house_owner))
	
	-- Re-acquire InteriorsM before the call
	InteriorsM = require(ReplicatedStorage.ClientModules.Core.InteriorsM.InteriorsM)

	-- Add a final small wait right before the InteriorsM.enter_smooth call
	task.wait(1) -- Added a 1-second wait here for final stability

	-- Call the enter_smooth function for the teleport
	InteriorsM.enter_smooth(destinationId, doorIdForTeleport, teleportSettings, nil)
	
	print("Successfully teleported to housing.")
	task.wait(2)
	lockDoor()

	-- Get the remote to buy the item
	local ShopRemote = ReplicatedStorage:WaitForChild("API"):WaitForChild("ShopAPI/BuyItem")
	local PetObjectRemote = ReplicatedStorage:WaitForChild("API"):WaitForChild("PetObjectAPI/CreatePetObject")
	
	if not ShopRemote or not PetObjectRemote then
		warn("Required remotes for 'sick' ailment not found.")
		return
	end
	
	local serverData = ClientDataModule.get_data()
	local playerData = serverData and serverData[LocalPlayer.Name]
	local petUniqueId = nil
	
	if not playerData or not playerData.inventory or not playerData.inventory.pets then
		warn("Required data tables for pets not found.")
		return
	end
	
	local playerPets = playerData.inventory.pets
	for uniqueId, petData in pairs(playerPets) do
		petUniqueId = uniqueId
		break
	end
	
	if not petUniqueId then
		warn("No pets found in your inventory to link to the apple.")
		return
	end
	
	print("Found pet unique ID:", petUniqueId)
	
	-- Wait for the ailment to complete or a timeout
	local ailmentCompleted = false
	local connection = AilmentsManager.get_ailment_completed_signal():Connect(function(instance, key)
		if key == ailmentData.entityUniqueKey and instance == ailmentData.ailmentInstance then
			ailmentCompleted = true
		end
	end)
	
	local timeout = 60 -- seconds
	local startTime = os.time()
	
	while not ailmentCompleted and (os.time() - startTime) < timeout do
		-- Buy the healing apple
		local buyArgs = {
			"food",
			"healing_apple",
			{
				buy_count = 1
			}
		}
		
		print("\nAttempting to buy Healing Apple...")
		local success, result = pcall(ShopRemote.InvokeServer, ShopRemote, unpack(buyArgs))
		
		if success then
			print("Successfully bought Healing Apple!")
		else
			print("Buy command failed: " .. tostring(result))
		end

		-- Wait for data to update after the purchase
		task.wait(2)
		
		local currentData = waitForData()
		local currentPlayerData = currentData[LocalPlayer.Name]
		local foodUniqueId = nil

		-- Find the unique ID for the newly bought Healing Apple
		local playerFood = currentPlayerData.inventory.food
		for uniqueId, itemData in pairs(playerFood) do
			if itemData.id == "healing_apple" then
				foodUniqueId = uniqueId
				break
			end
		end

		if not foodUniqueId then
			warn("Healing Apple not found in your inventory after purchase.")
		end

		if foodUniqueId then
			print("Found Healing Apple unique ID:", foodUniqueId)
			local args = {
				"__Enum_PetObjectCreatorType_2",
				{
					additional_consume_uniques = {},
					pet_unique = petUniqueId,
					unique_id = foodUniqueId
				}
			}
			
			print("Attempting to create the healing apple...")
			local createSuccess, createResult = pcall(PetObjectRemote.InvokeServer, PetObjectRemote, unpack(args))
			
			if createSuccess then
				print("Successfully sent create command!")
			else
				warn("Create command failed:", tostring(createResult))
			end
		end
		
		task.wait(5) -- Wait between attempts
	end
	
	connection:Disconnect()

	if not ailmentCompleted then
		warn("Ailment did not complete within timeout. Cannot force completion, relying on in-game action.")
	end
	
	print("Ailment 'sick' completed. Starting interior teleport sequence.")
	
	-- Now, perform the teleport sequence to the interiors.
	teleportToInteriors()
	
	print("Interior teleport sequence complete. Teleporting back to housing.")
	
	-- Replicate the call to go back to housing
	local destinationId_Return = "housing"
	local doorIdForTeleport_Return = "MainDoor"
	local teleportSettings_Return = {
		house_owner = LocalPlayer,
	}
	
	task.wait(1)
	
	-- Re-acquire InteriorsM before the return teleport
	InteriorsM = require(ReplicatedStorage.ClientModules.Core.InteriorsM.InteriorsM)
	InteriorsM.enter_smooth(destinationId_Return, doorIdForTeleport_Return, teleportSettings_Return, nil)
	
	task.wait(2)
	print("Successfully returned to housing.")
	lockDoor()
end

-- Updated function to handle ailments that require teleporting to the pet's head CFrame.
local function handleAilmentOnPlatform(ailmentData)
    -- Re-acquire InteriorsM here to ensure it's not nil after the teleport
    InteriorsM = require(ReplicatedStorage.ClientModules.Core.InteriorsM.InteriorsM)
    
    if not AilmentsManager then
        warn("AilmentsManager is nil. Cannot handle ailment on platform.")
        isProcessingAilment = false
        return
    end

    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    local petModel = getFirstPetModel()
    
    print("🔄Teleporting to AilmentPlatform...")
    local targetPart = AilmentPlatform
    
    if not targetPart then
        warn("Could not find AilmentPlatform. Cannot proceed with ailment fix.")
        return
    end
    
    -- Teleport the character to the platform first
    local targetCFrame = targetPart.CFrame * CFrame.new(0, 5, 0)
    humanoidRootPart.CFrame = targetCFrame
    
    if petModel and petModel:FindFirstChild("PrimaryPart") then
        petModel.PrimaryPart.CFrame = targetCFrame
    end
    
    task.wait(1)

    local humanoid = character:WaitForChild("Humanoid")
    local ailmentId = ailmentData.ailmentId

    -- NEW LOGIC: Determine CFrame based on ailment
    local petHead = petModel:FindFirstChild("Head")
    if not petHead then
        warn("Could not find pet's 'Head' part. Cannot perform head CFrame action.")
        return
    end

    local targetHeadCFrame = petHead.CFrame
    local furnitureName = nil
    local furnitureAction = nil

    -- Use specific CFrame logic for each ailment
    if ailmentId == "dirty" then
        targetHeadCFrame = petHead.CFrame * CFrame.Angles(0, 0, 0.2)
        furnitureName = "CheapPetBathtub"
        furnitureAction = "UseBlock"
    elseif ailmentId == "sleepy" then
        targetHeadCFrame = petHead.CFrame * CFrame.Angles(0, -0.2, 0) * CFrame.new(0, -0.5, 0)
        furnitureName = "BasicCrib"
        furnitureAction = "UseBlock"
    elseif ailmentId == "hungry" then
        targetHeadCFrame = petHead.CFrame * CFrame.new(0, -0.2, 0) * CFrame.Angles(-0.3, 0, 0)
        furnitureName = "PetFoodBowl"
        furnitureAction = "UseBlock"
    elseif ailmentId == "thirsty" then
        targetHeadCFrame = petHead.CFrame * CFrame.Angles(0, 0.2, 0) * CFrame.new(0, -0.2, 0)
        furnitureName = "PetWaterBowl"
        furnitureAction = "UseBlock"
    elseif ailmentId == "toilet" then
        targetHeadCFrame = petHead.CFrame * CFrame.new(0, -1, 0) * CFrame.Angles(0.5, 0, 0)
        furnitureName = "Toilet"
        furnitureAction = "Seat1"
    end
    
    -- After teleporting, find and activate the furniture
    if furnitureName then
        local furnitureFolder = Workspace:WaitForChild("HouseInteriors"):WaitForChild("furniture")
        if furnitureFolder then
            local foundItem = findDeep(furnitureFolder, furnitureName)
            if foundItem then
                local furnitureParent = foundItem.Parent
                local parts = string.split(furnitureParent.Name, "/")
                local furnitureId = parts[#parts]
                
                print("Found the furniture ID for " .. furnitureName .. ": " .. furnitureId)
                
                local cframe = character:WaitForChild("Head").CFrame
                
                local args = {
                    LocalPlayer,
                    furnitureId,
                    furnitureAction,
                    {
                        cframe = cframe
                    },
                    petModel -- Use the first found pet model.
                }
                
                activateFurniture:InvokeServer(unpack(args))
                print("Successfully called ActivateFurniture for " .. furnitureName .. " with the '" .. furnitureAction .. "' action.")
            else
                warn("Could not find " .. furnitureName .. " inside the furniture folder.")
            end
        else
            warn("The 'furniture' folder could not be found.")
        end
    elseif ailmentId == "play" then
        print("Attempting to fix 'play' ailment by creating Squeaky Bone.")
        
        local PetObjectRemote = ReplicatedStorage:WaitForChild("API"):WaitForChild("PetObjectAPI/CreatePetObject")
        if not PetObjectRemote then
            warn("PetObjectAPI/CreatePetObject not found. Cannot fix 'play' ailment.")
            return
        end

        local serverData = ClientDataModule.get_data()
        local playerData = serverData and serverData[LocalPlayer.Name]
        local itemUniqueId = nil
        
        if playerData and playerData.inventory and playerData.inventory.toys then
            for uniqueId, itemData in pairs(playerData.inventory.toys) do
                if itemData.id == "squeaky_bone_default" then
                    itemUniqueId = uniqueId
                    break
                end
            end
        end

        if not itemUniqueId then
            warn("Squeaky Bone not found in inventory. Cannot fix 'play' ailment.")
            return
        end

        print("Found Squeaky Bone with unique ID:", itemUniqueId)

        -- Wait for the ailment to complete or a timeout
        local ailmentCompleted = false
        local connection = AilmentsManager.get_ailment_completed_signal():Connect(function(instance, key)
            if key == ailmentData.entityUniqueKey and instance == ailmentData.ailmentInstance then
                ailmentCompleted = true
            end
        end)
        
        local timeout = 60 -- seconds
        local startTime = os.time()
        
        while not ailmentCompleted and (os.time() - startTime) < timeout do
            local args = {
                "__Enum_PetObjectCreatorType_1",
                {
                    reaction_name = "ThrowToyReaction",
                    unique_id = itemUniqueId
                }
            }
            
            local success, result = pcall(PetObjectRemote.InvokeServer, PetObjectRemote, unpack(args))
            
            if success then
                print("Successfully created the toy.")
            else
                warn("Failed to create toy:", tostring(result))
            end
            
            -- This is the requested change: wait 10 seconds between creations.
            task.wait(10)
        end
        
        connection:Disconnect()

        if not ailmentCompleted then
            warn("Ailment did not complete within timeout. Cannot force completion, relying on in-game action.")
        end
    elseif ailmentId == "walk" then
        print("Attempting to hold pet for 'walk' ailment.")
        
        -- Store the pet model for cleanup
        local uiEntry = activeAilments[ailmentData.entityUniqueKey] and activeAilments[ailmentData.entityUniqueKey][ailmentId]
        if uiEntry then
            uiEntry.petModel = petModel
        end

        local success, result = pcall(function()
            HoldBabyRemote:FireServer(petModel)
        end)
        if not success then warn("Failed to hold baby:", result) end
    elseif ailmentId == "ride" then
        print("Attempting to equip stroller for 'ride' ailment.")
        
        local serverData = ClientDataModule.get_data()
        local playerData = serverData and serverData[LocalPlayer.Name]
        local itemType = "strollers"
        
        if playerData and playerData.inventory and playerData.inventory[itemType] then
            local playerItems = playerData.inventory[itemType]
            
            if next(playerItems) then
                local firstItemUniqueId = nil
                for uniqueId, itemData in pairs(playerItems) do
                    firstItemUniqueId = uniqueId
                    break -- Only need the first one
                end
                
                if firstItemUniqueId then
                    print("✅ Found a stroller to equip!")
                    
                    -- Store the unique item ID for later cleanup.
                    local uiEntry = activeAilments[ailmentData.entityUniqueKey] and activeAilments[ailmentData.entityUniqueKey][ailmentId]
                    if uiEntry then
                        uiEntry.unequipItemId = firstItemUniqueId
                    end
                    
                    local success, result = pcall(function()
                        ToolEquipRemote:InvokeServer(firstItemUniqueId)
                    end)
                    
                    if success then
                        print("✅ Successfully sent equip command!")
                    else
                        print("❌ Equip command failed: " .. tostring(result))
                    end
                else
                    print("❌ No strollers found in your inventory.")
                end
            else
                print("❌ No strollers found in your inventory.")
            end
        else
            print("❌ Required data tables not found for " .. itemType .. ".")
        end
    end
    
    -- Wait for the ailment to complete or a timeout
    local ailmentCompleted = false
    local connection = AilmentsManager.get_ailment_completed_signal():Connect(function(instance, key)
        if key == ailmentData.entityUniqueKey and instance == ailmentData.ailmentInstance then
            ailmentCompleted = true
        end
    end)

    local timeout = 60 -- seconds
    local startTime = os.time()
    while not ailmentCompleted and (os.time() - startTime) < timeout do
        -- For "walk" and "ride", make the character jump to force completion
        if ailmentId == "walk" or ailmentId == "ride" then
            if humanoid and humanoid.Parent then
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end
        task.wait(1)
    end
    
    connection:Disconnect()

    if not ailmentCompleted then
        warn("Ailment did not complete within timeout. Cannot force completion, relying on in-game action.")
    end
    
    print("Ailment completed. Teleporting back to housing.")
    
    local destinationId_Return = "housing"
    local doorIdForTeleport_Return = "MainDoor"
    local teleportSettings_Return = {
        house_owner = LocalPlayer,
    }
    
    task.wait(1)
    
    -- Re-acquire InteriorsM before the return teleport
    InteriorsM = require(ReplicatedStorage.ClientModules.Core.InteriorsM.InteriorsM)
    InteriorsM.enter_smooth(destinationId_Return, doorIdForTeleport_Return, teleportSettings_Return, nil)
    
    task.wait(2)
    print("Successfully returned to housing.")
    lockDoor()
end

-- New function to handle interior-specific ailments like Salon, Pizza Shop, and School.
local function handleInteriorAilment(ailmentData, locationName)
	-- Re-acquire InteriorsM here to ensure it's not nil after the teleport
	InteriorsM = require(ReplicatedStorage.ClientModules.Core.InteriorsM.InteriorsM)
	
	print("🔄Performing smooth entry to " .. locationName .. " before teleport.")
	local destinationId = locationName
	local doorIdForTeleport = "MainDoor"
	local teleportSettings = { house_owner = LocalPlayer }
	
	-- Smoothly enter the interior first.
	InteriorsM.enter_smooth(destinationId, doorIdForTeleport, teleportSettings, nil)
	task.wait(2) -- Wait for the smooth entry to complete
	
	-- Get the specific furniture name from our new mapping.
	local furnitureName = AILMENT_FURNITURE_MAPPING[ailmentData.ailmentId]
	if not furnitureName then
		warn("No specific furniture mapped for ailment:", ailmentData.ailmentId)
		return
	end
	
	print("Attempting to find and teleport to the " .. furnitureName .. "...")
	
	-- The key change: search in the shared HouseInteriors.furniture folder
    local furnitureFolder = Workspace:WaitForChild("HouseInteriors"):WaitForChild("furniture")
    if not furnitureFolder then
        warn("Could not find the 'furniture' folder.")
        return
    end

    local furnitureModel = findDeep(furnitureFolder, furnitureName)

	if furnitureModel then
		local placementBlock = findDeep(furnitureModel, "PlacementBlock")

		if placementBlock and placementBlock:IsA("BasePart") then
			-- Teleport player and pet to the furniture's CFrame to be in range for activation.
			safeTeleportToCFrame(placementBlock.CFrame * CFrame.new(0, 5, 0)) -- Add a small offset
			print("✅Teleported to " .. furnitureModel.Name .. " CFrame using PlacementBlock.")
			task.wait(1)
			
			-- Use the parent's name to get the correct furniture ID
			local furnitureParent = furnitureModel.Parent
			local parts = string.split(furnitureParent.Name, "/")
			local furnitureId = parts[#parts]
			local furnitureAction = "Seat1"

			-- Special case for the washbasin in the salon. It has no parent.
			if furnitureName == "ColoredHairSprayWashBasin" then
				furnitureId = furnitureModel.Name
				furnitureAction = "Use" -- Assuming 'Use' is the action.
			end
			
			local args = {
				LocalPlayer,
				furnitureId,
				furnitureAction,
				{
					cframe = LocalPlayer.Character.HumanoidRootPart.CFrame
				},
				getFirstPetModel()
			}
			
			local success, result = pcall(activateFurniture.InvokeServer, activateFurniture, unpack(args))
			
			if success then
				print("✅ Successfully called ActivateFurniture for " .. furnitureModel.Name .. "!")
			else
				warn("❌ Failed to call ActivateFurniture:", tostring(result))
			end
		else
			warn("❌ Could not find PlacementBlock within the furniture:", furnitureName)
		end
	else
		warn("❌ Could not find " .. furnitureName .. " inside the furniture folder.")
	end

	-- Wait for the ailment to complete or a timeout
	local ailmentCompleted = false
	local connection = AilmentsManager.get_ailment_completed_signal():Connect(function(instance, key)
		if key == ailmentData.entityUniqueKey and instance == ailmentData.ailmentInstance then
			ailmentCompleted = true
		end
	end)
	
	local timeout = 60 -- seconds
	local startTime = os.time()
	while not ailmentCompleted and (os.time() - startTime) < timeout do
		task.wait(1)
	end
	
	connection:Disconnect()

	if not ailmentCompleted then
		warn("Ailment did not complete within timeout. Cannot force completion, relying on in-game action.")
	end
	
	print("Ailment completed. Teleporting back to housing.")
	
	local destinationId_Return = "housing"
	local doorIdForTeleport_Return = "MainDoor"
	local teleportSettings_Return = {
		house_owner = LocalPlayer,
	}
	
	task.wait(1)
	
	-- Re-acquire InteriorsM before the return teleport
	InteriorsM = require(ReplicatedStorage.ClientModules.Core.InteriorsM.InteriorsM)
	InteriorsM.enter_smooth(destinationId_Return, doorIdForTeleport_Return, teleportSettings_Return, nil)
	
	task.wait(2)
	print("Successfully returned to housing.")
	lockDoor()
end

-- New function to teleport to a static map location and handle the ailment.
local function teleportToStaticMap(ailmentData)
	local targetPath = STATIC_MAP_TARGETS[ailmentData.ailmentId]
	if not targetPath then
		warn("No target path found for ailment:", ailmentData.ailmentId)
		return
	end

    -- Find the target part, waiting a bit in case the map hasn't loaded fully
    local targetPart = Workspace:FindFirstChild(string.split(targetPath, ".")[#string.split(targetPath, ".")], true)

	if not targetPart or not targetPart:IsA("BasePart") then
		warn("Could not find a valid part at path:", targetPath)
		return
	end
	
	safeTeleportToCFrame(targetPart.CFrame * CFrame.new(0, 5, 0))
	print("Successfully teleported to the static map location for the ailment.")

    -- Now, handle the ailment-specific logic
    if ailmentData.ailmentId == "camping" or ailmentData.ailmentId == "bored" or ailmentData.ailmentId == "beach_party" then
        -- Wait for the ailment to complete or a timeout
        local ailmentCompleted = false
        local connection = AilmentsManager.get_ailment_completed_signal():Connect(function(instance, key)
            if key == ailmentData.entityUniqueKey and instance == ailmentData.ailmentInstance then
                ailmentCompleted = true
            end
        end)
        
        local timeout = 88 -- seconds
        local startTime = os.time()
        while not ailmentCompleted and (os.time() - startTime) < timeout do
            task.wait(1)
        end
        
        connection:Disconnect()

        if not ailmentCompleted then

	
            warn("Ailment did not complete within timeout. Cannot force completion, relying on in-game action.")
        end

        print("Ailment resolved at static map location. Teleporting back to housing.")
        
        local destinationId_Return = "housing"
        local doorIdForTeleport_Return = "MainDoor"
        local teleportSettings_Return = {
            house_owner = LocalPlayer,
        }
        
        task.wait(1)
        InteriorsM.enter_smooth(destinationId_Return, doorIdForTeleport_Return, teleportSettings_Return, nil)
        
        task.wait(2)
        print("Successfully returned to housing.")
    end
end


-- The main processing function which handles the `isProcessingAilment` flag.
local function processAilment(ailmentData)
	-- Re-acquire InteriorsM here to ensure it's not nil before the first teleport
	InteriorsM = require(ReplicatedStorage.ClientModules.Core.InteriorsM.InteriorsM)

	if not AilmentsManager then
		warn("AilmentsManager is nil. Cannot process ailment.")
		isProcessingAilment = false
		return
	end
	
	isProcessingAilment = true
	print("✅Processing flag set to: true")
	print("---")
	print("🔄 Starting process for:", ailmentData.ailmentId, "for", getEntityDisplayInfo(ailmentData.entityRef))
	
	local success, result = pcall(function()
		local ailmentId = ailmentData.ailmentId
		local locationName = LOCATION_MAPPING[ailmentId]
		
		if not locationName then
			warn("No mapped location for:", ailmentId)
			return
		end

		if ailmentId == "sick" then
			handleSickAilment(ailmentData)
		elseif locationName == "far_away_platform" then
			print("Handling far_away_platform teleport. Teleporting to housing first to ensure proper positioning.")
			InteriorsM.enter_smooth("housing", "MainDoor", { house_owner = LocalPlayer }, nil)
			task.wait(2)
			handleAilmentOnPlatform(ailmentData)
		elseif ailmentId == "camping" or ailmentId == "bored" or ailmentId == "beach_party" then
			print("🔄Teleporting to MainMap...")
			InteriorsM.enter_smooth("MainMap", "MainDoor", {
				fade_in_length = 0.5,
				fade_out_length = 0.4,
				fade_color = Color3.new(0,0,0),
				player_about_to_teleport = function() end,
			}, nil)
			
			task.wait(2)

			print("🔄Teleport to MainMap finished. Now teleporting to specific location and resolving.")
			teleportToStaticMap(ailmentData)
		elseif locationName == "PizzaShop" or locationName == "School" or locationName == "Salon" then
			-- Now calls the new, specialized function for interiors
			handleInteriorAilment(ailmentData, locationName)
		else
			warn("Unhandled teleport location:", locationName)
		end
	end)
	
	if not success then
		warn("Processing ailment failed:", result)
	end

	isProcessingAilment = false
	print("✅Processing flag reset to: false")

	-- The call to handle the next ailment is now moved to the onAilmentComplete handler,
	-- ensuring one task finishes before the next one starts.
end

-- The core queue handling function. It pulls and processes the next ailment if available.
local function handleNextAilment()
	if not isProcessingAilment and #ailmentsToProcess > 0 then
		local data = table.remove(ailmentsToProcess, 1)
		task.spawn(function()
			processAilment(data)
		end)
	end
end

-- --- EVENT CONNECTIONS & LOGGING ---
local function logAilmentAdded(ailmentInstance, entityUniqueKey, entityRef)
	local ailmentId = getAilmentIdFromInstance(ailmentInstance)
	local entityDisplayName, entityUniqueIdForDisplay = getEntityDisplayInfo(entityRef)
	
	if not activeAilments[entityUniqueKey] then
		activeAilments[entityUniqueKey] = {}
	end
	
	if not activeAilments[entityUniqueKey][ailmentId] then
		activeAilments[entityUniqueKey][ailmentId] = {
			AilmentInstance = ailmentInstance,
			EntityRef = entityRef,
			StoredAilmentId = ailmentId
		}
		print(string.format("[AILMENT ADDED] %s for %s (%s)%s", ailmentId, entityDisplayName, entityUniqueIdForDisplay, formatAilmentDetails(ailmentInstance)))
	else
		activeAilments[entityUniqueKey][ailmentId].AilmentInstance = ailmentInstance
		print(string.format("[AILMENT UPDATED] %s for %s (%s)%s", ailmentId, entityDisplayName, entityUniqueIdForDisplay, formatAilmentDetails(ailmentInstance)))
	end
end

local function logAilmentRemoved(ailmentInstance, entityUniqueKey, entityRef)
	local ailmentIdToRemove = getAilmentIdFromInstance(ailmentInstance)
	local foundEntry = activeAilments[entityUniqueKey] and activeAilments[entityUniqueKey][ailmentIdToRemove]
	
	if not foundEntry then
		for currentAilmentId, entry in pairs(activeAilments[entityUniqueKey] or {}) do
			if entry.AilmentInstance == ailmentInstance then
				ailmentIdToRemove = currentAilmentId
				foundEntry = entry
				break
			end
		end
	end

	if foundEntry then
		local storedAilmentId = foundEntry.StoredAilmentId
		activeAilments[entityUniqueKey][storedAilmentId] = nil
		if next(activeAilments[entityUniqueKey]) == nil then
			activeAilments[entityUniqueKey] = nil
		end
		local entityDisplayName, entityUniqueIdForDisplay = getEntityDisplayInfo(entityRef)
		print(string.format("[AILMENT REMOVED] %s for %s (%s)", storedAilmentId, entityDisplayName, entityUniqueIdForDisplay))
	else
		print(string.format("[AILMENT REMOVAL ERROR] Could not find Ailment to remove: %s for %s (Key attempted: %s)", ailmentIdToRemove, entityUniqueKey, ailmentIdToRemove))
	end
	
	if impendingAilments[entityUniqueKey] and impendingAilments[entityUniqueKey][ailmentIdToRemove] then
		impendingAilments[entityUniqueKey][ailmentIdToRemove] = nil
		if next(impendingAilments[entityUniqueKey]) == nil then
			impendingAilments[entityUniqueKey] = nil
		end
	end
end

local function logImpendingAilment(ailmentInstance, entityUniqueKey, entityRef, timeLeftSeconds)
	local ailmentId = getAilmentIdFromInstance(ailmentInstance)
	local entityDisplayName, entityUniqueIdForDisplay = getEntityDisplayInfo(entityRef)

	if not impendingAilments[entityUniqueKey] then
		impendingAilments[entityUniqueKey] = {}
	end
	
	-- Only log if it's a new warning or the time has changed significantly
	if not impendingAilments[entityUniqueKey][ailmentId] then
		impendingAilments[entityUniqueKey][ailmentId] = true
		print(string.format("[IMPENDING] %s for %s (%s) will complete in %s", ailmentId, entityDisplayName, entityUniqueIdForDisplay, formatTimeRemaining(timeLeftSeconds)))
	end
end

local function removeImpendingAilment(entityUniqueKey, ailmentId)
	if impendingAilments[entityUniqueKey] and impendingAilments[entityUniqueKey][ailmentId] then
		impendingAilments[entityUniqueKey][ailmentId] = nil
		if next(impendingAilments[entityUniqueKey]) == nil then
			impendingAilments[entityUniqueKey] = nil
		end
	end
end

local function onAilmentCreated(ailmentInstance, entityUniqueKey)
	local isPet = string.len(entityUniqueKey) > 10
	local entityRef = createEntityReference(LocalPlayer, isPet, entityUniqueKey)
	local ailmentId = getAilmentIdFromInstance(ailmentInstance)
	local queueKey = entityUniqueKey .. "_" .. ailmentId
	
	logAilmentAdded(ailmentInstance, entityUniqueKey, entityRef)
	
	-- Only add to the queue if the ailment is not already being processed or is not already in the queue.
	if LOCATION_MAPPING[ailmentId] and not queuedAilments[queueKey] then
		queuedAilments[queueKey] = true
		table.insert(ailmentsToProcess, {
			ailmentId = ailmentId,
			entityUniqueKey = entityUniqueKey,
			entityRef = entityRef,
			ailmentInstance = ailmentInstance,
		})
		print("✅[New Ailment Detected]:", ailmentId, "for pet key:", entityUniqueKey, ". Added to queue.")
		
		-- Immediately try to handle the next ailment if none is currently being processed.
		if not isProcessingAilment then
			handleNextAilment()
		end
	else
		print("Skipping unsupported or duplicate ailment:", ailmentId)
	end
end

local function onAilmentComplete(ailmentInstance, entityUniqueKey, completionReason)
	local isPet = string.len(entityUniqueKey) > 10
	local entityRef = createEntityReference(LocalPlayer, isPet, entityUniqueKey)
	
	-- Get the ailment data before it's removed by the logger.
	local ailmentEntry = activeAilments[entityUniqueKey] and activeAilments[entityUniqueKey][getAilmentIdFromInstance(ailmentInstance)]
	
	logAilmentRemoved(ailmentInstance, entityUniqueKey, entityRef)
	
	if ailmentEntry then
		cleanupAilment(ailmentEntry)
	end
	
	print(string.format("[EVENT] Ailment COMPLETED for %s: '%s' (Reason: %s)",
		getEntityDisplayInfo(entityRef),
		getAilmentIdFromInstance(ailmentInstance),
		tostring(completionReason)
	))
	
	isProcessingAilment = false
	print("✅Processing flag reset to: false")

	-- After an ailment is completed, immediately check for the next one in the queue.
	task.spawn(handleNextAilment)
end

-- Check for any ailments that exist when the script first runs
local function initialAilmentScan()
	print("--- Initial Ailment Scan Started ---")

	activeAilments = {}
	impendingAilments = {}

	local localPlayerEntity = createEntityReference(LocalPlayer, false, nil)
	local localPlayerAilments = AilmentsManager.get_ailments_for_pet(localPlayerEntity)
	if localPlayerAilments then
		for _, ailmentInstance in pairs(localPlayerAilments) do
			onAilmentCreated(ailmentInstance, tostring(LocalPlayer.UserId))
		end
	end

	local myInventory = ClientDataModule.get("inventory")
	if myInventory and myInventory.pets then
		for petUniqueId, petData in pairs(myInventory.pets) do
			local petEntityRef = createEntityReference(LocalPlayer, true, petUniqueId)
			local petAilments = AilmentsManager.get_ailments_for_pet(petEntityRef)
			if petAilments then
				for _, ailmentInstance in pairs(petAilments) do
					onAilmentCreated(ailmentInstance, petUniqueId)
				end
			end
		end
	end
	print("--- Initial Ailment Scan Complete. Found:", #ailmentsToProcess, "ailments to process.")
end

-- --- MAIN EXECUTION LOGIC ---
local function runMainLogic()
	createAilmentPlatform()

	-- Connect to signals for continuous listening
	AilmentsManager.get_ailment_created_signal():Connect(onAilmentCreated)
	AilmentsManager.get_ailment_completed_signal():Connect(onAilmentComplete)

	local lastUpdateTime = 0
	local WARNING_THRESHOLD_SECONDS = 120

	RunService.Heartbeat:Connect(function()
		if os.time() - lastUpdateTime < 1 then return end
		lastUpdateTime = os.time()

		for entityUniqueKey, ailmentMap in pairs(activeAilments) do
			for ailmentId, entry in pairs(ailmentMap) do
				local ailmentInstance = entry.AilmentInstance
				local entityRef = entry.EntityRef
				
				if type(ailmentInstance.get_progress) == "function" then
					local progress = string.format("%.2f", ailmentInstance:get_progress())
				end

				local rateFinishedTimestamp = ailmentInstance:get_rate_finished_timestamp()
				if rateFinishedTimestamp then
					local timeLeftSeconds = rateFinishedTimestamp - workspace:GetServerTimeNow()
					if timeLeftSeconds > 0 and timeLeftSeconds <= WARNING_THRESHOLD_SECONDS then
						logImpendingAilment(ailmentInstance, entityUniqueKey, entityRef, timeLeftSeconds)
					else
						removeImpendingAilment(entityUniqueKey, ailmentId)
					end
				else
					removeImpendingAilment(entityUniqueKey, ailmentId)
				end
			end
		end
	end)

	-- Start the main loop and initial scan AFTER all modules are defined.
	task.spawn(initialAilmentScan)
end

-- --- STARTUP ---
print("✅Ailment Manager Script initializing...")

-- The main entry point is now wrapped in a function and called after module loading is confirmed.
runMainLogic()


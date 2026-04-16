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

-- Furniture mappings for specific interiors.
-- Fix: Corrected the path by removing the redundant "workspace" part.
local INTERIOR_FURNITURE_MAPPING = {
    ["salon"] = "Interiors.Salon.InteriorOrigin",
    ["pizza_party"] = "Interiors.PizzaShop.InteriorOrigin",
    ["school"] = "Interiors.School.InteriorOrigin"
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

	-- Add a final small wait right before the InteriorsM.enter_smooth call
	task.wait(1) -- Added a 1-second wait here for final stability

	-- Call the enter_smooth function for the teleport
	InteriorsM.enter_smooth(destinationId, doorIdForTeleport, teleportSettings, nil)
	
	print("Successfully teleported to housing.")
	task.wait(2)

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
	
	InteriorsM.enter_smooth(destinationId_Return, doorIdForTeleport_Return, teleportSettings_Return, nil)
	
	task.wait(2)
	print("Successfully returned to housing.")
end

local function handleAilmentOnPlatform(ailmentData)
	-- Add a check to prevent nil errors
	if not AilmentsManager then
		warn("AilmentsManager is nil. Cannot handle ailment on platform.")
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
	
	local targetCFrame = targetPart.CFrame * CFrame.new(0, 5, 0)
	
	humanoidRootPart.CFrame = targetCFrame
	
	if petModel and petModel:FindFirstChild("PrimaryPart") then
		petModel.PrimaryPart.CFrame = targetCFrame
	end
	
	task.wait(1)

	local humanoid = character:WaitForChild("Humanoid")
	local ailmentId = ailmentData.ailmentId

	local furnitureMapping = {
		["hungry"] = "PetFoodBowl",
		["thirsty"] = "PetWaterBowl",
		["dirty"] = "CheapPetBathtub",
		["sleepy"] = "BasicCrib",
		["toilet"] = "Toilet",
	}
	
	local furnitureName = furnitureMapping[ailmentId]
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
				
				-- New logic to determine the correct action for the furniture
				local furnitureAction = "UseBlock"
				if furnitureName == "Toilet" then
					furnitureAction = "Seat1"
				end
				
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
		local playerData = serverData[LocalPlayer.Name]
		local itemType = "strollers"
		
		if playerData and playerData.inventory and playerData.inventory[itemType] then
			local playerItems = playerData.inventory[itemType]
			
			if next(playerItems) then
				local firstItemUniqueId = nil
				for uniqueId, itemData in pairs(playerItems) do
					firstItemUniqueId = uniqueId
					break 
				end
				
				if firstItemUniqueId then
					print("✅ Found a stroller to equip!")
					
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
	
	local ailmentCompleted = false
	local connection = AilmentsManager.get_ailment_completed_signal():Connect(function(instance, key)
		if key == ailmentData.entityUniqueKey and instance == ailmentData.ailmentInstance then
			ailmentCompleted = true
		end
	end)

	local timeout = 60 -- seconds
	local startTime = os.time()
	while not ailmentCompleted and (os.time() - startTime) < timeout do

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
	
	InteriorsM.enter_smooth(destinationId_Return, doorIdForTeleport_Return, teleportSettings_Return, nil)
	
	task.wait(2)
	print("Successfully returned to housing.")
end

local function teleportToStaticMap(ailmentData)

	if not AilmentsManager then
		warn("AilmentsManager is nil. Cannot teleport to static map.")
		return
	end

	local targetPath = STATIC_MAP_TARGETS[ailmentData.ailmentId]
	if not targetPath then
		warn("No static map target found for ailment:", ailmentData.ailmentId)
		return
	end
	
	local targetPart = Workspace:FindFirstChild(targetPath)
	if not targetPart then
		local parts = string.split(targetPath, ".")
		local currentParent = Workspace
		for _, partName in ipairs(parts) do
			currentParent = currentParent:FindFirstChild(partName)
			if not currentParent then
				warn("Could not find part '" .. partName .. "' at path: " .. targetPath)
				return
			end
		end
		targetPart = currentParent
	end

	if not targetPart then
		warn("Could not find target part at path:", targetPath)
		return
	end

    print("🔄Teleporting to Ailment Location on MainMap...")
    local targetCFrame = targetPart.CFrame * CFrame.new(0, 5, 0) 

    safeTeleportToCFrame(targetCFrame)
	
	print("Teleported to static map location:", targetPath)

	print("Waiting for ailment to complete:", ailmentData.ailmentId)
	
	local ailmentCompleted = false
	local connection = AilmentsManager.get_ailment_completed_signal():Connect(function(instance, key)
		if key == ailmentData.entityUniqueKey and instance == ailmentData.ailmentInstance then
			ailmentCompleted = true
		end
	end)

	local timeout = 60
	local startTime = os.time()
	while not ailmentCompleted and (os.time() - startTime) < timeout do
		task.wait(1)
	end
	
	connection:Disconnect()
	
	if not ailmentCompleted then
		warn("Ailment did not complete within timeout. Cannot force completion, relying on in-game action.")
	end
	
	print("Task wait completed. Teleporting back to housing.")

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

local function handleInteriorAilment(ailmentData, locationName)
	print("🔄Performing smooth entry to " .. locationName .. " before teleport.")
	local destinationId = locationName
	local doorIdForTeleport = "MainDoor"
	local teleportSettings = { house_owner = LocalPlayer }

	InteriorsM.enter_smooth(destinationId, doorIdForTeleport, teleportSettings, nil)
	task.wait(2) 

	local ailmentId = ailmentData.ailmentId
	local furnitureName = nil
	
	if ailmentId == "pizza_party" then
		furnitureName = "PizzaTable" 
		print("Attempting to find and sit at a " .. furnitureName .. "...")
	elseif ailmentId == "salon" then
		furnitureName = "SalonChair" 
		print("Attempting to find and sit at a " .. furnitureName .. "...")
	elseif ailmentId == "school" then
		furnitureName = "SchoolDesk" 
		print("Attempting to find and sit at a " .. furnitureName .. "...")
	end

	local furniturePart = findDeep(Workspace:WaitForChild("Interiors"):WaitForChild(locationName):WaitForChild("Interior"), furnitureName)

	if furniturePart and furniturePart.Parent then
		local furnitureId = furniturePart.Parent.Name
		local furnitureAction = "Seat1"
		
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
			print("✅ Successfully called ActivateFurniture for " .. furnitureName .. "!")
		else
			warn("❌ Failed to call ActivateFurniture:", tostring(result))
		end
	else
		warn("❌ Could not find " .. furnitureName .. " inside the " .. locationName .. " interior.")
	end

	local ailmentCompleted = false
	local connection = AilmentsManager.get_ailment_completed_signal():Connect(function(instance, key)
		if key == ailmentData.entityUniqueKey and instance == ailmentData.ailmentInstance then
			ailmentCompleted = true
		end
	end)
	
	local timeout = 60
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
	
	InteriorsM.enter_smooth(destinationId_Return, doorIdForTeleport_Return, teleportSettings_Return, nil)
	
	task.wait(2)
	print("Successfully returned to housing.")
end

local function cleanupAilment(ailmentData)
	local ailmentId = ailmentData.ailmentId

	if ailmentId == "ride" then
		if ailmentData.unequipItemId and UnequipRemote then
			local success, result = pcall(function()
				return UnequipRemote:InvokeServer(ailmentData.unequipItemId)
			end)
			if success then
				print("✅ Unequipped stroller with ID:", ailmentData.unequipItemId, "after 'ride' ailment.")
			else
				warn("Failed to unequip stroller:", result)
			end
		end
	elseif ailmentId == "walk" then
		if ailmentData.petModel and EjectBabyRemote then
			local success, result = pcall(function()
				EjectBabyRemote:FireServer(ailmentData.petModel)
			end)
			if success then
				print("✅ Unheld/Ejected pet after 'walk'/'ride' ailment.")
			else
				warn("Failed to unhold/eject pet:", result)
			end
		end
	end
end

local function processAilment(ailmentData)
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

end

local function handleNextAilment()
	if not isProcessingAilment and #ailmentsToProcess > 0 then
		local data = table.remove(ailmentsToProcess, 1)
		task.spawn(function()
			processAilment(data)
		end)
	end
end

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

	if LOCATION_MAPPING[ailmentId] and not queuedAilments[queueKey] then
		queuedAilments[queueKey] = true
		table.insert(ailmentsToProcess, {
			ailmentId = ailmentId,
			entityUniqueKey = entityUniqueKey,
			entityRef = entityRef,
			ailmentInstance = ailmentInstance,
		})
		print("✅[New Ailment Detected]:", ailmentId, "for pet key:", entityUniqueKey, ". Added to queue.")

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
	
	logAilmentRemoved(ailmentInstance, entityUniqueKey, entityRef)
	
	local ailmentEntry = activeAilments[entityUniqueKey] and activeAilments[entityUniqueKey][getAilmentIdFromInstance(ailmentInstance)]
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

	task.spawn(handleNextAilment)
end

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

local function runMainLogic()
	createAilmentPlatform()

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

	task.spawn(initialAilmentScan)
end

print("✅Ailment Manager Script initializing...")

runMainLogic()

-- This is a LocalScript (put in StarterPlayerScripts or similar)
-- This script is designed to automatically teleport the local player to their house,
-- then move them to a new platform, and finally activate specific furniture items.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")

-- Attempt to require necessary modules.
local InteriorsM = nil
local UIManager = nil 

local successInteriorsM, errorMessageInteriorsM = pcall(function()
    InteriorsM = require(ReplicatedStorage.ClientModules.Core.InteriorsM.InteriorsM)
end)

if not successInteriorsM then
    warn("Failed to require InteriorsM:", errorMessageInteriorsM)
    warn("Please ensure the path 'ReplicatedStorage.ClientModules.Core.InteriorsM.InteriorsM' is correct.")
    return
end

local successUIManager, errorMessageUIManager = pcall(function()
    UIManager = require(ReplicatedStorage:WaitForChild("Fsys")).load("UIManager")
end)

if not successUIManager or not UIManager then
    warn("Failed to require UIManager module:", errorMessageUIManager)
    warn("Could not load UIManager module. Teleport script might not function correctly.")
    return
end

print("InteriorsM and UIManager modules loaded successfully. Proceeding with automatic teleport setup.")

-- Define common teleport settings.
local teleportSettings = {
    fade_in_length = 0.5,
    fade_out_length = 0.4,
    fade_color = Color3.new(0, 0, 0),
    player_about_to_teleport = function() print("Player is about to teleport...") end,
    teleport_completed_callback = function()
        print("Teleport completed callback.")
        task.wait(0.2)
    end,
    player_to_teleport_to = nil,
    anchor_char_immediately = true,
    post_character_anchored_wait = 0.5,
    move_camera = true,
    door_id_for_location_module = nil,
    exiting_door = nil,
    house_owner = LocalPlayer,
}

-- Wait for house interior to stream before teleport.
local waitBeforeTeleport = 10
print(string.format("\nWaiting %d seconds for house interior to stream before teleport...", waitBeforeTeleport))
task.wait(waitBeforeTeleport)

print("\n--- Initiating Direct Teleport to Housing ---")
-- Call the enter_smooth function for the teleport.
InteriorsM.enter_smooth("housing", "MainDoor", teleportSettings, nil)
print(" automatic direct house teleport script initiated.")

-- Add a wait to ensure the teleport is fully complete before continuing.
task.wait(5) 


-- --- LOGIC TO CREATE AND TELEPORT TO A TRANSPARENT PLATFORM ---
local function createAndTeleportPlatform(player)
    -- Create the new platform Part.
    local platform = Instance.new("Part")
    platform.Name = "TeleportPlatform"
    platform.Size = Vector3.new(20, 1, 20)
    
    -- Make it transparent and set properties as requested.
    platform.Transparency = 1
    platform.CanCollide = true
    platform.Anchored = true
    
    -- Set the CFrame to a far-away, high position.
    platform.CFrame = CFrame.new(0, 200, -10000)
    platform.Parent = Workspace

    -- Wait for the player's character and HumanoidRootPart to load.
    local character = player.Character or player.CharacterAdded:Wait()
    local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

    -- Teleport the player on top of the platform.
    local newPosition = platform.CFrame * CFrame.new(0, platform.Size.Y/2 + humanoidRootPart.Size.Y/2, 0)
    humanoidRootPart.CFrame = newPosition
    print("Player teleported to the new transparent platform.")
    
    return character
end

local character = createAndTeleportPlatform(LocalPlayer)
-- Add a small wait for the character to settle on the new platform.
task.wait(1)

-- --- FURNITURE ACTIVATION LOGIC (AFTER TELEPORT) ---

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

-- Define the path to the furniture folder.
local furnitureFolder = Workspace:WaitForChild("HouseInteriors"):WaitForChild("furniture")

-- Get the first pet model from the Pets folder.
local petModel = nil
local petsFolder = Workspace:WaitForChild("Pets")
for _, petChild in ipairs(petsFolder:GetChildren()) do
    if petChild:IsA("Model") then
        petModel = petChild
        break
    end
end

if not petModel then
    warn("Could not find a pet model in the 'Pets' folder.")
end

-- Define the lists of furniture to check.
local furnitureItems = {
    "BasicCrib", <---- sleepy
    "PetFoodBowl", <---- hungry
    "PetWaterBowl",  <---- thirsty
    "CheapPetBathtub",<---- dirty
    "Toilet" <---- toilet
}

-- Combine the lists for processing.
local allItems = {}
for _, item in ipairs(furnitureItems) do table.insert(allItems, {name = item, isBaby = false}) end


if furnitureFolder then
    local player = Players:WaitForChild("new123ac76789")
    local head = character:WaitForChild("Head")
    local activateFurniture = ReplicatedStorage:WaitForChild("API"):WaitForChild("HousingAPI/ActivateFurniture")
    
    for _, item in ipairs(allItems) do
        local itemName = item.name
        local foundItem = findDeep(furnitureFolder, itemName)
        
        if foundItem then
            local furnitureParent = foundItem.Parent
            local parts = string.split(furnitureParent.Name, "/")
            local furnitureId = parts[#parts]
            
            print("Found the furniture ID for " .. itemName .. ": " .. furnitureId)

            local cframe = head.CFrame
            
            local args = {
                player,
                furnitureId,
                "UseBlock",
                {
                    cframe = cframe
                },
                petModel -- Use the first found pet model.
            }
            
            activateFurniture:InvokeServer(unpack(args))
            print("Successfully called ActivateFurniture for " .. itemName .. " with the found ID.")
        else
            warn("Could not find " .. itemName .. " inside the furniture folder.")
        end
    end
else
    warn("The 'furniture' folder could not be found.")
end

-- Gets the Players service to access the local player
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClientDataModule = require(ReplicatedStorage.ClientModules.Core.ClientData)
local Workspace = game:GetService("Workspace")

local function waitForData()
    local data = ClientDataModule.get_data()
    while not data do
        task.wait(0.5)
        data = ClientDataModule.get_data()
    end
    return data
end

-- --- MAIN SCRIPT EXECUTION ---
-- Get the local player and their character
local localPlayer = Players.LocalPlayer
local targetPlayerName = localPlayer.Name
local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
local humanoid = character:WaitForChild("Humanoid")

-- Create a new transparent platform far away and teleport the player
-- It's placed 1000 studs away in the Z direction and 50 studs up.
local platformSize = Vector3.new(20, 1, 20)
local platformPosition = humanoidRootPart.Position + Vector3.new(0, 50, 1000)

local newPlatform = Instance.new("Part")
newPlatform.Name = "TeleportPlatform"
newPlatform.Size = platformSize
newPlatform.CFrame = CFrame.new(platformPosition)
newPlatform.Anchored = true
newPlatform.CanCollide = true
newPlatform.Transparency = 1 -- Make the platform transparent
newPlatform.Parent = Workspace

print("Created a transparent platform at " .. tostring(platformPosition))

-- Teleport the player's character to the platform.
-- We add half of the platform's Y size plus a small offset to place the player on top.
humanoidRootPart.CFrame = CFrame.new(platformPosition + Vector3.new(0, platformSize.Y / 2 + 3, 0))
print("Teleported player to the platform.")

local serverData = waitForData()
local playerData = serverData[targetPlayerName]
local itemType = "strollers"

if playerData and playerData.inventory and playerData.inventory[itemType] then
    local playerItems = playerData.inventory[itemType]
    
    if next(playerItems) then
        local firstItemUniqueId = nil
        local firstItemSpeciesId = nil
        
        -- Find the first stroller in the inventory
        for uniqueId, itemData in pairs(playerItems) do
            firstItemUniqueId = uniqueId
            firstItemSpeciesId = itemData.id
            break -- Only need the first one
        end
        
        if firstItemUniqueId then
            print("Found a stroller to equip!")
            print("Species ID: " .. firstItemSpeciesId)
            print("Unique ID: " .. firstItemUniqueId)

            local args = {
                firstItemUniqueId,
                {
                    use_sound_delay = false,
                    equip_as_last = false
                }
            }
            
            local ToolEquipRemote = ReplicatedStorage:WaitForChild("API"):WaitForChild("ToolAPI/Equip")
            
            print("Attempting to equip the stroller...")
            local success, result = pcall(ToolEquipRemote.InvokeServer, ToolEquipRemote, unpack(args))
            
            if success then
                print("Successfully sent equip command! Check if your stroller is equipped.")
                -- Make the character jump a few times on the platform after the equip command is successful.
                for i = 1, 5 do
                    humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                    task.wait(1) -- Wait for 1 second between jumps
                end
            else
                print("Equip command failed: " .. tostring(result))
            end
        else
            print("No strollers found in your inventory.")
        end
    else
        print("No strollers found in your inventory.")
    end
else
    print("Required data tables not found for " .. itemType .. ".")
end

-- This is a LocalScript (put in StarterPlayerScripts or similar)
-- This script is designed to automatically teleport the local player to their house.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- Attempt to require necessary modules.
local InteriorsM = nil
local UIManager = nil -- We will load UIManager explicitly now

local successInteriorsM, errorMessageInteriorsM = pcall(function()
    InteriorsM = require(ReplicatedStorage.ClientModules.Core.InteriorsM.InteriorsM)
end)

if not successInteriorsM then
    warn("Failed to require InteriorsM:", errorMessageInteriorsM)
    warn("Please ensure the path 'ReplicatedStorage.ClientModules.Core.InteriorsM.InteriorsM' is correct.")
    return
end

local successUIManager, errorMessageUIManager = pcall(function()
    -- UIManager is often found in ReplicatedStorage or as a service.
    -- Based on the decompiled code, it's loaded via Fsys, which implies it's a module.
    UIManager = require(ReplicatedStorage:WaitForChild("Fsys")).load("UIManager")
end)

if not successUIManager or not UIManager then
    warn("Failed to require UIManager module:", errorMessageUIManager)
    warn("Attempting to get UIManager as a service (less likely for this context)...")
    UIManager = game:GetService("UIManager") -- Fallback, though less likely to be the correct UIManager for apps
    if not UIManager then
        warn("Could not load UIManager module or service. Teleport script might not function correctly.")
        return
    end
end


print("InteriorsM module loaded successfully. Proceeding with automatic teleport setup.")
print("UIManager module loaded successfully.")


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

-- --- DIRECT TELEPORT TO HOUSING (Replicating MagicHouseDoorInteractions Call) ---
local destinationId = "housing"
local doorIdForTeleport = "MainDoor" -- KEY: Using "MainDoor" as the door ID

-- Create a *minimal* settings table for the teleport, as seen in MagicHouseDoorInteractions
local teleportSettings = {
    house_owner = LocalPlayer; -- Pass the LocalPlayer object directly
}

-- Wait for house interior to stream. This duration might need adjustment based on your game's loading speed.
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

print("\nAdopt Me automatic direct house teleport script initiated.")

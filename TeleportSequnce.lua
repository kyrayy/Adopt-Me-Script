-- This is a LocalScript (put in StarterPlayerScripts or similar)
-- This script will automatically teleport the local player to multiple locations in sequence:
-- School, PizzaShop, Salon, VIP, and finally their House, with a delay between each teleport.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- --- Module Loading ---
local InteriorsM = nil
local UIManager = nil

-- Attempt to require InteriorsM
local successInteriorsM, errorMessageInteriorsM = pcall(function()
    InteriorsM = require(ReplicatedStorage.ClientModules.Core.InteriorsM.InteriorsM)
end)

if not successInteriorsM or not InteriorsM then
    warn("Failed to require InteriorsM:", errorMessageInteriorsM)
    warn("Please ensure the path 'ReplicatedStorage.ClientModules.Core.InteriorsM.InteriorsM' is correct and it returns a table.")
    return -- Cannot proceed without InteriorsM
end

print("InteriorsM module loaded successfully.")

-- Attempt to require UIManager (from your original PizzaShop/Salon scripts)
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
        warn("Could not load UIManager module or service. Some UI-related functionality might be affected.")
    end
end

print("UIManager module loaded successfully (if applicable).")

-- Debugging prints to check the type of InteriorsM and its enter_smooth property
print("Type of InteriorsM after require:", typeof(InteriorsM))
if typeof(InteriorsM) == "table" and InteriorsM.enter_smooth then
    print("Type of InteriorsM.enter_smooth:", typeof(InteriorsM.enter_smooth))
end

-- --- Generic Teleport Function ---
-- This function encapsulates the common logic for calling InteriorsM.enter_smooth.
-- It takes the destination ID, the second argument for enter_smooth (e.g., house owner name or door ID),
-- and the complete settings table for the teleport.
local function performTeleport(destinationId, secondArgumentForEnterSmooth, customTeleportSettings)
    print("\n--- Initiating Teleport to " .. destinationId .. " ---")
    print("Attempting to trigger automatic door teleport to destination:", destinationId)
    print("Using second argument for enter_smooth:", tostring(secondArgumentForEnterSmooth))
    
    -- IMPORTANT: Check if InteriorsM.enter_smooth is a function before calling it
    if typeof(InteriorsM) == "table" and typeof(InteriorsM.enter_smooth) == "function" then
        InteriorsM.enter_smooth(destinationId, secondArgumentForEnterSmooth, customTeleportSettings, nil)
        print("Teleport to " .. destinationId .. " initiated.")
    else
        warn("Error: InteriorsM.enter_smooth is not a function. Please check the 'InteriorsM' module. Skipping teleport to " .. destinationId .. ".")
        if typeof(InteriorsM) ~= "table" then
            warn("InteriorsM is not a table. Its actual type is: " .. typeof(InteriorsM))
        elseif InteriorsM.enter_smooth == nil then
            warn("InteriorsM.enter_smooth is nil (does not exist).")
        else
            warn("InteriorsM.enter_smooth exists but is not a function. Its actual type is: " .. typeof(InteriorsM.enter_smooth))
        end
    end
end

-- --- Define Teleport Settings for Each Location ---

-- Common settings for most teleports (can be extended or overridden per location)
local baseTeleportSettings = {
    fade_in_length = 0.5,
    fade_out_length = 0.4,
    fade_color = Color3.new(0, 0, 0),
    player_to_teleport_to = nil,
    anchor_char_immediately = true,
    post_character_anchored_wait = 0.5,
    move_camera = true,
    door_id_for_location_module = nil,
    exiting_door = nil,
}

-- School Teleport Settings
local schoolTeleportSettings = table.clone(baseTeleportSettings) -- Clone base settings
schoolTeleportSettings.spawn_cframe = CFrame.new(-11999.2021, 6956.3877, -3046.7124, -1, 8.99184105e-09, 6.68028477e-09, 8.99184105e-09, 1, 6.64605082e-08, -6.68028388e-09, 6.64605082e-08, -1)
schoolTeleportSettings.player_about_to_teleport = function() print("Player is about to teleport to School...") end
schoolTeleportSettings.teleport_completed_callback = function() print("Teleport to School completed callback."); task.wait(0.2) end

-- PizzaShop Teleport Settings
local pizzaShopTeleportSettings = table.clone(baseTeleportSettings)
pizzaShopTeleportSettings.spawn_cframe = CFrame.new(3000.79272, 6972.51465, -5935.65771, 0.999907732, 7.24115323e-10, 0.0135839125, -7.15150994e-10, 1, -6.64780953e-10, -0.0135839125, 6.5500505e-10, 0.999907732)
pizzaShopTeleportSettings.player_about_to_teleport = function() print("Player is about to teleport to PizzaShop...") end
pizzaShopTeleportSettings.teleport_completed_callback = function() print("Teleport to PizzaShop completed callback."); task.wait(0.2) end

-- Salon Teleport Settings
local salonTeleportSettings = table.clone(baseTeleportSettings)
salonTeleportSettings.spawn_cframe = CFrame.new(9075.83105, 6957.29834, 6006.72559, 1, 2.0051715e-08, -1.03284826e-13, -2.0051715e-08, 1, -4.51613431e-08, 1.02379266e-13, 4.51613431e-08, 1)
salonTeleportSettings.player_about_to_teleport = function() print("Player is about to teleport to Salon...") end
salonTeleportSettings.teleport_completed_callback = function() print("Teleport to Salon completed callback."); task.wait(0.2) end

-- VIP Teleport Settings
local vipTeleportSettings = table.clone(baseTeleportSettings)
vipTeleportSettings.spawn_cframe = CFrame.new(-3045.61719, 6846.86328, 12031.4531, 1, 8.82150104e-08, -8.73267054e-05, -8.82070097e-08, 1, 9.15622778e-08, 8.73267054e-05, -9.15545755e-08, 1)
vipTeleportSettings.player_about_to_teleport = function() print("Player is about to teleport to VIP...") end
vipTeleportSettings.teleport_completed_callback = function() print("Teleport to VIP completed callback."); task.wait(0.2) end

-- Housing Teleport Settings (as per your provided script, minimal settings)
local housingTeleportSettings = {
    house_owner = LocalPlayer; -- Pass the LocalPlayer object directly
    -- The other common settings like fade, callbacks, etc., are not explicitly defined here
    -- as the original housing script had a very minimal settings table.
    -- If you want the fade effects, you would need to add them here.
    fade_in_length = 0.5,
    fade_out_length = 0.4,
    fade_color = Color3.new(0, 0, 0),
    player_about_to_teleport = function() print("Player is about to teleport to their House...") end,
    teleport_completed_callback = function() print("Teleport to House completed callback."); task.wait(0.2) end,
    move_camera = true,
    anchor_char_immediately = true,
    post_character_anchored_wait = 0.5,
}

-- --- Sequential Teleport Calls ---
task.wait(2) -- Initial wait to ensure game services are ready

performTeleport("PizzaShop", LocalPlayer.Name, pizzaShopTeleportSettings)
task.wait(5) -- Wait 5 seconds before the next teleport

performTeleport("School", LocalPlayer.Name, schoolTeleportSettings)
task.wait(5) -- Wait 5 seconds before the next teleport

performTeleport("Salon", LocalPlayer.Name, salonTeleportSettings)
task.wait(5) -- Wait 5 seconds before the next teleport

performTeleport("VIP", LocalPlayer.Name, vipTeleportSettings)
task.wait(5) -- Wait 5 seconds before the next teleport

-- Housing Teleport
local waitBeforeHousingTeleport = 10 -- Wait for house interior to stream as per your script
print(string.format("\nWaiting %d seconds for house interior to stream before teleport...", waitBeforeHousingTeleport))
task.wait(waitBeforeHousingTeleport)

-- For housing, the second argument to enter_smooth is "MainDoor"
performTeleport("housing", "MainDoor", housingTeleportSettings)

print("\nAdopt Me automatic sequential teleport script completed all attempts.")

-- Full Script: Sequential Teleports with Path Countdown, starting with "Playground"

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace") -- Added Workspace service
local LocalPlayer = game:GetService("Players").LocalPlayer

-- --- Module Loading ---
local InteriorsM = nil
local UIManager = nil
local ClientDataModule = nil -- Declared globally
local PetMeAilmentModule = nil -- Declared globally for new logic

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

-- Attempt to require UIManager
local successUIManager, errorMessageUIManager = pcall(function()
    UIManager = require(ReplicatedStorage:WaitForChild("Fsys")).load("UIManager")
end)

if not successUIManager or not UIManager then
    warn("Failed to require UIManager module:", errorMessageUIManager)
    warn("Attempting to get UIManager as a service (less likely for this context)...")
    UIManager = game:GetService("UIManager")
    if not UIManager then
        warn("Could not load UIManager module or service. Some UI-related functionality might be affected.")
    end
end
print("UIManager module loaded successfully (if applicable).")

-- Attempt to require ClientDataModule
local successClientData, errorMessageClientData = pcall(function()
    ClientDataModule = require(ReplicatedStorage.ClientModules.Core.ClientData)
end)
if not successClientData or not ClientDataModule then
    warn("Failed to require ClientData module:", errorMessageClientData)
    warn("Please ensure the path 'ReplicatedStorage.ClientModules.Core.ClientData' is correct and it returns a table.")
    return -- Cannot proceed without ClientData
end
print("ClientData module loaded successfully.")

-- Attempt to require PetMeAilmentModule
local successPetMeAilment, errorMessagePetMeAilment = pcall(function()
    PetMeAilmentModule = require(ReplicatedStorage.new.modules.Ailments.AilmentsDB.pet_me)
end)
if not successPetMeAilment or not PetMeAilmentModule then
    warn("Failed to require PetMeAilment module:", errorMessagePetMeAilment)
    warn("Please ensure the path 'ReplicatedStorage.new.modules.Ailments.AilmentsDB.pet_me' is correct and it returns a table.")
    -- This is not a critical error for the whole script, so we don't return here.
end
print("PetMeAilment module loaded successfully (if applicable).")


-- Debugging prints to check the type of InteriorsM and its enter_smooth property
print("Type of InteriorsM after require:", typeof(InteriorsM))
if typeof(InteriorsM) == "table" and InteriorsM.enter_smooth then
    print("Type of InteriorsM.enter_smooth:", typeof(InteriorsM.enter_smooth))
end

-- RemoteFunctions/Events for API calls (assuming these paths are correct in your game)
local ToolEquipRemote = ReplicatedStorage:WaitForChild("API"):WaitForChild("ToolAPI/Equip")
local PetObjectCreateRemote = ReplicatedStorage:WaitForChild("API"):WaitForChild("PetObjectAPI/CreatePetObject")
local ServerUseToolEvent = ReplicatedStorage:WaitForChild("API"):WaitForChild("ToolAPI/ServerUseTool")
local ToolUnequipRemote = ReplicatedStorage:WaitForChild("API"):WaitForChild("ToolAPI/Unequip")
local AdoptAPIHoldBabyRemote = ReplicatedStorage:WaitForChild("API"):WaitForChild("AdoptAPI/HoldBaby") -- Added HoldBaby Remote


-- UI Status Label (Moved to ensure it's defined before being called)
local function createStatusUI()
    local playerGui = LocalPlayer:WaitForChild("PlayerGui")
    local gui = Instance.new("ScreenGui", playerGui)
    gui.Name = "TeleportStatusGUI"
    local label = Instance.new("TextLabel", gui)
    label.Name = "StatusLabel"
    label.Size = UDim2.new(0, 300, 0, 50)
    label.Position = UDim2.new(0.5, -150, 0, 10)
    label.BackgroundColor3 = Color3.new(0,0,0)
    label.TextColor3 = Color3.new(1,1,1)
    label.TextSize = 20
    label.Text = "Idle"
    return label
end
local statusLabel = createStatusUI()

local function updateStatus(text)
    if statusLabel then statusLabel.Text = text end
end

-- Function to create the large baseplate platform
local function createBaseplatePlatform()
    local platform = Instance.new("Part")
    platform.Name = "TeleportBaseplatePlatform"
    platform.Size = Vector3.new(500, 1, 500) -- Large, flat platform
    -- Create the platform at a very high, out-of-sight position initially
    platform.Position = Vector3.new(0, 10000, 0)
    platform.Color = Color3.fromRGB(85, 170, 0) -- Green color
    platform.Material = Enum.Material.Grass -- Optional: Make it look like grass
    platform.Anchored = true -- Essential so it doesn't fall
    platform.CanCollide = true -- Essential so players can stand on it
    platform.Parent = workspace

    print("Created TeleportBaseplatePlatform at initial hidden position: " .. tostring(platform.Position))
end

-- Function to get the target position for a given location type
local function getTargetPosition(targetType)
    if targetType == "Playground" then
        local part = workspace.StaticMap and workspace.StaticMap.Park and workspace.StaticMap.Park.AilmentTarget
        return part and part.Position
    elseif targetType == "BeachParty" then
        local part = workspace.StaticMap and workspace.StaticMap.Beach and workspace.StaticMap.Beach.BeachPartyAilmentTarget
        return part and part.Position
    elseif targetType == "Camp" then
        local part = workspace.StaticMap and workspace.StaticMap.Campsite and workspace.StaticMap.Campsite.CampsiteOrigin
        return part and part.Position
    elseif targetType == "PizzaShop" then
        -- Position extracted from original PizzaShop CFrame
        return Vector3.new(3000.79272, 6972.51465, -5935.65771)
    elseif targetType == "School" then
        -- Position extracted from original School CFrame
        return Vector3.new(-11999.2021, 6956.3877, -3046.7124)
    elseif targetType == "Salon" then
        -- Position extracted from original Salon CFrame
        return Vector3.new(9075.83105, 6957.29834, 6006.72559)
    elseif targetType == "House" or targetType == "housing" then
        -- Placeholder for House position. This might need to be adjusted based on your game's house system.
        -- If houses are instanced, you might need to get the CFrame of the player's specific house door.
        -- For now, using a generic central location for the platform.
        return Vector3.new(0, 100, 0) -- Example: a generic central spot for houses
    end
    return nil
end

-- Function to move the baseplate platform to a target position and return the spawn CFrame on it
local function moveBaseplateToTarget(targetPosition)
    local platform = workspace:FindFirstChild("TeleportBaseplatePlatform")
    if not platform then
        warn("TeleportBaseplatePlatform not found! Cannot move. Spawning at target position.")
        return CFrame.new(targetPosition + Vector3.new(0, 2, 0)) -- Fallback to direct spawn
    end

    -- Calculate the CFrame to place the platform such that its bottom is at targetPosition.Y
    -- Add a small offset (e.g., 0.1) to ensure it's visibly above if targetPosition.Y is ground level
    local offsetAboveTarget = 0.1
    local platformCFrame = CFrame.new(targetPosition.X, targetPosition.Y + offsetAboveTarget + (platform.Size.Y / 2), targetPosition.Z)
    platform.CFrame = platformCFrame

    -- Return the CFrame for the character to spawn slightly above the platform's new top surface
    local characterSpawnOffset = 2 -- Standard humanoid height offset
    return CFrame.new(targetPosition.X, platform.Position.Y + (platform.Size.Y / 2) + characterSpawnOffset, targetPosition.Z)
end


-- Updated taskOrder to remove "Shower" as its target part logic is being removed
local taskOrder = {"Playground", "BeachParty", "Camp", "PostCampLogic"}

local function getTargetPart(targetType)
    if targetType == "Playground" then
        return workspace.StaticMap and workspace.StaticMap.Park and workspace.StaticMap.Park.AilmentTarget
    elseif targetType == "BeachParty" then
        return workspace.StaticMap and workspace.StaticMap.Beach and workspace.StaticMap.Beach.BeachPartyAilmentTarget
    elseif targetType == "Camp" then
        return workspace.StaticMap and workspace.StaticMap.Campsite and workspace.StaticMap.Campsite.CampsiteOrigin
    -- No specific target part needed for "PostCampLogic" as it's not a direct teleport
    end
end

-- Helper: create floating message on a part
local function showFloatingMessage(targetPart, message)
    -- If targetPart is nil (because we're using the baseplate), we can attach the message to the baseplate itself
    local adorneePart = targetPart or workspace:FindFirstChild("TeleportBaseplatePlatform")
    if not adorneePart then return end

    -- Remove existing BillboardGuis on the part to prevent overlaps
    for _, gui in ipairs(adorneePart:GetChildren()) do
        if gui:IsA("BillboardGui") then
            gui:Destroy()
        end
    end
    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.new(0, 200, 0, 50)
    billboard.Adornee = adorneePart
    billboard.AlwaysOnTop = true
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.Parent = adorneePart

    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.TextColor3 = Color3.new(1, 1, 1)
    textLabel.TextScaled = true
    textLabel.Text = message
    textLabel.Parent = billboard

    return billboard
end

-- Show a countdown message on the path for 'seconds'
-- Now accepts locationName to make the message specific
local function showCountdownOnPath(targetPart, locationName, seconds)
    -- Create initial message
    local billboardGui = showFloatingMessage(targetPart, "Teleporting to " .. locationName .. " Platform... " .. seconds .. "s")
    -- Update message every second
    for i = seconds, 1, -1 do
        if billboardGui then
            local label = billboardGui:FindFirstChildOfClass("TextLabel")
            if label then
                label.Text = "Teleporting to " .. locationName .. " Platform... " .. i .. "s"
            end
        end
        task.wait(1)
    end
    -- Cleanup after countdown
    if billboardGui then billboardGui:Destroy() end
end

local function performTeleport(targetType)
    local targetPart = getTargetPart(targetType) -- This gets the actual map part for billboard
    local targetPos = getTargetPosition(targetType) -- This gets the position for platform movement and character spawn

    if not targetPos then
        warn("Target position for " .. targetType .. " not found! Skipping teleport.")
        return
    end

    local spawnCFrameToUse = moveBaseplateToTarget(targetPos)

    -- Prepare teleport settings
    local teleportSettings = {
        fade_in_length = 0.5,
        fade_out_length = 0.4,
        fade_color = Color3.new(0,0,0),
        player_about_to_teleport = function() print("About to teleport to "..targetType) end,
        teleport_completed_callback = function() print("Teleport to "..targetType.." complete") end,
        player_to_teleport_to = nil,
        anchor_char_immediately = true,
        post_character_anchored_wait = 0.5,
        move_camera = true,
        spawn_cframe = spawnCFrameToUse, -- Use the determined CFrame
        door_id_for_location_module = nil,
        exiting_door = nil,
    }

    -- Teleport
    print("Teleporting to " .. targetType .. "...")
    if typeof(InteriorsM.enter_smooth) ~= "function" then
        warn("InteriorsM.enter_smooth is not a function")
        return
    end
    local success, err = pcall(function()
        InteriorsM.enter_smooth("MainMap", targetType, teleportSettings, nil)
    end)
    if not success then
        warn("Teleport failed: " .. tostring(err))
        return
    end

    -- Wait for fade and initial teleport to finish
    task.wait(teleportSettings.fade_in_length + teleportSettings.fade_out_length + 1)

    -- Ensure character is loaded and then force CFrame to the platform
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if hrp then
        task.wait(0.2) -- Small wait for character to stabilize
        hrp.CFrame = spawnCFrameToUse -- Explicitly set CFrame
        task.wait(0.1) -- Small buffer after setting CFrame
    else
        warn("HumanoidRootPart not found after teleport to " .. targetType .. ". Cannot force CFrame.")
    end

    -- Show the path countdown - pass the actual targetPart or the moved baseplate platform as the adornee
    -- And pass the targetType as the locationName
    showCountdownOnPath(targetPart or workspace:FindFirstChild("TeleportBaseplatePlatform"), targetType, 100)
end

-- New function to handle logic after "Camp"
local function handlePostCampLogic()
    print("Starting post-Camp logic (new teleport sequence)...")

    -- --- Generic Teleport Function for this sequence ---
    -- This function encapsulates the common logic for calling InteriorsM.enter_smooth.
    -- It takes the destination ID, the second argument for enter_smooth (e.g., house owner name or door ID),
    -- and the complete settings table for the teleport.
    local function performSequentialTeleport(destinationId, secondArgumentForEnterSmooth, customTeleportSettings)
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

        -- Wait for fade and initial teleport to finish (even if teleport failed, to maintain sequence timing)
        task.wait(customTeleportSettings.fade_in_length + customTeleportSettings.fade_out_length + 1)

        -- Ensure character is loaded and then force CFrame to the platform
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            task.wait(0.2) -- Small wait for character to stabilize
            hrp.CFrame = customTeleportSettings.spawn_cframe -- Explicitly set CFrame
            task.wait(0.1) -- Small buffer after setting CFrame
        else
            warn("HumanoidRootPart not found after teleport to " .. destinationId .. ". Cannot force CFrame.")
        end

        -- Show the path countdown for sequential teleports
        -- For these, the platform itself is the target, so use it as the adornee.
        local adorneeForMessage = workspace:FindFirstChild("TeleportBaseplatePlatform")
        if adorneeForMessage then
            showCountdownOnPath(adorneeForMessage, destinationId, 100) -- Pass destinationId as locationName
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
    schoolTeleportSettings.player_about_to_teleport = function() print("Player is about to teleport to School...") end
    schoolTeleportSettings.teleport_completed_callback = function() print("Teleport to School completed callback."); task.wait(0.2) end
    schoolTeleportSettings.spawn_cframe = moveBaseplateToTarget(getTargetPosition("School")) -- Set CFrame via platform

    -- PizzaShop Teleport Settings
    local pizzaShopTeleportSettings = table.clone(baseTeleportSettings)
    pizzaShopTeleportSettings.player_about_to_teleport = function() print("Player is about to teleport to PizzaShop...") end
    pizzaShopTeleportSettings.teleport_completed_callback = function() print("Teleport to PizzaShop completed callback."); task.wait(0.2) end
    pizzaShopTeleportSettings.spawn_cframe = moveBaseplateToTarget(getTargetPosition("PizzaShop")) -- Set CFrame via platform

    -- Salon Teleport Settings
    local salonTeleportSettings = table.clone(baseTeleportSettings)
    salonTeleportSettings.player_about_to_teleport = function() print("Player is about to teleport to Salon...") end
    salonTeleportSettings.teleport_completed_callback = function() print("Teleport to Salon completed callback."); task.wait(0.2) end
    salonTeleportSettings.spawn_cframe = moveBaseplateToTarget(getTargetPosition("Salon")) -- Set CFrame via platform

    -- VIP Teleport Settings
    local vipTeleportSettings = table.clone(baseTeleportSettings)
    -- VIP retains its specific spawn_cframe and does NOT move the platform
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
        spawn_cframe = moveBaseplateToTarget(getTargetPosition("House")), -- Set CFrame via platform
    }

    -- --- Sequential Teleport Calls ---
    task.wait(2) -- Initial wait to ensure game services are ready before this sequence starts

    updateStatus("Current task: PizzaShop") -- Update status before teleport
    performSequentialTeleport("PizzaShop", LocalPlayer.Name, pizzaShopTeleportSettings)
    task.wait(5) -- Wait 5 seconds before the next teleport

    updateStatus("Current task: School") -- Update status before teleport
    performSequentialTeleport("School", LocalPlayer.Name, schoolTeleportSettings)
    task.wait(5) -- Wait 5 seconds before the next teleport

    updateStatus("Current task: Salon") -- Update status before teleport
    performSequentialTeleport("Salon", LocalPlayer.Name, salonTeleportSettings)
    task.wait(5) -- Wait 5 seconds before the next teleport

    updateStatus("Current task: VIP") -- Update status before teleport
    performSequentialTeleport("VIP", LocalPlayer.Name, vipTeleportSettings)
    task.wait(5) -- Wait 5 seconds before the next teleport

    -- Housing Teleport
    local waitBeforeHousingTeleport = 10 -- Wait for house interior to stream as per your script
    print(string.format("\nWaiting %d seconds for house interior to stream before teleport...", waitBeforeHousingTeleport))
    task.wait(waitBeforeHousingTeleport)

    updateStatus("Current task: House") -- Update status before teleport
    -- For housing, the second argument to enter_smooth is "MainDoor"
    performSequentialTeleport("housing", "MainDoor", housingTeleportSettings)

    print("\nAdopt Me automatic sequential teleport script completed all attempts.")

    -- --- START OF NEW LOGIC FOR HOUSE PLATFORM (Pet Interaction) ---
    -- Add a small wait to ensure character is fully on the platform
    task.wait(0.5)

    local platform = workspace:FindFirstChild("TeleportBaseplatePlatform")
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

    -- Check if player is on the House Platform before running pet logic
    if platform and hrp and (hrp.Position - platform.Position).Magnitude < 10 then -- Check if close to platform (adjust threshold if needed)
        updateStatus("Current task: Petting") -- Update status for pet interaction
        local myPetModel = nil

        local petsFolder = Workspace:FindFirstChild("Pets")
        if petsFolder and petsFolder:IsA("Folder") then
            print("Found 'Pets' folder in Workspace. Searching for a Model inside...")
            for _, child in ipairs(petsFolder:GetChildren()) do
                if child:IsA("Model") then
                    myPetModel = child
                    print("Found the first pet model:", myPetModel.Name)
                    break -- Found it, stop iterating
                end
            end
        else
            warn("Could not find a 'Pets' folder directly in Workspace.")
        end

        if myPetModel then -- Ensure a pet Model was found before proceeding
            if PetMeAilmentModule and type(PetMeAilmentModule) == "table" and PetMeAilmentModule.create_action then
                print("Found pet model. Calling create_action with pet...")
                -- Pass the found pet model as arg1 to create_action
                local inlineAction = PetMeAilmentModule.create_action(myPetModel)

                if type(inlineAction) == "table" and type(inlineAction.callback) == "function" then
                    print("Found 'callback' function on InlineAction object. Attempting to call it...")
                    inlineAction.callback() -- Call the function directly
                    print("'callback' function executed! 'start_petting()' should have been triggered.")
                else
                    warn("Could not find a 'callback' function on the InlineAction object.")
                    print("Type of inlineAction:", type(inlineAction))
                    for k, v in pairs(inlineAction) do
                        print("  Key:", k, "Value Type:", type(v))
                    end
                end
            else
                warn("The 'pet_me' module did not return a table with a 'create_action' function, or it's not the expected structure.")
                print("Type of PetMeAilmentModule:", type(PetMeAilmentModule))
            end
        else
            warn("No pet Model was found within the 'Pets' folder. Petting action cannot be triggered without a pet.")
        end
        task.wait(5) -- Give some time for pet interaction to run
    else
        warn("Player not detected on House Platform. Skipping pet interaction logic.")
        updateStatus("Petting skipped.")
        task.wait(1)
    end
    -- --- END OF NEW LOGIC FOR HOUSE PLATFORM (Pet Interaction) ---


    -- --- START OF ORIGINAL INVENTORY/JUMP LOGIC (Moved here) ---
    updateStatus("Current task: Inventory & Jumps") -- Update status for this section
    local serverData = waitForData()
    local playerData = serverData[LocalPlayer.Name] -- Get data for the local player

    -- Variable to store the unique ID of the equipped stroller, so it can be unequipped later
    local equippedStrollerUniqueId = nil

    if playerData and playerData.inventory then
        print("--- INVENTORY AND API ATTEMPTS FOR: " .. LocalPlayer.Name .. " ---")
        local foundAnyItems = false
        local shouldPerformFirstJumps = false -- Renamed for clarity

        --- TOYS INVENTORY AND API ATTEMPTS (Existing SqueakyBone Logic) ---
        if playerData.inventory.toys then
            local playerToys = playerData.inventory.toys
            print("\n--- OWNED TOY ITEMS ---")
            if next(playerToys) then
                foundAnyItems = true
                local firstToyUniqueId = nil
                local firstToySpeciesId = nil
                local squeakyBoneUniqueId = nil
                local squeakyBoneSpeciesId = "squeaky_bone_default" -- The specific toy to look for

                -- Find the first toy in the inventory and also look for "SqueakyBone"
                for uniqueId, toyData in pairs(playerToys) do
                    -- Debug print: Show every toy ID found
                    print(string.format("DEBUG: Found toy with Species ID: %s, Unique ID: %s", toyData.id, uniqueId))

                    -- Store the first toy found
                    if not firstToyUniqueId then
                        firstToyUniqueId = uniqueId
                        firstToySpeciesId = toyData.id
                    end

                    -- Check if this is the SqueakyBone
                    if toyData.id == squeakyBoneSpeciesId then
                        squeakyBoneUniqueId = uniqueId
                        print(string.format("DEBUG: Matched SqueakyBone with Unique ID: %s", squeakyBoneUniqueId))
                        -- Do NOT break here if you want to see all toy IDs.
                    end
                end

                -- Prioritize equipping SqueakyBone if found
                if squeakyBoneUniqueId then
                    print("DEBUG: SqueakyBone found, attempting to equip it and use it repeatedly with longer delays.")

                    -- Repeat actions 7 times
                    for i = 1, 7 do -- Loop 7 times
                        print(string.format("\n--- SqueakyBone Action Cycle %d of 7 ---", i))

                        attemptEquip(squeakyBoneUniqueId, squeakyBoneSpeciesId, "toy (SqueakyBone)")
                        task.wait(0.5) -- Longer delay after equip

                        attemptCreatePetObject(squeakyBoneUniqueId, "__Enum_PetObjectCreatorType_1")
                        task.wait(0.5) -- Longer delay after create pet object

                        attemptUseTool(squeakyBoneUniqueId, "START")
                        task.wait(0.5) -- Longer delay after START

                        attemptUseTool(squeakyBoneUniqueId, "END")
                        task.wait(0.5) -- Longer delay after END

                        task.wait(1) -- Even longer delay before the next full cycle
                    end
                    shouldPerformFirstJumps = true -- Set flag to perform jumps after SqueakyBone logic
                else
                    print("DEBUG: SqueakyBone not found in inventory. Attempting to equip the first available toy instead.")
                    -- Attempt to equip the first toy if SqueakyBone wasn't found
                    if attemptEquip(firstToyUniqueId, firstToySpeciesId, "toy") then
                        shouldPerformFirstJumps = true -- Set flag to perform jumps if any toy equipped
                    end
                end

            else
                print("No toys found in your inventory.")
            end
        else
            print("\nNo toy data table found in inventory.")
        end

        --- STROLLER INVENTORY AND EQUIP ATTEMPT ---
        if playerData.inventory.strollers then -- Corrected to 'strollers' (plural)
            local playerStrollers = playerData.inventory.strollers -- Corrected to 'strollers' (plural)
            print("\n--- OWNED STROLLER ITEMS ---")

            if next(playerStrollers) then
                foundAnyItems = true
                local firstStrollerUniqueIdLocal = nil -- Use a local variable here first
                local firstStrollerSpeciesId = nil

                -- Find the first stroller in the inventory
                for uniqueId, itemData in pairs(playerStrollers) do
                    firstStrollerUniqueIdLocal = uniqueId
                    firstStrollerSpeciesId = itemData.id
                    break -- Only need the first one
                end

                if firstStrollerUniqueIdLocal then
                    print("Found a stroller to equip!")
                    print("Species ID: %s", firstStrollerSpeciesId)
                    print("Unique ID: %s", firstStrollerUniqueIdLocal)

                    -- Direct equip logic as per your example
                    local args = {
                        firstStrollerUniqueIdLocal,
                        {
                            use_sound_delay = false,
                            equip_as_last = false
                        }
                    }

                    print("Attempting to equip the stroller...")
                    local success, result = pcall(ToolEquipRemote.InvokeServer, ToolEquipRemote, unpack(args))

                    if success then
                        print("Successfully sent equip command! Check if your stroller is equipped.")
                        equippedStrollerUniqueId = firstStrollerUniqueIdLocal -- Store for later unequip
                        shouldPerformFirstJumps = true -- Set flag to perform jumps
                    else
                        warn("Equip command for stroller failed: %s", tostring(result))
                        print("Stroller equip failed, not performing jumps based on stroller equip.")
                    end
                else
                    print("No strollers found in your inventory to equip.")
                end
            else
                print("No strollers found in your inventory.")
            end
        else
            print("\nNo stroller data table found in inventory.")
        end

        if not foundAnyItems then
            print("\nNo items found across toys or strollers in your inventory.")
        end

        --- Perform Jumps, Unequip, Hold Baby, and Second Jumps ---
        if shouldPerformFirstJumps then
            task.spawn(function()
                task.wait(2) -- Give some time for all previous actions to settle

                -- First set of jumps
                performHighJumps(10)
                task.wait(1) -- Wait for jumps to complete before unequip

                -- Unequip the stroller if it was equipped
                if equippedStrollerUniqueId then
                    print("\n--- Attempting to unequip the stroller ---")
                    attemptUnequip(equippedStrollerUniqueId)
                    task.wait(1) -- Wait for unequip to process
                else
                    print("\nNo stroller was equipped, skipping unequip step.")
                end

                -- Hold the first baby/pet model found in Workspace.Pets
                print("\n--- Attempting to hold the first baby/pet model ---")
                local petsFolder = Workspace:WaitForChild("Pets", 10) -- Wait up to 10 seconds for "Pets" folder
                if petsFolder then
                    local firstBabyModel = findFirstModel(petsFolder)
                    if firstBabyModel then
                        print(string.format("Found baby/pet model to hold: %s", firstBabyModel.Name))
                        local args = { firstBabyModel }
                        local success, result = pcall(AdoptAPIHoldBabyRemote.FireServer, AdoptAPIHoldBabyRemote, unpack(args))
                        if success then
                            print(string.format("Successfully sent HoldBaby command for %s!", firstBabyModel.Name))
                        else
                            warn(string.format("HoldBaby command for %s failed: %s", firstBabyModel.Name, tostring(result)))
                        end
                    else
                        warn("No baby/pet model (first model) found in Workspace.Pets to hold.")
                    end
                else
                    warn("Workspace.Pets folder not found.")
                end
                task.wait(1) -- Wait for HoldBaby to process

                -- Second set of jumps after unequip and hold baby
                print("\n--- Initiating SECOND set of High Jumps ---")
                performHighJumps(10)
            end)
        else
            print("\nNo items were successfully interacted with to trigger the jump sequences.")
        end

    else
        print("Required player data or inventory tables not found for %s", LocalPlayer.Name)
    end
    -- --- END OF ORIGINAL INVENTORY/JUMP LOGIC ---

    updateStatus("Finished sequence.") -- Revert to "Finished sequence" after all tasks
    task.wait(2) -- Small delay after the sequence
end


local function runSequence()
    for _, taskType in ipairs(taskOrder) do
        -- Only update status for the main tasks, PostCampLogic handles its own
        if taskType ~= "PostCampLogic" then
            updateStatus("Current task: " .. taskType)
        end

        if taskType == "PostCampLogic" then
            handlePostCampLogic()
        else
            performTeleport(taskType)
        end
        -- Optional delay between teleports/tasks
        -- task.wait(2)
    end
end

local function init()
    -- Create the baseplate platform first
    createBaseplatePlatform()

    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        LocalPlayer.CharacterAdded:Wait()
        wait(1)
    end
    updateStatus("Starting teleport sequence...")
    runSequence()
    updateStatus("Finished sequence.")
end

init()

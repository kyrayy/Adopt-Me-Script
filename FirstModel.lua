-- This script demonstrates how to get the first model from a folder in the Roblox Workspace.

-- First, we need to get a reference to the folder that contains the pets.
-- It's a good practice to use WaitForChild() to ensure the folder exists before the script tries to access it.
local petsFolder = workspace:WaitForChild("Pets")

-- Get a table of all the children (pets) inside the folder.
local allPets = petsFolder:GetChildren()

-- Check if the table is not empty before trying to access the first item.
-- If the folder is empty, allPets will be an empty table.
if #allPets > 0 then
	-- Get the first pet from the table.
	local firstPet = allPets[1]

	-- You can now do something with the first pet, like printing its name.
	print("The first pet found is: " .. firstPet.Name)
	
	-- Here's an example of what you might do with the pet.
	-- For instance, if the pet is a model, you can set its PrimaryPart.
	-- if firstPet:IsA("Model") and firstPet.PrimaryPart then
	-- 	firstPet.PrimaryPart.Transparency = 0.5
	-- end
else
	print("The 'Pets' folder is empty. No pets found.")
end

local db_url = "https://githubusercontent.com/kyrayy/Adopt-Me-Script/blob/main/DataBase.lua"
local whitelist = loadstring(game:HttpGet(db_url))()

if whitelist[game.Players.LocalPlayer.UserId] then
    print("Доступ разрешен!")

    game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = 50
else
    game.Players.LocalPlayer:Kick("Тебя нет в вайтлисте!")
end

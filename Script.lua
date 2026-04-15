local db_url = "https://github.com/kyrayy/Adopt-Me-Script/blob/main/DataBase.lua"
local whitelist = loadstring(game:HttpGet(db_url))()1111

if whitelist[game.Players.LocalPlayer.UserId] then
    print("Доступ разрешен!")
    
    -- ТВОЙ ОСНОВНОЙ КОД ПИШИ НИЖЕ ЭТОЙ СТРОКИ:
    game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = 50
    -- Сюда можно вставлять меню или другие функции
    
else
    -- Если твоего ID нет в DataBase.lua, тебя кикнет
    game.Players.LocalPlayer:Kick("Тебя нет в вайтлисте!")
end

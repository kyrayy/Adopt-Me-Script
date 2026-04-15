local db_url = "https://githubusercontent.com"
local whitelist = loadstring(game:HttpGet(db_url))()

if whitelist[game.Players.LocalPlayer.UserId] then
    print("Доступ разрешен!")
    
    -- ТВОЙ ОСНОВНОЙ КОД ПИШИ НИЖЕ ЭТОЙ СТРОКИ:
    game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = 50
    -- Сюда можно вставлять меню или другие функции
    
else
    -- Если твоего ID нет в DataBase.lua, тебя кикнет
    game.Players.LocalPlayer:Kick("Тебя нет в вайтлисте!")
end

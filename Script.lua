local db_url = "https://raw.githubusercontent.com/kyrayy/Adopt-Me-Script/refs/heads/main/DataBase.lua"


local success, result = pcall(function()
    return loadstring(game:HttpGet(db_url))()
end)

if success and result then
    local whitelist = result
    local userId = game.Players.LocalPlayer.UserId

    if whitelist[userId] then
        print("Доступ разрешен!")
        
        ---------сюда скрипт--------

    else
        game.Players.LocalPlayer:Kick("Тебя нет в вайтлисте!")
    end
else
    warn("Ошибка загрузки базы данных: " .. tostring(result))
end

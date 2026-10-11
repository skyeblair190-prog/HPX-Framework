-- Added for HPX: creates the md-drugs tables on resource start (mddrugs.sql only uses CREATE TABLE IF NOT EXISTS).
CreateThread(function()
    local sql = LoadResourceFile(GetCurrentResourceName(), 'mddrugs.sql')
    if not sql then return end
    for statement in sql:gmatch('[^;]+') do
        if statement:find('%S') then MySQL.query.await(statement) end
    end
end)

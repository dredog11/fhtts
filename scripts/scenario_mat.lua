require("json")

-- scenario mat
hidden_buttons = 1
debugSnapPoints = false
relativeStateButtonLocations = {
    persist = { 0.4, 0.01, -2 },
    lost = { 1.0, 0.01, -2 },
    fast = { -0.5, 0.01, -2 },
    slow = { -0.5, 0.01, -2 }
}

colors = { "Green", "Red", "White", "Blue" }

stateValues = {
    none = 0,
    persist = 1,
    lost = 2
}

function onSave()
    return JSON.encode({
        trackedGuids = trackedGuids,
        cardStates = cardStates,
        elementStates = elementStates,
        characterStates = characterStates,
        initiativeTypes = initiativeTypes
    })
end

-- current bg : http://cloud-3.steamusercontent.com/ugc/2035103391730369424/AFC2649C41791FBFF1C74226198868D4AE7506F5/


function onLoad(state)
    self.interactable = false
    if state ~= nil then
        local json = JSON.decode(state)
        if json ~= nil then
            if json.trackedGuids ~= nil then
                trackedGuids = json.trackedGuids
            end
            if json.cardStates ~= nil then
                cardStates = json.cardStates
            end
            if json.elementStates ~= nil then
                elementStates = json.elementStates
            end
            if json.characterStates ~= nil then
                characterStates = json.characterStates
            end
            initiativeTypes = json.initiativeTypes or {}
        end
    end

    if trackedGuids == nil then
        trackedGuids = {}
    end
    if elementStates == nil then
        elementStates = { fire = 0, ice = 0, air = 0, earth = 0, light = 0, dark = 0 }
    end
    if characterStates == nil then
        characterStates = {}
    end
    if initiativeTypes == nil then
        initiativeTypes = {}
    end
    isUpdateRunning = false

    updateUpdateRunning()

    for _, guid in ipairs(trackedGuids) do
        local obj = getObjectFromGUID(guid)
        obj.removeTag("lootable")
        onStandeeRegistered(obj)
    end

    --self.interactable = false
    if cardStates == nil then
        cardStates = {
            Green = { 0, 0, 0 },
            Red = { 0, 0, 0 },
            White = { 0, 0, 0 },
            Blue = { 0, 0, 0 }
        }
    end

    deckPositions = {}

    locateBoardElementsFromTags()

    -- print(JSON.encode({
    --     DrawButtons = DrawButtons,
    --     DrawDecks = DrawDecks,
    --     ChallengesDestinations = ChallengesDestinations,
    --     BackButtons = BackButtons
    -- }))

    -- toggle buttons for the various cards played
    for color, locations in pairs(cardLocations) do
        for i, location in pairs(locations) do
            for _, state in ipairs({ "persist", "lost" }) do
                -- local offset = relativeStateButtonLocations[offset]
                local fName = "toggleClick_" .. color .. "_" .. i .. "_" .. state
                local position = getStatePosition(color, i, state)
                position[1] = -position[1]
                button_parameters = getButtonParams(fName, "", position)
                self.setVar(fName, function() clickedToggle(color, i, state) end)
                self.createButton(button_parameters)
            end
        end
    end

    -- toggle buttons for the elements
    for element, position in pairs(elementsLocations) do
        local fName = "toggleElement_" .. element
        local buttonPosition = { -position.x, position.y + 0.02, position.z }
        local params = getButtonParams(fName, "Toggle " .. element, buttonPosition, 300, 300)
        self.setVar(fName, function(obj, color, alt) toggleElement(element, alt) end)
        self.createButton(params)
    end

    -- Hp and Xp buttons
    local buttonsToCreate = { "increment", "decrement" }
    for color, categories in pairs(hpAndXpLocations) do
        for category, positions in pairs(categories) do
            for _, action in ipairs(buttonsToCreate) do
                local position = positions[action]
                if position ~= nil then
                    local fName = "onButton_" .. color .. "_" .. category .. "_" .. action
                    local buttonPosition = { -position.x, position.y + 0.02, position.z }
                    self.setVar(fName, function() onButtonClicked(color, category, action) end)
                    local params = getButtonParams(fName, action .. " " .. category, buttonPosition, 150, 150)
                    self.createButton(params)
                end
            end
        end
    end

    -- round actions
    button_parameters = getButtonParams("onStart", "Start Round", { 4.3, 0.06, -10.25 }, 1150, 400)
    self.createButton(button_parameters)

    button_parameters = getButtonParams("onEnd", "End Round", { -4.3, 0.06, -10.25 }, 1150, 400)
    self.createButton(button_parameters)

    button_parameters = getButtonParams("onCleanup", "Delete all elements on the lighter section of the mat",
    { -15.5, 0.06, -10.25 }, 1100, 400)
    self.createButton(button_parameters)

    if debugSnapPoints then
        for _, point in pairs(self.getSnapPoints()) do
            print(point.position)
        end
    end

    -- tag based actions
    for _, point in pairs(self.getSnapPoints()) do
        tags = point.tags
        mTags = {}
        for _, tag in ipairs(tags) do
            mTags[tag] = true
        end

        isDeck = mTags["deck"] ~= nil
        isCurse = mTags["player curse"] ~= nil
        isBless = mTags["bless"] ~= nil
        isPlayerMinus1 = mTags["player minus 1"] ~= nil
        isGreen = mTags["Green"] ~= nil
        isRed = mTags["Red"] ~= nil
        isWhite = mTags["White"] ~= nil
        isBlue = mTags["Blue"] ~= nil

        color = nil
        if isGreen then
            color = "Green"
        elseif isRed then
            color = "Red"
        elseif isWhite then
            color = "White"
        elseif isBlue then
            color = "Blue"
        end


        if isDeck then
            if isCurse then
                deckPositions["player curse"] = point.position
            elseif isBless then
                deckPositions["bless"] = point.position
            elseif isPlayerMinus1 then
                deckPositions["player minus 1"] = point.position
            end
        else
            if color ~= nil then
                if isBless then
                    createActionButton("Bless", color, point.position)
                elseif isCurse then
                    createActionButton("Curse", color, point.position)
                elseif isPlayerMinus1 then
                    createActionButton("Minus1", color, point.position)
                end
            end
        end
    end

    -- Deck buttons
    if DrawButtons["Battle Goals"] ~= nil and DrawDecks["Battle Goals"] ~= nil then
        local pos = DrawButtons["Battle Goals"]
        local params = getButtonParams("drawBattleGoal", "Deal to all players", { -pos.x, pos.y + 0.02, pos.z })
        self.createButton(params)
    end

    if DrawButtons["Challenges"] ~= nil and DrawDecks["Challenges"] ~= nil then
        local pos = DrawButtons["Challenges"]
        local params = getButtonParams("drawChallenge", "Draw", { -pos.x, pos.y + 0.02, pos.z })
        self.createButton(params)
    end


    -- print(JSON.encode(BackButtons))

    for name, pos in pairs(BackButtons) do
        local fName = "returnChallenge_" .. name
        self.setVar(fName, function() returnChallenge(name) end)
        local params = getButtonParams(fName, "Return to bottom of draw deck",  { -pos.x, pos.y + 0.02, pos.z })
        self.createButton(params)
    end

    refreshDecals()
end

function getButtonParams(fName, tooltip, pos, width, height)
    return {
        function_owner = self,
        click_function = fName,
        label = "",
        tooltip = tooltip,
        position = pos,
        width = width or 200,
        height = height or 200,
        font_size = 50,
        color = { 1, 1, 1, 1 - hidden_buttons },
        scale = { 1, 1, 1 },
        font_color = { 0, 0, 0, 1 }
    }
end

function drawBattleGoal()
    -- Locate the deck
    local hitlist = Physics.cast({
        origin       = self.positionToWorld(DrawDecks["Battle Goals"]),
        direction    = { 0, 1, 0 },
        type         = 2,
        size         = { 1, 1, 1 },
        max_distance = 0,
        debug        = false
    })

    for i, j in pairs(hitlist) do
        if j.hit_object.tag == "Deck" then
            j.hit_object.deal(1)
        end
    end
end

function drawChallenge()
    -- find a destination
    local destination = findChallengeDestination()
    -- print(JSON.encode(destination))
    if destination ~= nil then
        local destinationPos = self.positionToWorld(ChallengesDestinations[destination])
        -- Locate the deck
        local hitlist = Physics.cast({
            origin       = self.positionToWorld(DrawDecks["Challenges"]),
            direction    = { 0, 1, 0 },
            type         = 2,
            size         = { 1, 1, 1 },
            max_distance = 0,
            debug        = false
        })
        for i, j in pairs(hitlist) do
            if j.hit_object.tag == "Card" then
                obj = j.hit_object
                obj.setPosition(shiftUp(destinationPos))
                obj.flip()
            elseif j.hit_object.tag == "Deck" then
                j.hit_object.takeObject({ position = shiftUp(destinationPos), flip = true })
            end
        end
    else
        broadcastToAll("No Challenge spot available")
    end
end

function returnChallenge(source)
    local destination = getChallengeDeck()

    local hitlist = getHitlist(ChallengesDestinations[source])
    for _, hit in pairs(hitlist) do
        if hit.hit_object.tag == "Card" then
            if destination == nil then
                hit.hit_object.setPosition(self.positionToWorld(DrawDecks["Challenges"]))
                hit.hit_object.flip()
            else
                destination.putObject(hit.hit_object)
            end
        end
    end
end

function getChallengeDeck()
    local hitlist = getHitlist(DrawDecks["Challenges"])
    for _, hit in pairs(hitlist) do
        if hit.hit_object.tag == "Card" or hit.hit_object.tag == "Deck" then
            return hit.hit_object
        end
    end
    return nil
end

function shiftUp(pos)
    return { pos[1], pos[2] + 0.05, pos[3] }
end

function getHitlist(relativePosition)
    return Physics.cast({
        origin       = self.positionToWorld(relativePosition),
        direction    = { 0, 1, 0 },
        type         = 2,
        size         = { 1, 1, 1 },
        max_distance = 0,
        debug        = false
    })
end

function findChallengeDestination()
    for _, candidate in ipairs({ "Active1", "Active2" }) do
        local hl2 = Physics.cast({
            origin       = self.positionToWorld(ChallengesDestinations[candidate]),
            direction    = { 0, 1, 0 },
            type         = 2,
            size         = { 1, 1, 1 },
            max_distance = 0,
            debug        = false
        })
        local used = false
        for _, h in pairs(hl2) do
            if h.hit_object.tag == "Card" or h.hit_object.tag == "Deck" then
                used = true
            end
        end
        if not used then
            return candidate
        end
    end
    return nil
end

function onButtonClicked(color, category, action)
    local playerMat = Global.call("getPlayerMatExt", { color })
    local characterName = playerMat.call("getCharacterName")
    if characterName ~= nil then
        local current = characterStates[characterName][category]
        if current ~= nil then
            local change = 0
            if action == "increment" then
                change = 1
            elseif action == "decrement" then
                change = -1
            end
            current = current + change
            if current < 0 then current = 0 end
            if current > 30 then current = 30 end
            characterStates[characterName][category] = current
            refreshDecals()
            updateAssistant("POST", "change", { target = characterName, what = category, change = change }, updateState)
        end
    end
end

function toggleElement(element, alt)
    if alt then
        elementStates[element] = 1
    elseif elementStates[element] == 2 then
        elementStates[element] = 0
    else
        elementStates[element] = 2
    end
    updateAssistant("POST", "setElement", { element = element, state = elementStates[element] })
    refreshDecals()
end

function createActionButton(action, color, position)
    --print("create " .. action .. " Button for ".. color)
    fName = "on" .. action .. "_" .. color
    self.setVar(fName, function() onAction(action, color) end)
    local pos = { -position[1], position[2], position[3] }
    params = {
        function_owner = self,
        click_function = fName,
        label = action,
        position = pos,
        width = 200,
        height = 200,
        font_size = 50,
        color = { 1, 1, 1, 1 - hidden_buttons },
        scale = { 1, 1, 1 },
        font_color = { 0, 0, 0, 1 - hidden_buttons }
    }
    self.createButton(params)
end

function onBless(color)
    moveCardFromTo("bless", color)
end

function onCurse(color)
    moveCardFromTo("player curse", color)
end

function onMinus1(color)
    moveCardFromTo("player minus 1", color)
end

function moveCardFromTo(deck, color)
    card = takeCardFrom(deck)
    if card ~= nil then
        card.flip()
        sendCardTo(card, color)
    end
end

function takeCardFrom(deck)
    deckPosition = deckPositions[deck]
    if deckPosition ~= nil then
        local hitlist = Physics.cast({
            origin       = self.positionToWorld(deckPosition),
            direction    = { 0, 1, 0 },
            type         = 2,
            size         = { 1, 1, 1 },
            max_distance = 0,
            debug        = false
        }) -- returns {{Vector point, Vector normal, float distance, Object hit_object}, ...}

        for i, j in pairs(hitlist) do
            if j.hit_object.tag == "Card" then
                return j.hit_object
            elseif j.hit_object.tag == "Deck" then
                return j.hit_object.takeObject({})
            end
        end
    end
    return nil
end

function sendCardTo(card, color)
    playerMat = Global.call("getPlayerMatExt", { color })
    if playerMat ~= nil then
        playerMat.call("addCardToAttackModifiers", { card })
    end
end

function returnCard(params)
    card = params[1]
    if card.hasTag("bless") then
        returnCardTo(card, deckPositions["bless"])
    elseif card.hasTag("player curse") then
        returnCardTo(card, deckPositions["player curse"])
    elseif card.hasTag("player minus 1") then
        returnCardTo(card, deckPositions["player minus 1"])
    end
end

function returnCardTo(card, position)
    local hitlist = Physics.cast({
        origin       = self.positionToWorld(position),
        direction    = { 0, 1, 0 },
        type         = 2,
        size         = { 1, 1, 1 },
        max_distance = 0,
        debug        = false
    }) -- returns {{Vector point, Vector normal, float distance, Object hit_object}, ...}

    if hitlist ~= nil then
        for i, j in pairs(hitlist) do
            if j.hit_object.tag == "Card" or j.hit_object.tag == "Deck" then
                j.hit_object.putObject(card)
                return
            end
        end
    end

    card.setPosition(self.positionToWorld(position))
end

function onAction(action, color)
    if action == "Bless" then
        onBless(color)
    elseif action == "Curse" then
        onCurse(color)
    elseif action == "Minus1" then
        onMinus1(color)
    end
end

function clickedToggle(color, card, name)
    --print("Clicked : " .. color .. "," .. card .. "," .. name)
    toggleState(color, card, stateValues[name])
end

function toggleState(color, card, state)
    currentState = cardStates[color][card]
    if currentState == state then
        setState(color, card, 0)
    else
        setState(color, card, state)
    end
end

function setState(color, card, state)
    cardStates[color][card] = state
    refreshDecals()
end

elementDecals = {
    fire = {
        "http://cloud-3.steamusercontent.com/ugc/2035103391730512339/983E473A83A1AE04151B470C4A0FBEFCDCCFAB05/",
        "http://cloud-3.steamusercontent.com/ugc/2035103391730231513/89FF10904ED889EB286C3EDFD59B8067A11CB914/",
        "http://cloud-3.steamusercontent.com/ugc/2035103391730231412/6B2719A39BEB7A4C43A29FCA3F4E4901EAACEF59/"
    },
    ice = {
        "http://cloud-3.steamusercontent.com/ugc/2035103391730512382/C238D61BBC2DF90EF82E6CED4814ADD44EF4A172/",
        "http://cloud-3.steamusercontent.com/ugc/2035103391730231612/ED743B202900553C6933FEB33045B6D67967C948/",
        "http://cloud-3.steamusercontent.com/ugc/2035103391730231568/38CEC6783DE0A6ED19D2A66A27DFB79F1B027FEC/",
    },
    air = {
        "http://cloud-3.steamusercontent.com/ugc/2035103391730512158/67D5198F0CFA0F42B05911A90FF61BEB5262137E/",
        "http://cloud-3.steamusercontent.com/ugc/2035103391730231889/659AF7BAD9A30322F8D75BF6DA2D7BADF3DA10A6/",
        "http://cloud-3.steamusercontent.com/ugc/2035103391730231017/CC169840C883C5354646AAC8FFBBB48C838619E5/",
    },
    earth = {
        "http://cloud-3.steamusercontent.com/ugc/2035103391730512282/D65A42A7797FAB3026DF480B581A81A831B57AA8/",
        "http://cloud-3.steamusercontent.com/ugc/2035103391730231316/E4EDCCB9A2D4BFBA4F758CD4A14C60A17F694555/",
        "http://cloud-3.steamusercontent.com/ugc/2035103391730231263/6BC4BDC7B2C57593DC43BA17A1ECCD977267F1DD/",
    },
    light = {
        "http://cloud-3.steamusercontent.com/ugc/2035103391730512435/885B9EB3B3A026E2AEA838DE08FAFCE416065645/",
        "http://cloud-3.steamusercontent.com/ugc/2035103391730231786/71EC8FDA0994605A82224B9158FB5271236A8DFE/",
        "http://cloud-3.steamusercontent.com/ugc/2035103391730231732/528533357276C83458B259BCEB464B10B4B4E807/",
    },
    dark = {
        "http://cloud-3.steamusercontent.com/ugc/2035103391730512201/A2ACA4BA06389A4D3824D9C174AD272451C3F487/",
        "http://cloud-3.steamusercontent.com/ugc/2035103391730231186/51B9CB0AB5F4DAF4B32682671BD9523AD800304A/",
        "http://cloud-3.steamusercontent.com/ugc/2035103391730231152/59157221D1B6F617643E9A948A626A119C6DD939/",
    }
}

numberDecals = {
    -- 0
    "http://cloud-3.steamusercontent.com/ugc/2035104110929705058/A94F238D1F996F5EB518007C0804EDCB424D79AE/",
    -- 1
    "http://cloud-3.steamusercontent.com/ugc/2035104110929705104/89E47BA0371962E664FFF5844BBBB2ACB375346B/",
    "http://cloud-3.steamusercontent.com/ugc/2035104110929705152/181569505DA792B8FA8663C233D234038AB963B2/",
    "http://cloud-3.steamusercontent.com/ugc/2035104110929705196/4387EF52E9756C7BCA7C73A9C4936E84EB298F1D/",
    "http://cloud-3.steamusercontent.com/ugc/2035104110929705237/E8D7796949B15DC9BE367794BF5F2C917B0C4FB3/",
    "http://cloud-3.steamusercontent.com/ugc/2035104110929705278/6206EFAA7886C682732686896A64132A34C90AA2/",
    -- 6
    "http://cloud-3.steamusercontent.com/ugc/2035104110929705320/2225985759A200B2255838C6B9F3711BAF53962D/",
    "http://cloud-3.steamusercontent.com/ugc/2035104110929705364/D415466DD20C39F4E54C60BE77FC05213FE86062/",
    "http://cloud-3.steamusercontent.com/ugc/2035104110929705364/D415466DD20C39F4E54C60BE77FC05213FE86062/",
    "http://cloud-3.steamusercontent.com/ugc/2035104110929705441/8C014333795006960CFCA37514E6CE39011C8D39/",
    "http://cloud-3.steamusercontent.com/ugc/2035104110929705476/B4DF46925BE4314AB0E16EDFCE8E197BDE9AC23E/",
    -- 11
    "http://cloud-3.steamusercontent.com/ugc/2035104110929705503/38EF039C34B86CE570CE80C851F3E01FD8C013B4/",
    "http://cloud-3.steamusercontent.com/ugc/2035104110929705533/679E2A2651DC119870F338E2E1F99DA3244E83E1/",
    "http://cloud-3.steamusercontent.com/ugc/2035104110929705571/3E7C2AB71E01288D0F7723F3C2A3AC241CB4C6EC/",
    "http://cloud-3.steamusercontent.com/ugc/2035104110929705598/A025872D019B601C4DF3FA5AD36BE0E24ABFF866/",
    "http://cloud-3.steamusercontent.com/ugc/2035104110929705627/98C7F2BA545154AF6BCE4CE459A705BE99607B91/",
    -- 16
    "http://cloud-3.steamusercontent.com/ugc/2035104110929705658/8E54F7FC6B4AEB5B0123ED4A2556DC307DB4AD3B/",
    "http://cloud-3.steamusercontent.com/ugc/2035104110929705693/36B180FB0C06D6D3D5D6BD6BF3DA77A86AEDA43E/",
    "http://cloud-3.steamusercontent.com/ugc/2035104110929705729/A5A3554316697D1C1FC4ADB4ACCC54432B77401B/",
    "http://cloud-3.steamusercontent.com/ugc/2035104110929705772/6CADB6483DA2BDFD1891BD967290D5FCEDE99782/",
    "http://cloud-3.steamusercontent.com/ugc/2035104110929705817/4F9CD23EB9EB78EB56A08D8874C74299634FD325/",
    -- 21
    "http://cloud-3.steamusercontent.com/ugc/2035104110929705865/14F9B88B8E1F0BF4A6191475E140196DD65F5A09/",
    "http://cloud-3.steamusercontent.com/ugc/2035104110929705909/CE7818305D98A9351F718F34112272A7D984F807/",
    "http://cloud-3.steamusercontent.com/ugc/2035104110929705956/9AF9D5075A1BEEB3CC192B78F073C15B7CF22B18/",
    "http://cloud-3.steamusercontent.com/ugc/2035104110929706009/63511EFFDD729316FCE339232289438662F4CC29/",
    "http://cloud-3.steamusercontent.com/ugc/2035104110929706064/4BE4FA76E6ED94764EC0AFE289B0D853B1E1AC27/",
    -- 26
    "http://cloud-3.steamusercontent.com/ugc/2035104110929706106/C6F3814AEFE9547598A8E3B5086015586E5AAC8C/",
    "http://cloud-3.steamusercontent.com/ugc/2035104110929706155/186648B526A23493B4A7869AAD8F7DF1AC4E2B7D/",
    "http://cloud-3.steamusercontent.com/ugc/2035104110929706203/D3476E30F4929B95AF7E65CE1F40899C90EC6A7B/",
    "http://cloud-3.steamusercontent.com/ugc/2035104110929706256/68A13533DEA9B3A4C899E3B994155EC37850274D/",
    "http://cloud-3.steamusercontent.com/ugc/2035104110929706302/D7F76671E78C5C7A1C10F0ADD4B73F9F5FF4A453/",
    "http://cloud-3.steamusercontent.com/ugc/2035104110929706343/045F706AA61462A36C7931E993AD8ED0E0F02505/",
}

function cacheDecals(decals)
    cacheDecalList(decals, cardActionDecals)
    cacheDecalList(decals, numberDecals)
    cacheDecalList(decals, conditionStickerUrls)
end

function cacheDecalList(decals, list)
    for _, url in ipairs(list) do
        cacheDecal(decals, url)
    end
end

function cacheDecal(decals, url)
    local decal = {
        position = { 0, -0.1, 0 },
        name = url,
        url = url,
        scale = { 1, 1, 1 },
        rotation = { 90, 0, 0 },
    }
    table.insert(decals, decal)
end

function maybeAddInitiativeToggleButton(color)
    local buttons = self.getButtons()
    for _, button in ipairs(buttons) do
        if button.click_function == "toggle_initiative_" .. color then
            -- Found it, no need to create a button
            return
        end
    end

    self.setVar("toggle_initiative_" .. color, function() toggleInitiative(color) end)
    local pos = getStatePosition(color, 1, "fast")
    local buttonPosition = { -pos[1], pos[2] + 0.02, pos[3] }
    local params = {
        function_owner = self,
        click_function = "toggle_initiative_" .. color,
        label = "",
        tooltip = "Switch between Fast and Slow",
        position = buttonPosition,
        width = 400,
        height = 200,
        font_size = 50,
        color = { 1, 1, 1, 1 - hidden_buttons },
        scale = { 1, 1, 1 },
        font_color = { 0, 0, 0, 1 - hidden_buttons }
    }
    self.createButton(params)
end

function toggleInitiative(color)
    print("Toggle initiative " .. color)
    if initiativeTypes[color] == nil or initiativeTypes[color] == "Fast" then
        initiativeTypes[color] = "Slow"
    else
        initiativeTypes[color] = "Fast"
    end
    refreshDecals()
end

function maybeRemoveInitiativeToggleButton(color)
    local buttons = self.getButtons()
    for _, button in ipairs(buttons) do
        if button.click_function == "toggle_initiative_" .. color then
            self.removeButton(button.index)
        end
    end
end

function updateCharacters()
    print("updateCharacters")
    for _, color in ipairs(colors) do
        local playerMat = Global.call("getPlayerMatExt", { color })
        if playerMat ~= nil then
            local characterName = playerMat.call("getCharacterName")
            if characterName ~= nil then
                if characterName == "Blinkblade" then
                    if initiativeTypes[color] == nil or initiativeTypes[color] == "Normal" then
                        initiativeTypes[color] = "Fast"
                    end
                    maybeAddInitiativeToggleButton(color)
                else
                    initiativeTypes[color] = "Normal"
                    maybeRemoveInitiativeToggleButton(color)
                end
            end
        else
            log("Could not find player mat " .. color)
        end
    end
    refreshDecals()
end

function refreshDecals()
    local decals = {}
    cacheDecals(decals)

    for color, states in pairs(cardStates) do
        for i, state in ipairs(states) do
            if state == 1 then
                table.insert(decals, getPersistDecal(color, i))
                table.insert(decals, getInactiveLostDecal(color, i))
            elseif state == 2 then
                table.insert(decals, getInactivePersistDecal(color, i))
                table.insert(decals, getLostDecal(color, i))
            else
                table.insert(decals, getInactivePersistDecal(color, i))
                table.insert(decals, getInactiveLostDecal(color, i))
            end
        end
    end

    for color, categories in pairs(hpAndXpLocations) do
        local playerMat = Global.call("getPlayerMatExt", { color })
        if playerMat == nil then
            log("Could not find player mat for " .. color)
        else
            local characterName = playerMat.call("getCharacterName")
            if characterName ~= nil then
                local state = characterStates[characterName]
                print("refreshing decals")
                for category, positions in pairs(categories) do
                    local labelPosition = positions["label"]
                    if labelPosition ~= nil then
                        local value = 0
                        if state ~= nil then
                            value = state[category] or 0
                        end
                        local url = numberDecals[value + 1]
                        if url ~= nil then
                            local decal = {
                                name = color .. "_" .. category .. "_" .. value,
                                url = url,
                                position = { labelPosition.x, labelPosition.y + 0.02, labelPosition.z },
                                rotation = { 90, 0, 0 },
                                scale = { 1, 1, 1 }
                            }
                            table.insert(decals, decal)
                        end
                    end
                end

                if initiativeTypes[color] ~= nil then
                    if initiativeTypes[color] == "Slow" then
                        local decal = getSlowDecal(color, 1)
                        decal.scale[1] = .8
                        table.insert(decals, decal)
                    elseif initiativeTypes[color] == "Fast" then
                        local decal = getFastDecal(color, 1)
                        decal.scale[1] = .8
                        table.insert(decals, decal)
                    end
                end
            end
        end
    end

    for element, elementState in pairs(elementStates) do
        local position = elementsLocations[element]
        if position ~= nil then
            local url = elementDecals[element][elementState + 1]
            if url ~= nil then
                local decal = {
                    name = element .. "_" .. elementState + 1,
                    url = url,
                    position = { position.x, position.y + 0.02, position.z },
                    rotation = { 90, 0, 0 },
                    scale = { .63, .63, .63 }
                }
                table.insert(decals, decal)
            end
        end
    end
    self.setDecals(decals)
end

cardActionDecals = {
    persit = "http://cloud-3.steamusercontent.com/ugc/2035103391730503108/916EF57D3AD98448D71B5A8E2C331E83A39F71D6/",
    lost = "http://cloud-3.steamusercontent.com/ugc/2035103391730503053/BBF9E517AC088D3D2EEEF0D40316210EDF39A8AE/",
    fast = "http://cloud-3.steamusercontent.com/ugc/2035104110936914421/C0373AA2715F00A0C68F2C59567A3D0A57A83DF2/",
    slow = "http://cloud-3.steamusercontent.com/ugc/2035104110936914522/C96BBBFB2392CCA611BCFB34E6A3B73A76F15AD8/",
    inactive_persist =
    "http://cloud-3.steamusercontent.com/ugc/2035103391730393072/A84E53160C7B92D6AFCFD25F9E9AFA7B29816FB7/",
    inactive_lost =
    "http://cloud-3.steamusercontent.com/ugc/2035103391730393295/CAA4420FEA5C40153A004F22A8465101A600F5A1/",
}

function getPersistDecal(color, card)
    return getDecal(color, card, "persist", cardActionDecals.persit)
end

function getLostDecal(color, card)
    return getDecal(color, card, "lost", cardActionDecals.lost)
end

function getFastDecal(color, card)
    return getDecal(color, card, "fast", cardActionDecals.fast)
end

function getSlowDecal(color, card)
    return getDecal(color, card, "slow", cardActionDecals.slow)
end

function getInactivePersistDecal(color, card)
    return getDecal(color, card, "persist", cardActionDecals.inactive_persist)
end

function getInactiveLostDecal(color, card)
    return getDecal(color, card, "lost", cardActionDecals.inactive_lost)
end

function getDecal(color, card, state, image)
    position = getStatePosition(color, card, state)
    --position[1] = -position[1]
    return {
        name = state,
        url = image,
        position = position,
        rotation = { 90, 0, 0 },
        scale = { .35, .35, .35 }
    }
end

function getStatePosition(color, card, state)
    -- print(JSON.encode({ color = color, card = card, state = state }))
    cardPosition = cardLocations[color][card]
    offset = relativeStateButtonLocations[state]
    -- print(JSON.encode({ cardPosition = cardPosition, offset=offset }))
    return {
        cardPosition[1] + offset[1],
        cardPosition[2] + offset[2],
        cardPosition[3] + offset[3],
    }
end

function onStart()
    -- flip all cards
    for color, cards in pairs(cardLocations) do
        for n, card in pairs(cards) do
            local hitlist = Physics.cast({
                origin       = self.positionToWorld(card),
                direction    = { 0, 1, 0 },
                type         = 2,
                size         = { 1, 1, 1 },
                max_distance = 0,
                debug        = false
            }) -- returns {{Vector point, Vector normal, float distance, Object hit_object}, ...}

            for i, j in pairs(hitlist) do
                if j.hit_object.tag == "Card" then
                    j.hit_object.flip()
                end
            end
        end
    end

    if isXHavenEnabled() then
        local initiatives = {}
        for color, cards in pairs(cardLocations) do
            playerMat = Global.call("getPlayerMatExt", { color })
            if playerMat ~= nil then
                characterName = playerMat.call("getCharacterName")
                if characterName ~= nil then
                    -- find the initiative card
                    local hitlist = Physics.cast({
                        origin       = self.positionToWorld(cardLocations[color][1]),
                        direction    = { 0, 1, 0 },
                        type         = 2,
                        size         = { 1, 1, 1 },
                        max_distance = 0,
                        debug        = false
                    })

                    for i, j in pairs(hitlist) do
                        if j.hit_object.tag == "Card" then
                            local cardName = j.hit_object.getName()
                            if cardName ~= nil then
                                local speed
                                local initiativeType = initiativeTypes[color] or "Normal"
                                if initiativeType == "Normal" or initiativeType == "Fast" then
                                    speed = tonumber(string.sub(cardName, 1, 2))
                                else
                                    speed = tonumber(string.sub(cardName, 4, 5))
                                end
                                initiatives[characterName] = speed
                            end
                        end
                    end

                    if initiatives[characterName] == nil then
                        initiatives[characterName] = 99
                    end
                end
            else
                log("Could not find player mat for " .. color)
            end
        end
        updateAssistant("POST", "startRound", initiatives)
    end
end

function onEnd()
    -- return cards to their respective mats
    for color, cards in pairs(cardLocations) do
        playerMat = Global.call("getPlayerMatExt", { color })
        if playerMat ~= nil then
            for n, card in pairs(cards) do
                local hitlist = Physics.cast({
                    origin       = self.positionToWorld(card),
                    direction    = { 0, 1, 0 },
                    type         = 2,
                    size         = { 1, 1, 1 },
                    max_distance = 0,
                    debug        = false
                }) -- returns {{Vector point, Vector normal, float distance, Object hit_object}, ...}

                for i, j in pairs(hitlist) do
                    if j.hit_object.tag == "Card" then
                        -- destination depends on state
                        state = cardStates[color][n]
                        playerMat.call("returnCard", { j.hit_object, state })
                    end
                end
            end

            -- send endTurn to Player Mats
            playerMat.call("endTurn")
        end
    end

    -- clearStates
    for color, cards in pairs(cardStates) do
        for i, card in ipairs(cards) do
            cardStates[color][i] = 0
        end
    end
    refreshDecals()

    -- clear drawn card
    Global.call("resetDrawnCard")

    updateAssistant("POST", "endRound")
end

function setScenario(params)
    updateAssistant("POST", "setScenario", params)
end

function spawned(params)
    local monster = params['monster']
    if isXHavenEnabled() then
        local isBoss = params['isBoss']
        local query = {
            monster = monster.getName(),
            isBoss = isBoss
        }
        updateAssistant(
            "POST",
            "addMonster",
            query,
            function(re)
                if re.response_code == 200 and re.text ~= nil and re.text ~= "" then
                    local inputs = monster.getInputs()
                    if inputs ~= nil then
                        input = inputs[1]
                        monster.editInput({ index = input.index, value = re.text })
                    end
                else
                    print("Could not fetch Standee number")
                end
            end
        )
    end
    registerStandee(monster)
end

function toggled(monster)
    updateAssistant("POST", "switchMonster", {
        monster = monster.getName(),
        nr = monster.getInputs()[1]["value"]
    })
end

function locateBoardElementsFromTags()
    cardLocations = {
        Green = { {}, {}, {} },
        Red = { {}, {}, {} },
        White = { {}, {}, {} },
        Blue = { {}, {}, {} }
    }

    elementsLocations = {
        air = {},
        earth = {},
        ice = {},
        fire = {},
        dark = {},
        light = {}
    }

    hpAndXpLocations = {
        Green = {
            hp = { decrement = {}, label = {}, increment = {} },
            xp = { decrement = {}, label = {}, increment = {} }
        },
        Red = {
            hp = { decrement = {}, label = {}, increment = {} },
            xp = { decrement = {}, label = {}, increment = {} }
        },
        White = {
            hp = { decrement = {}, label = {}, increment = {} },
            xp = { decrement = {}, label = {}, increment = {} }
        },
        Blue = {
            hp = { decrement = {}, label = {}, increment = {} },
            xp = { decrement = {}, label = {}, increment = {} }
        },
    }

    scenarioElementPositions = {}

    DrawButtons = {}

    DrawDecks = {}

    ChallengesDestinations = {}

    BackButtons = {}

    for _, point in ipairs(self.getSnapPoints()) do
        local tagsMap = {}
        local tagCount = 0
        for _, tag in ipairs(point.tags) do
            tagsMap[tag] = true
            tagCount = tagCount + 1
        end
        if tagsMap["ability card"] ~= nil then
            local color = getColorFromTags(tagsMap)
            if color ~= nil then
                local locations = cardLocations[color]
                local cardNr = 1
                if tagsMap["a1"] ~= nil then
                    cardNr = 1
                elseif tagsMap["a2"] ~= nil then
                    cardNr = 2
                else
                    cardNr = 3
                end
                locations[cardNr] = point.position
            end
        end
        if tagsMap["button"] ~= nil then
            if tagsMap["fire"] ~= nil then
                elementsLocations.fire = point.position
            elseif tagsMap["air"] ~= nil then
                elementsLocations.air = point.position
            elseif tagsMap["ice"] ~= nil then
                elementsLocations.ice = point.position
            elseif tagsMap["earth"] ~= nil then
                elementsLocations.earth = point.position
            elseif tagsMap["dark"] ~= nil then
                elementsLocations.dark = point.position
            elseif tagsMap["light"] ~= nil then
                elementsLocations.light = point.position
            elseif tagsMap["draw"] ~= nil then
                if tagsMap["challenges"] ~= nil then
                    DrawButtons["Challenges"] = point.position
                elseif tagsMap["battle goals"] ~= nil then
                    DrawButtons["Battle Goals"] = point.position
                end
            elseif tagsMap["back"] ~= nil and tagsMap["challenges"] ~= nil then
                if tagsMap["active1"] ~= nil then
                    BackButtons["Active1"] = point.position
                elseif tagsMap["active2"] ~= nil then
                    BackButtons["Active2"] = point.position
                end
            end
        end
        if tagsMap["deck"] ~= nil then
            if tagsMap["draw"] ~= nil then
                if tagsMap["battle goals"] ~= nil then
                    DrawDecks["Battle Goals"] = point.position
                elseif tagsMap["challenges"] ~= nil then
                    DrawDecks["Challenges"] = point.position
                end
            else
                if tagsMap["challenges"] ~= nil then
                    if tagsMap["active1"] ~= nil then
                        ChallengesDestinations["Active1"] = point.position
                    elseif tagsMap["active2"] ~= nil then
                        ChallengesDestinations["Active2"] = point.position
                    elseif tagsMap["discard"] ~= nil then
                        ChallengesDestinations["Discard"] = point.position
                    end
                end
            end
        end

        local color = getColorFromTags(tagsMap)
        if color ~= nil then
            local categories = { "hp", "xp" }
            for _, category in ipairs(categories) do
                if tagsMap[category] ~= nil then
                    if tagsMap["button"] ~= nil then
                        if tagsMap["minus"] ~= nil then
                            hpAndXpLocations[color][category]["decrement"] = point.position
                        elseif tagsMap["plus"] ~= nil then
                            hpAndXpLocations[color][category]["increment"] = point.position
                        end
                    elseif tagsMap["label"] ~= nil then
                        hpAndXpLocations[color][category]["label"] = point.position
                    end
                end
            end
        end

        if tagCount == 0 then
            -- untagged element, if in the upper area of the board,
            -- then this should be a scenario element point
            if point.position.z > 5 then
                table.insert(scenarioElementPositions, self.positionToWorld(point.position))
            end
        end
    end

    table.sort(scenarioElementPositions, comparePositions)
    --print(JSON.encode(cardLocations))
end

function comparePositions(pos1, pos2)
    if pos1.x < pos2.x then
        return true
    else
        return false
    end
end

function getScenarioElementPositions()
    return scenarioElementPositions
end

function getColorFromTags(tagsMap)
    for _, color in ipairs(colors) do
        if tagsMap[color] ~= nil then
            return color
        end
    end
    return nil
end

function sendCard(params)
    color = params[1]
    card = params[2]
    index = params[3]
    destination = self.positionToWorld(cardLocations[color][index])
    card.flip()
    card.setPosition(destination)
end

function onCleanup()
    Global.call('cleanup')
end

-- Standee functions
function registerStandee(standee)
    standee.addTag("tracked")
    onStandeeRegistered(standee)
    table.insert(trackedGuids, standee.guid)
    updateUpdateRunning()
    -- We can't rely on the last update anymore, as we have a new standee to update
    previousHash = ""
end

function onStandeeRegistered(standee)
    print("Tracking " .. standee.getName())

    -- We need to wait a bit to register for Collisions
    -- probably as the object isn't fully loaded yet?
    Wait.frames(function() standee.registerCollisions() end, 10)
    standee.addContextMenuItem("-1 health", damageStandee, true)
    standee.addContextMenuItem("+1 health", undamageStandee, true)
end

function onStandeeUnregistered(standee)
    print("Untracking " .. standee.getName())
    standee.removeTag("tracked")
    standee.removeTag("lootable")
    standee.unregisterCollisions()
    standee.clearContextMenu()
end

function damageStandee(color, position, standee)
    local name = standee.getName()
    local nr = 0
    local inputs = standee.getInputs()
    if inputs ~= nil then
        nr = tonumber(inputs[1].value)
    end
    updateAssistant("POST", "change", { target = name, nr = nr, what="hp", change = -1 }, updateState)
end

function undamageStandee(color, position, standee)
    local name = standee.getName()
    local nr = 0
    local inputs = standee.getInputs()
    if inputs ~= nil then
        nr = tonumber(inputs[1].value)
    end
    updateAssistant("POST", "change", { target = name, nr = nr, what="hp", change = 1 }, updateState)
end

function unregisterStandee(standee)
    for idx, guid in ipairs(trackedGuids) do
        if guid == standee.guid then
            table.remove(trackedGuids, idx)
            clearStandee(standee)
        end
    end
    standeeStates[standee.guid] = nil
    onStandeeUnregistered(standee)
    updateUpdateRunning()
end

function updateUpdateRunning()
    if isUpdateRunning then
        for _, _ in ipairs(trackedGuids) do
            return
        end
        isUpdateRunning = false
        print("isUpdateRunning : ", isUpdateRunning)
    else
        for _, _ in ipairs(trackedGuids) do
            isUpdateRunning = true
            refreshState()
            print("isUpdateRunning : ", isUpdateRunning)
            return
        end
    end
end

function refreshState()
    if isUpdateRunning then
        updateAssistant("GET", "state", {}, updateState)
    end
end

previousHash = ""
hasTrackedChanged = false
function updateState(request)
    -- print("Updating state")
    if request.is_done and not request.is_error then
        local hash = request.getResponseHeader("hash")
        if hash ~= nil and hash == previousHash then
            if isUpdateRunning then
                Wait.time(refreshState, 0.5)
            end
            return
        end
        previousHash = hash
        -- Parse and process the response
        local fullState = jsonDecode(request.text)
        processState(fullState)
    else
        print("Error Fetching State : ", request.error)
    end
    if isUpdateRunning then
        Wait.time(refreshState, 0.5)
    end
end

function processState(state)
    local newState = {}
    newState.round = {
        round = state.round,
        state = state.roundState
    }
    for _, entry in ipairs(state.currentList) do
        -- print(JSON.encode(entry))
        local id = entry.id
        -- We need to get rid of some of the (FH) and scenario specific monster names
        local searches = {' (FH)', ' Scenario 0'}
        for _,s in ipairs(searches) do
            local search = string.find(id, s, 1, true)
            if search ~= nil then
                id = string.sub(id, 1, search - 1)
            end
        end
        
        newState[id] = entry
        -- Handle summons separately
        if entry.characterState ~= nil then
            for _, summon in ipairs(entry.characterState.summonList) do
                local summonName = summon.name
                if summonName == "Shambling Skeleton" then
                    summonName = summonName .. " " .. summon.standeeNr
                end
                newState[summonName] = { characterState = summon }
            end
            characterStates[entry.id] = { hp = entry.characterState.health, xp = entry.characterState.xp }
        end
    end
    local elements = state.elements
    if elements ~= nil then
        for element, value in pairs(elements) do
            elementStates[element] = value
        end
        refreshDecals();
    end
    -- print(JSON.encode(newState))
    refreshStandees(newState)
end

function refreshStandees(state)
    for _, guid in ipairs(trackedGuids) do
        local standee = getObjectFromGUID(guid)
        if standee ~= nil then
            local found = false
            local name = standee.getName()
            local standeeNr = 1
            if name:sub(#name - 1, #name - 1) == " " and name:sub(#name, #name):find("%d") ~= nil then
                standeeNr = tonumber(name:sub(#name))
                name = name:sub(1, #name - 2)
            end
            -- log(name, standeeNr)
            -- We can't always assume there is a standeeNr, as bosses do not have one
            local inputs = standee.getInputs()
            if inputs ~= nil and inputs[1] ~= nil then
                standeeNr = tonumber(inputs[1].value)
            end

            local typeState = state[name]
            if typeState == nil then
                typeState = state[name .. " " .. standeeNr]
            end

            if typeState ~= nil then
                local instances = typeState.monsterInstances
                if instances ~= nil then
                    for _, instance in ipairs(instances) do
                        if instance.standeeNr == standeeNr then
                            -- copy the turn state from the type
                            instance.turnState = typeState.turnState
                            refreshStandee(standee, instance)
                            --print("Matched Standee, health : " .. instance.health .. " / " .. instance.maxHealth)
                            found = true
                        end
                    end
                else
                    -- Characters and Summons
                    local characterState = typeState.characterState
                    if characterState ~= nil then
                        -- copy the turn state from the type
                        characterState.turnState = typeState.turnState
                        refreshStandee(standee, characterState)
                        --print("Matched Standee, health : " .. instance.health .. " / " .. instance.maxHealth)
                        found = true
                    end
                end
            end
            if not found and standee.hasTag("deletable") and standee.hasTag("lootable") then
                local position = standee.getPosition()
                standee.destroyObject()
                -- loot
                getObjectFromGUID('5e0624').takeObject({ position = position, smooth = false })
            end
            if not found and standee.hasTag("trackable") then
                clearStandee(standee)
            end
        end
    end
end

conditionStickerUrls = {
    hp1 = "http://cloud-3.steamusercontent.com/ugc/2035103391709055343/7A64B372E18684E1E9DAB433C02217133D4DCCA3/",
    hp2 = "http://cloud-3.steamusercontent.com/ugc/2035103391709055385/AA663B8A8D8A1997060B9D4D3D7600617CAE8332/",
    hp3 = "http://cloud-3.steamusercontent.com/ugc/2035103391709055446/78B1A3C2C4E00F07B01BA81A108DD52156D7BBAE/",
    hp4 = "http://cloud-3.steamusercontent.com/ugc/2035103391709055481/625109B6E542E9B178441B7474F6207993B4CE9D/",
    hp5 = "http://cloud-3.steamusercontent.com/ugc/2035103391709055520/A4E6D2F93126548037DDA5FB8B6217EF1E01058A/",
    hp6 = "http://cloud-3.steamusercontent.com/ugc/2035103391709055566/7C3B6D8772CCE1EEF33CA6C22F2AE473ED969D32/",
    hp7 = "http://cloud-3.steamusercontent.com/ugc/2035103391709055620/0CE305DD7B81DEF45C48FEE25932E3599C6C5230/",
    hp8 = "http://cloud-3.steamusercontent.com/ugc/2035103391709055666/C832C26D2AEE472C233C4DABCC468680EF4965CF/",
    hp9 = "http://cloud-3.steamusercontent.com/ugc/2035103391709055713/124BE0A20873A0A286C206487BB05EC1BB3DE0B0/",
    hp10 = "http://cloud-3.steamusercontent.com/ugc/2035103391709055762/48D67B1D41430B081C975956A8AE06C792A58714/",
    hp11 = "http://cloud-3.steamusercontent.com/ugc/2035103391709055809/23ECF3DAE5372B72EA48A22CC57B74470B2ED5CB/",
    hp12 = "http://cloud-3.steamusercontent.com/ugc/2035103391709055863/8E747809AC673892E7D092B4D31FE121B7B67E69/",
    hp13 = "http://cloud-3.steamusercontent.com/ugc/2035103391709055906/209766A075F6DA806A6F9DAA25F910C01EAC9149/",
    hp14 = "http://cloud-3.steamusercontent.com/ugc/2035103391709055953/A8B9B9F4B64C7906CC84A7FD9D64AD8DD2A72707/",
    hp15 = "http://cloud-3.steamusercontent.com/ugc/2035103391709055999/7F9D1A06187C83F3031ACF92F6FB0682C0D99245/",
    hp16 = "http://cloud-3.steamusercontent.com/ugc/2035103391709056034/8929A4EC2C80A92B818AEF20CF67D026ECEDC6D7/",
    hp17 = "http://cloud-3.steamusercontent.com/ugc/2035103391709056078/A4BC8999CDB5D264D6395BD0C200FD46694E19B1/",
    hp18 = "http://cloud-3.steamusercontent.com/ugc/2035103391709056108/18147D154C883EEF05C1D027C9042B0E00CD96DA/",
    hp19 = "http://cloud-3.steamusercontent.com/ugc/2035103391709056140/7F8FFA939B5B601C9E2F68EEAA4E8B8643F83DB8/",
    hp20 = "http://cloud-3.steamusercontent.com/ugc/2035103391709056188/E96FA7B2FBD19672D299F80185F9BDF55EE1CFF6/",
    hp21 = "http://cloud-3.steamusercontent.com/ugc/2035103391709056216/F1568D22D7B317A20DAB8A9EF6DC2FE90441CE35/",
    hp22 = "http://cloud-3.steamusercontent.com/ugc/2035103391709056261/E928B4D5E8C65B63A297D4D828769DFB640552E4/",
    hp23 = "http://cloud-3.steamusercontent.com/ugc/2035103391709056306/0EB79936BCD1EFA1D337E700B7041C0A1A0C68CE/",
    hp24 = "http://cloud-3.steamusercontent.com/ugc/2035103391709056351/AFB76162D1CFB02E57163E3C037344BA8AA4C887/",
    immobilize = "http://cloud-3.steamusercontent.com/ugc/2035103391708914698/544D391BC3FFA0710CDCA0455E069D0BA3A0E516/",
    invisible = "http://cloud-3.steamusercontent.com/ugc/2035103391708914745/B7778CB621FAC723D1DCF709C6DD5F831D6BBD9B/",
    muddle = "http://cloud-3.steamusercontent.com/ugc/2035103391708914772/A1453591AAD62662071B05FF31327EF8724DB3D0/",
    poison = "http://cloud-3.steamusercontent.com/ugc/2035103391708914856/3D9BB599D8414AD9CE0C43A07C825D0092F26B84/",
    regenerate = "http://cloud-3.steamusercontent.com/ugc/2035103391708914955/5DE151FC580FC26277350DDA552C61E5CA0ED02C/",
    strengthen = "http://cloud-3.steamusercontent.com/ugc/2035103391708915016/45A93A5447EE74C6B981ED9CC7992AE26BE5EC5A/",
    stun = "http://cloud-3.steamusercontent.com/ugc/2035103391708915049/9B5A10A5C652DB0333BD177B66F09348DE05BF68/",
    ward = "http://cloud-3.steamusercontent.com/ugc/2035103391708915078/60939930CF3E926157A5BD018A5ABDC194C95147/",
    wound = "http://cloud-3.steamusercontent.com/ugc/2035103391708915110/06281870BFC2A6ABE6F02B095F48DFBFCAC3567E/",
    disarm = "http://cloud-3.steamusercontent.com/ugc/2035103391708914666/0B131D55F65331E55962A34A4EFB5A1433193AEE/",
    brittle = "http://cloud-3.steamusercontent.com/ugc/2035103391708914586/88F7DA427C9C3A0F57EA8E86CBB769DEF4FCF892/",
    bane = "http://cloud-3.steamusercontent.com/ugc/2035103391708914520/C764491CDC2E58A3CF6A712F49834B9D9880DC07/"
}

conditionsOrder = {
    "stun",
    "immobilize",
    "disarm",
    "wound",
    "wound2",
    "muddle",
    "poison",
    "poison2",
    "poison3",
    "poison4",
    "bane",
    "brittle",
    "chill",
    "infect",
    "impair",
    "rupture",
    "strengthen",
    "invisible",
    "regenerate",
    "ward",
    "dodge",
}

function noop()
end

standeeStates = {}
function refreshStandee(standee, instance)
    local xScaleFactor = 1.1
    local yScaleFactor = 1.1
    if standee.hasTag("token") then
        -- tokens are smaller and need an additional scale
        xScaleFactor = 4
        yScaleFactor = 1.3
    elseif standee.hasTag("overlay") then
        xScaleFactor = 0.6
        yScaleFactor = 0.7
    end
    if instance.health == 0 then
        clearStandee(standee)
        return
    end
    -- print(standee.getName() .. ": " .. JSON.encode(standee.getRotation()))
    local baseYRot = standee.getRotation().y
    local flip = (baseYRot > 90 and baseYRot < 270)
    if flip then
        baseYRot = 180
    else
        baseYRot = 0
    end
    standee.addTag("lootable")
    local stickers = {}
    local hp = math.ceil(instance.health * 24 / instance.maxHealth)
    local vec = mapToStandeeInfoArea(-0.05, 0, 0, xScaleFactor, yScaleFactor, flip)
    local hpSticker = {
        position = { vec.x, vec.y, vec.z },
        rotation = { 35, baseYRot, 0 },
        scale = { 1 * xScaleFactor, 0.16 * yScaleFactor, 0.1 },
        url = conditionStickerUrls["hp" .. hp],
        name = standee.guid .. "_hp_" .. hp
    }
    table.insert(stickers, hpSticker)

    local btnWidth = 0
    -- Create / Update a button for the HP
    local buttons = standee.getButtons()
    local buttonIdx = -1
    if buttons ~= nil then
        for _, button in ipairs(buttons) do
            if button.width == btnWidth then
                buttonIdx = button.index
            end
        end
    end
    vec = mapToStandeeInfoArea(0, 0, -0.005, xScaleFactor, yScaleFactor, flip)
    local rot = Vector(1, 0, 0)
    if not flip then
        rot:rotateOver('y', 180):normalize()
    end
    -- print("rot : " .. JSON.encode(rot) .. " hy " .. rot:heading('y'))
    local buttonParams = {
        function_owner = self,
        click_function = "noop",
        label = instance.health .. " / " .. instance.maxHealth,
        position = { vec.x, vec.y, vec.z },
        -- Hacky rotation calculations ... might need to figure out what's going on ...
        rotation = { -55 * rot.x, 540 - baseYRot, 55 * rot.z },
        width = btnWidth,
        height = 200,
        font_size = 160,
        color = { 1, 1, 1, 0 },
        scale = { .4 * xScaleFactor, .4 * yScaleFactor, .4 * yScaleFactor },
        font_color = { 1, 1, 1, 100 }
        --font_color = { 0,0,0,1 }
    }

    if buttonIdx == -1 then
        standee.createButton(buttonParams)
    else
        buttonParams.index = buttonIdx
        standee.editButton(buttonParams)
    end

    local nbConditions = 0
    local conditions = {}
    for _, idx in ipairs(instance.conditions) do
        local condition = conditionsOrder[idx + 1]
        if condition ~= nil then
            table.insert(conditions, condition)
            nbConditions = nbConditions + 1
        end
    end

    -- Special casing for looting (when going from turnState 1 to 2)
    if standee.hasTag("looter") and isEndOfRoundLootingEnabled() then
        --print(JSON.encode(instance))
        if standeeStates[standee.guid] ~= nil and
            standeeStates[standee.guid].turnState ~= nil and
            standeeStates[standee.guid].turnState == 1 and
            instance.turnState == 2 then
            print("End of round looting for " .. standee.getName())
            local position = standee.getPosition()
            local hitlist = Physics.cast({
                origin       = position,
                direction    = { 0, -1, 0 },
                type         = 1,
                max_distance = 3,
                debug        = false
            })
            local nbLoot = 0
            for _, item in pairs(hitlist) do
                if item.hit_object.getName() == "Loot" then
                    print("Found loot")
                    log(item.hit_object)
                    nbLoot = nbLoot + 1
                    destroyObject(item.hit_object)
                end
            end

            if nbLoot > 0 then
                updateAssistant("POST", "loot", { target = standee.getName(), count = nbLoot })
            end
        end
    end

    standeeStates[standee.guid] = {
        hp = instance.health,
        maxHp = instance.maxHealth,
        conditons = conditions,
        turnState = instance.turnState
    }
    --print(JSON.encode(conditions))
    if nbConditions > 0 then
        local xOffset = 0.13 * (nbConditions - 1) * xScaleFactor
        for _, condition in ipairs(conditions) do
            local url = conditionStickerUrls[condition]
            if url ~= nil then
                vec = mapToStandeeInfoArea(xOffset, 0.23, 0, xScaleFactor, yScaleFactor, flip)
                local sticker = {
                    position = { vec.x, vec.y, vec.z },
                    rotation = { 35, -baseYRot, 0 },
                    scale = { .23 * xScaleFactor, 0.23 * yScaleFactor, 0.23 },
                    url = url,
                    name = standee.guid .. "_" .. condition
                }
                table.insert(stickers, sticker)
                xOffset = xOffset - 0.26 * xScaleFactor
            end
        end
    end
    standee.setDecals(stickers)

    if instance.turnState ~= nil then
        if instance.turnState == 1 and isHighlightCurrentFiguresEnabled() then
            standee.highlightOn({ 1, 1, 1, 5 })
        elseif instance.turnState == 2 and isHighlightPastFiguresEnabled() then
            standee.highlightOn({ .4, .4, .4, 5 })
        else
            highlightOff(standee)
        end
    else
        highlightOff(standee)
    end
end

function highlightOff(standee)
    standee.highlightOff()
    local gmNotes = getGMNotes(standee)
    local settings = getSettings()
    if gmNotes.highlight ~= nil and (settings["enable-highlight-tiles-by-type"] or false) then
        standee.highlightOn(gmNotes.highlight)
    end
end

function mapToStandeeInfoArea(x, y, z, scaleX, scaleY, flip)
    -- base position in x/y plane
    local vec = Vector(x * scaleX, y * scaleY, z)
    -- incline the plane by 35 degrees
    vec:rotateOver('x', 35)
    -- go up towards the standee top
    vec:add(Vector(0, 0.95 * scaleY, 0))
    -- counter the standee rotation
    if flip then
        vec:rotateOver('y', 180)
    end

    return vec
end

function clearStandee(standee)
    local stickers = {}
    standee.setDecals(stickers)
    local buttonIdx = -1
    local buttons = standee.getButtons()
    if buttons ~= nil then
        for _, button in ipairs(buttons) do
            if button.width == 0 then
                buttonIdx = button.index
            end
        end
    end
    if buttonIdx ~= -1 then
        standee.removeButton(buttonIdx)
    end
end

function applyCondition(params)
    local standee = params[1]
    local condition = params[2]
    local name = standee.getName()
    local nr = 0
    local inputs = standee.getInputs()
    if inputs ~= nil then
        nr = tonumber(inputs[1].value)
    end
    updateAssistant("POST", "applyCondition", { target = name, nr = nr, condition = condition }, updateState)
end

lastSettingsUpdateTime = 0
settings = {}
function updateSettings()
    -- print(Time.time)
    if Time.time > lastSettingsUpdateTime + 1 then
        settings = JSON.decode(Global.call("getSettings"))
        lastSettingsUpdateTime = Time.time
    end
end

function getSettings()
    updateSettings()
    return settings or {}
end

function isEndOfRoundLootingEnabled()
    return getSettings()["enable-end-of-round-looting"] or false
end

function isHighlightCurrentFiguresEnabled()
    return getSettings()["enable-highlight-current-figurines"] or false
end

function isHighlightPastFiguresEnabled()
    return getSettings()["enable-highlight-past-figurines"] or false
end

function isXHavenEnabled()
    return getSettings()["enable-x-haven"] or false
end

function updateAssistant(method, command, params, callback)
    -- print("updateAssistant")
    if isXHavenEnabled() then
        local address = getSettings()["address"] or ""
        local port = getSettings()["port"] or ""
        if address ~= "" and port ~= "" then
            local url = "http://" .. address .. ":" .. port .. "/" .. command
            -- print(url)
            if method == "GET" then
                if callback ~= nil then
                    WebRequest.get(url, callback)
                else
                    -- fire and forget
                    WebRequest.get(url)
                end
            elseif method == "POST" then
                if params == nil then
                    params = {}
                end
                if callback ~= nil then
                    local payload = JSON.encode(params)
                    print(command .. ":" .. payload)
                    WebRequest.post(url, payload, callback)
                else
                    -- fire and forget
                    local payload = JSON.encode(params)
                    print(command .. ":" .. payload)
                    WebRequest.post(url, payload)
                end
            end
        end
    else
        if isUpdateRunning then
            Wait.time(refreshState, 0.5)
        end
    end
end


function getGMNotes(obj)
    local current = obj.getGMNotes()
    if current == nil or current == "" then
       current = {}
    else
       current = JSON.decode(current)
    end
    return current
 end
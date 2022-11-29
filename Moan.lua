local utf8 = require("utf8")

Moan = {
  indicatorCharacter = ">",
  optionCharacter = "=> ",
  indicatorDelay = 25,
  selectButton = "space",
  typeSpeed = 0.01,
  debug = false,
  mute = false,
  allMsgs = {},

  history = {},
  currentMessage  = "",
  currentMsgInstance = 1,
  currentMsgKey= 1,
  currentOption = 1,
  currentImage = nil,
  UI = {
    titleBoxPos = "left",
    messageboxPos = "bottom",
    imagePos = "left"
  }
}

-- Section of the text printed so far
local printedText  = ""
-- Timer to know when to print a new letter
local typeTimer    = Moan.typeSpeed
local typeTimerMax = Moan.typeSpeed
-- Current position in the text
local typePosition = 0
-- Initialise timer for the indicator
local indicatorTimer = 0
local defaultFont = love.graphics.newFont()

if Moan.font == nil then
  Moan.font = defaultFont
end

function Moan.speak(title, messages, config)
  if type(title) == "table" then
    titleColor = title[2]
    title = title[1]
  else -- just a string
    titleColor = {255, 255, 255}
  end

  -- Config checking / defaulting
  local config = config or {}
  local x = config.x
  local y = config.y
  local image = config.image or "nil"
  local options = config.options -- or {{"",function()end},{"",function()end},{"",function()end}}
  local onstart = config.onstart or function() end
  local oncomplete = config.oncomplete or function() end
  if image == nil or type(image) ~= "userdata" then
    -- image = Moan.noImage
  end

  -- Insert \n before text is printed, stops half-words being printed
  -- and then wrapped onto new line
  if Moan.autoWrap then
    for i=1, #messages do
      messages[i] = Moan.wordwrap(messages[i], 60)
    end
  end

  -- Insert the Moan.speak into its own instance (table)
  Moan.allMsgs[#Moan.allMsgs+1] = {
    title=title,
    titleColor=titleColor,
    messages=messages,
    x=x,
    y=y,
    image=image,
    options=options,
    onstart=onstart,
    oncomplete=oncomplete
  }
  Moan.history[#Moan.history+1] = {title, messages}

  -- Set the last message as "\n", an indicator to change currentMsgInstance
  Moan.allMsgs[#Moan.allMsgs].messages[#messages+1] = "\n"
  Moan.showingMessage = true

  -- Only run .onstart()/setup if first message instance on first Moan.speak
  -- Prevents onstart=Moan.speak(... recursion crashing the game.
  if Moan.currentMsgInstance == 1 then
    -- Set the first message up, after this is set up via advanceMsg()
    typePosition = 0
    Moan.currentMessage = Moan.allMsgs[Moan.currentMsgInstance].messages[Moan.currentMsgKey]
    Moan.currentTitle = Moan.allMsgs[Moan.currentMsgInstance].title
    Moan.currentImage = Moan.allMsgs[Moan.currentMsgInstance].image
    Moan.showingOptions = false
    -- Run the first startup function
    Moan.allMsgs[Moan.currentMsgInstance].onstart()
  end
end

-------------------------------------------------
-- Moan Message updater
-- @int dt love delta-time
--
-- @usage
-- function love.update(dt)
--   Moan.update(dt)
-- end
-------------------------------------------------
function Moan.update(dt)
  -- Check if the output string is equal to final string, else we must be still typing it
  if printedText == Moan.currentMessage then
    typing = false else typing = true
  end

  if Moan.showingMessage then
    -- Tiny timer for the message indicator
    if (Moan.paused or not typing) then
      indicatorTimer = indicatorTimer + 1
      if indicatorTimer > Moan.indicatorDelay then
        Moan.showIndicator = not Moan.showIndicator
        indicatorTimer = 0
      end
    else
      Moan.showIndicator = false
    end

    -- Check if we're the 2nd to last message, verify if an options table exists, on next advance show options
    if Moan.allMsgs[Moan.currentMsgInstance].messages[Moan.currentMsgKey+1] == "\n" and type(Moan.allMsgs[Moan.currentMsgInstance].options) == "table" then
      Moan.showingOptions = true
    end
    if Moan.showingOptions then
      -- Constantly update the option prefix
      for i=1, #Moan.allMsgs[Moan.currentMsgInstance].options do
        -- Remove the indicators from other selections
        Moan.allMsgs[Moan.currentMsgInstance].options[i][1] = string.gsub(Moan.allMsgs[Moan.currentMsgInstance].options[i][1], Moan.optionCharacter.." " , "")
      end
      -- Add an indicator to the current selection
      if Moan.allMsgs[Moan.currentMsgInstance].options[Moan.currentOption][1] ~= "" then
        Moan.allMsgs[Moan.currentMsgInstance].options[Moan.currentOption][1] = Moan.optionCharacter.." ".. Moan.allMsgs[Moan.currentMsgInstance].options[Moan.currentOption][1]
      end
    end

    -- Detect a 'pause' by checking the content of the last two characters in the printedText
    if string.sub(Moan.currentMessage, string.len(printedText)+1, string.len(printedText)+2) == "--" then
      Moan.paused = true
      else Moan.paused = false
    end

    --https://www.reddit.com/r/love2d/comments/4185xi/quick_question_typing_effect/
    if typePosition <= string.len(Moan.currentMessage) then
      -- Only decrease the timer when not paused
      if not Moan.paused then
        typeTimer = typeTimer - dt
      end
      -- Timer done, we need to print a new letter:
      -- Adjust position, use string.sub to get sub-string
      if typeTimer <= 0 then
        -- Only make the keypress sound if the next character is a letter
        if string.sub(Moan.currentMessage, typePosition, typePosition) ~= " " and typing then
          Moan.playSound(Moan.typeSound)
        end
        typeTimer = typeTimerMax
        typePosition = typePosition + 1
        -- UTF8 support, thanks @FluffySifilis
        local byteoffset = utf8.offset(Moan.currentMessage, typePosition)
        if byteoffset then
          printedText = string.sub(Moan.currentMessage, 0, byteoffset - 1)
        end
      end
    end
  end
end

-------------------------------------------------
-- Force Moan to progress onto the next message in the message queue
-- @usage
-- if love.keyboard.isDown("space") then Moan.advanceMsg() end
-------------------------------------------------
function Moan.advanceMsg()
  if Moan.showingMessage then
    -- Check if we're at the last message in the instances queue (+1 because "\n" indicated end of instance)
    if Moan.allMsgs[Moan.currentMsgInstance].messages[Moan.currentMsgKey+1] == "\n" then
      -- Last message in instance, so run the final function.
      Moan.allMsgs[Moan.currentMsgInstance].oncomplete()

      -- Check if we're the last instance in Moan.allMsgs
      if Moan.allMsgs[Moan.currentMsgInstance+1] == nil then
        Moan.currentMsgInstance = 1
        Moan.currentMsgKey = 1
        Moan.currentOption = 1
        typing = false
        Moan.showingMessage = false
        typePosition = 0
        Moan.showingOptions = false
        Moan.allMsgs = {}
      else
        -- We're not the last instance, so we can go to the next one
        -- Reset the msgKey such that we read the first msg of the new instance
        Moan.currentMsgInstance = Moan.currentMsgInstance + 1
        Moan.currentMsgKey = 1
        Moan.currentOption = 1
        typePosition = 0
        Moan.showingOptions = false
        Moan.moveCamera()
      end
    else
      -- We're not the last message and we can show the next one
      -- Reset type position to restart typing
      typePosition = 0
      Moan.currentMsgKey = Moan.currentMsgKey + 1
    end
  end

  -- Check showingMessage again - throws an error if next instance is nil otherwise
  if Moan.showingMessage then
    if Moan.currentMsgKey == 1 then
      Moan.allMsgs[Moan.currentMsgInstance].onstart()
    end
    Moan.currentMessage = Moan.allMsgs[Moan.currentMsgInstance].messages[Moan.currentMsgKey] or ""
    Moan.currentTitle = Moan.allMsgs[Moan.currentMsgInstance].title or ""
    Moan.currentImage = Moan.allMsgs[Moan.currentMsgInstance].image
  end
end

-------------------------------------------------
-- Draw Moan messagebox
--
-- @usage
-- function love.draw()
--   Moan.draw()
-- end
-------------------------------------------------
function Moan.draw()
  -- This section is mostly unfinished...
  -- Lots of magic numbers and generally takes a lot of
  -- trial and error to look right, beware.

  love.graphics.setDefaultFilter( "nearest", "nearest")
  if Moan.showingMessage then
    local scale = 0.26
    local margin = 10

    local boxH = (love.graphics.getHeight()/4)-(2*margin)
    local boxW = love.graphics.getWidth()-(2*margin)
    local boxX = margin
    local boxY = love.graphics.getHeight()-(boxH+margin)
    if Moan.UI.messageboxPos == "top" then boxY = 10 end

    local fontHeight = Moan.font:getHeight(" ")

    local imgX = (boxX+margin)*(1/scale)
    local imgY = (boxY+margin)*(1/scale)
    if type(Moan.currentImage) == "userdata" then
      imgW = Moan.currentImage:getWidth()
      imgH = Moan.currentImage:getHeight()
    else
      imgW = -10/(scale)
      imgH = 0
    end

    if Moan.UI.imagePos == "right" then
      imgX = ((boxX+boxW)*(1/scale))-(imgW+margin*(1/scale))
    end

    local titleBoxW = Moan.font:getWidth(Moan.currentTitle)+(2*margin)
    local titleBoxH = fontHeight+margin
    local titleBoxX = boxX
    -- overrides
    local titleBoxY = boxY-titleBoxH-(margin/2)
    if Moan.UI.messageboxPos == "top" then
      titleBoxY = boxY+boxH+margin
    end
    if Moan.UI.titleBoxPos == "right" then titleBoxX = boxX+boxW-(titleBoxW) end

    local titleColor = Moan.allMsgs[Moan.currentMsgInstance].titleColor
    local titleX = titleBoxX+margin
    local titleY = titleBoxY+2

    local textX = (imgX+imgW)/(1/scale)+margin
    local textY = boxY
    local msgTextY = textY+Moan.font:getHeight()/1.2
    local msgLimit = boxW-(imgW/(1/scale))-(4*margin)
    if Moan.UI.imagePos == "right" then textX = boxX+margin end

    local optionsY = textY+Moan.font:getHeight(printedText)-(margin/1.6)
    local optionsSpace = fontHeight/1.5

    local fontColour = { 255, 255, 255, 255 }
    local boxColour = { 0, 0, 0, 222 }


    love.graphics.setFont(Moan.font)

    -- Message title
    love.graphics.setColor(boxColour)
    love.graphics.rectangle("fill", titleBoxX, titleBoxY, titleBoxW, titleBoxH)
    love.graphics.setColor(titleColor)
    love.graphics.print(Moan.currentTitle, titleX, titleY)

    -- Main message box
    love.graphics.setColor(boxColour)
    love.graphics.rectangle("fill", boxX, boxY, boxW, boxH)
    love.graphics.setColor(fontColour)

    -- Message avatar
    if type(Moan.currentImage) == "userdata" then
      love.graphics.push()
        love.graphics.scale(scale, scale)
        love.graphics.draw(Moan.currentImage, imgX, imgY)
      love.graphics.pop()
    end

    -- Message text
    if Moan.autoWrap then
      love.graphics.print(printedText, textX, textY)
    else
      love.graphics.printf(printedText, textX, textY, msgLimit)
    end

    -- Message options (when shown)
    if Moan.showingOptions and typing == false then
      for k, option in pairs(Moan.allMsgs[Moan.currentMsgInstance].options) do
        -- First option has no Y margin...
        love.graphics.print(option[1], textX+margin, optionsY+((k-1)*optionsSpace))
      end
    end

    -- Next message/continue indicator
    if Moan.showIndicator then
      if not (Moan.UI.imagePos == "right" and type(Moan.currentImage) == "userdata") then
        love.graphics.print(Moan.indicatorCharacter, boxX+boxW-(2.5*margin), boxY+boxH-(margin/2)-fontHeight)
      end
    end
  end

  -- Reset fonts, run debugger if allowed
  love.graphics.setFont(defaultFont)
  if Moan.debug then
    Moan.drawDebug()
  end
end

-------------------------------------------------
-- Pass keys to Moan when pressed
-- @param key Keypress to be handed
--
-- @see keyreleased
-- @usage
-- function love.keypressed(key)
--   Moan.keypressed(key)
-- end
-------------------------------------------------
function Moan.keypressed(key)
  -- Lazily handle the keypress
  Moan.keyreleased(key)
end

-------------------------------------------------
-- Pass keys to Moan when key released
-- @param key Keyreleased to be handled
--
-- @see keypressed
-- @usage
-- function love.keyreleased(key)
--   Moan.keyreleased(key)
-- end
-------------------------------------------------
function Moan.keyreleased(key)
  if Moan.showingOptions then
    if key == Moan.selectButton and not typing then
      if Moan.currentMsgKey == #Moan.allMsgs[Moan.currentMsgInstance].messages-1 then
        -- Execute the selected option function
        for i=1, #Moan.allMsgs[Moan.currentMsgInstance].options do
          if Moan.currentOption == i then
            Moan.allMsgs[Moan.currentMsgInstance].options[i][2]()
            Moan.playSound(Moan.optionSwitchSound)
          end
        end
      end
      -- Option selection
      elseif key == "down" or key == "s" then
        Moan.currentOption = Moan.currentOption + 1
        Moan.playSound(Moan.optionSwitchSound)
      elseif key == "up" or key == "w" then
        Moan.currentOption = Moan.currentOption - 1
        Moan.playSound(Moan.optionSwitchSound)
      end
      -- Return to top/bottom of options on overflow
      if Moan.currentOption < 1 then
        Moan.currentOption = #Moan.allMsgs[Moan.currentMsgInstance].options
      elseif Moan.currentOption > #Moan.allMsgs[Moan.currentMsgInstance].options then
        Moan.currentOption = 1
    end
  end
  -- Check if we're still typing, if we are we can skip it
  -- If not, then go to next message/instance
  if key == Moan.selectButton then
    if Moan.paused then
      -- Get the text left and right of "--"
      leftSide = string.sub(Moan.currentMessage, 1, string.len(printedText))
      rightSide = string.sub(Moan.currentMessage, string.len(printedText)+3, string.len(Moan.currentMessage))
      -- And then concatenate them, kudos to @pfirsich for the help :)
      Moan.currentMessage = leftSide .. " " .. rightSide
      -- Put the typerwriter back a bit and start up again
      typePosition = typePosition - 1
      typeTimer = 0
    else
      if typing == true then
        -- Skip the typing completely, replace all -- with spaces since we're skipping the pauses
        Moan.currentMessage = string.gsub(Moan.currentMessage, "%-%-", " ")
        printedText = Moan.currentMessage
        typePosition = string.len(Moan.currentMessage)
      else
        Moan.advanceMsg()
      end
    end
  end
end

-------------------------------------------------
-- Change the typing speed of Moan
-- @string speed Type speed presets ("fast", "medium", "slow") __or__ some integer
-- @usage
-- Moan.setSpeed("slow")
-- Moan.setSpeed(0.10)
-------------------------------------------------
function Moan.setSpeed(speed)
  if speed == "fast" then
    Moan.typeSpeed = 0.01
  elseif speed == "medium" then
    Moan.typeSpeed = 0.04
  elseif speed == "slow" then
    Moan.typeSpeed = 0.08
  else
    assert(tonumber(speed), "Moan.setSpeed() - Expected number, got " .. tostring(speed))
    Moan.typeSpeed = speed
  end
  -- Update the timeout timer.
  typeTimerMax = Moan.typeSpeed
end

-------------------------------------------------
-- Define a HUMP camera for Moan to use
--
-- @param camToUse HUMP camera
-- @usage
-- Camera = require("HUMP.camera")
-- HUMPcam = Camera(10, 10)
-- Moan.setCamera(HUMPcam)
-------------------------------------------------
function Moan.setCamera(camToUse)
  Moan.currentCamera = camToUse
end

function Moan.moveCamera()
  -- Only move the camera if one exists
  if Moan.currentCamera ~= nil then
    -- Move the camera to the new instances position
    if (Moan.allMsgs[Moan.currentMsgInstance].x and Moan.allMsgs[Moan.currentMsgInstance].y) ~= nil then
      flux.to(Moan.currentCamera, 1, { x = Moan.allMsgs[Moan.currentMsgInstance].x, y = Moan.allMsgs[Moan.currentMsgInstance].y }):ease("cubicout")
    end
  end
end

function Moan.setTheme(style)
  for _, setting in pairs(Moan.UI) do
  end
end

function Moan.playSound(sound)
  if type(sound) == "userdata" and not Moan.mute then
    sound:play()
  end
end

-------------------------------------------------
-- Clear the current message container and close the message box
-------------------------------------------------
function Moan.clearMessages()
  Moan.showingMessage = false -- Prevents crashing
  Moan.currentMsgKey = 1
  Moan.currentMsgInstance = 1
  Moan.allMsgs = {}
end

-------------------------------------------------
-- Define an alternate message container (default: `Moan.allMsgs`)
--
-- @param table table Alternate messages container
-- @usage
-- aContainer = {}
-- Moan.defMsgContainer(aContainer)
-------------------------------------------------
function Moan.defMsgContainer(table)
  Moan.allMsgs = table
end

-------------------------------------------------
-- Display some debug information
---------------------------------------------------
function Moan.drawDebug()
  log = { -- It works...
    "typing", typing,
    "paused", Moan.paused,
    "showOptions", Moan.showingOptions,
    "indicatorTimer", indicatorTimer,
    "showIndicator", Moan.showIndicator,
    "printedText", printedText,
    "textToPrint", Moan.currentMessage,
    "currentMsgInstance", Moan.currentMsgInstance,
    "currentMsgKey", Moan.currentMsgKey,
    "currentOption", Moan.currentOption,
    "currentHeader", utf8.sub(Moan.currentMessage, utf8.len(printedText)+1, utf8.len(printedText)+2),
    "typeSpeed", Moan.typeSpeed,
    "typeSound", type(Moan.typeSound) .. " " .. tostring(Moan.typeSound),
    "Moan.allMsgs.len", #Moan.allMsgs,
    --"titleColor", unpack(Moan.allMsgs[Moan.currentMsgInstance].titleColor)
  }
  for i=1, #log, 2 do
    love.graphics.print(tostring(log[i]) .. ":  " .. tostring(log[i+1]), 10, 7*i)
  end
end

-- External UTF8 functions
-- https://github.com/alexander-yakushev/awesompd/blob/master/utf8.lua
function utf8.charbytes (s, i)
   -- argument defaults
   i = i or 1
   local c = string.byte(s, i)

   -- determine bytes needed for character, based on RFC 3629
   if c > 0 and c <= 127 then
      -- UTF8-1
      return 1
   elseif c >= 194 and c <= 223 then
      -- UTF8-2
      local c2 = string.byte(s, i + 1)
      return 2
   elseif c >= 224 and c <= 239 then
      -- UTF8-3
      local c2 = s:byte(i + 1)
      local c3 = s:byte(i + 2)
      return 3
   elseif c >= 240 and c <= 244 then
      -- UTF8-4
      local c2 = s:byte(i + 1)
      local c3 = s:byte(i + 2)
      local c4 = s:byte(i + 3)
      return 4
   end
end

function utf8.sub (s, i, j)
   j = j or -1

   if i == nil then
      return ""
   end

   local pos = 1
   local bytes = string.len(s)
   local len = 0

   -- only set l if i or j is negative
   local l = (i >= 0 and j >= 0) or utf8.len(s)
   local startChar = (i >= 0) and i or l + i + 1
   local endChar = (j >= 0) and j or l + j + 1

   -- can't have start before end!
   if startChar > endChar then
      return ""
   end

   -- byte offsets to pass to string.sub
   local startByte, endByte = 1, bytes

   while pos <= bytes do
      len = len + 1

      if len == startChar then
   startByte = pos
      end

      pos = pos + utf8.charbytes(s, pos)

      if len == endChar then
   endByte = pos - 1
   break
      end
   end

   return string.sub(s, startByte, endByte)
end

-- ripped from https://github.com/rxi/lume
function Moan.wordwrap(str, limit)
  limit = limit or 72
  local check
  if type(limit) == "number" then
    check = function(s) return #s >= limit end
  else
    check = limit
  end
  local rtn = {}
  local line = ""
  for word, spaces in str:gmatch("(%S+)(%s*)") do
    local s = line .. word
    if check(s) then
      table.insert(rtn, line .. "\n")
      line = word
    else
      line = s
    end
    for c in spaces:gmatch(".") do
      if c == "\n" then
        table.insert(rtn, line .. "\n")
        line = ""
      else
        line = line .. c
      end
    end
  end
  table.insert(rtn, line)
  return table.concat(rtn)
end

return Moan

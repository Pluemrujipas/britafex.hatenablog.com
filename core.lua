if not config then
  error("[criticalscripts.shop] cs-hall configuration file has a syntax error, please resolve it otherwise the resource will not work.")
  return
end

local version = "1.1.4"
local scaleformName = "cs_scaleform_hall_renderer"
local monitors = {}
local spotlights = {}
local speakers = {}
local smokers = {}
local sparklers = {}
local screens = {}
local effects = {}
local scaleform = {}
scaleform.ready = false
scaleform.draw = false
scaleform.tick = false
scaleform.failed = false
scaleform.solid = true
scaleform.handle = nil
scaleform.interval = nil
scaleform.first = nil
scaleform.position = nil
scaleform.rotation = nil
scaleform.scale = nil

local camSettings = {}
camSettings.dynamic = false

local musicData = {}
musicData.time = 0
musicData.playing = false

local defaultFrequencyLevels = {}
defaultFrequencyLevels.bass = 0
defaultFrequencyLevels.mid = 0
defaultFrequencyLevels.treble = 0
defaultFrequencyLevels.lowMid = 0
defaultFrequencyLevels.highMid = 0

local frequencyLevelsSmooth = {}
frequencyLevelsSmooth.current = {
  bass = 0,
  mid = 0,
  treble = 0,
  lowMid = 0,
  highMid = 0
}
frequencyLevelsSmooth.previous = {
  bass = 0,
  mid = 0,
  treble = 0,
  lowMid = 0,
  highMid = 0
}
frequencyLevelsSmooth.time = 0

local frequencyLevelsStatic = {
  bass = 0,
  mid = 0,
  treble = 0,
  lowMid = 0,
  highMid = 0
}

local frequencyLevelsFiltered = {
  bass = 0,
  mid = 0,
  treble = 0,
  lowMid = 0,
  highMid = 0
}

local vibrantColors = {}
vibrantColors.DarkVibrant = {0, 0, 0}
vibrantColors.Vibrant = {0, 0, 0}
vibrantColors.LightVibrant = {0, 0, 0}
vibrantColors.DarkMuted = {0, 0, 0}
vibrantColors.LightMuted = {0, 0, 0}

local tickData = {}
local hallEntry = {
  identifier = nil,
  enabled = false,
  active = false,
  playing = false,
  isUpdater = false,
  isController = false,
  screensAdvanced = false,
  time = 0,
  duration = 0,
  settings = {
    bass = {
      smoke = {
        cooldownMs = nil,
        colorWithDynamicSpotlights = nil
      },
      sparklers = {
        cooldownMs = nil,
        colorWithDynamicSpotlights = nil
      }
    },
    spotlights = {
      white = nil,
      dynamic = nil,
      photorythmic = nil,
      states = {},
      colors = {}
    },
    smokers = {
      colors = {}
    },
    sparklers = {
      colors = {}
    },
    speakers = {
      volumes = {}
    },
    idleWallpaperUrl = nil,
    videoToggle = nil
  },
  original = {},
  lastFrequencyLevels = defaultFrequencyLevels
}

local currentHallIdentifier = nil
local previousHallIdentifier = nil
local hallEntries = nil
local nearestHallEntry = nil
local playerId = nil
local playerPed = nil
local playerCoords = nil
local playerHeading = nil
local isPlayerDead = nil
local gameTimer = nil
local frameTime = 0
local gameplayCamCoords = 0
local gameplayCamRot = 0
local gameplayCamFov = 0
local musicSpeed = 0
local webViewId = 0

local hasPlayerRespawned = false
local hasPlayerBucketsChanged = false
local hasPlayerSpawned = false
local hasPlayerTeleported = false
local isHallPlayerVisible = false
local isPlayerInVehicle = false
local isPlayerInArea = false
local wasPlayerInArea = false
local isPlayerNearHall = false
local wasPlayerNearHall = false
local hasHallDataReceived = false
local hasHallDisappeared = false
local isNewHallEntry = false
local isHallEntryEnabled = true
local isHallEntryRefreshing = false
local isEffectsToggled = false
local isSpeakersToggled = false
local isScreensToggled = false
local isSmokersToggled = false
local isSparklerToggled = false
local isScreensAdvanced = false
local isSpotlightsColorToggled = false
local isSpotlightsWhiteToggled = false
local isUiHidden = false
local canDisplayScaleform = true

local frameTickMs = 250
local frequencyLevelsUpdateMs = 200
local frequencyLevelsFilterUpdateMs = 200
local frequencyLevelsFilterTolerance = 75
local assetLoadTimeoutMs = 100
local assetLoadUpdateMs = 25
local assetLoadAnimationMs = 50
local scaleformLoadMs = 100
local scaleformLoadTimeoutMs = 250
local spotlightToggleMs = 3000
local smokerToggleMs = 1000
local sparklerToggleMs = 1000
local tickReadyMs = 100
local tickPollMs = 100
local tickUpdateMs = 100
local updateTimeMs = 5000
local inputTimeMs = 1500
local multipleDistanceTreshold = 3
local areaDistanceTreshold = 1
local screenRefreshMs = 1500
local screenAdvancedRefreshMs = 2500

local isDebugEnabled = false
local isStartDebugEnabled = false
local debugText = nil
local debugSparklers = {}
local debugEffects = {}

function RotationToDirection(rotation)
  local radianZ = math.rad(rotation.z)
  local radianX = math.rad(math.min(math.max(rotation.x, -30.0), 30.0))
  local cosRadianX = math.abs(math.cos(radianX))
  
  return vector3(
    -math.sin(radianZ) * cosRadianX,
    math.cos(radianZ) * cosRadianX,
    math.sin(radianX)
  )
end

function IsPositionInsideArea(position, hall)
  local polygons = Ternary(hall, {hall}, config.entries[currentHallIdentifier].area.polygons and config.entries[currentHallIdentifier].area.polygons.entries)
  
  for i = 1, #polygons, 1 do
    local polygon = polygons[i]
    local inside = false
    
    if position.z >= polygon.height.min then
      if not (position.z < polygon.height.max) then
        if #polygons ~= 1 then
          goto continue
        end
        if position.z ~= polygon.height.max then
          goto continue
        end
      end
      
      local j = #polygon.points
      for k = 1, #polygon.points, 1 do
        local xi = polygon.points[k].x
        local yi = polygon.points[k].y
        local xj = polygon.points[j].x
        local yj = polygon.points[j].y
        
        if (yi > position.y) ~= (yj > position.y) then
          if position.x < (xj - xi) * (position.y - yi) / (yj - yi) + xi then
            inside = not inside
          end
        end
        j = k
      end
    end
    
    ::continue::
    if inside then
      return true
    end
  end
  return false
end

function RequestAssetModel(model, isSync)
  if HasModelLoaded(model) then
    return
  end
  
  local startTime = GetGameTimer()
  while true do
    if HasModelLoaded(model) then
      break
    end
    RequestModel(model)
    Wait(tickUpdateMs)
    if GetGameTimer() - startTime > Ternary(isSync, config.timeouts.assetLoadMs, config.timeouts.syncAssetLoadMs) then
      break
    end
  end
  
  if isSync then
    if not HasModelLoaded(model) then
      if model == 1036697368 or model == -824545400 or model == "cs_prop_hall_spotlight" or model == "h4_prop_battle_club_screen" then
        error("[criticalscripts.shop] cs-hall enabled configuration model \"" .. model .. "\" (" .. isSync .. ") which is included by default in \"cs-stream\" resource could not be loaded, consult the package's store page for further information.")
      else
        error("[criticalscripts.shop] cs-hall enabled configuration model \"" .. model .. "\" (" .. isSync .. ") could not be loaded.")
      end
    end
  end
end

function RequestAssetPtfx(asset, isSync)
  if HasNamedPtfxAssetLoaded(asset) then
    return
  end
  
  local startTime = GetGameTimer()
  while true do
    if HasNamedPtfxAssetLoaded(asset) then
      break
    end
    RequestNamedPtfxAsset(asset)
    Wait(tickUpdateMs)
    if GetGameTimer() - startTime > Ternary(isSync, config.timeouts.assetLoadMs, config.timeouts.syncAssetLoadMs) then
      break
    end
  end
  
  if isSync then
    if not HasNamedPtfxAssetLoaded(asset) then
      if asset == "scr_ba_club" or asset == "scr_ih_club" then
        error("[criticalscripts.shop] cs-hall enabled configuration effect \"" .. asset .. "\" (" .. isSync .. ") which is included by default in \"cs-stream\" resource could not be loaded, consult the package's store page for further information.")
      else
        error("[criticalscripts.shop] cs-hall enabled configuration effect \"" .. asset .. "\" (" .. isSync .. ") could not be loaded.")
      end
    end
  end
end

function CreateSpeakerOrSmokeOrSparklersMachine(objData)
  if not HasModelLoaded(objData.hash) then
    return
  end
  
  local entity = CreateObject(objData.hash, objData.position.x, objData.position.y, objData.position.z, false, true, false)
  SetEntityCoords(entity, objData.position.x, objData.position.y, objData.position.z)
  SetEntityHeading(entity, Ternary(objData.heading, objData.heading, 0.0))
  
  if objData.rotation then
    SetEntityRotation(entity, objData.rotation.x, objData.rotation.y, objData.rotation.z, 2)
  end
  
  if objData.quaternion then
    SetEntityQuaternion(entity, objData.quaternion.x, objData.quaternion.y, objData.quaternion.z, objData.quaternion.w)
  end
  
  if not objData.visible then
    SetEntityVisible(entity, false)
    SetEntityCompletelyDisableCollision(entity, false, false)
  end
  
  if objData.lodDistance then
    SetEntityLodDist(entity, objData.lodDistance)
  end
  
  FreezeEntityPosition(entity, true)
  return entity
end

function CreateSpotlight(objData)
  if not HasModelLoaded(objData.hash) then
    return
  end
  
  local entity = CreateObject(objData.hash, objData.position.x, objData.position.y, objData.position.z, false, true, false)
  SetEntityCoords(entity, objData.position.x, objData.position.y, objData.position.z)
  SetEntityHeading(entity, Ternary(objData.heading, objData.heading, 0.0))
  
  if objData.rotation then
    SetEntityRotation(entity, objData.rotation.x, objData.rotation.y, objData.rotation.z, 2)
  end
  
  if objData.quaternion then
    SetEntityQuaternion(entity, objData.quaternion.x, objData.quaternion.y, objData.quaternion.z, objData.quaternion.w)
  end
  
  if objData.lodDistance then
    SetEntityLodDist(entity, objData.lodDistance)
  end
  
  FreezeEntityPosition(entity, true)
  SetEntityLights(entity, false)
  SetObjectLightColor(entity, true, 0, 0, 0)
  return entity
end

function CreateMonitorOrScreen(objData)
  if not HasModelLoaded(objData.hash) then
    return
  end
  
  local entity = CreateObject(objData.hash, objData.position.x, objData.position.y, objData.position.z, false, true, false)
  SetEntityCoords(entity, objData.position.x, objData.position.y, objData.position.z)
  SetEntityHeading(entity, Ternary(objData.heading, objData.heading, 0.0))
  
  if objData.rotation then
    SetEntityRotation(entity, objData.rotation.x, objData.rotation.y, objData.rotation.z, 2)
  end
  
  if objData.quaternion then
    SetEntityQuaternion(entity, objData.quaternion.x, objData.quaternion.y, objData.quaternion.z, objData.quaternion.w)
  end
  
  if objData.lodDistance then
    SetEntityLodDist(entity, objData.lodDistance)
  end
  
  FreezeEntityPosition(entity, true)
  return entity
end

function RGB2HSL(rgb)
  local r = rgb[1] / 255
  local g = rgb[2] / 255
  local b = rgb[3] / 255
  local min = math.min(r, g, b)
  local max = math.max(r, g, b)
  local h, s
  local l = (max + min) / 2
  
  if max == min then
    h = 0
    s = 0
  else
    local diff = max - min
    s = Ternary(l > 0.5, diff / (2 - max - min), diff / (max + min))
    
    if max == r then
      h = (g - b) / diff + Ternary(g < b, 6, 0)
    elseif max == g then
      h = (b - r) / diff + 2
    elseif max == b then
      h = (r - g) / diff + 4
    end
    h = h / 6
  end
  
  return {h, s, l}
end

function Hue2RGB(p, q, t)
  if t < 0 then
    t = t + 1
  end
  if t > 1 then
    t = t - 1
  end
  
  if t < 0.16666666666666666 then
    return p + (q - p) * 6 * t
  end
  if t < 0.5 then
    return q
  end
  if t < 0.6666666666666666 then
    return p + (q - p) * (0.6666666666666666 - t) * 6
  end
  return p
end

function HSL2RGB(hsl)
  local h = hsl[1]
  local s = hsl[2]
  local l = hsl[3]
  local r, g, b
  
  if s == 0 then
    r = l
    g = l
    b = l
  else
    local q = Ternary(l < 0.5, l * (1 + s), l + s - l * s)
    local p = 2 * l - q
    r = Hue2RGB(p, q, h + 0.3333333333333333)
    g = Hue2RGB(p, q, h)
    b = Hue2RGB(p, q, h - 0.3333333333333333)
  end
  
  return {
    math.floor(math.round(r * 255)),
    math.floor(math.round(g * 255)),
    math.floor(math.round(b * 255))
  }
end

function LightenColor(color, amount)
  if amount == 0 then
    return {0, 0, 0}
  end
  
  local hsl = RGB2HSL(color)
  hsl[3] = hsl[3] * amount
  return HSL2RGB(hsl)
end

function AlterColorBrightness(original, target, factor)
  local result = original * (1 - factor) + target * factor
  return result
end

function Lerp(startValue, endValue, progress)
  return startValue + progress * (endValue - startValue)
end

function LerpCallback(startValue, endValue, duration, updateInterval, callback, condition, onComplete, threshold)
  local startTime = GetGameTimer()
  local finished = false
  
  CreateThread(function()
    while true do
      if finished then
        break
      end
      
      local currentTime = GetGameTimer()
      local elapsed = currentTime - startTime
      local progress = elapsed / duration
      
      if type(startValue) == "table" or type(endValue) == "table" then
        local result = {}
        for i = 1, #startValue, 1 do
          result[i] = Lerp(startValue[i], endValue[i], progress)
        end
        callback(result)
      else
        callback(Lerp(startValue, endValue, progress))
      end
      
      local progressPercent = progress * 100
      local thresholdValue = Ternary(threshold, threshold, 100)
      if progressPercent >= thresholdValue then
        break
      end
      
      if condition then
        if not condition() then
          break
        end
      end
      
      Wait(updateInterval)
    end
    
    if onComplete then
      onComplete()
    end
    finished = true
  end)
  
  return function()
    return finished
  end
end

function JumpPercentage(startValue, currentValue, endValue)
  local percentage = 0
  
  if type(startValue) == "table" then
    for i = 1, #startValue, 1 do
      local range = endValue[i] - startValue[i]
      if range ~= 0 then
        local progress = (currentValue[i] - startValue[i]) / range * 100
        if percentage == 0 or percentage > progress then
          percentage = progress
        end
      else
        percentage = 100
      end
    end
  else
    local range = endValue - startValue
    if range ~= 0 then
      percentage = (currentValue - startValue) / range * 100
    else
      percentage = 100
    end
  end
  
  if percentage > 100 then
    percentage = 100
  end
  return percentage
end

function CalculatePercentage(startValue, currentValue, endValue, callback)
  if type(startValue) == "table" then
    local result = {}
    for i = 1, #startValue, 1 do
      local value = startValue[i] + (currentValue / 100) * (endValue[i] - startValue[i])
      result[i] = value
    end
    callback(result)
  else
    local value = startValue + (currentValue / 100) * (endValue - startValue)
    callback(value)
  end
end

function GetSpotlightColor(stageIndex, spotlightIndex)
  local entry = spotlights[stageIndex]
  if not entry then
    return {0, 0, 0}
  else
    local color = SceneVariable("spotlightColor", spotlightIndex, stageIndex)
    return {color[1], color[2], color[3]}
  end
end

function GetSmokeColor()
  if isSmokersToggled then
    local entry = config.entries[currentHallIdentifier]
    if entry.bass and entry.bass.smoke then
      local useColor = SceneVariable("bassSmokeColorWithDynamicSpotlights", entry.bass.smoke.colorWithDynamicSpotlights)
      if useColor then
        if not isSpotlightsWhiteToggled and isSpotlightsColorToggled and camSettings.dynamic and musicData.playing then
          return FloatValues(vibrantColors.DarkVibrant)
        end
      end
    end
  else
    return
  end
end

function GetSparklersColor()
  if isSparklerToggled then
    local entry = config.entries[currentHallIdentifier]
    if entry.bass and entry.bass.sparklers then
      local useColor = SceneVariable("bassSparklersColorWithDynamicSpotlights", entry.bass.sparklers.colorWithDynamicSpotlights)
      if useColor then
        if not isSpotlightsWhiteToggled and isSpotlightsColorToggled and camSettings.dynamic and musicData.playing then
          return FloatValues(vibrantColors.DarkVibrant)
        end
      end
    end
  else
    return
  end
end

function DoSmoke(useColor, stageIndex)
  if not isSpeakersToggled and not isSmokersToggled then
    return
  end
  
  if isSmokersToggled then
    isSpeakersToggled = true
    
    for smokeStageIndex = 1, #smokers, 1 do
      local stage = smokers[smokeStageIndex]
      if stage and stage.smokes and (not stageIndex or smokeStageIndex == stageIndex) then
        CreateThread(function()
          for smokeIndex = 1, #stage.smokes, 1 do
            local multiplier = Ternary(config.entries[currentHallIdentifier].smokeFxMultiplier, config.smokeFxMultiplier)
            for fxIndex = 1, multiplier, 1 do
              CreateThread(function()
                local color = FloatValues(Ternary(Ternary(useColor, SceneVariable("smokeColor", stage.color, smokeStageIndex)), {255, 255, 255}))
                
                UseParticleFxAsset(stage.fx.library)
                
                table.insert(stage.smokes[smokeIndex].handles, StartParticleFxLoopedAtCoord(
                  stage.fx.effect,
                  stage.smokes[smokeIndex].position.x,
                  stage.smokes[smokeIndex].position.y,
                  stage.smokes[smokeIndex].position.z,
                  0.0, 0.0, 0.0, 10.0, 0, 0, 0, 1
                ))
                
                local handleIndex = #stage.smokes[smokeIndex].handles
                SetParticleFxLoopedColour(stage.smokes[smokeIndex].handles[handleIndex], color[1], color[2], color[3], 0)
              end)
            end
            
            Wait(Ternary(config.entries[currentHallIdentifier].delayBetweenSmokeChainMs, config.delayBetweenSmokeChainMs))
          end
        end)
      end
    end
    
    local totalSmokes = 0
    for smokeStageIndex = 1, #smokers, 1 do
      totalSmokes = totalSmokes + #smokers[smokeStageIndex].smokes
    end
    
    local timeout = Ternary(config.entries[currentHallIdentifier].smokeTimeoutMs, config.smokeTimeoutMs)
    local chainDelay = Ternary(config.entries[currentHallIdentifier].delayBetweenSmokeChainMs, config.delayBetweenSmokeChainMs)
    Wait(timeout + totalSmokes * chainDelay)
    
    for smokeStageIndex = 1, #smokers, 1 do
      if not stageIndex or smokeStageIndex == stageIndex then
        for smokeIndex = 1, #smokers[smokeStageIndex].smokes, 1 do
          for handleIndex = 1, #smokers[smokeStageIndex].smokes[smokeIndex].handles, 1 do
            StopParticleFxLooped(smokers[smokeStageIndex].smokes[smokeIndex].handles[handleIndex], false)
          end
          smokers[smokeStageIndex].smokes[smokeIndex].handles = {}
        end
      end
    end
    
    isSpeakersToggled = false
  end
end

function DoSparklers(useColor, sparklerIndex)
  if not isSparklerToggled and not isSmokersToggled then
    return
  end
  
  if isSmokersToggled then
    isSparklerToggled = true
    
    for currentSparklerIndex = 1, #sparklers, 1 do
      if not sparklerIndex or currentSparklerIndex == sparklerIndex then
        local multiplier = Ternary(config.entries[currentHallIdentifier].sparklerFxMultiplier, config.sparklerFxMultiplier)
        for fxIndex = 1, multiplier, 1 do
          CreateThread(function()
            local color = FloatValues(Ternary(Ternary(useColor, SceneVariable("sparklerColor", sparklers[currentSparklerIndex].color, currentSparklerIndex)), {255, 255, 255}))
            
            UseParticleFxAsset(sparklers[currentSparklerIndex].fx.library)
            
            table.insert(sparklers[currentSparklerIndex].handles, StartParticleFxLoopedAtCoord(
              sparklers[currentSparklerIndex].fx.effect,
              sparklers[currentSparklerIndex].position.x,
              sparklers[currentSparklerIndex].position.y,
              sparklers[currentSparklerIndex].position.z,
              0.0, 0.0, 0.0, 10.0, 0, 0, 0, 1
            ))
            
            local handleIndex = #sparklers[currentSparklerIndex].handles
            SetParticleFxLoopedColour(sparklers[currentSparklerIndex].handles[handleIndex], color[1], color[2], color[3], 0)
          end)
        end
      end
    end
    
    Wait(Ternary(config.entries[currentHallIdentifier].sparklerTimeoutMs, config.sparklerTimeoutMs))
    
    for currentSparklerIndex = 1, #sparklers, 1 do
      if not sparklerIndex or currentSparklerIndex == sparklerIndex then
        for handleIndex = 1, #sparklers[currentSparklerIndex].handles, 1 do
          StopParticleFxLooped(sparklers[currentSparklerIndex].handles[handleIndex], false)
        end
        sparklers[currentSparklerIndex].handles = {}
      end
    end
    
    isSparklerToggled = false
  end
end

CreateThread(function()
  while true do
    if not canDisplayScaleform then
      break
    end

    local allValid = false
    for i = 1, #effects, 1 do
      if not effects[i]() then
        allValid = true
        break
      end
    end

    if not allValid then
      isUiHidden = false
      break
    end

    Wait(tickPollMs)
  end
end)

RetractScreens = function()
  if not CanAccessUi() then
    return
  end
  isUiHidden = true
  SetNuiFocus(isUiHidden, isUiHidden)
  SetNuiFocusKeepInput(true)
  SendNUIMessage({ type = "cs-hall:show" })
  TriggerEvent("cs-hall:onControllerInterfaceOpen")
end

ShowUi = function()
  isUiHidden = false
  SetNuiFocus(isUiHidden, isUiHidden)
  SetNuiFocusKeepInput(false)
  SendNUIMessage({ type = "cs-hall:hide" })
  TriggerEvent("cs-hall:onControllerInterfaceClose")
end

CanAccessUi = function()
  if hasHallDataReceived and canDisplayScaleform and isHallEntryEnabled and isPlayerNearHall then
    return isHallEntryRefreshing
  end
  return nil
end

SetScaleformTexture = function(scaleform)
  PushScaleformMovieFunction(scaleform, "SET_TEXTURE")
  PushScaleformMovieMethodParameterString("browser")
  PushScaleformMovieMethodParameterString("browserTexture")
  PushScaleformMovieFunctionParameterInt(0)
  PushScaleformMovieFunctionParameterInt(0)
  PushScaleformMovieFunctionParameterInt(1280)
  PushScaleformMovieFunctionParameterInt(720)
  PopScaleformMovieFunctionVoid()
end

LoadAssets = function(entryKey)
  if isHallEntryRefreshing or not canDisplayScaleform then
    return
  end
  isHallEntryRefreshing = true

  local entry = config.entries[entryKey]

  if entry.smokers then
    for i = 1, #entry.smokers, 1 do
      RequestAssetPtfx(entry.smokers[i].fx.library)
      RequestAssetModel(entry.smokers[i].hash, entry.smokers[i].interior and ("\"" .. entryKey .. "\" - smoker index: " .. i) or nil)
    end
  end

  if entry.sparklers then
    for i = 1, #entry.sparklers, 1 do
      RequestAssetPtfx(entry.sparklers[i].fx.library)
      RequestAssetModel(entry.sparklers[i].hash, entry.sparklers[i].interior and ("\"" .. entryKey .. "\" - sparkler index: " .. i) or nil)
    end
  end

  if entry.speakers then
    for i = 1, #entry.speakers, 1 do
      RequestAssetModel(entry.speakers[i].hash, entry.speakers[i].interior and ("\"" .. entryKey .. "\" - speaker index: " .. i) or nil)
    end
  end

  if entry.spotlights then
    for i = 1, #entry.spotlights, 1 do
      RequestAssetModel(entry.spotlights[i].hash, entry.spotlights[i].interior and ("\"" .. entryKey .. "\" - spotlight index: " .. i) or nil)
    end
  end

  if entry.monitors then
    for i = 1, #entry.monitors, 1 do
      RequestAssetModel(entry.monitors[i].hash, entry.monitors[i].interior and ("\"" .. entryKey .. "\" - monitor index: " .. i) or nil)
    end
  end

  if entry.screens then
    for i = 1, #entry.screens, 1 do
      RequestAssetModel(entry.screens[i].hash, entry.screens[i].interior and ("\"" .. entryKey .. "\" - screen index: " .. i) or nil)
    end
  end

  if entry.disableEmitters then
    for i = 1, #entry.disableEmitters, 1 do
      SetStaticEmitterEnabled(entry.disableEmitters[i], false)
    end
  end

  if entry.smokers then
    for i = 1, #entry.smokers, 1 do
      local data = Copy(entry.smokers[i])
      local handle = CreateSpeakerOrSmokeOrSparklersMachine(data)
      if handle and HasNamedPtfxAssetLoaded(data.fx.library) then
        local forward, right, up, position = GetEntityMatrix(handle)
        data.forward = forward
        data.right = right
        data.up = up
        data.position = position
        data.handle = handle

        local smoke1 = { position = data.position + (data.up * 0.25), handles = {} }
        local smoke2 = { position = data.position + (data.forward * -3.0) + (data.up * 0.5), handles = {} }
        data.smokes = { smoke1, smoke2 }

        table.insert(smokers, data)
      end
    end
  end
end



if not config then
  error("[criticalscripts.shop] cs-hall configuration file has a syntax error, please resolve it otherwise the resource will not work.")
  return
end

local version = "1.1.4"
local scaleformName = "cs_scaleform_hall_renderer"
local monitors = {}
local spotlights = {}
local speakers = {}
local smokers = {}
local sparklers = {}
local screens = {}
local effects = {}
local scaleform = {}
scaleform.ready = false
scaleform.draw = false
scaleform.tick = false
scaleform.failed = false
scaleform.solid = true
scaleform.handle = nil
scaleform.interval = nil
scaleform.first = nil
scaleform.position = nil
scaleform.rotation = nil
scaleform.scale = nil

local camSettings = {}
camSettings.dynamic = false

local musicData = {}
musicData.time = 0
musicData.playing = false

local defaultFrequencyLevels = {}
defaultFrequencyLevels.bass = 0
defaultFrequencyLevels.mid = 0
defaultFrequencyLevels.treble = 0
defaultFrequencyLevels.lowMid = 0
defaultFrequencyLevels.highMid = 0

local frequencyLevelsSmooth = {}
frequencyLevelsSmooth.current = {
  bass = 0,
  mid = 0,
  treble = 0,
  lowMid = 0,
  highMid = 0
}
frequencyLevelsSmooth.previous = {
  bass = 0,
  mid = 0,
  treble = 0,
  lowMid = 0,
  highMid = 0
}
frequencyLevelsSmooth.time = 0

local frequencyLevelsStatic = {
  bass = 0,
  mid = 0,
  treble = 0,
  lowMid = 0,
  highMid = 0
}

local frequencyLevelsFiltered = {
  bass = 0,
  mid = 0,
  treble = 0,
  lowMid = 0,
  highMid = 0
}

local vibrantColors = {}
vibrantColors.DarkVibrant = {0, 0, 0}
vibrantColors.Vibrant = {0, 0, 0}
vibrantColors.LightVibrant = {0, 0, 0}
vibrantColors.DarkMuted = {0, 0, 0}
vibrantColors.LightMuted = {0, 0, 0}

local tickData = {}
local hallEntry = {
  identifier = nil,
  enabled = false,
  active = false,
  playing = false,
  isUpdater = false,
  isController = false,
  screensAdvanced = false,
  time = 0,
  duration = 0,
  settings = {
    bass = {
      smoke = {
        cooldownMs = nil,
        colorWithDynamicSpotlights = nil
      },
      sparklers = {
        cooldownMs = nil,
        colorWithDynamicSpotlights = nil
      }
    },
    spotlights = {
      white = nil,
      dynamic = nil,
      photorythmic = nil,
      states = {},
      colors = {}
    },
    smokers = {
      colors = {}
    },
    sparklers = {
      colors = {}
    },
    speakers = {
      volumes = {}
    },
    idleWallpaperUrl = nil,
    videoToggle = nil
  },
  original = {},
  lastFrequencyLevels = defaultFrequencyLevels
}

local currentHallIdentifier = nil
local previousHallIdentifier = nil
local hallEntries = nil
local nearestHallEntry = nil
local playerId = nil
local playerPed = nil
local playerCoords = nil
local playerHeading = nil
local isPlayerDead = nil
local gameTimer = nil
local frameTime = 0
local gameplayCamCoords = 0
local gameplayCamRot = 0
local gameplayCamFov = 0
local musicSpeed = 0
local webViewId = 0

local hasPlayerRespawned = false
local hasPlayerBucketsChanged = false
local hasPlayerSpawned = false
local hasPlayerTeleported = false
local isHallPlayerVisible = false
local isPlayerInVehicle = false
local isPlayerInArea = false
local wasPlayerInArea = false
local isPlayerNearHall = false
local wasPlayerNearHall = false
local hasHallDataReceived = false
local hasHallDisappeared = false
local isNewHallEntry = false
local isHallEntryEnabled = true
local isHallEntryRefreshing = false
local isEffectsToggled = false
local isSpeakersToggled = false
local isScreensToggled = false
local isSmokersToggled = false
local isSparklerToggled = false
local isScreensAdvanced = false
local isSpotlightsColorToggled = false
local isSpotlightsWhiteToggled = false
local isUiHidden = false
local canDisplayScaleform = true

local frameTickMs = 250
local frequencyLevelsUpdateMs = 200
local frequencyLevelsFilterUpdateMs = 200
local frequencyLevelsFilterTolerance = 75
local assetLoadTimeoutMs = 100
local assetLoadUpdateMs = 25
local assetLoadAnimationMs = 50
local scaleformLoadMs = 100
local scaleformLoadTimeoutMs = 250
local spotlightToggleMs = 3000
local smokerToggleMs = 1000
local sparklerToggleMs = 1000
local tickReadyMs = 100
local tickPollMs = 100
local tickUpdateMs = 100
local updateTimeMs = 5000
local inputTimeMs = 1500
local multipleDistanceTreshold = 3
local areaDistanceTreshold = 1
local screenRefreshMs = 1500
local screenAdvancedRefreshMs = 2500

local isDebugEnabled = false
local isStartDebugEnabled = false
local debugText = nil
local debugSparklers = {}
local debugEffects = {}

function RotationToDirection(rotation)
  local radianZ = math.rad(rotation.z)
  local radianX = math.rad(math.min(math.max(rotation.x, -30.0), 30.0))
  local cosRadianX = math.abs(math.cos(radianX))
  
  return vector3(
    -math.sin(radianZ) * cosRadianX,
    math.cos(radianZ) * cosRadianX,
    math.sin(radianX)
  )
end

function IsPositionInsideArea(position, hall)
  local polygons = Ternary(hall, {hall}, config.entries[currentHallIdentifier].area.polygons and config.entries[currentHallIdentifier].area.polygons.entries)
  
  for i = 1, #polygons, 1 do
    local polygon = polygons[i]
    local inside = false
    
    if position.z >= polygon.height.min then
      if not (position.z < polygon.height.max) then
        if #polygons ~= 1 then
          goto continue
        end
        if position.z ~= polygon.height.max then
          goto continue
        end
      end
      
      local j = #polygon.points
      for k = 1, #polygon.points, 1 do
        local xi = polygon.points[k].x
        local yi = polygon.points[k].y
        local xj = polygon.points[j].x
        local yj = polygon.points[j].y
        
        if (yi > position.y) ~= (yj > position.y) then
          if position.x < (xj - xi) * (position.y - yi) / (yj - yi) + xi then
            inside = not inside
          end
        end
        j = k
      end
    end
    
    ::continue::
    if inside then
      return true
    end
  end
  return false
end

function RequestAssetModel(model, isSync)
  if HasModelLoaded(model) then
    return
  end
  
  local startTime = GetGameTimer()
  while true do
    if HasModelLoaded(model) then
      break
    end
    RequestModel(model)
    Wait(tickUpdateMs)
    if GetGameTimer() - startTime > Ternary(isSync, config.timeouts.assetLoadMs, config.timeouts.syncAssetLoadMs) then
      break
    end
  end
  
  if isSync then
    if not HasModelLoaded(model) then
      if model == 1036697368 or model == -824545400 or model == "cs_prop_hall_spotlight" or model == "h4_prop_battle_club_screen" then
        error("[criticalscripts.shop] cs-hall enabled configuration model \"" .. model .. "\" (" .. isSync .. ") which is included by default in \"cs-stream\" resource could not be loaded, consult the package's store page for further information.")
      else
        error("[criticalscripts.shop] cs-hall enabled configuration model \"" .. model .. "\" (" .. isSync .. ") could not be loaded.")
      end
    end
  end
end

function RequestAssetPtfx(asset, isSync)
  if HasNamedPtfxAssetLoaded(asset) then
    return
  end
  
  local startTime = GetGameTimer()
  while true do
    if HasNamedPtfxAssetLoaded(asset) then
      break
    end
    RequestNamedPtfxAsset(asset)
    Wait(tickUpdateMs)
    if GetGameTimer() - startTime > Ternary(isSync, config.timeouts.assetLoadMs, config.timeouts.syncAssetLoadMs) then
      break
    end
  end
  
  if isSync then
    if not HasNamedPtfxAssetLoaded(asset) then
      if asset == "scr_ba_club" or asset == "scr_ih_club" then
        error("[criticalscripts.shop] cs-hall enabled configuration effect \"" .. asset .. "\" (" .. isSync .. ") which is included by default in \"cs-stream\" resource could not be loaded, consult the package's store page for further information.")
      else
        error("[criticalscripts.shop] cs-hall enabled configuration effect \"" .. asset .. "\" (" .. isSync .. ") could not be loaded.")
      end
    end
  end
end

function CreateSpeakerOrSmokeOrSparklersMachine(objData)
  if not HasModelLoaded(objData.hash) then
    return
  end
  
  local entity = CreateObject(objData.hash, objData.position.x, objData.position.y, objData.position.z, false, true, false)
  SetEntityCoords(entity, objData.position.x, objData.position.y, objData.position.z)
  SetEntityHeading(entity, Ternary(objData.heading, objData.heading, 0.0))
  
  if objData.rotation then
    SetEntityRotation(entity, objData.rotation.x, objData.rotation.y, objData.rotation.z, 2)
  end
  
  if objData.quaternion then
    SetEntityQuaternion(entity, objData.quaternion.x, objData.quaternion.y, objData.quaternion.z, objData.quaternion.w)
  end
  
  if not objData.visible then
    SetEntityVisible(entity, false)
    SetEntityCompletelyDisableCollision(entity, false, false)
  end
  
  if objData.lodDistance then
    SetEntityLodDist(entity, objData.lodDistance)
  end
  
  FreezeEntityPosition(entity, true)
  return entity
end

function CreateSpotlight(objData)
  if not HasModelLoaded(objData.hash) then
    return
  end
  
  local entity = CreateObject(objData.hash, objData.position.x, objData.position.y, objData.position.z, false, true, false)
  SetEntityCoords(entity, objData.position.x, objData.position.y, objData.position.z)
  SetEntityHeading(entity, Ternary(objData.heading, objData.heading, 0.0))
  
  if objData.rotation then
    SetEntityRotation(entity, objData.rotation.x, objData.rotation.y, objData.rotation.z, 2)
  end
  
  if objData.quaternion then
    SetEntityQuaternion(entity, objData.quaternion.x, objData.quaternion.y, objData.quaternion.z, objData.quaternion.w)
  end
  
  if objData.lodDistance then
    SetEntityLodDist(entity, objData.lodDistance)
  end
  
  FreezeEntityPosition(entity, true)
  SetEntityLights(entity, false)
  SetObjectLightColor(entity, true, 0, 0, 0)
  return entity
end

function CreateMonitorOrScreen(objData)
  if not HasModelLoaded(objData.hash) then
    return
  end
  
  local entity = CreateObject(objData.hash, objData.position.x, objData.position.y, objData.position.z, false, true, false)
  SetEntityCoords(entity, objData.position.x, objData.position.y, objData.position.z)
  SetEntityHeading(entity, Ternary(objData.heading, objData.heading, 0.0))
  
  if objData.rotation then
    SetEntityRotation(entity, objData.rotation.x, objData.rotation.y, objData.rotation.z, 2)
  end
  
  if objData.quaternion then
    SetEntityQuaternion(entity, objData.quaternion.x, objData.quaternion.y, objData.quaternion.z, objData.quaternion.w)
  end
  
  if objData.lodDistance then
    SetEntityLodDist(entity, objData.lodDistance)
  end
  
  FreezeEntityPosition(entity, true)
  return entity
end

function RGB2HSL(rgb)
  local r = rgb[1] / 255
  local g = rgb[2] / 255
  local b = rgb[3] / 255
  local min = math.min(r, g, b)
  local max = math.max(r, g, b)
  local h, s
  local l = (max + min) / 2
  
  if max == min then
    h = 0
    s = 0
  else
    local diff = max - min
    s = Ternary(l > 0.5, diff / (2 - max - min), diff / (max + min))
    
    if max == r then
      h = (g - b) / diff + Ternary(g < b, 6, 0)
    elseif max == g then
      h = (b - r) / diff + 2
    elseif max == b then
      h = (r - g) / diff + 4
    end
    h = h / 6
  end
  
  return {h, s, l}
end

function Hue2RGB(p, q, t)
  if t < 0 then
    t = t + 1
  end
  if t > 1 then
    t = t - 1
  end
  
  if t < 0.16666666666666666 then
    return p + (q - p) * 6 * t
  end
  if t < 0.5 then
    return q
  end
  if t < 0.6666666666666666 then
    return p + (q - p) * (0.6666666666666666 - t) * 6
  end
  return p
end

function HSL2RGB(hsl)
  local h = hsl[1]
  local s = hsl[2]
  local l = hsl[3]
  local r, g, b
  
  if s == 0 then
    r = l
    g = l
    b = l
  else
    local q = Ternary(l < 0.5, l * (1 + s), l + s - l * s)
    local p = 2 * l - q
    r = Hue2RGB(p, q, h + 0.3333333333333333)
    g = Hue2RGB(p, q, h)
    b = Hue2RGB(p, q, h - 0.3333333333333333)
  end
  
  return {
    math.floor(math.round(r * 255)),
    math.floor(math.round(g * 255)),
    math.floor(math.round(b * 255))
  }
end

function LightenColor(color, amount)
  if amount == 0 then
    return {0, 0, 0}
  end
  
  local hsl = RGB2HSL(color)
  hsl[3] = hsl[3] * amount
  return HSL2RGB(hsl)
end

function AlterColorBrightness(original, target, factor)
  local result = original * (1 - factor) + target * factor
  return result
end

function Lerp(startValue, endValue, progress)
  return startValue + progress * (endValue - startValue)
end

function LerpCallback(startValue, endValue, duration, updateInterval, callback, condition, onComplete, threshold)
  local startTime = GetGameTimer()
  local finished = false
  
  CreateThread(function()
    while true do
      if finished then
        break
      end
      
      local currentTime = GetGameTimer()
      local elapsed = currentTime - startTime
      local progress = elapsed / duration
      
      if type(startValue) == "table" or type(endValue) == "table" then
        local result = {}
        for i = 1, #startValue, 1 do
          result[i] = Lerp(startValue[i], endValue[i], progress)
        end
        callback(result)
      else
        callback(Lerp(startValue, endValue, progress))
      end
      
      local progressPercent = progress * 100
      local thresholdValue = Ternary(threshold, threshold, 100)
      if progressPercent >= thresholdValue then
        break
      end
      
      if condition then
        if not condition() then
          break
        end
      end
      
      Wait(updateInterval)
    end
    
    if onComplete then
      onComplete()
    end
    finished = true
  end)
  
  return function()
    return finished
  end
end

function JumpPercentage(startValue, currentValue, endValue)
  local percentage = 0
  
  if type(startValue) == "table" then
    for i = 1, #startValue, 1 do
      local range = endValue[i] - startValue[i]
      if range ~= 0 then
        local progress = (currentValue[i] - startValue[i]) / range * 100
        if percentage == 0 or percentage > progress then
          percentage = progress
        end
      else
        percentage = 100
      end
    end
  else
    local range = endValue - startValue
    if range ~= 0 then
      percentage = (currentValue - startValue) / range * 100
    else
      percentage = 100
    end
  end
  
  if percentage > 100 then
    percentage = 100
  end
  return percentage
end

function CalculatePercentage(startValue, currentValue, endValue, callback)
  if type(startValue) == "table" then
    local result = {}
    for i = 1, #startValue, 1 do
      local value = startValue[i] + (currentValue / 100) * (endValue[i] - startValue[i])
      result[i] = value
    end
    callback(result)
  else
    local value = startValue + (currentValue / 100) * (endValue - startValue)
    callback(value)
  end
end

function GetSpotlightColor(stageIndex, spotlightIndex)
  local entry = spotlights[stageIndex]
  if not entry then
    return {0, 0, 0}
  else
    local color = SceneVariable("spotlightColor", spotlightIndex, stageIndex)
    return {color[1], color[2], color[3]}
  end
end

function GetSmokeColor()
  if isSmokersToggled then
    local entry = config.entries[currentHallIdentifier]
    if entry.bass and entry.bass.smoke then
      local useColor = SceneVariable("bassSmokeColorWithDynamicSpotlights", entry.bass.smoke.colorWithDynamicSpotlights)
      if useColor then
        if not isSpotlightsWhiteToggled and isSpotlightsColorToggled and camSettings.dynamic and musicData.playing then
          return FloatValues(vibrantColors.DarkVibrant)
        end
      end
    end
  else
    return
  end
end

function GetSparklersColor()
  if isSparklerToggled then
    local entry = config.entries[currentHallIdentifier]
    if entry.bass and entry.bass.sparklers then
      local useColor = SceneVariable("bassSparklersColorWithDynamicSpotlights", entry.bass.sparklers.colorWithDynamicSpotlights)
      if useColor then
        if not isSpotlightsWhiteToggled and isSpotlightsColorToggled and camSettings.dynamic and musicData.playing then
          return FloatValues(vibrantColors.DarkVibrant)
        end
      end
    end
  else
    return
  end
end

function DoSmoke(useColor, stageIndex)
  if not isSpeakersToggled and not isSmokersToggled then
    return
  end
  
  if isSmokersToggled then
    isSpeakersToggled = true
    
    for smokeStageIndex = 1, #smokers, 1 do
      local stage = smokers[smokeStageIndex]
      if stage and stage.smokes and (not stageIndex or smokeStageIndex == stageIndex) then
        CreateThread(function()
          for smokeIndex = 1, #stage.smokes, 1 do
            local multiplier = Ternary(config.entries[currentHallIdentifier].smokeFxMultiplier, config.smokeFxMultiplier)
            for fxIndex = 1, multiplier, 1 do
              CreateThread(function()
                local color = FloatValues(Ternary(Ternary(useColor, SceneVariable("smokeColor", stage.color, smokeStageIndex)), {255, 255, 255}))
                
                UseParticleFxAsset(stage.fx.library)
                
                table.insert(stage.smokes[smokeIndex].handles, StartParticleFxLoopedAtCoord(
                  stage.fx.effect,
                  stage.smokes[smokeIndex].position.x,
                  stage.smokes[smokeIndex].position.y,
                  stage.smokes[smokeIndex].position.z,
                  0.0, 0.0, 0.0, 10.0, 0, 0, 0, 1
                ))
                
                local handleIndex = #stage.smokes[smokeIndex].handles
                SetParticleFxLoopedColour(stage.smokes[smokeIndex].handles[handleIndex], color[1], color[2], color[3], 0)
              end)
            end
            
            Wait(Ternary(config.entries[currentHallIdentifier].delayBetweenSmokeChainMs, config.delayBetweenSmokeChainMs))
          end
        end)
      end
    end
    
    local totalSmokes = 0
    for smokeStageIndex = 1, #smokers, 1 do
      totalSmokes = totalSmokes + #smokers[smokeStageIndex].smokes
    end
    
    local timeout = Ternary(config.entries[currentHallIdentifier].smokeTimeoutMs, config.smokeTimeoutMs)
    local chainDelay = Ternary(config.entries[currentHallIdentifier].delayBetweenSmokeChainMs, config.delayBetweenSmokeChainMs)
    Wait(timeout + totalSmokes * chainDelay)
    
    for smokeStageIndex = 1, #smokers, 1 do
      if not stageIndex or smokeStageIndex == stageIndex then
        for smokeIndex = 1, #smokers[smokeStageIndex].smokes, 1 do
          for handleIndex = 1, #smokers[smokeStageIndex].smokes[smokeIndex].handles, 1 do
            StopParticleFxLooped(smokers[smokeStageIndex].smokes[smokeIndex].handles[handleIndex], false)
          end
          smokers[smokeStageIndex].smokes[smokeIndex].handles = {}
        end
      end
    end
    
    isSpeakersToggled = false
  end
end

function DoSparklers(useColor, sparklerIndex)
  if not isSparklerToggled and not isSmokersToggled then
    return
  end
  
  if isSmokersToggled then
    isSparklerToggled = true
    
    for currentSparklerIndex = 1, #sparklers, 1 do
      if not sparklerIndex or currentSparklerIndex == sparklerIndex then
        local multiplier = Ternary(config.entries[currentHallIdentifier].sparklerFxMultiplier, config.sparklerFxMultiplier)
        for fxIndex = 1, multiplier, 1 do
          CreateThread(function()
            local color = FloatValues(Ternary(Ternary(useColor, SceneVariable("sparklerColor", sparklers[currentSparklerIndex].color, currentSparklerIndex)), {255, 255, 255}))
            
            UseParticleFxAsset(sparklers[currentSparklerIndex].fx.library)
            
            table.insert(sparklers[currentSparklerIndex].handles, StartParticleFxLoopedAtCoord(
              sparklers[currentSparklerIndex].fx.effect,
              sparklers[currentSparklerIndex].position.x,
              sparklers[currentSparklerIndex].position.y,
              sparklers[currentSparklerIndex].position.z,
              0.0, 0.0, 0.0, 10.0, 0, 0, 0, 1
            ))
            
            local handleIndex = #sparklers[currentSparklerIndex].handles
            SetParticleFxLoopedColour(sparklers[currentSparklerIndex].handles[handleIndex], color[1], color[2], color[3], 0)
          end)
        end
      end
    end
    
    Wait(Ternary(config.entries[currentHallIdentifier].sparklerTimeoutMs, config.sparklerTimeoutMs))
    
    for currentSparklerIndex = 1, #sparklers, 1 do
      if not sparklerIndex or currentSparklerIndex == sparklerIndex then
        for handleIndex = 1, #sparklers[currentSparklerIndex].handles, 1 do
          StopParticleFxLooped(sparklers[currentSparklerIndex].handles[handleIndex], false)
        end
        sparklers[currentSparklerIndex].handles = {}
      end
    end
    
    isSparklerToggled = false
  end
end

CreateThread(function()
  while true do
    if not canDisplayScaleform then
      break
    end

    local allValid = false
    for i = 1, #effects, 1 do
      if not effects[i]() then
        allValid = true
        break
      end
    end

    if not allValid then
      isUiHidden = false
      break
    end

    Wait(tickPollMs)
  end
end)

RetractScreens = function()
  if not CanAccessUi() then
    return
  end
  isUiHidden = true
  SetNuiFocus(isUiHidden, isUiHidden)
  SetNuiFocusKeepInput(true)
  SendNUIMessage({ type = "cs-hall:show" })
  TriggerEvent("cs-hall:onControllerInterfaceOpen")
end

ShowUi = function()
  isUiHidden = false
  SetNuiFocus(isUiHidden, isUiHidden)
  SetNuiFocusKeepInput(false)
  SendNUIMessage({ type = "cs-hall:hide" })
  TriggerEvent("cs-hall:onControllerInterfaceClose")
end

CanAccessUi = function()
  if hasHallDataReceived and canDisplayScaleform and isHallEntryEnabled and isPlayerNearHall then
    return isHallEntryRefreshing
  end
  return nil
end

SetScaleformTexture = function(scaleform)
  PushScaleformMovieFunction(scaleform, "SET_TEXTURE")
  PushScaleformMovieMethodParameterString("browser")
  PushScaleformMovieMethodParameterString("browserTexture")
  PushScaleformMovieFunctionParameterInt(0)
  PushScaleformMovieFunctionParameterInt(0)
  PushScaleformMovieFunctionParameterInt(1280)
  PushScaleformMovieFunctionParameterInt(720)
  PopScaleformMovieFunctionVoid()
end

SyncArea = function(entryKey)
  if isHallEntryRefreshing or not canDisplayScaleform then
    return
  end
  isHallEntryRefreshing = true

  local entry = config.entries[entryKey]

  if entry.smokers then
    for i = 1, #entry.smokers, 1 do
      RequestAssetPtfx(entry.smokers[i].fx.library)
      RequestAssetModel(entry.smokers[i].hash, entry.smokers[i].interior and ("\"" .. entryKey .. "\" - smoker index: " .. i) or nil)
    end
  end

  if entry.sparklers then
    for i = 1, #entry.sparklers, 1 do
      RequestAssetPtfx(entry.sparklers[i].fx.library)
      RequestAssetModel(entry.sparklers[i].hash, entry.sparklers[i].interior and ("\"" .. entryKey .. "\" - sparkler index: " .. i) or nil)
    end
  end

  if entry.speakers then
    for i = 1, #entry.speakers, 1 do
      RequestAssetModel(entry.speakers[i].hash, entry.speakers[i].interior and ("\"" .. entryKey .. "\" - speaker index: " .. i) or nil)
    end
  end

  if entry.spotlights then
    for i = 1, #entry.spotlights, 1 do
      RequestAssetModel(entry.spotlights[i].hash, entry.spotlights[i].interior and ("\"" .. entryKey .. "\" - spotlight index: " .. i) or nil)
    end
  end

  if entry.monitors then
    for i = 1, #entry.monitors, 1 do
      RequestAssetModel(entry.monitors[i].hash, entry.monitors[i].interior and ("\"" .. entryKey .. "\" - monitor index: " .. i) or nil)
    end
  end

  if entry.screens then
    for i = 1, #entry.screens, 1 do
      RequestAssetModel(entry.screens[i].hash, entry.screens[i].interior and ("\"" .. entryKey .. "\" - screen index: " .. i) or nil)
    end
  end

  if entry.disableEmitters then
    for i = 1, #entry.disableEmitters, 1 do
      SetStaticEmitterEnabled(entry.disableEmitters[i], false)
    end
  end

  if entry.sparklers then
    for i = 1, #entry.sparklers, 1 do
      local data = Copy(entry.sparklers[i])
      local handle = CreateSpeakerOrSmokeOrSparklersMachine(data)
      if handle and HasNamedPtfxAssetLoaded(data.fx.library) then
        local forward, right, up, position = GetEntityMatrix(handle)
        data.handles = {}
        data.forward = forward
        data.right = right
        data.up = up
        data.position = position
        data.handle = handle
        table.insert(sparklers, data)
      end
    end
  end

  if entry.speakers then
    for i = 1, #entry.speakers, 1 do
      local data = Copy(entry.speakers[i])
      local handle = CreateSpeakerOrSmokeOrSparklersMachine(data)
      if handle then
        local forward, right, up, position = GetEntityMatrix(handle)
        data.forward = forward
        data.right = right
        data.up = up
        data.position = position
        data.id = i
        data.handle = handle
        data.originalVolumeMultiplier = Ternary(data.volumeMultiplier, data.volumeMultiplier, 1.0)
        table.insert(speakers, data)
        AddBrowserSpeaker(data, entryKey)
      end
    end
  end

  if entry.monitors then
    for i = 1, #entry.monitors, 1 do
      local data = Copy(entry.monitors[i])
      local handle = CreateMonitorOrScreen(data)
      if handle then
        local forward, right, up, position = GetEntityMatrix(handle)
        data.forward = forward
        data.right = right
        data.up = up
        data.position = position
        data.handle = handle
        table.insert(monitors, data)
      end
    end
  end

  if entry.screens then
    for i = 1, #entry.screens, 1 do
      local data = Copy(entry.screens[i])
      local handle = CreateMonitorOrScreen(data)
      if handle then
        local forward, right, up, position = GetEntityMatrix(handle)
        data.forward = forward
        data.right = right
        data.up = up
        data.position = position
        data.handle = handle
        table.insert(screens, data)
      end
    end
  end

  if entry.spotlights then
    for i = 1, #entry.spotlights, 1 do
      local data = Copy(entry.spotlights[i])
      local handle = CreateSpotlight(data)
      if handle then
        local forward, right, up, position = GetEntityMatrix(handle)
        data.originalColor = {data.color[1], data.color[2], data.color[3]}
        
        if isSpotlightsWhiteToggled then
          data.currentColor = {255, 255, 255}
        else
          data.currentColor = {0, 0, 0}
        end
        
        data.lastColor = {0, 0, 0}
        data.forward = forward
        data.right = right
        data.up = up
        data.position = position
        data.handle = handle
        table.insert(spotlights, data)
      end
    end
  end

  if entry.scaleform then
    scaleform.solid = Ternary(entry.scaleform.solid, entry.scaleform.solid, true)
    scaleform.position = entry.scaleform.position
    scaleform.rotation = entry.scaleform.rotation
    scaleform.scale = entry.scaleform.scale
    scaleform.draw = true
    
    if scaleform.ready then
      SetScaleformTexture(scaleform.handle)
      scaleform.tick = true
    end
    
    SetBrowserFlagRatio(Ternary(entry.scaleform.flag, entry.scaleform.flag, false))
  else
    SetBrowserFlagRatio(false)
  end

  if entry.replacers then
    if entry.area and entry.area.polygons then
      if not entry.area.polygons.hideReplacersOutside then
        for hash, txd in pairs(entry.replacers) do
          AddReplaceTexture(hash, txd, "browser", "browserTexture")
        end
      end
    end
  end

  hallEntry.settings.idleWallpaperUrl = Ternary(entry.idleWallpaperUrl, entry.idleWallpaperUrl, "none")
  SetBrowserIdleWallpaperUrl(hallEntry.settings.idleWallpaperUrl)
  
  playerPed = GetInteriorFromEntity(PlayerPedId())
  canDisplayScaleform = true
  isHallEntryRefreshing = false
  
  SetScene()
  TriggerEvent("cs-hall:areaSynced", entryKey)
  TriggerServerEvent("cs-hall:enteredSyncArea", entryKey)

  if entry.smokers then
    for i = 1, #entry.smokers, 1 do
      local data = Copy(entry.smokers[i])
      local handle = CreateSpeakerOrSmokeOrSparklersMachine(data)
      if handle and HasNamedPtfxAssetLoaded(data.fx.library) then
        local forward, right, up, position = GetEntityMatrix(handle)
        data.forward = forward
        data.right = right
        data.up = up
        data.position = position
        data.handle = handle

        local smoke1 = { position = data.position + (data.up * 0.25), handles = {} }
        local smoke2 = { position = data.position + (data.forward * -3.0) + (data.up * 0.5), handles = {} }
        data.smokes = { smoke1, smoke2 }

        table.insert(smokers, data)
      end
    end
  end
end

DesyncArea = function(entryKey)
  if not isHallEntryRefreshing or not canDisplayScaleform then
    return
  end
  
  isHallEntryRefreshing = true
  canDisplayScaleform = false
  HideUi()
  DesyncBrowser()

  for i = 1, #speakers, 1 do
    DeleteEntity(speakers[i].handle)
  end

  for i = 1, #monitors, 1 do
    DeleteEntity(monitors[i].handle)
  end

  for i = 1, #screens, 1 do
    DeleteEntity(screens[i].handle)
  end

  for i = 1, #spotlights, 1 do
    if spotlights[i].handle then
      DeleteEntity(spotlights[i].handle)
    end
  end

  for i = 1, #smokers, 1 do
    if smokers[i] and smokers[i].smokes then
      for j = 1, #smokers[i].smokes, 1 do
        for k = 1, #smokers[i].smokes[j].handles, 1 do
          StopParticleFxLooped(smokers[i].smokes[j].handles[k], false)
        end
      end
    end
  end

  for i = 1, #sparklers, 1 do
    for j = 1, #sparklers[i].handles, 1 do
      StopParticleFxLooped(sparklers[i].handles[j], false)
    end
  end

  speakers = {}
  smokers = {}
  sparklers = {}
  monitors = {}
  screens = {}
  spotlights = {}

  scaleform.tick = false
  scaleform.draw = false
  scaleform.solid = true
  scaleform.position = nil
  scaleform.rotation = nil
  scaleform.scale = nil

  local entry = config.entries[entryKey]
  
  if entry.smokers then
    for i = 1, #entry.smokers, 1 do
      RemoveNamedPtfxAsset(entry.smokers[i].fx.library)
      SetModelAsNoLongerNeeded(entry.smokers[i].hash)
    end
  end

  if entry.sparklers then
    for i = 1, #entry.sparklers, 1 do
      RemoveNamedPtfxAsset(entry.sparklers[i].fx.library)
      SetModelAsNoLongerNeeded(entry.sparklers[i].hash)
    end
  end

  if entry.speakers then
    for i = 1, #entry.speakers, 1 do
      SetModelAsNoLongerNeeded(entry.speakers[i].hash)
    end
  end

  if entry.spotlights then
    for i = 1, #entry.spotlights, 1 do
      SetModelAsNoLongerNeeded(entry.spotlights[i].hash)
    end
  end

  if entry.monitors then
    for i = 1, #entry.monitors, 1 do
      SetModelAsNoLongerNeeded(entry.monitors[i].hash)
    end
  end

  if entry.screens then
    for i = 1, #entry.screens, 1 do
      SetModelAsNoLongerNeeded(entry.screens[i].hash)
    end
  end

  if entry.disableEmitters then
    for i = 1, #entry.disableEmitters, 1 do
      SetStaticEmitterEnabled(entry.disableEmitters[i], true)
    end
  end

  if entry.replacers then
    for hash, txd in pairs(entry.replacers) do
      RemoveReplaceTexture(hash, txd)
    end
  end

  hallEntry.settings.idleWallpaperUrl = nil
  playerPed = nil
  isScreensAdvanced = false
  isUiHidden = false
  isEffectsToggled = false
  isSpeakersToggled = false
  isHallEntryRefreshing = false

  if hallEntry.active then
    ResetScene()
  end

  TriggerEvent("cs-hall:areaDesynced", entryKey)
  TriggerServerEvent("cs-hall:leftSyncArea", entryKey)
end

SyncHallArea = function(entryKey)
  if isScreensAdvanced or not isPlayerInArea then
    return
  end
  
  isScreensAdvanced = true

  if config.entries[entryKey].replacers then
    for hash, txd in pairs(config.entries[entryKey].replacers) do
      AddReplaceTexture(hash, txd, "browser", "browserTexture")
    end
  end

  isPlayerInArea = true
  isScreensAdvanced = false
end

DesyncHallArea = function(entryKey)
  if isScreensAdvanced or not isPlayerInArea then
    return
  end
  
  isScreensAdvanced = true
  isPlayerInArea = false

  if config.entries[entryKey].replacers then
    if config.entries[entryKey].area and config.entries[entryKey].area.polygons then
      if config.entries[entryKey].area.polygons.hideReplacersOutside then
        for hash, txd in pairs(config.entries[entryKey].replacers) do
          RemoveReplaceTexture(hash, txd)
        end
      end
    end
  end

  isScreensAdvanced = false
end

ResetFrequencyData = function()
  frequencyLevelsStatic.bass = 0
  frequencyLevelsStatic.mid = 0
  frequencyLevelsStatic.treble = 0
  frequencyLevelsStatic.lowMid = 0
  frequencyLevelsStatic.highMid = 0

  frequencyLevelsSmooth.current.bass = 0
  frequencyLevelsSmooth.current.mid = 0
  frequencyLevelsSmooth.current.treble = 0
  frequencyLevelsSmooth.current.lowMid = 0
  frequencyLevelsSmooth.current.highMid = 0

  frequencyLevelsSmooth.previous.bass = 0
  frequencyLevelsSmooth.previous.mid = 0
  frequencyLevelsSmooth.previous.treble = 0
  frequencyLevelsSmooth.previous.lowMid = 0
  frequencyLevelsSmooth.previous.highMid = 0

  frequencyLevelsSmooth.time = 0

  frequencyLevelsFiltered.bass = 0
  frequencyLevelsFiltered.mid = 0
  frequencyLevelsFiltered.treble = 0
  frequencyLevelsFiltered.lowMid = 0
  frequencyLevelsFiltered.highMid = 0
end

SyncBrowser = function(data, temp)
  if isSpeakersToggled then
    if isSmokersToggled then
      tickData = { data = data, temp = temp }
      return
    end
  end

  isSmokersToggled = true
  tickData = nil

  SendDuiMessage(webViewId, json.encode({
    type = "cs-hall:sync",
    area = currentHallIdentifier,
    playing = data.playing,
    stopped = data.stopped,
    time = data.time,
    duration = data.duration,
    volume = data.volume,
    url = data.url,
    temp = {
      force = temp.force,
      adjust = temp.adjust,
      seek = Ternary(temp.media, temp.media and temp.media.seek, false)
    }
  }))
end


AdjustBrowserTime = function(time)
  if isSpeakersToggled then
    SendDuiMessage(webViewId, json.encode({
      type = "cs-hall:adjust",
      time = time
    }))
  end
end



AdjustBrowser = function()
  if not L54_1 then
    return
  end
  
  local playerPed = PlayerPedId()
  local gameplayCamRot = GetGameplayCamRot(2)
  local entityMatrix, up, right, forward, position = GetEntityMatrix(playerPed)
  local camDirection = RotationToDirection(gameplayCamRot)
  local headBoneIndex = GetEntityBoneIndexByName(playerPed, "BONETAG_HEAD")
  local listenerPosition = Ternary(-1 ~= headBoneIndex, GetWorldPositionOfEntityBone(playerPed, headBoneIndex), position)
  
  local speakers = {}
  for i = 1, #L7_1, 1 do
    local speaker = L7_1[i]
    local speakerPosition = speaker.position + Ternary(speaker.soundOffset, speaker.soundOffset, vector3(0.0, 0.0, 0.0))
    local speakerForward = speaker.forward * -1 * Ternary(speaker.directionOffset, speaker.directionOffset, vector3(1.0, 1.0, 1.0))
    
    local lowPassFilterFade
    if config.entries[L19_1].area.polygons and config.entries[L19_1].area.polygons.invertLowPassApplication then
      lowPassFilterFade = Ternary(L55_1, 1.0, 0.0)
    else
      lowPassFilterFade = Ternary(L55_1, 0.0, 1.0)
    end
    
    table.insert(speakers, {
      id = speaker.id,
      lowPassFilterFade = lowPassFilterFade,
      position = {speakerPosition.x, speakerPosition.y, speakerPosition.z},
      orientation = {speakerForward.x, speakerForward.y, speakerForward.z},
      distance = #(listenerPosition - speakerPosition)
    })
  end
  
  local applyLowPassFilter = Ternary(config.entries[L19_1].area.polygons and config.entries[L19_1].area.polygons.applyLowPassFilterOutside, true, false)
  
  SendDuiMessage(L20_1, json.encode({
    type = "cs-hall:update",
    applyLowPassFilter = applyLowPassFilter,
    listener = {
      up = {up.x, up.y, up.z},
      forward = {camDirection.x, camDirection.y, camDirection.z},
      position = {listenerPosition.x, listenerPosition.y, listenerPosition.z}
    },
    speakers = speakers
  }))
end

UpdateBrowser = function()
  L84_1 = true
  while #L87_1 > 0 do
    L87_1[1]()
    table.remove(L87_1, 1)
  end
  if L86_1 then
    SyncBrowser(L86_1.data, L86_1.temp)
  end
end

OnBrowserManagerReady = function()
  L85_1 = false
  if L86_1 then
    SyncBrowser(L86_1.data, L86_1.temp)
  end
end

OnBrowserSynced = function()
  L85_1 = false
  if L86_1 then
    SyncBrowser(L86_1.data, L86_1.temp)
  end
end

AddBrowserSpeaker = function(speakerData, entryIndex)
  if not L84_1 then
    table.insert(L87_1, function()
      AddBrowserSpeaker(speakerData, entryIndex)
    end)
  else
    local maxDistance = Ternary(speakerData.maxDistance, speakerData.maxDistance, config.entries[entryIndex].area.range / 4)
    local refDistance = Ternary(speakerData.refDistance, speakerData.refDistance, config.entries[entryIndex].area.range / 8)
    
    SendDuiMessage(L20_1, json.encode({
      type = "cs-hall:addSpeaker",
      speakerId = speakerData.id,
      maxDistance = Ternary(maxDistance < refDistance, refDistance + refDistance / 2, maxDistance),
      refDistance = refDistance,
      rolloffFactor = Ternary(speakerData.rolloffFactor, speakerData.rolloffFactor, 1.25),
      coneInnerAngle = Ternary(speakerData.coneInnerAngle, speakerData.coneInnerAngle, 90),
      coneOuterAngle = Ternary(speakerData.coneOuterAngle, speakerData.coneOuterAngle, 180),
      coneOuterGain = Ternary(speakerData.coneOuterGain, speakerData.coneOuterGain, 0.5),
      fadeDurationMs = Ternary(speakerData.fadeDurationMs, speakerData.fadeDurationMs, 250),
      volumeMultiplier = speakerData.originalVolumeMultiplier,
      lowPassGainReductionPercent = Ternary(speakerData.lowPassGainReductionPercent, speakerData.lowPassGainReductionPercent, 15)
    }))
  end
end

SetBrowserSpeakerVolume = function(speakerId, volume)
  if not L84_1 then
    table.insert(L87_1, function()
      SetBrowserSpeakerVolume(speakerId, volume)
    end)
  else
    SendDuiMessage(L20_1, json.encode({
      type = "cs-hall:setSpeakerVolume",
      speakerId = speakerId,
      volumeMultiplier = Ternary(volume, volume, 1.0)
    }))
  end
end

SetBrowserFlagRatio = function(flag)
  if not L84_1 then
    table.insert(L87_1, function()
      SetBrowserFlagRatio(flag)
    end)
  else
    SendDuiMessage(L20_1, json.encode({
      type = "cs-hall:setFlagRatio",
      flag = flag
    }))
  end
end

SetBrowserIdleWallpaperUrl = function(url)
  if not L84_1 then
    table.insert(L87_1, function()
      SetBrowserIdleWallpaperUrl(url)
    end)
  else
    SendDuiMessage(L20_1, json.encode({
      type = "cs-hall:setIdleWallpaperUrl",
      url = url
    }))
  end
end


SetBrowserIdleWallpaperUrl = L89_1
function L89_1(A0_2)
  local L1_2, L2_2, L3_2, L4_2
  L1_2 = L84_1
  if not L1_2 then
    L1_2 = table
    L1_2 = L1_2.insert
    L2_2 = L87_1
    function L3_2()
      local L0_3, L1_3
      L0_3 = SetBrowserVideoToggle
      L1_3 = A0_2
      L0_3(L1_3)
    end
    L1_2(L2_2, L3_2)
  else
    L1_2 = SendDuiMessage
    L2_2 = L20_1
    L3_2 = json
    L3_2 = L3_2.encode
    L4_2 = {}
    L4_2.type = "cs-hall:setVideoToggle"
    L4_2.toggle = A0_2
    L3_2, L4_2 = L3_2(L4_2)
    L1_2(L2_2, L3_2, L4_2)
  end
end
SetBrowserVideoToggle = L89_1
function L89_1()
  local L0_2, L1_2, L2_2, L3_2
  L0_2 = L84_1
  if not L0_2 then
    L0_2 = table
    L0_2 = L0_2.insert
    L1_2 = L87_1
    function L2_2()
      local L0_3, L1_3
      L0_3 = DesyncBrowser
      L0_3()
    end
    L0_2(L1_2, L2_2)
  else
    L0_2 = SendDuiMessage
    L1_2 = L20_1
    L2_2 = json
    L2_2 = L2_2.encode
    L3_2 = {}
    L3_2.type = "cs-hall:desync"
    L2_2, L3_2 = L2_2(L3_2)
    L0_2(L1_2, L2_2, L3_2)
  end
end
DesyncBrowser = L89_1
function L89_1(A0_2, A1_2, A2_2)
  local L3_2
  L3_2 = L43_1
  if L3_2 then
    L3_2 = L18_1.active
    if L3_2 then
      if "smokeColor" == A0_2 then
        L3_2 = L18_1.settings
        L3_2 = L3_2.smokers
        L3_2 = L3_2.colors
        L3_2 = L3_2[A2_2]
        if nil ~= L3_2 then
          L3_2 = L18_1.settings
          L3_2 = L3_2.smokers
          L3_2 = L3_2.colors
          L3_2 = L3_2[A2_2]
          return L3_2
        end
      elseif "sparklerColor" == A0_2 then
        L3_2 = L18_1.settings
        L3_2 = L3_2.sparklers
        L3_2 = L3_2.colors
        L3_2 = L3_2[A2_2]
        if nil ~= L3_2 then
          L3_2 = L18_1.settings
          L3_2 = L3_2.sparklers
          L3_2 = L3_2.colors
          L3_2 = L3_2[A2_2]
          return L3_2
        end
      elseif "speakerVolume" == A0_2 then
        L3_2 = L18_1.settings
        L3_2 = L3_2.speakers
        L3_2 = L3_2.volumes
        L3_2 = L3_2[A2_2]
        if nil ~= L3_2 then
          L3_2 = L18_1.settings
          L3_2 = L3_2.speakers
          L3_2 = L3_2.volumes
          L3_2 = L3_2[A2_2]
          return L3_2
        end
      elseif "spotlightColor" == A0_2 then
        L3_2 = L18_1.settings
        L3_2 = L3_2.spotlights
        L3_2 = L3_2.colors
        L3_2 = L3_2[A2_2]
        if nil ~= L3_2 then
          L3_2 = L18_1.settings
          L3_2 = L3_2.spotlights
          L3_2 = L3_2.colors
          L3_2 = L3_2[A2_2]
          return L3_2
        end
      elseif "idleWallpaperUrl" == A0_2 then
        L3_2 = L18_1.settings
        L3_2 = L3_2.idleWallpaperUrl
        if nil ~= L3_2 then
          L3_2 = L18_1.settings
          L3_2 = L3_2.idleWallpaperUrl
          return L3_2
        end
      elseif "whiteSpotlights" == A0_2 then
        L3_2 = L18_1.settings
        L3_2 = L3_2.spotlights
        L3_2 = L3_2.white
        if nil ~= L3_2 then
          L3_2 = L18_1.settings
          L3_2 = L3_2.spotlights
          L3_2 = L3_2.white
          return L3_2
        end
      elseif "dynamicSpotlights" == A0_2 then
        L3_2 = L18_1.settings
        L3_2 = L3_2.spotlights
        L3_2 = L3_2.dynamic
        if nil ~= L3_2 then
          L3_2 = L18_1.settings
          L3_2 = L3_2.spotlights
          L3_2 = L3_2.dynamic
          return L3_2
        end
      elseif "photorythmicSpotlights" == A0_2 then
        L3_2 = L18_1.settings
        L3_2 = L3_2.spotlights
        L3_2 = L3_2.photorythmic
        if nil ~= L3_2 then
          L3_2 = L18_1.settings
          L3_2 = L3_2.spotlights
          L3_2 = L3_2.photorythmic
          return L3_2
        end
      elseif "videoToggle" == A0_2 then
        L3_2 = L18_1.settings
        L3_2 = L3_2.videoToggle
        if nil ~= L3_2 then
          L3_2 = L18_1.settings
          L3_2 = L3_2.videoToggle
          return L3_2
        end
      elseif "bassSmoke" == A0_2 then
        L3_2 = L18_1.settings
        L3_2 = L3_2.bass
        L3_2 = L3_2.smoke
        if "off" == L3_2 then
          L3_2 = nil
          return L3_2
        else
          L3_2 = L18_1.settings
          L3_2 = L3_2.bass
          L3_2 = L3_2.smoke
          if L3_2 then
            L3_2 = L18_1.settings
            L3_2 = L3_2.bass
            L3_2 = L3_2.smoke
            return L3_2
          end
        end
      elseif "bassSparklers" == A0_2 then
        L3_2 = L18_1.settings
        L3_2 = L3_2.bass
        L3_2 = L3_2.sparklers
        if "off" == L3_2 then
          L3_2 = nil
          return L3_2
        else
          L3_2 = L18_1.settings
          L3_2 = L3_2.bass
          L3_2 = L3_2.sparklers
          if L3_2 then
            L3_2 = L18_1.settings
            L3_2 = L3_2.bass
            L3_2 = L3_2.sparklers
            return L3_2
          end
        end
      elseif "bassSmokeCooldownMs" == A0_2 then
        L3_2 = L18_1.settings
        L3_2 = L3_2.bass
        L3_2 = L3_2.smoke
        if L3_2 then
          L3_2 = L18_1.settings
          L3_2 = L3_2.bass
          L3_2 = L3_2.smoke
          L3_2 = L3_2.cooldownMs
          if nil ~= L3_2 then
            L3_2 = L18_1.settings
            L3_2 = L3_2.bass
            L3_2 = L3_2.smoke
            L3_2 = L3_2.cooldownMs
            return L3_2
          end
        end
      elseif "bassSparklersCooldownMs" == A0_2 then
        L3_2 = L18_1.settings
        L3_2 = L3_2.bass
        L3_2 = L3_2.sparklers
        if L3_2 then
          L3_2 = L18_1.settings
          L3_2 = L3_2.bass
          L3_2 = L3_2.sparklers
          L3_2 = L3_2.cooldownMs
          if nil ~= L3_2 then
            L3_2 = L18_1.settings
            L3_2 = L3_2.bass
            L3_2 = L3_2.sparklers
            L3_2 = L3_2.cooldownMs
            return L3_2
          end
        end
      elseif "bassSmokeColorWithDynamicSpotlights" == A0_2 then
        L3_2 = L18_1.settings
        L3_2 = L3_2.bass
        L3_2 = L3_2.smoke
        if L3_2 then
          L3_2 = L18_1.settings
          L3_2 = L3_2.bass
          L3_2 = L3_2.smoke
          if "off" ~= L3_2 then
            L3_2 = L18_1.settings
            L3_2 = L3_2.bass
            L3_2 = L3_2.smoke
            L3_2 = L3_2.colorWithDynamicSpotlights
            if nil ~= L3_2 then
              L3_2 = L18_1.settings
              L3_2 = L3_2.bass
              L3_2 = L3_2.smoke
              L3_2 = L3_2.colorWithDynamicSpotlights
              return L3_2
            end
          end
        end
      elseif "bassSparklersColorWithDynamicSpotlights" == A0_2 then
        L3_2 = L18_1.settings
        L3_2 = L3_2.bass
        L3_2 = L3_2.sparklers
        if L3_2 then
          L3_2 = L18_1.settings
          L3_2 = L3_2.bass
          L3_2 = L3_2.smoke
          if "off" ~= L3_2 then
            L3_2 = L18_1.settings
            L3_2 = L3_2.bass
            L3_2 = L3_2.sparklers
            L3_2 = L3_2.colorWithDynamicSpotlights
            if nil ~= L3_2 then
              L3_2 = L18_1.settings
              L3_2 = L3_2.bass
              L3_2 = L3_2.sparklers
              L3_2 = L3_2.colorWithDynamicSpotlights
              return L3_2
            end
          end
        end
      end
    end
  end
  return A1_2
end
SceneVariable = L89_1
function L89_1()
  local L0_2, L1_2, L2_2, L3_2, L4_2, L5_2, L6_2, L7_2, L8_2, L9_2
  L0_2 = L18_1.SetIdleWallpaperUrl
  L1_2 = SceneVariable
  L2_2 = "idleWallpaperUrl"
  L3_2 = L28_1
  L1_2, L2_2, L3_2, L4_2, L5_2, L6_2, L7_2, L8_2, L9_2 = L1_2(L2_2, L3_2)
  L0_2(L1_2, L2_2, L3_2, L4_2, L5_2, L6_2, L7_2, L8_2, L9_2)
  L0_2 = L18_1.SetVideoToggle
  L1_2 = SceneVariable
  L2_2 = "videoToggle"
  L3_2 = L49_1
  L1_2, L2_2, L3_2, L4_2, L5_2, L6_2, L7_2, L8_2, L9_2 = L1_2(L2_2, L3_2)
  L0_2(L1_2, L2_2, L3_2, L4_2, L5_2, L6_2, L7_2, L8_2, L9_2)
  L0_2 = SceneVariable
  L1_2 = "whiteSpotlights"
  L2_2 = L46_1
  L0_2 = L0_2(L1_2, L2_2)
  L46_1 = L0_2
  L0_2 = SceneVariable
  L1_2 = "dynamicSpotlights"
  L2_2 = L47_1
  L0_2 = L0_2(L1_2, L2_2)
  L47_1 = L0_2
  L0_2 = SceneVariable
  L1_2 = "photorythmicSpotlights"
  L2_2 = L48_1
  L0_2 = L0_2(L1_2, L2_2)
  L48_1 = L0_2
  L0_2 = SyncSpotlightColors
  L0_2()
  L0_2 = SyncSpotlightStates
  L0_2()
  L0_2 = 1
  L1_2 = L7_1
  L1_2 = #L1_2
  L2_2 = 1
  for L3_2 = L0_2, L1_2, L2_2 do
    L4_2 = SetBrowserSpeakerVolume
    L5_2 = L7_1
    L5_2 = L5_2[L3_2]
    L5_2 = L5_2.id
    L6_2 = SceneVariable
    L7_2 = "speakerVolume"
    L8_2 = L7_1
    L8_2 = L8_2[L3_2]
    L8_2 = L8_2.originalVolumeMultiplier
    L9_2 = L3_2
    L6_2, L7_2, L8_2, L9_2 = L6_2(L7_2, L8_2, L9_2)
    L4_2(L5_2, L6_2, L7_2, L8_2, L9_2)
  end
end
ActivateScenes = L89_1
function L89_1()
  local L0_2, L1_2, L2_2, L3_2, L4_2, L5_2, L6_2
  L0_2 = SetBrowserVideoToggle
  L1_2 = L49_1
  L0_2(L1_2)
  L0_2 = SetBrowserIdleWallpaperUrl
  L1_2 = L28_1
  L0_2(L1_2)
  L0_2 = L18_1.original
  L0_2 = L0_2.whiteSpotlights
  if nil ~= L0_2 then
    L0_2 = L18_1.original
    L0_2 = L0_2.whiteSpotlights
    L46_1 = L0_2
  end
  L0_2 = L18_1.original
  L0_2 = L0_2.dynamicSpotlights
  if nil ~= L0_2 then
    L0_2 = L18_1.original
    L0_2 = L0_2.dynamicSpotlights
    L47_1 = L0_2
  end
  L0_2 = L18_1.original
  L0_2 = L0_2.photorythmicSpotlights
  if nil ~= L0_2 then
    L0_2 = L18_1.original
    L0_2 = L0_2.photorythmicSpotlights
    L48_1 = L0_2
  end
  L0_2 = SyncSpotlightColors
  L0_2()
  L0_2 = SyncSpotlightStates
  L0_2()
  L0_2 = 1
  L1_2 = L7_1
  L1_2 = #L1_2
  L2_2 = 1
  for L3_2 = L0_2, L1_2, L2_2 do
    L4_2 = SetBrowserSpeakerVolume
    L5_2 = L7_1
    L5_2 = L5_2[L3_2]
    L5_2 = L5_2.id
    L6_2 = L7_1
    L6_2 = L6_2[L3_2]
    L6_2 = L6_2.originalVolumeMultiplier
    L4_2(L5_2, L6_2)
  end
end
DeactivateScenes = L89_1
function L89_1()
  local L0_2, L1_2, L2_2, L3_2
  L0_2 = L27_1
  if L0_2 then
    L0_2 = L19_1
    if L0_2 then
      L0_2 = L11_1.playing
      if L0_2 then
        L1_2 = L27_1
        L0_2 = L8_1
        L0_2 = L0_2[L1_2]
        if L0_2 then
          L0_2 = L18_1.active
          if L0_2 then
            L0_2 = L18_1.identifier
            L1_2 = L27_1
            if L0_2 == L1_2 then
              goto lbl_79
            end
          end
          L0_2 = InArray
          L1_2 = L19_1
          L3_2 = L27_1
          L2_2 = L8_1
          L2_2 = L2_2[L3_2]
          L2_2 = L2_2.areas
          L0_2 = L0_2(L1_2, L2_2)
          if L0_2 then
            L18_1.active = true
            L0_2 = L19_1
            L18_1.area = L0_2
            L0_2 = L27_1
            L18_1.identifier = L0_2
            L1_2 = L27_1
            L0_2 = L8_1
            L0_2 = L0_2[L1_2]
            L0_2 = L0_2.register
            L1_2 = L18_1.identifier
            L0_2(L1_2)
            L0_2 = L27_1
            if L0_2 then
              L1_2 = L27_1
              L0_2 = L8_1
              L0_2 = L0_2[L1_2]
              if L0_2 then
                L1_2 = L27_1
                L0_2 = L8_1
                L0_2 = L0_2[L1_2]
                L0_2 = L0_2.ticker
                if L0_2 then
                  while true do
                    L0_2 = L18_1.active
                    if not L0_2 then
                      break
                    end
                    L0_2 = L27_1
                    if not L0_2 then
                      break
                    end
                    L0_2 = L18_1.identifier
                    if not L0_2 then
                      break
                    end
                    L0_2 = L18_1.identifier
                    L1_2 = L27_1
                    if L0_2 ~= L1_2 then
                      break
                    end
                    L1_2 = L27_1
                    L0_2 = L8_1
                    L0_2 = L0_2[L1_2]
                    L0_2 = L0_2.ticker
                    L1_2 = L18_1
                    L0_2(L1_2)
                    L0_2 = Wait
                    L1_2 = L74_1
                    L0_2(L1_2)
                  end
                end
              end
            end
          end
        end
      end
    end
  end
  ::lbl_79::
end
SetScene = L89_1
function L89_1()
  local L0_2, L1_2, L2_2
  L0_2 = L18_1.active
  if L0_2 then
    L18_1.active = false
    L18_1.area = nil
    L18_1.identifier = nil
    L0_2 = {}
    L1_2 = {}
    L1_2.smoke = nil
    L1_2.sparklers = nil
    L0_2.bass = L1_2
    L1_2 = {}
    L1_2.white = nil
    L1_2.dynamic = nil
    L1_2.photorythmic = nil
    L2_2 = {}
    L1_2.states = L2_2
    L2_2 = {}
    L1_2.colors = L2_2
    L0_2.spotlights = L1_2
    L1_2 = {}
    L2_2 = {}
    L1_2.colors = L2_2
    L0_2.smokers = L1_2
    L1_2 = {}
    L2_2 = {}
    L1_2.colors = L2_2
    L0_2.sparklers = L1_2
    L1_2 = {}
    L2_2 = {}
    L1_2.volumes = L2_2
    L0_2.speakers = L1_2
    L0_2.idleWallpaperUrl = nil
    L0_2.videoToggle = nil
    L18_1.settings = L0_2
  end
  L0_2 = DeactivateScenes
  L0_2()
end
ResetScene = L89_1
function L89_1(A0_2)
  local L1_2, L2_2, L3_2
  if "off" == A0_2 then
    L1_2 = L18_1.settings
    L1_2 = L1_2.bass
    L1_2.smoke = "off"
  else
    L1_2 = L18_1.settings
    L1_2 = L1_2.bass
    if A0_2 then
      L2_2 = {}
      L3_2 = A0_2.cooldownMs
      L2_2.cooldownMs = L3_2
      L3_2 = A0_2.colorWithDynamicSpotlights
      L2_2.colorWithDynamicSpotlights = L3_2
      if L2_2 then
        goto lbl_20
      end
    end
    L2_2 = nil
    ::lbl_20::
    L1_2.smoke = L2_2
  end
end
L18_1.SetSmokeBassSettings = L89_1
function L89_1(A0_2)
  local L1_2, L2_2, L3_2
  if "off" == A0_2 then
    L1_2 = L18_1.settings
    L1_2 = L1_2.bass
    L1_2.sparklers = "off"
  else
    L1_2 = L18_1.settings
    L1_2 = L1_2.bass
    if A0_2 then
      L2_2 = {}
      L3_2 = A0_2.cooldownMs
      L2_2.cooldownMs = L3_2
      L3_2 = A0_2.colorWithDynamicSpotlights
      L2_2.colorWithDynamicSpotlights = L3_2
      if L2_2 then
        goto lbl_20
      end
    end
    L2_2 = nil
    ::lbl_20::
    L1_2.sparklers = L2_2
  end
end
L18_1.SetSparklersBassSettings = L89_1
function L89_1(A0_2, A1_2, A2_2)
  local L3_2
  L3_2 = L18_1.settings
  L3_2 = L3_2.spotlights
  L3_2.white = A0_2
  L3_2 = L18_1.settings
  L3_2 = L3_2.spotlights
  L3_2.dynamic = A1_2
  L3_2 = L18_1.settings
  L3_2 = L3_2.spotlights
  L3_2.photorythmic = A2_2
  L3_2 = L43_1
  if L3_2 then
    L3_2 = L18_1.active
    if L3_2 then
      L46_1 = A0_2
      L47_1 = A1_2
      L48_1 = A2_2
      L3_2 = SyncSpotlightColors
      L3_2()
    end
  end
end
L18_1.SetSpotlightsSettings = L89_1
function L89_1(A0_2, A1_2)
  local L2_2
  L2_2 = L2_1
  L2_2 = L2_2[A0_2]
  if L2_2 then
    L2_2 = L18_1.settings
    L2_2 = L2_2.spotlights
    L2_2 = L2_2.states
    L2_2[A0_2] = A1_2
  end
  L2_2 = L43_1
  if L2_2 then
    L2_2 = L18_1.active
    if L2_2 then
      L2_2 = SyncSpotlightStates
      L2_2()
    end
  end
end
L18_1.SetSpotlightState = L89_1
function L89_1(A0_2, A1_2)
  local L2_2
  L2_2 = L2_1
  L2_2 = L2_2[A0_2]
  if L2_2 then
    L2_2 = L18_1.settings
    L2_2 = L2_2.spotlights
    L2_2 = L2_2.colors
    L2_2[A0_2] = A1_2
  end
  L2_2 = L43_1
  if L2_2 then
    L2_2 = L18_1.active
    if L2_2 then
      L2_2 = SyncSpotlightColors
      L2_2()
    end
  end
end
L18_1.SetSpotlightColor = L89_1
function L89_1(A0_2, A1_2)
  local L2_2
  L2_2 = L3_1
  L2_2 = L2_2[A0_2]
  if L2_2 then
    L2_2 = L18_1.settings
    L2_2 = L2_2.smokers
    L2_2 = L2_2.colors
    L2_2[A0_2] = A1_2
  end
end
L18_1.SetSmokerColor = L89_1
function L89_1(A0_2, A1_2)
  local L2_2
  L2_2 = L4_1
  L2_2 = L2_2[A0_2]
  if L2_2 then
    L2_2 = L18_1.settings
    L2_2 = L2_2.sparklers
    L2_2 = L2_2.colors
    L2_2[A0_2] = A1_2
  end
end
L18_1.SetSparklerColor = L89_1
function L89_1(A0_2, A1_2)
  local L2_2, L3_2, L4_2
  L2_2 = L7_1
  L2_2 = L2_2[A0_2]
  if L2_2 then
    L2_2 = L18_1.settings
    L2_2 = L2_2.speakers
    L2_2 = L2_2.volumes
    L2_2[A0_2] = A1_2
    L2_2 = L43_1
    if L2_2 then
      L2_2 = L18_1.active
      if L2_2 then
        L2_2 = SetBrowserSpeakerVolume
        L3_2 = L7_1
        L3_2 = L3_2[A0_2]
        L3_2 = L3_2.id
        L4_2 = A1_2
        L2_2(L3_2, L4_2)
      end
    end
  end
end
L18_1.SetSpeakerVolume = L89_1
function L89_1(A0_2)
  local L1_2, L2_2
  L1_2 = L18_1.settings
  L1_2.idleWallpaperUrl = A0_2
  L1_2 = L43_1
  if L1_2 then
    L1_2 = L18_1.active
    if L1_2 then
      L1_2 = SetBrowserIdleWallpaperUrl
      L2_2 = A0_2
      L1_2(L2_2)
    end
  end
end
L18_1.SetIdleWallpaperUrl = L89_1
function L89_1(A0_2)
  local L1_2, L2_2
  L1_2 = L18_1.settings
  L1_2.videoToggle = A0_2
  L1_2 = L43_1
  if L1_2 then
    L1_2 = L18_1.active
    if L1_2 then
      L1_2 = SetBrowserVideoToggle
      L2_2 = A0_2
      L1_2(L2_2)
    end
  end
end
L18_1.SetVideoToggle = L89_1
function L89_1(A0_2, A1_2)
  local L2_2, L3_2
  L2_2 = L19_1
  if L2_2 then
    L2_2 = L43_1
    if L2_2 then
      L2_2 = L18_1.active
      if L2_2 then
        L2_2 = CreateThread
        function L3_2()
          local L0_3, L1_3, L2_3
          L0_3 = DoSmoke
          L1_3 = A0_2
          if not L1_3 then
            L1_3 = GetSmokeColor
            L1_3 = L1_3()
          end
          L2_3 = A1_2
          L0_3(L1_3, L2_3)
        end
        L2_2(L3_2)
      end
    end
  end
end
L18_1.TriggerSmoke = L89_1
function L89_1(A0_2, A1_2)
  local L2_2, L3_2
  L2_2 = L19_1
  if L2_2 then
    L2_2 = L43_1
    if L2_2 then
      L2_2 = L18_1.active
      if L2_2 then
        L2_2 = CreateThread
        function L3_2()
          local L0_3, L1_3, L2_3
          L0_3 = DoSparklers
          L1_3 = A0_2
          if not L1_3 then
            L1_3 = GetSparklersColor
            L1_3 = L1_3()
          end
          L2_3 = A1_2
          L0_3(L1_3, L2_3)
        end
        L2_2(L3_2)
      end
    end
  end
end
L18_1.TriggerSparklers = L89_1
function L89_1()
  local L0_2, L1_2, L2_2, L3_2
  L0_2 = L19_1
  if L0_2 then
    L0_2 = L43_1
    if L0_2 then
      L0_2 = L18_1.active
      if L0_2 then
        L0_2 = L42_1
        if not L0_2 then
          L0_2 = isController
          if L0_2 then
            L0_2 = TriggerServerEvent
            L1_2 = "cs-hall:triggerSetting"
            L2_2 = L19_1
            L3_2 = "screenControl"
            L0_2(L1_2, L2_2, L3_2)
          end
        end
      end
    end
  end
end
L18_1.AdvanceScreens = L89_1
function L89_1()
  local L0_2, L1_2, L2_2, L3_2
  L0_2 = L19_1
  if L0_2 then
    L0_2 = L43_1
    if L0_2 then
      L0_2 = L18_1.active
      if L0_2 then
        L0_2 = L42_1
        if L0_2 then
          L0_2 = isController
          if L0_2 then
            L0_2 = TriggerServerEvent
            L1_2 = "cs-hall:triggerSetting"
            L2_2 = L19_1
            L3_2 = "screenControl"
            L0_2(L1_2, L2_2, L3_2)
          end
        end
      end
    end
  end
end
L18_1.RetractScreens = L89_1
function L89_1()
  local L0_2, L1_2
  L0_2 = ResetScene
  L0_2()
end
L18_1.Reset = L89_1
function L89_1()
  local L0_2, L1_2
  L0_2 = L2_1
  return L0_2
end
L18_1.GetSpotlights = L89_1
function L89_1()
  local L0_2, L1_2
  L0_2 = L3_1
  return L0_2
end
L18_1.GetSmokers = L89_1
function L89_1()
  local L0_2, L1_2
  L0_2 = L4_1
  return L0_2
end
L18_1.GetSparklers = L89_1
function L89_1()
  local L0_2, L1_2
  L0_2 = L7_1
  return L0_2
end
L18_1.GetSpeakers = L89_1
L89_1 = LerpCallback
L18_1.LerpCallback = L89_1
L89_1 = RegisterNUICallback
L90_1 = "browserReady"
function L91_1(A0_2, A1_2)
  local L2_2, L3_2
  L2_2 = true
  L54_1 = L2_2
  L2_2 = A1_2
  L3_2 = true
  L2_2(L3_2)
end
L89_1(L90_1, L91_1)
L89_1 = RegisterNUICallback
L90_1 = "managerReady"
function L91_1(A0_2, A1_2)
  local L2_2, L3_2
  L2_2 = OnBrowserManagerReady
  L2_2()
  L2_2 = A1_2
  L3_2 = true
  L2_2(L3_2)
end
L89_1(L90_1, L91_1)
L89_1 = RegisterNUICallback
L90_1 = "synced"
function L91_1(A0_2, A1_2)
  local L2_2, L3_2
  L2_2 = OnBrowserSynced
  L2_2()
  L2_2 = A1_2
  L3_2 = true
  L2_2(L3_2)
end
L89_1(L90_1, L91_1)
L89_1 = RegisterNUICallback
L90_1 = "controllerInfo"
function L91_1(A0_2, A1_2)
  local L2_2, L3_2, L4_2, L5_2, L6_2, L7_2, L8_2, L9_2, L10_2
  L2_2 = L57_1
  if L2_2 then
    L2_2 = A0_2.area
    L3_2 = L19_1
    if L2_2 == L3_2 then
      L2_2 = A0_2.dynamic
      L10_1.dynamic = L2_2
      L2_2 = L46_1
      if not L2_2 then
        L2_2 = L47_1
        if L2_2 then
          L2_2 = L10_1.dynamic
          if L2_2 then
            L2_2 = 1
            L3_2 = L2_1
            L3_2 = #L3_2
            L4_2 = 1
            for L5_2 = L2_2, L3_2, L4_2 do
              L6_2 = L2_1
              L6_2 = L6_2[L5_2]
              L7_2 = {}
              L8_2 = 0
              L9_2 = 0
              L10_2 = 0
              L7_2[1] = L8_2
              L7_2[2] = L9_2
              L7_2[3] = L10_2
              L6_2.currentColor = L7_2
            end
        end
        else
          L2_2 = 1
          L3_2 = L2_1
          L3_2 = #L3_2
          L4_2 = 1
          for L5_2 = L2_2, L3_2, L4_2 do
            L6_2 = L2_1
            L6_2 = L6_2[L5_2]
            L7_2 = GetSpotlightColor
            L8_2 = L5_2
            L9_2 = L2_1
            L9_2 = L9_2[L5_2]
            L9_2 = L9_2.originalColor
            L7_2 = L7_2(L8_2, L9_2)
            L6_2.currentColor = L7_2
          end
        end
      end
    end
  end
  L2_2 = A1_2
  L3_2 = true
  L2_2(L3_2)
end
L89_1(L90_1, L91_1)
L89_1 = RegisterNUICallback
L90_1 = "controllerError"
function L91_1(A0_2, A1_2)
  local L2_2, L3_2, L4_2
  L2_2 = L57_1
  if L2_2 then
    L2_2 = A0_2.area
    L3_2 = L19_1
    if L2_2 == L3_2 then
      L2_2 = L38_1
      if L2_2 then
        L2_2 = A0_2.error
        L3_2 = A0_2.error
        if "E_SOURCE_ERROR" == L3_2 then
          L3_2 = config
          L3_2 = L3_2.lang
          L2_2 = L3_2.sourceError
        else
          L3_2 = A0_2.error
          if "E_SOURCE_NOT_FOUND" == L3_2 then
            L3_2 = config
            L3_2 = L3_2.lang
            L2_2 = L3_2.sourceNotFound
          end
        end
        L3_2 = SendNUIMessage
        L4_2 = {}
        L4_2.type = "cs-hall:error"
        L4_2.error = L2_2
        L3_2(L4_2)
      end
      L2_2 = L53_1
      if L2_2 then
        L2_2 = TriggerServerEvent
        L3_2 = "cs-hall:controllerError"
        L4_2 = L19_1
        L2_2(L3_2, L4_2)
      end
    end
  end
  L2_2 = ResetFrequencyData
  L2_2()
  L2_2 = A1_2
  L3_2 = true
  L2_2(L3_2)
end
L89_1(L90_1, L91_1)
L89_1 = RegisterNUICallback
L90_1 = "controllerEnded"
function L91_1(A0_2, A1_2)
  local L2_2, L3_2, L4_2
  L2_2 = L57_1
  if L2_2 then
    L2_2 = A0_2.area
    L3_2 = L19_1
    if L2_2 == L3_2 then
      L2_2 = L53_1
      if L2_2 then
        L2_2 = TriggerServerEvent
        L3_2 = "cs-hall:controllerEnded"
        L4_2 = L19_1
        L2_2(L3_2, L4_2)
      end
    end
  end
  L2_2 = ResetFrequencyData
  L2_2()
  L2_2 = A1_2
  L3_2 = true
  L2_2(L3_2)
end
L89_1(L90_1, L91_1)
L89_1 = RegisterNUICallback
L90_1 = "controllerResync"
function L91_1(A0_2, A1_2)
  local L2_2, L3_2, L4_2, L5_2
  L2_2 = L57_1
  if L2_2 then
    L2_2 = A0_2.area
    L3_2 = L19_1
    if L2_2 == L3_2 then
      L2_2 = TriggerServerEvent
      L3_2 = "cs-hall:resync"
      L4_2 = L19_1
      L5_2 = true
      L2_2(L3_2, L4_2, L5_2)
    end
  end
  L2_2 = A1_2
  L3_2 = true
  L2_2(L3_2)
end
L89_1(L90_1, L91_1)
L89_1 = RegisterNUICallback
L90_1 = "frequencyData"
function L91_1(A0_2, A1_2)
  local L2_2, L3_2, L4_2
  L2_2 = A0_2.levels
  L2_2 = L2_2.bass
  L12_1.bass = L2_2
  L2_2 = A0_2.levels
  L2_2 = L2_2.mid
  L12_1.mid = L2_2
  L2_2 = A0_2.levels
  L2_2 = L2_2.treble
  L12_1.treble = L2_2
  L2_2 = A0_2.levels
  L2_2 = L2_2.lowMid
  L12_1.lowMid = L2_2
  L2_2 = A0_2.levels
  L2_2 = L2_2.highMid
  L12_1.highMid = L2_2
  L2_2 = GetGameTimer
  L2_2 = L2_2()
  L3_2 = L13_1.time
  L2_2 = L2_2 - L3_2
  L3_2 = L63_1
  if L2_2 >= L3_2 then
    L2_2 = GetGameTimer
    L2_2 = L2_2()
    L13_1.time = L2_2
    L2_2 = L13_1.previous
    L3_2 = L13_1.current
    L3_2 = L3_2.bass
    L2_2.bass = L3_2
    L2_2 = L13_1.previous
    L3_2 = L13_1.current
    L3_2 = L3_2.mid
    L2_2.mid = L3_2
    L2_2 = L13_1.previous
    L3_2 = L13_1.current
    L3_2 = L3_2.treble
    L2_2.treble = L3_2
    L2_2 = L13_1.previous
    L3_2 = L13_1.current
    L3_2 = L3_2.lowMid
    L2_2.lowMid = L3_2
    L2_2 = L13_1.previous
    L3_2 = L13_1.current
    L3_2 = L3_2.highMid
    L2_2.highMid = L3_2
    L2_2 = L13_1.current
    L2_2.bass = 0
    L2_2 = L13_1.current
    L2_2.mid = 0
    L2_2 = L13_1.current
    L2_2.treble = 0
    L2_2 = L13_1.current
    L2_2.lowMid = 0
    L2_2 = L13_1.current
    L2_2.highMid = 0
    L14_1.bass = 0
    L14_1.mid = 0
    L14_1.treble = 0
    L14_1.lowMid = 0
    L14_1.highMid = 0
    L15_1.bass = 0
    L15_1.mid = 0
    L15_1.treble = 0
    L15_1.lowMid = 0
    L15_1.highMid = 0
  end
  L2_2 = L14_1.bass
  L3_2 = L12_1.bass
  L2_2 = L2_2 + L3_2
  L14_1.bass = L2_2
  L2_2 = L15_1.bass
  L2_2 = L2_2 + 1
  L15_1.bass = L2_2
  L2_2 = L13_1.current
  L3_2 = L14_1.bass
  L4_2 = L15_1.bass
  L3_2 = L3_2 / L4_2
  L2_2.bass = L3_2
  L2_2 = L14_1.mid
  L3_2 = L12_1.mid
  L2_2 = L2_2 + L3_2
  L14_1.mid = L2_2
  L2_2 = L15_1.mid
  L2_2 = L2_2 + 1
  L15_1.mid = L2_2
  L2_2 = L13_1.current
  L3_2 = L14_1.mid
  L4_2 = L15_1.mid
  L3_2 = L3_2 / L4_2
  L2_2.mid = L3_2
  L2_2 = L14_1.treble
  L3_2 = L12_1.treble
  L2_2 = L2_2 + L3_2
  L14_1.treble = L2_2
  L2_2 = L15_1.treble
  L2_2 = L2_2 + 1
  L15_1.treble = L2_2
  L2_2 = L13_1.current
  L3_2 = L14_1.treble
  L4_2 = L15_1.treble
  L3_2 = L3_2 / L4_2
  L2_2.treble = L3_2
  L2_2 = L14_1.lowMid
  L3_2 = L12_1.lowMid
  L2_2 = L2_2 + L3_2
  L14_1.lowMid = L2_2
  L2_2 = L15_1.lowMid
  L2_2 = L2_2 + 1
  L15_1.lowMid = L2_2
  L2_2 = L13_1.current
  L3_2 = L14_1.lowMid
  L4_2 = L15_1.lowMid
  L3_2 = L3_2 / L4_2
  L2_2.lowMid = L3_2
  L2_2 = L14_1.highMid
  L3_2 = L12_1.highMid
  L2_2 = L2_2 + L3_2
  L14_1.highMid = L2_2
  L2_2 = L15_1.highMid
  L2_2 = L2_2 + 1
  L15_1.highMid = L2_2
  L2_2 = L13_1.current
  L3_2 = L14_1.highMid
  L4_2 = L15_1.highMid
  L3_2 = L3_2 / L4_2
  L2_2.highMid = L3_2
  L2_2 = A1_2
  L3_2 = true
  L2_2(L3_2)
end
L89_1(L90_1, L91_1)
L89_1 = RegisterNUICallback
L90_1 = "mediaKey"
function L91_1(A0_2, A1_2)
  local L2_2, L3_2, L4_2, L5_2, L6_2
  L2_2 = L57_1
  if L2_2 then
    L3_2 = L19_1
    L2_2 = L17_1
    L2_2 = L2_2[L3_2]
    if L2_2 then
      L2_2 = CanAccessUi
      L2_2 = L2_2()
      if L2_2 then
        goto lbl_14
      end
    end
  end
  do return end
  ::lbl_14::
  L2_2 = A0_2.type
  if "play" == L2_2 then
    L2_2 = TriggerServerEvent
    L3_2 = "cs-hall:play"
    L4_2 = L19_1
    L5_2 = true
    L6_2 = L38_1
    L2_2(L3_2, L4_2, L5_2, L6_2)
  else
    L2_2 = A0_2.type
    if "pause" == L2_2 then
      L2_2 = TriggerServerEvent
      L3_2 = "cs-hall:pause"
      L4_2 = L19_1
      L5_2 = true
      L6_2 = L38_1
      L2_2(L3_2, L4_2, L5_2, L6_2)
    else
      L2_2 = A0_2.type
      if "stop" == L2_2 then
        L2_2 = TriggerServerEvent
        L3_2 = "cs-hall:stop"
        L4_2 = L19_1
        L5_2 = true
        L6_2 = L38_1
        L2_2(L3_2, L4_2, L5_2, L6_2)
      else
        L2_2 = A0_2.type
        if "nexttrack" == L2_2 then
          L2_2 = TriggerServerEvent
          L3_2 = "cs-hall:nextQueueSong"
          L4_2 = L19_1
          L5_2 = true
          L6_2 = L38_1
          L2_2(L3_2, L4_2, L5_2, L6_2)
        end
      end
    end
  end
  L2_2 = A1_2
  L3_2 = true
  L2_2(L3_2)
end
L89_1(L90_1, L91_1)
L89_1 = RegisterNUICallback
L90_1 = "controllerPlayingInfo"
function L91_1(A0_2, A1_2)
  local L2_2, L3_2, L4_2, L5_2
  L2_2 = A0_2.area
  L3_2 = L19_1
  if L2_2 ~= L3_2 then
    return
  end
  L2_2 = L11_1.playing
  if not L2_2 then
    L2_2 = A0_2.playing
    if L2_2 then
      L2_2 = GetGameTimer
      L2_2 = L2_2()
      L24_1 = L2_2
  end
  else
    L2_2 = A0_2.playing
    if not L2_2 then
      L2_2 = nil
      L24_1 = L2_2
    end
  end
  L2_2 = A0_2.time
  L11_1.time = L2_2
  L2_2 = A0_2.duration
  L11_1.duration = L2_2
  L2_2 = A0_2.playing
  L11_1.playing = L2_2
  L2_2 = A0_2.time
  L18_1.time = L2_2
  L2_2 = A0_2.duration
  L18_1.duration = L2_2
  L2_2 = A0_2.playing
  L18_1.playing = L2_2
  L2_2 = SetScene
  L2_2()
  L2_2 = L18_1.active
  if L2_2 then
    L2_2 = L27_1
    if L2_2 then
      L3_2 = L27_1
      L2_2 = L8_1
      L2_2 = L2_2[L3_2]
      if L2_2 then
        goto lbl_48
      end
    end
    L2_2 = ResetScene
    L2_2()
  end
  ::lbl_48::
  L2_2 = SendNUIMessage
  L3_2 = {}
  L3_2.type = "cs-hall:info"
  L4_2 = L11_1.time
  L3_2.time = L4_2
  L4_2 = L11_1.duration
  L3_2.duration = L4_2
  L2_2(L3_2)
  L2_2 = L11_1.duration
  if L2_2 then
    L2_2 = L11_1.duration
    L3_2 = L23_1
    if L2_2 ~= L3_2 then
      L2_2 = L11_1.duration
      L23_1 = L2_2
      L2_2 = L53_1
      if L2_2 then
        L2_2 = TriggerServerEvent
        L3_2 = "cs-hall:duration"
        L4_2 = L19_1
        L5_2 = L11_1.duration
        L2_2(L3_2, L4_2, L5_2)
      end
    end
  end
  L2_2 = A1_2
  L3_2 = true
  L2_2(L3_2)
end
L89_1(L90_1, L91_1)
L89_1 = RegisterNUICallback
L90_1 = "controllerSeeked"
function L91_1(A0_2, A1_2)
  local L2_2, L3_2
  L2_2 = SendNUIMessage
  L3_2 = {}
  L3_2.type = "cs-hall:seeked"
  L2_2(L3_2)
  L2_2 = A1_2
  L3_2 = true
  L2_2(L3_2)
end
L89_1(L90_1, L91_1)
L89_1 = RegisterNUICallback
L90_1 = "colorData"
function L91_1(A0_2, A1_2)
  local L2_2, L3_2, L4_2, L5_2, L6_2, L7_2
  L2_2 = A0_2.colors
  L2_2 = L2_2.DarkVibrant
  L16_1.DarkVibrant = L2_2
  L2_2 = A0_2.colors
  L2_2 = L2_2.Vibrant
  L16_1.Vibrant = L2_2
  L2_2 = A0_2.colors
  L2_2 = L2_2.LightVibrant
  L16_1.LightVibrant = L2_2
  L2_2 = A0_2.colors
  L2_2 = L2_2.DarkMuted
  L16_1.DarkMuted = L2_2
  L2_2 = A0_2.colors
  L2_2 = L2_2.LightMuted
  L16_1.LightMuted = L2_2
  L2_2 = L46_1
  if not L2_2 then
    L2_2 = L47_1
    if L2_2 then
      L2_2 = L10_1.dynamic
      if L2_2 then
        L2_2 = 1
        L3_2 = L2_1
        L3_2 = #L3_2
        L4_2 = 1
        for L5_2 = L2_2, L3_2, L4_2 do
          L6_2 = L2_1
          L6_2 = L6_2[L5_2]
          L6_2 = L6_2.soundSyncType
          L7_2 = SOUND_SYNC_TYPE
          L7_2 = L7_2.BASS
          if L6_2 == L7_2 then
            L6_2 = L2_1
            L6_2 = L6_2[L5_2]
            L7_2 = A0_2.colors
            L7_2 = L7_2.DarkVibrant
            L6_2.currentColor = L7_2
          else
            L6_2 = L2_1
            L6_2 = L6_2[L5_2]
            L6_2 = L6_2.soundSyncType
            L7_2 = SOUND_SYNC_TYPE
            L7_2 = L7_2.MID
            if L6_2 == L7_2 then
              L6_2 = L2_1
              L6_2 = L6_2[L5_2]
              L7_2 = A0_2.colors
              L7_2 = L7_2.Vibrant
              L6_2.currentColor = L7_2
            else
              L6_2 = L2_1
              L6_2 = L6_2[L5_2]
              L6_2 = L6_2.soundSyncType
              L7_2 = SOUND_SYNC_TYPE
              L7_2 = L7_2.TREBLE
              if L6_2 == L7_2 then
                L6_2 = L2_1
                L6_2 = L6_2[L5_2]
                L7_2 = A0_2.colors
                L7_2 = L7_2.LightVibrant
                L6_2.currentColor = L7_2
              else
                L6_2 = L2_1
                L6_2 = L6_2[L5_2]
                L6_2 = L6_2.soundSyncType
                L7_2 = SOUND_SYNC_TYPE
                L7_2 = L7_2.LOW_MID
                if L6_2 == L7_2 then
                  L6_2 = L2_1
                  L6_2 = L6_2[L5_2]
                  L7_2 = A0_2.colors
                  L7_2 = L7_2.DarkMuted
                  L6_2.currentColor = L7_2
                else
                  L6_2 = L2_1
                  L6_2 = L6_2[L5_2]
                  L6_2 = L6_2.soundSyncType
                  L7_2 = SOUND_SYNC_TYPE
                  L7_2 = L7_2.HIGH_MID
                  if L6_2 == L7_2 then
                    L6_2 = L2_1
                    L6_2 = L6_2[L5_2]
                    L7_2 = A0_2.colors
                    L7_2 = L7_2.LightMuted
                    L6_2.currentColor = L7_2
                  end
                end
              end
            end
          end
        end
      end
    end
  end
  L2_2 = A1_2
  L3_2 = true
  L2_2(L3_2)
end
L89_1(L90_1, L91_1)
L89_1 = RegisterNUICallback
L90_1 = "urlAdded"
function L91_1(A0_2, A1_2)
  local L2_2, L3_2, L4_2, L5_2, L6_2, L7_2, L8_2, L9_2, L10_2, L11_2
  L2_2 = TriggerServerEvent
  L3_2 = "cs-hall:addToQueue"
  L4_2 = L19_1
  L5_2 = A0_2.url
  L6_2 = A0_2.thumbnailUrl
  L7_2 = Ternary
  L8_2 = A0_2.thumbnailTitle
  L9_2 = false
  L7_2 = L7_2(L8_2, L9_2)
  L8_2 = A0_2.title
  L9_2 = Ternary
  L10_2 = A0_2.icon
  L11_2 = false
  L9_2, L10_2, L11_2 = L9_2(L10_2, L11_2)
  L2_2(L3_2, L4_2, L5_2, L6_2, L7_2, L8_2, L9_2, L10_2, L11_2)
  L2_2 = A1_2
  L3_2 = true
  L2_2(L3_2)
end
L89_1(L90_1, L91_1)
L89_1 = RegisterNUICallback
L90_1 = "remoteControl"
function L91_1(A0_2, A1_2)
  local L2_2, L3_2, L4_2, L5_2
  L3_2 = L19_1
  L2_2 = L17_1
  L5_2 = L19_1
  L4_2 = L17_1
  L4_2 = L4_2[L5_2]
  L4_2 = not L4_2
  L2_2[L3_2] = L4_2
  L2_2 = TriggerServerEvent
  L3_2 = "cs-hall:resync"
  L4_2 = L19_1
  L5_2 = false
  L2_2(L3_2, L4_2, L5_2)
  L2_2 = A1_2
  L3_2 = true
  L2_2(L3_2)
end
L89_1(L90_1, L91_1)
L89_1 = RegisterNUICallback
L90_1 = "setSceneIdentifier"
function L91_1(A0_2, A1_2)
  local L2_2, L3_2
  L2_2 = A0_2.identifier
  L27_1 = L2_2
  L2_2 = A1_2
  L3_2 = true
  L2_2(L3_2)
end
L89_1(L90_1, L91_1)
L89_1 = RegisterNUICallback
L90_1 = "playerPaused"
function L91_1(A0_2, A1_2)
  local L2_2, L3_2, L4_2
  L2_2 = TriggerServerEvent
  L3_2 = "cs-hall:pause"
  L4_2 = L19_1
  L2_2(L3_2, L4_2)
  L2_2 = A1_2
  L3_2 = true
  L2_2(L3_2)
end
L89_1(L90_1, L91_1)
L89_1 = RegisterNUICallback
L90_1 = "playerPlayed"
function L91_1(A0_2, A1_2)
  local L2_2, L3_2, L4_2
  L2_2 = TriggerServerEvent
  L3_2 = "cs-hall:play"
  L4_2 = L19_1
  L2_2(L3_2, L4_2)
  L2_2 = A1_2
  L3_2 = true
  L2_2(L3_2)
end
L89_1(L90_1, L91_1)
L89_1 = RegisterNUICallback
L90_1 = "playerStopped"
function L91_1(A0_2, A1_2)
  local L2_2, L3_2, L4_2
  L2_2 = TriggerServerEvent
  L3_2 = "cs-hall:stop"
  L4_2 = L19_1
  L2_2(L3_2, L4_2)
  L2_2 = A1_2
  L3_2 = true
  L2_2(L3_2)
end
L89_1(L90_1, L91_1)
L89_1 = RegisterNUICallback
L90_1 = "playerSkipped"
function L91_1(A0_2, A1_2)
  local L2_2, L3_2, L4_2
  L2_2 = TriggerServerEvent
  L3_2 = "cs-hall:nextQueueSong"
  L4_2 = L19_1
  L2_2(L3_2, L4_2)
  L2_2 = A1_2
  L3_2 = true
  L2_2(L3_2)
end
L89_1(L90_1, L91_1)
L89_1 = RegisterNUICallback
L90_1 = "playerLooped"
function L91_1(A0_2, A1_2)
  local L2_2, L3_2, L4_2
  L2_2 = TriggerServerEvent
  L3_2 = "cs-hall:toggleLoop"
  L4_2 = L19_1
  L2_2(L3_2, L4_2)
  L2_2 = A1_2
  L3_2 = true
  L2_2(L3_2)
end
L89_1(L90_1, L91_1)
L89_1 = RegisterNUICallback
L90_1 = "changeVolume"
function L91_1(A0_2, A1_2)
  local L2_2, L3_2, L4_2, L5_2
  L2_2 = TriggerServerEvent
  L3_2 = "cs-hall:changeVolume"
  L4_2 = L19_1
  L5_2 = A0_2.value
  L2_2(L3_2, L4_2, L5_2)
  L2_2 = A1_2
  L3_2 = true
  L2_2(L3_2)
end
L89_1(L90_1, L91_1)
L89_1 = RegisterNUICallback
L90_1 = "seek"
function L91_1(A0_2, A1_2)
  local L2_2, L3_2, L4_2, L5_2, L6_2, L7_2, L8_2
  L2_2 = TriggerServerEvent
  L3_2 = "cs-hall:seek"
  L4_2 = L19_1
  L5_2 = Ternary
  L6_2 = L11_1.duration
  if L6_2 then
    L6_2 = L11_1.duration
    L6_2 = L6_2 > 0
  end
  L7_2 = L11_1.duration
  L7_2 = L7_2 - 0.5
  L8_2 = A0_2.value
  L5_2, L6_2, L7_2, L8_2 = L5_2(L6_2, L7_2, L8_2)
  L2_2(L3_2, L4_2, L5_2, L6_2, L7_2, L8_2)
  L2_2 = A1_2
  L3_2 = true
  L2_2(L3_2)
end
L89_1(L90_1, L91_1)
L89_1 = RegisterNUICallback
L90_1 = "queueNow"
function L91_1(A0_2, A1_2)
  local L2_2, L3_2, L4_2, L5_2
  L2_2 = TriggerServerEvent
  L3_2 = "cs-hall:queueNow"
  L4_2 = L19_1
  L5_2 = A0_2.index
  L2_2(L3_2, L4_2, L5_2)
  L2_2 = A1_2
  L3_2 = true
  L2_2(L3_2)
end
L89_1(L90_1, L91_1)
L89_1 = RegisterNUICallback
L90_1 = "queueNext"
function L91_1(A0_2, A1_2)
  local L2_2, L3_2, L4_2, L5_2
  L2_2 = TriggerServerEvent
  L3_2 = "cs-hall:queueNext"
  L4_2 = L19_1
  L5_2 = A0_2.index
  L2_2(L3_2, L4_2, L5_2)
  L2_2 = A1_2
  L3_2 = true
  L2_2(L3_2)
end
L89_1(L90_1, L91_1)
L89_1 = RegisterNUICallback
L90_1 = "queueRemove"
function L91_1(A0_2, A1_2)
  local L2_2, L3_2, L4_2, L5_2
  L2_2 = TriggerServerEvent
  L3_2 = "cs-hall:queueRemove"
  L4_2 = L19_1
  L5_2 = A0_2.index
  L2_2(L3_2, L4_2, L5_2)
  L2_2 = A1_2
  L3_2 = true
  L2_2(L3_2)
end
L89_1(L90_1, L91_1)
L89_1 = RegisterNUICallback
L90_1 = "toggleSetting"
function L91_1(A0_2, A1_2)
  local L2_2, L3_2, L4_2, L5_2
  L2_2 = TriggerServerEvent
  L3_2 = "cs-hall:toggleSetting"
  L4_2 = L19_1
  L5_2 = A0_2.key
  L2_2(L3_2, L4_2, L5_2)
  L2_2 = A1_2
  L3_2 = true
  L2_2(L3_2)
end
L89_1(L90_1, L91_1)
L89_1 = RegisterNUICallback
L90_1 = "triggerSetting"
function L91_1(A0_2, A1_2)
  local L2_2, L3_2, L4_2, L5_2
  L2_2 = TriggerServerEvent
  L3_2 = "cs-hall:triggerSetting"
  L4_2 = L19_1
  L5_2 = A0_2.key
  L2_2(L3_2, L4_2, L5_2)
  L2_2 = A1_2
  L3_2 = true
  L2_2(L3_2)
end
L89_1(L90_1, L91_1)
L89_1 = RegisterNUICallback
L90_1 = "inputBlur"
function L91_1(A0_2, A1_2)
  local L2_2, L3_2
  L2_2 = L38_1
  if L2_2 then
    L2_2 = SetNuiFocusKeepInput
    L3_2 = true
    L2_2(L3_2)
  end
  L2_2 = A1_2
  L3_2 = true
  L2_2(L3_2)
end
L89_1(L90_1, L91_1)
L89_1 = RegisterNUICallback
L90_1 = "inputFocus"
function L91_1(A0_2, A1_2)
  local L2_2, L3_2
  L2_2 = Wait
  L3_2 = 250
  L2_2(L3_2)
  L2_2 = SetNuiFocusKeepInput
  L3_2 = false
  L2_2(L3_2)
  L2_2 = A1_2
  L3_2 = true
  L2_2(L3_2)
end
L89_1(L90_1, L91_1)
L89_1 = RegisterNUICallback
L90_1 = "hideUi"
function L91_1(A0_2, A1_2)
  local L2_2, L3_2
  L2_2 = L38_1
  if L2_2 then
    L2_2 = HideUi
    L2_2()
  end
  L2_2 = A1_2
  L3_2 = true
  L2_2(L3_2)
end
L89_1(L90_1, L91_1)
L89_1 = RegisterNUICallback
L90_1 = "nuiReady"
function L91_1(A0_2, A1_2)
  local L2_2, L3_2, L4_2
  L2_2 = true
  L61_1 = L2_2
  L2_2 = SendNUIMessage
  L3_2 = {}
  L3_2.type = "cs-hall:ready"
  L4_2 = config
  L4_2 = L4_2.lang
  L3_2.lang = L4_2
  L2_2(L3_2)
  L2_2 = A1_2
  L3_2 = true
  L2_2(L3_2)
end
L89_1(L90_1, L91_1)
L89_1 = RegisterNetEvent
L90_1 = "cs-hall:cui"
function L91_1(A0_2)
  local L1_2
  L1_2 = L38_1
  if L1_2 then
    L1_2 = HideUi
    L1_2()
  elseif not A0_2 then
    L1_2 = ShowUi
    L1_2()
  end
end
L89_1(L90_1, L91_1)
L89_1 = RegisterNetEvent
L90_1 = "cs-hall:updater"
function L91_1(A0_2, A1_2)
  local L2_2
  L2_2 = L19_1
  if A0_2 == L2_2 then
    L53_1 = A1_2
    L2_2 = L53_1
    L18_1.isUpdater = L2_2
  end
end
L89_1(L90_1, L91_1)
L89_1 = RegisterNetEvent
L90_1 = "cs-hall:controller"
function L91_1(A0_2, A1_2)
  local L2_2
  L2_2 = L19_1
  if A0_2 == L2_2 then
    isController = A1_2
    L2_2 = isController
    L18_1.isController = L2_2
  end
end
L89_1(L90_1, L91_1)
L89_1 = RegisterNetEvent
L90_1 = "cs-hall:smoke"
function L91_1(A0_2, A1_2)
  local L2_2, L3_2
  L2_2 = L19_1
  if A0_2 == L2_2 then
    L2_2 = DoSmoke
    L3_2 = A1_2
    L2_2(L3_2)
  end
end
L89_1(L90_1, L91_1)
L89_1 = RegisterNetEvent
L90_1 = "cs-hall:sparklers"
function L91_1(A0_2, A1_2)
  local L2_2, L3_2
  L2_2 = L19_1
  if A0_2 == L2_2 then
    L2_2 = DoSparklers
    L3_2 = A1_2
    L2_2(L3_2)
  end
end
L89_1(L90_1, L91_1)
L89_1 = RegisterNetEvent
L90_1 = "cs-hall:queue"
function L91_1(A0_2, A1_2)
  local L2_2, L3_2, L4_2
  L2_2 = L19_1
  if A0_2 == L2_2 then
    L88_1 = A1_2
    L2_2 = SendNUIMessage
    L3_2 = {}
    L3_2.type = "cs-hall:queue"
    L4_2 = L88_1
    L3_2.queue = L4_2
    L2_2(L3_2)
  end
end
L89_1(L90_1, L91_1)
L89_1 = RegisterNetEvent
L90_1 = "cs-hall:client"
function L91_1()
  local L0_2, L1_2
  L0_2 = true
  L36_1 = L0_2
end
L89_1(L90_1, L91_1)
L89_1 = RegisterNetEvent
L90_1 = "cs-hall:params"
function L91_1(A0_2, A1_2)
  local L2_2
  L25_1 = A0_2
  L26_1 = A1_2
  L2_2 = true
  L37_1 = L2_2
end
L89_1(L90_1, L91_1)
L89_1 = RegisterNetEvent
L90_1 = "cs-hall:sync"
function L91_1(A0_2, A1_2, A2_2, A3_2)
  local L4_2, L5_2, L6_2, L7_2, L8_2, L9_2, L10_2, L11_2, L12_2
  L4_2 = L19_1
  if A0_2 == L4_2 then
    L4_2 = config
    L4_2 = L4_2.debug
    if L4_2 then
      L4_2 = print
      L5_2 = "[debug] syncing"
      L6_2 = L6_1
      L6_2 = #L6_2
      L7_2 = A2_2.force
      L8_2 = A1_2.screens
      L8_2 = L8_2.advancedAt
      L9_2 = A1_2.screens
      L9_2 = L9_2.retractedAt
      L10_2 = A3_2
      L11_2 = A1_2.screens
      L11_2 = L11_2.advancingAt
      L12_2 = A1_2.screens
      L12_2 = L12_2.retractingAt
      L4_2(L5_2, L6_2, L7_2, L8_2, L9_2, L10_2, L11_2, L12_2)
    end
    L4_2 = A2_2.force
    if L4_2 then
      L4_2 = A1_2.screens
      L4_2 = L4_2.advancedAt
      if L4_2 then
        L4_2 = A1_2.screens
        L4_2 = L4_2.advancedAt
        if A3_2 > L4_2 then
          L4_2 = A1_2.screens
          L4_2 = L4_2.retractedAt
          if L4_2 then
            L4_2 = A1_2.screens
            L4_2 = L4_2.advancedAt
            L5_2 = A1_2.screens
            L5_2 = L5_2.retractedAt
            if not (L4_2 > L5_2) then
              goto lbl_53
            end
          end
          L4_2 = config
          L4_2 = L4_2.debug
          if L4_2 then
            L4_2 = print
            L5_2 = "[debug] advancing screens immediately"
            L4_2(L5_2)
          end
          L4_2 = AdvanceScreensImmediately
          L4_2()
        end
      end
    end
    ::lbl_53::
    L4_2 = L6_1
    L4_2 = #L4_2
    if L4_2 > 0 then
      L4_2 = A1_2.screens
      L4_2 = L4_2.advancedAt
      if L4_2 then
        L4_2 = A1_2.screens
        L4_2 = L4_2.advancedAt
        if A3_2 <= L4_2 then
          L4_2 = A1_2.screens
          L4_2 = L4_2.retractingAt
          if L4_2 then
            L4_2 = A1_2.screens
            L4_2 = L4_2.advancingAt
            L5_2 = A1_2.screens
            L5_2 = L5_2.retractingAt
            if not (L4_2 > L5_2) then
              goto lbl_91
            end
          end
          L4_2 = config
          L4_2 = L4_2.debug
          if L4_2 then
            L4_2 = print
            L5_2 = "[debug] advancing screens normally"
            L4_2(L5_2)
          end
          L4_2 = AdvanceScreens
          L5_2 = A1_2.screens
          L5_2 = L5_2.advancingAt
          L6_2 = A3_2
          L4_2(L5_2, L6_2)
          L4_2 = true
          L42_1 = L4_2
          L18_1.screensAdvanced = true
      end
      ::lbl_91::
      else
        L4_2 = A1_2.screens
        L4_2 = L4_2.retractedAt
        if L4_2 then
          L4_2 = A1_2.screens
          L4_2 = L4_2.retractedAt
          if A3_2 <= L4_2 then
            L4_2 = A1_2.screens
            L4_2 = L4_2.advancingAt
            if L4_2 then
              L4_2 = A1_2.screens
              L4_2 = L4_2.retractingAt
              L5_2 = A1_2.screens
              L5_2 = L5_2.advancingAt
              if not (L4_2 > L5_2) then
                goto lbl_124
              end
            end
            L4_2 = config
            L4_2 = L4_2.debug
            if L4_2 then
              L4_2 = print
              L5_2 = "[debug] retracting screens"
              L4_2(L5_2)
            end
            L4_2 = RetractScreens
            L5_2 = A1_2.screens
            L5_2 = L5_2.retractingAt
            L6_2 = A3_2
            L4_2(L5_2, L6_2)
            L4_2 = false
            L42_1 = L4_2
            L18_1.screensAdvanced = false
          end
        end
      end
    end
    ::lbl_124::
    L4_2 = SendNUIMessage
    L5_2 = {}
    L5_2.type = "cs-hall:sync"
    L6_2 = A1_2.media
    L5_2.media = L6_2
    L6_2 = A1_2.screens
    L5_2.screens = L6_2
    L6_2 = A1_2.settings
    L5_2.settings = L6_2
    L6_2 = L6_1
    L6_2 = #L6_2
    L6_2 = L6_2 > 0
    L5_2.hasScreens = L6_2
    L6_2 = L3_1
    L6_2 = #L6_2
    L6_2 = L6_2 > 0
    L5_2.hasSmokers = L6_2
    L6_2 = L4_1
    L6_2 = #L6_2
    L6_2 = L6_2 > 0
    L5_2.hasSparklers = L6_2
    L6_2 = config
    L6_2 = L6_2.entries
    L7_2 = L19_1
    L6_2 = L6_2[L7_2]
    L6_2 = L6_2.bass
    L6_2 = config
    L6_2 = L6_2.entries
    L7_2 = L19_1
    L6_2 = L6_2[L7_2]
    L6_2 = L6_2.bass
    L6_2 = L6_2.smoke
    L6_2 = not L6_2
    L6_2 = L6_2 and L6_2
    L5_2.hasAutoSmokers = L6_2
    L6_2 = config
    L6_2 = L6_2.entries
    L7_2 = L19_1
    L6_2 = L6_2[L7_2]
    L6_2 = L6_2.bass
    L6_2 = config
    L6_2 = L6_2.entries
    L7_2 = L19_1
    L6_2 = L6_2[L7_2]
    L6_2 = L6_2.bass
    L6_2 = L6_2.sparklers
    L6_2 = not L6_2
    L6_2 = L6_2 and L6_2
    L5_2.hasAutoSparklers = L6_2
    L6_2 = L2_1
    L6_2 = #L6_2
    L6_2 = L6_2 > 0
    L5_2.hasSpotlights = L6_2
    L6_2 = L7_1
    L6_2 = #L6_2
    L6_2 = L6_2 > 0
    L5_2.hasSpeakers = L6_2
    L7_2 = L19_1
    L6_2 = L17_1
    L6_2 = L6_2[L7_2]
    L5_2.remoteControl = L6_2
    L4_2(L5_2)
    L4_2 = A1_2.settings
    L4_2 = L4_2.scenesEnabled
    L43_1 = L4_2
    L4_2 = A1_2.settings
    L4_2 = L4_2.bassSmoke
    L44_1 = L4_2
    L4_2 = A1_2.settings
    L4_2 = L4_2.bassSparklers
    L45_1 = L4_2
    L4_2 = L43_1
    L18_1.enabled = L4_2
    L4_2 = L18_1.original
    L5_2 = A1_2.settings
    L5_2 = L5_2.whiteSpotlights
    L4_2.whiteSpotlights = L5_2
    L4_2 = L18_1.original
    L5_2 = A1_2.settings
    L5_2 = L5_2.dynamicSpotlights
    L4_2.dynamicSpotlights = L5_2
    L4_2 = L18_1.original
    L5_2 = A1_2.settings
    L5_2 = L5_2.photorythmicSpotlights
    L4_2.photorythmicSpotlights = L5_2
    L4_2 = L43_1
    if L4_2 then
      L4_2 = L18_1.active
      if L4_2 then
        goto lbl_250
      end
    end
    L4_2 = A1_2.settings
    L4_2 = L4_2.whiteSpotlights
    L46_1 = L4_2
    L4_2 = A1_2.settings
    L4_2 = L4_2.dynamicSpotlights
    L47_1 = L4_2
    L4_2 = A1_2.settings
    L4_2 = L4_2.photorythmicSpotlights
    L48_1 = L4_2
    ::lbl_250::
    L4_2 = A1_2.settings
    L4_2 = L4_2.videoToggle
    L49_1 = L4_2
    L4_2 = SyncSpotlightColors
    L4_2()
    L4_2 = L53_1
    if L4_2 then
      L4_2 = A1_2.media
      L4_2 = L4_2.duration
      if L4_2 then
        L4_2 = A1_2.media
        L4_2 = L4_2.duration
        if L4_2 > 0 then
          L4_2 = A1_2.media
          L4_2 = L4_2.time
          if L4_2 then
            L4_2 = L11_1.time
            if L4_2 then
              L4_2 = Round
              L5_2 = A1_2.media
              L5_2 = L5_2.time
              L4_2 = L4_2(L5_2)
              L5_2 = Round
              L6_2 = L11_1.time
              L5_2 = L5_2(L6_2)
              if L4_2 ~= L5_2 then
                L4_2 = L11_1.time
                L22_1 = L4_2
                L4_2 = TriggerServerEvent
                L5_2 = "cs-hall:time"
                L6_2 = L19_1
                L7_2 = L11_1.time
                L8_2 = true
                L4_2(L5_2, L6_2, L7_2, L8_2)
              end
            end
          end
        end
      end
    end
    L4_2 = A1_2.media
    L4_2 = L4_2.stopped
    if L4_2 then
      L4_2 = nil
      L23_1 = L4_2
    end
    L4_2 = L43_1
    if L4_2 then
      L4_2 = ActivateScenes
      L4_2()
    else
      L4_2 = DeactivateScenes
      L4_2()
    end
    L4_2 = SyncBrowser
    L5_2 = A1_2.media
    L6_2 = A2_2
    L4_2(L5_2, L6_2)
    L4_2 = L43_1
    if L4_2 then
      L4_2 = L18_1.active
      if L4_2 then
        goto lbl_317
      end
    end
    L4_2 = SetBrowserVideoToggle
    L5_2 = L49_1
    L4_2(L5_2)
  end
  ::lbl_317::
end
L89_1(L90_1, L91_1)
L89_1 = RegisterNetEvent
L90_1 = "cs-hall:adjust"
function L91_1(A0_2, A1_2)
  local L2_2, L3_2
  L2_2 = L19_1
  if A0_2 == L2_2 then
    L2_2 = AdjustBrowser
    L3_2 = A1_2
    L2_2(L3_2)
  end
end
L89_1(L90_1, L91_1)
L89_1 = RegisterNetEvent
L90_1 = "cs-hall:interfacelessFeatureUsed"
function L91_1(A0_2, A1_2)
  local L2_2, L3_2, L4_2, L5_2
  L2_2 = TriggerEvent
  L3_2 = "cs-hall:onInterfacelessFeatureUsed"
  L4_2 = A0_2
  L5_2 = A1_2
  L2_2(L3_2, L4_2, L5_2)
end
L89_1(L90_1, L91_1)
L89_1 = RegisterNetEvent
L90_1 = "cs-hall:setUiAccessible"
function L91_1(A0_2)
  local L1_2
  L39_1 = A0_2
end
L89_1(L90_1, L91_1)
L89_1 = AddEventHandler
L90_1 = "onResourceStop"
function L91_1(A0_2)
  local L1_2, L2_2, L3_2, L4_2, L5_2, L6_2, L7_2, L8_2, L9_2, L10_2, L11_2, L12_2, L13_2
  L1_2 = GetCurrentResourceName
  L1_2 = L1_2()
  if A0_2 == L1_2 then
    L1_2 = GetCurrentServerEndpoint
    L1_2 = L1_2()
    if L1_2 then
      goto lbl_10
    end
  end
  do return end
  ::lbl_10::
  L1_2 = L57_1
  if L1_2 then
    L1_2 = config
    L1_2 = L1_2.entries
    L2_2 = L19_1
    L1_2 = L1_2[L2_2]
    L1_2 = L1_2.replacers
    if L1_2 then
      L1_2 = pairs
      L2_2 = config
      L2_2 = L2_2.entries
      L3_2 = L19_1
      L2_2 = L2_2[L3_2]
      L2_2 = L2_2.replacers
      L1_2, L2_2, L3_2, L4_2 = L1_2(L2_2)
      for L5_2, L6_2 in L1_2, L2_2, L3_2, L4_2 do
        L7_2 = RemoveReplaceTexture
        L8_2 = L5_2
        L9_2 = L6_2
        L7_2(L8_2, L9_2)
      end
    end
  end
  L1_2 = L20_1
  if L1_2 then
    L1_2 = DestroyDui
    L2_2 = L20_1
    L1_2(L2_2)
  end
  L1_2 = L9_1.handle
  if L1_2 then
    L1_2 = SetScaleformMovieAsNoLongerNeeded
    L2_2 = L9_1.handle
    L1_2(L2_2)
  end
  L1_2 = 1
  L2_2 = L7_1
  L2_2 = #L2_2
  L3_2 = 1
  for L4_2 = L1_2, L2_2, L3_2 do
    L5_2 = DeleteEntity
    L6_2 = L7_1
    L6_2 = L6_2[L4_2]
    L6_2 = L6_2.handle
    L5_2(L6_2)
  end
  L1_2 = 1
  L2_2 = L2_1
  L2_2 = #L2_2
  L3_2 = 1
  for L4_2 = L1_2, L2_2, L3_2 do
    L5_2 = L2_1
    L5_2 = L5_2[L4_2]
    L5_2 = L5_2.handle
    if L5_2 then
      L5_2 = DeleteEntity
      L6_2 = L2_1
      L6_2 = L6_2[L4_2]
      L6_2 = L6_2.handle
      L5_2(L6_2)
    end
  end
  L1_2 = 1
  L2_2 = L3_1
  L2_2 = #L2_2
  L3_2 = 1
  for L4_2 = L1_2, L2_2, L3_2 do
    L5_2 = DeleteEntity
    L6_2 = L3_1
    L6_2 = L6_2[L4_2]
    L6_2 = L6_2.handle
    L5_2(L6_2)
  end
  L1_2 = 1
  L2_2 = L4_1
  L2_2 = #L2_2
  L3_2 = 1
  for L4_2 = L1_2, L2_2, L3_2 do
    L5_2 = DeleteEntity
    L6_2 = L4_1
    L6_2 = L6_2[L4_2]
    L6_2 = L6_2.handle
    L5_2(L6_2)
  end
  L1_2 = 1
  L2_2 = L5_1
  L2_2 = #L2_2
  L3_2 = 1
  for L4_2 = L1_2, L2_2, L3_2 do
    L5_2 = DeleteEntity
    L6_2 = L5_1
    L6_2 = L6_2[L4_2]
    L6_2 = L6_2.handle
    L5_2(L6_2)
  end
  L1_2 = 1
  L2_2 = L6_1
  L2_2 = #L2_2
  L3_2 = 1
  for L4_2 = L1_2, L2_2, L3_2 do
    L5_2 = DeleteEntity
    L6_2 = L6_1
    L6_2 = L6_2[L4_2]
    L6_2 = L6_2.handle
    L5_2(L6_2)
  end
  L1_2 = pairs
  L2_2 = config
  L2_2 = L2_2.entries
  L1_2, L2_2, L3_2, L4_2 = L1_2(L2_2)
  for L5_2, L6_2 in L1_2, L2_2, L3_2, L4_2 do
    L7_2 = L6_2.enabled
    if L7_2 then
      L7_2 = L6_2.smokers
      if L7_2 then
        L7_2 = 1
        L8_2 = L6_2.smokers
        L8_2 = #L8_2
        L9_2 = 1
        for L10_2 = L7_2, L8_2, L9_2 do
          L11_2 = RemoveNamedPtfxAsset
          L12_2 = L6_2.smokers
          L12_2 = L12_2[L10_2]
          L12_2 = L12_2.fx
          L12_2 = L12_2.library
          L11_2(L12_2)
          L11_2 = SetModelAsNoLongerNeeded
          L12_2 = L6_2.smokers
          L12_2 = L12_2[L10_2]
          L12_2 = L12_2.hash
          L11_2(L12_2)
        end
      end
      L7_2 = L6_2.sparklers
      if L7_2 then
        L7_2 = 1
        L8_2 = L6_2.sparklers
        L8_2 = #L8_2
        L9_2 = 1
        for L10_2 = L7_2, L8_2, L9_2 do
          L11_2 = RemoveNamedPtfxAsset
          L12_2 = L6_2.sparklers
          L12_2 = L12_2[L10_2]
          L12_2 = L12_2.fx
          L12_2 = L12_2.library
          L11_2(L12_2)
          L11_2 = SetModelAsNoLongerNeeded
          L12_2 = L6_2.sparklers
          L12_2 = L12_2[L10_2]
          L12_2 = L12_2.hash
          L11_2(L12_2)
        end
      end
      L7_2 = L6_2.speakers
      if L7_2 then
        L7_2 = 1
        L8_2 = L6_2.speakers
        L8_2 = #L8_2
        L9_2 = 1
        for L10_2 = L7_2, L8_2, L9_2 do
          L11_2 = SetModelAsNoLongerNeeded
          L12_2 = L6_2.speakers
          L12_2 = L12_2[L10_2]
          L12_2 = L12_2.hash
          L11_2(L12_2)
        end
      end
      L7_2 = L6_2.spotlights
      if L7_2 then
        L7_2 = 1
        L8_2 = L6_2.spotlights
        L8_2 = #L8_2
        L9_2 = 1
        for L10_2 = L7_2, L8_2, L9_2 do
          L11_2 = SetModelAsNoLongerNeeded
          L12_2 = L6_2.spotlights
          L12_2 = L12_2[L10_2]
          L12_2 = L12_2.hash
          L11_2(L12_2)
        end
      end
      L7_2 = L6_2.monitors
      if L7_2 then
        L7_2 = 1
        L8_2 = L6_2.monitors
        L8_2 = #L8_2
        L9_2 = 1
        for L10_2 = L7_2, L8_2, L9_2 do
          L11_2 = SetModelAsNoLongerNeeded
          L12_2 = L6_2.monitors
          L12_2 = L12_2[L10_2]
          L12_2 = L12_2.hash
          L11_2(L12_2)
        end
      end
      L7_2 = L6_2.screens
      if L7_2 then
        L7_2 = 1
        L8_2 = L6_2.screens
        L8_2 = #L8_2
        L9_2 = 1
        for L10_2 = L7_2, L8_2, L9_2 do
          L11_2 = SetModelAsNoLongerNeeded
          L12_2 = L6_2.screens
          L12_2 = L12_2[L10_2]
          L12_2 = L12_2.hash
          L11_2(L12_2)
        end
      end
      L7_2 = L6_2.disableEmitters
      if L7_2 then
        L7_2 = 1
        L8_2 = L6_2.disableEmitters
        L8_2 = #L8_2
        L9_2 = 1
        for L10_2 = L7_2, L8_2, L9_2 do
          L11_2 = SetStaticEmitterEnabled
          L12_2 = L6_2.disableEmitters
          L12_2 = L12_2[L10_2]
          L13_2 = true
          L11_2(L12_2, L13_2)
        end
      end
    end
  end
end
L89_1(L90_1, L91_1)
L89_1 = CreateThread
function L90_1()
  local L0_2, L1_2, L2_2, L3_2
  while true do
    L0_2 = L20_1
    if L0_2 then
      L0_2 = IsDuiAvailable
      L1_2 = L20_1
      L0_2 = L0_2(L1_2)
      if L0_2 then
        L0_2 = L61_1
        if L0_2 then
          L0_2 = L54_1
          if L0_2 then
            L0_2 = L36_1
            if L0_2 then
              break
            end
          end
        end
      end
    end
    L0_2 = Wait
    L1_2 = L77_1
    L0_2(L1_2)
  end
  L0_2 = SendDuiMessage
  L1_2 = L20_1
  L2_2 = json
  L2_2 = L2_2.encode
  L3_2 = {}
  L3_2.type = "cs-hall:create"
  L2_2, L3_2 = L2_2(L3_2)
  L0_2(L1_2, L2_2, L3_2)
end
L89_1(L90_1)
L89_1 = CreateThread
function L90_1()
  local L0_2, L1_2, L2_2, L3_2, L4_2, L5_2, L6_2, L7_2, L8_2, L9_2, L10_2, L11_2, L12_2, L13_2, L14_2, L15_2, L16_2, L17_2, L18_2
  while true do
    L0_2 = NetworkIsSessionStarted
    L0_2 = L0_2()
    if L0_2 then
      break
    end
    L0_2 = Wait
    L1_2 = L75_1
    L0_2(L1_2)
  end
  L0_2 = CreateThread
  function L1_2()
    local L0_3, L1_3
    L0_3 = TriggerServerEvent
    L1_3 = "cs-hall:fetch"
    L0_3(L1_3)
  end
  L0_2(L1_2)
  while true do
    L0_2 = L61_1
    if L0_2 then
      L0_2 = L37_1
      if L0_2 then
        break
      end
    end
    L0_2 = Wait
    L1_2 = L75_1
    L0_2(L1_2)
  end
  L0_2 = pairs
  L1_2 = config
  L1_2 = L1_2.entries
  L0_2, L1_2, L2_2, L3_2 = L0_2(L1_2)
  for L4_2, L5_2 in L0_2, L1_2, L2_2, L3_2 do
    L6_2 = L5_2.enabled
    if L6_2 then
      L6_2 = L5_2.smokers
      if L6_2 then
        L6_2 = 1
        L7_2 = L5_2.smokers
        L7_2 = #L7_2
        L8_2 = 1
        for L9_2 = L6_2, L7_2, L8_2 do
          L10_2 = RequestAssetPtfx
          L11_2 = L5_2.smokers
          L11_2 = L11_2[L9_2]
          L11_2 = L11_2.fx
          L11_2 = L11_2.library
          L12_2 = "\""
          L13_2 = L4_2
          L14_2 = "\" - smoker index: "
          L15_2 = L9_2
          L12_2 = L12_2 .. L13_2 .. L14_2 .. L15_2
          L10_2(L11_2, L12_2)
          L10_2 = L5_2.smokers
          L10_2 = L10_2[L9_2]
          L10_2 = L10_2.interior
          if not L10_2 then
            L10_2 = RequestAssetModel
            L11_2 = L5_2.smokers
            L11_2 = L11_2[L9_2]
            L11_2 = L11_2.hash
            L12_2 = "\""
            L13_2 = L4_2
            L14_2 = "\" - smoker index: "
            L15_2 = L9_2
            L12_2 = L12_2 .. L13_2 .. L14_2 .. L15_2
            L10_2(L11_2, L12_2)
          end
          L10_2 = RemoveNamedPtfxAsset
          L11_2 = L5_2.smokers
          L11_2 = L11_2[L9_2]
          L11_2 = L11_2.fx
          L11_2 = L11_2.library
          L10_2(L11_2)
          L10_2 = SetModelAsNoLongerNeeded
          L11_2 = L5_2.smokers
          L11_2 = L11_2[L9_2]
          L11_2 = L11_2.hash
          L10_2(L11_2)
        end
      end
      L6_2 = L5_2.sparklers
      if L6_2 then
        L6_2 = 1
        L7_2 = L5_2.sparklers
        L7_2 = #L7_2
        L8_2 = 1
        for L9_2 = L6_2, L7_2, L8_2 do
          L10_2 = RequestAssetPtfx
          L11_2 = L5_2.sparklers
          L11_2 = L11_2[L9_2]
          L11_2 = L11_2.fx
          L11_2 = L11_2.library
          L12_2 = "\""
          L13_2 = L4_2
          L14_2 = "\" - sparklers index: "
          L15_2 = L9_2
          L12_2 = L12_2 .. L13_2 .. L14_2 .. L15_2
          L10_2(L11_2, L12_2)
          L10_2 = L5_2.sparklers
          L10_2 = L10_2[L9_2]
          L10_2 = L10_2.interior
          if not L10_2 then
            L10_2 = RequestAssetModel
            L11_2 = L5_2.sparklers
            L11_2 = L11_2[L9_2]
            L11_2 = L11_2.hash
            L12_2 = "\""
            L13_2 = L4_2
            L14_2 = "\" - sparklers index: "
            L15_2 = L9_2
            L12_2 = L12_2 .. L13_2 .. L14_2 .. L15_2
            L10_2(L11_2, L12_2)
          end
          L10_2 = RemoveNamedPtfxAsset
          L11_2 = L5_2.sparklers
          L11_2 = L11_2[L9_2]
          L11_2 = L11_2.fx
          L11_2 = L11_2.library
          L10_2(L11_2)
          L10_2 = SetModelAsNoLongerNeeded
          L11_2 = L5_2.sparklers
          L11_2 = L11_2[L9_2]
          L11_2 = L11_2.hash
          L10_2(L11_2)
        end
      end
      L6_2 = L5_2.speakers
      if L6_2 then
        L6_2 = 1
        L7_2 = L5_2.speakers
        L7_2 = #L7_2
        L8_2 = 1
        for L9_2 = L6_2, L7_2, L8_2 do
          L10_2 = L5_2.speakers
          L10_2 = L10_2[L9_2]
          L10_2 = L10_2.interior
          if not L10_2 then
            L10_2 = RequestAssetModel
            L11_2 = L5_2.speakers
            L11_2 = L11_2[L9_2]
            L11_2 = L11_2.hash
            L12_2 = "\""
            L13_2 = L4_2
            L14_2 = "\" - speaker index: "
            L15_2 = L9_2
            L12_2 = L12_2 .. L13_2 .. L14_2 .. L15_2
            L10_2(L11_2, L12_2)
          end
          L10_2 = SetModelAsNoLongerNeeded
          L11_2 = L5_2.speakers
          L11_2 = L11_2[L9_2]
          L11_2 = L11_2.hash
          L10_2(L11_2)
        end
      end
      L6_2 = L5_2.spotlights
      if L6_2 then
        L6_2 = 1
        L7_2 = L5_2.spotlights
        L7_2 = #L7_2
        L8_2 = 1
        for L9_2 = L6_2, L7_2, L8_2 do
          L10_2 = L5_2.spotlights
          L10_2 = L10_2[L9_2]
          L10_2 = L10_2.interior
          if not L10_2 then
            L10_2 = RequestAssetModel
            L11_2 = L5_2.spotlights
            L11_2 = L11_2[L9_2]
            L11_2 = L11_2.hash
            L12_2 = "\""
            L13_2 = L4_2
            L14_2 = "\" - spotlight index: "
            L15_2 = L9_2
            L12_2 = L12_2 .. L13_2 .. L14_2 .. L15_2
            L10_2(L11_2, L12_2)
          end
          L10_2 = SetModelAsNoLongerNeeded
          L11_2 = L5_2.spotlights
          L11_2 = L11_2[L9_2]
          L11_2 = L11_2.hash
          L10_2(L11_2)
        end
      end
      L6_2 = L5_2.monitors
      if L6_2 then
        L6_2 = 1
        L7_2 = L5_2.monitors
        L7_2 = #L7_2
        L8_2 = 1
        for L9_2 = L6_2, L7_2, L8_2 do
          L10_2 = L5_2.monitors
          L10_2 = L10_2[L9_2]
          L10_2 = L10_2.interior
          if not L10_2 then
            L10_2 = RequestAssetModel
            L11_2 = L5_2.monitors
            L11_2 = L11_2[L9_2]
            L11_2 = L11_2.hash
            L12_2 = "\""
            L13_2 = L4_2
            L14_2 = "\" - monitor index: "
            L15_2 = L9_2
            L12_2 = L12_2 .. L13_2 .. L14_2 .. L15_2
            L10_2(L11_2, L12_2)
          end
          L10_2 = SetModelAsNoLongerNeeded
          L11_2 = L5_2.monitors
          L11_2 = L11_2[L9_2]
          L11_2 = L11_2.hash
          L10_2(L11_2)
        end
      end
      L6_2 = L5_2.screens
      if L6_2 then
        L6_2 = 1
        L7_2 = L5_2.screens
        L7_2 = #L7_2
        L8_2 = 1
        for L9_2 = L6_2, L7_2, L8_2 do
          L10_2 = L5_2.screens
          L10_2 = L10_2[L9_2]
          L10_2 = L10_2.interior
          if not L10_2 then
            L10_2 = RequestAssetModel
            L11_2 = L5_2.screens
            L11_2 = L11_2[L9_2]
            L11_2 = L11_2.hash
            L12_2 = "\""
            L13_2 = L4_2
            L14_2 = "\" - screen index: "
            L15_2 = L9_2
            L12_2 = L12_2 .. L13_2 .. L14_2 .. L15_2
            L10_2(L11_2, L12_2)
          end
          L10_2 = SetModelAsNoLongerNeeded
          L11_2 = L5_2.screens
          L11_2 = L11_2[L9_2]
          L11_2 = L11_2.hash
          L10_2(L11_2)
        end
      end
      L6_2 = L5_2.disableEmitters
      if L6_2 then
        L6_2 = 1
        L7_2 = L5_2.disableEmitters
        L7_2 = #L7_2
        L8_2 = 1
        for L9_2 = L6_2, L7_2, L8_2 do
          L10_2 = SetStaticEmitterEnabled
          L11_2 = L5_2.disableEmitters
          L11_2 = L11_2[L9_2]
          L12_2 = false
          L10_2(L11_2, L12_2)
        end
      end
    end
  end
  L0_2 = CreateDui
  L1_2 = L25_1
  L2_2 = "?v="
  L3_2 = L26_1
  L4_2 = "+"
  L5_2 = L0_1
  L6_2 = config
  L6_2 = L6_2.debug
  if L6_2 then
    L6_2 = "&debug=1"
    if L6_2 then
      goto lbl_269
    end
  end
  L6_2 = ""
  ::lbl_269::
  L7_2 = "#"
  L8_2 = GetCurrentResourceName
  L8_2 = L8_2()
  L1_2 = L1_2 .. L2_2 .. L3_2 .. L4_2 .. L5_2 .. L6_2 .. L7_2 .. L8_2
  L2_2 = 1280
  L3_2 = 720
  L0_2 = L0_2(L1_2, L2_2, L3_2)
  L20_1 = L0_2
  L0_2 = CreateRuntimeTextureFromDuiHandle
  L1_2 = CreateRuntimeTxd
  L2_2 = "browser"
  L1_2 = L1_2(L2_2)
  L2_2 = "browserTexture"
  L3_2 = GetDuiHandle
  L4_2 = L20_1
  L3_2, L4_2, L5_2, L6_2, L7_2, L8_2, L9_2, L10_2, L11_2, L12_2, L13_2, L14_2, L15_2, L16_2, L17_2, L18_2 = L3_2(L4_2)
  L0_2(L1_2, L2_2, L3_2, L4_2, L5_2, L6_2, L7_2, L8_2, L9_2, L10_2, L11_2, L12_2, L13_2, L14_2, L15_2, L16_2, L17_2, L18_2)
  L0_2 = TriggerServerEvent
  L1_2 = "cs-hall:server"
  L0_2(L1_2)
  L0_2 = AddEventHandler
  L1_2 = "cs-hall:integrationReady"
  function L2_2()
    local L0_3, L1_3
    L0_3 = TriggerEvent
    L1_3 = "cs-hall:ready"
    L0_3(L1_3)
  end
  L0_2(L1_2, L2_2)
  L0_2 = TriggerEvent
  L1_2 = "cs-hall:ready"
  L0_2(L1_2)
  L0_2 = false
  L1_2 = pairs
  L2_2 = config
  L2_2 = L2_2.entries
  L1_2, L2_2, L3_2, L4_2 = L1_2(L2_2)
  for L5_2, L6_2 in L1_2, L2_2, L3_2, L4_2 do
    L7_2 = L6_2.enabled
    if L7_2 then
      L7_2 = L6_2.scaleform
      if L7_2 then
        L0_2 = true
        break
      end
    end
  end
  if L0_2 then
    L9_1.interval = true
    L1_2 = CreateThread
    function L2_2()
      local L0_3, L1_3
      while true do
        L0_3 = L9_1.interval
        if not L0_3 then
          break
        end
        L0_3 = L36_1
        if L0_3 then
          L0_3 = L9_1.first
          if not L0_3 then
            L0_3 = GetGameTimer
            L0_3 = L0_3()
            L9_1.first = L0_3
          end
          L0_3 = L9_1.handle
          if L0_3 then
            L0_3 = HasScaleformMovieLoaded
            L1_3 = L9_1.handle
            L0_3 = L0_3(L1_3)
            if L0_3 then
              L9_1.interval = false
              L9_1.ready = true
              L0_3 = L9_1.draw
              if L0_3 then
                L0_3 = SetScaleformTexture
                L1_3 = L9_1.handle
                L0_3(L1_3)
                L9_1.tick = true
              end
          end
          else
            L0_3 = GetGameTimer
            L0_3 = L0_3()
            L1_3 = L9_1.first
            L0_3 = L0_3 - L1_3
            L1_3 = config
            L1_3 = L1_3.timeouts
            L1_3 = L1_3.scaleformRequestMs
            if L0_3 >= L1_3 then
              L9_1.tick = false
              L9_1.interval = false
              L9_1.failed = true
              L0_3 = error
              L1_3 = "[criticalscripts.shop] cs-hall enabled renderer scaleform which is included by default in \"cs-stream\" resource could not be loaded, consult the package's store page for further information."
              L0_3(L1_3)
            else
              L0_3 = RequestScaleformMovie
              L1_3 = L1_1
              L0_3 = L0_3(L1_3)
              L9_1.handle = L0_3
            end
          end
        end
        L0_3 = Wait
        L1_3 = L67_1
        L0_3(L1_3)
      end
    end
    L1_2(L2_2)
  end
  while true do
    L1_2 = L61_1
    if L1_2 then
      L1_2 = L36_1
      if L1_2 then
        L1_2 = L62_1
        if L1_2 then
          L1_2 = GetGameTimer
          L1_2 = L1_2()
          L2_2 = L33_1
          L2_2 = L1_2 - L2_2
          L3_2 = L71_1
          if L2_2 > L3_2 then
            L33_1 = L1_2
            L2_2 = L57_1
            if L2_2 then
              L2_2 = L38_1
              if L2_2 then
                L2_2 = CanAccessUi
                L2_2 = L2_2()
                if not L2_2 then
                  L2_2 = HideUi
                  L2_2()
                end
              end
            end
            L2_2 = nil
            L3_2 = PlayerPedId
            L3_2 = L3_2()
            L4_2 = GetEntityCoords
            L5_2 = L3_2
            L4_2 = L4_2(L5_2)
            L5_2 = pairs
            L6_2 = config
            L6_2 = L6_2.entries
            L5_2, L6_2, L7_2, L8_2 = L5_2(L6_2)
            for L9_2, L10_2 in L5_2, L6_2, L7_2, L8_2 do
              L11_2 = L10_2.enabled
              if L11_2 then
                L11_2 = L10_2.area
                L11_2 = L11_2.center
                L11_2 = L4_2 - L11_2
                L11_2 = #L11_2
                L12_2 = L10_2.area
                L12_2 = L12_2.range
                if L11_2 <= L12_2 then
                  L11_2 = L10_2.area
                  L11_2 = L11_2.height
                  if L11_2 then
                    L11_2 = L4_2.z
                    L12_2 = L10_2.area
                    L12_2 = L12_2.height
                    L12_2 = L12_2.min
                    if not (L11_2 >= L12_2) then
                      goto lbl_390
                    end
                    L11_2 = L4_2.z
                    L12_2 = L10_2.area
                    L12_2 = L12_2.height
                    L12_2 = L12_2.max
                    if not (L11_2 <= L12_2) then
                      goto lbl_390
                    end
                  end
                  L2_2 = L9_2
                  break
                end
              end
              ::lbl_390::
            end
            L5_2 = L57_1
            if L5_2 then
              L5_2 = L19_1
              if L5_2 ~= L2_2 then
                L5_2 = DesyncHallArea
                L6_2 = L19_1
                L5_2(L6_2)
                L5_2 = DesyncArea
                L6_2 = L19_1
                L5_2(L6_2)
                L5_2 = false
                L56_1 = L5_2
                L5_2 = false
                L55_1 = L5_2
              end
            end
            L5_2 = not L2_2
            L5_2 = not L5_2
            L6_2 = L56_1
            if L5_2 ~= L6_2 then
              L6_2 = L59_1
              if not L6_2 then
                L56_1 = L5_2
                if L5_2 then
                  L6_2 = SyncArea
                  L7_2 = L2_2
                  L6_2(L7_2)
                else
                  L6_2 = DesyncArea
                  L7_2 = L19_1
                  L6_2(L7_2)
                end
              end
            end
            L6_2 = L19_1
            if L6_2 ~= L2_2 then
              L6_2 = {}
              L88_1 = L6_2
              if L2_2 then
                L6_2 = TriggerEvent
                L7_2 = "cs-hall:onAreaEntered"
                L8_2 = L2_2
                L6_2(L7_2, L8_2)
              else
                L6_2 = TriggerEvent
                L7_2 = "cs-hall:onAreaLeft"
                L8_2 = L19_1
                L6_2(L7_2, L8_2)
              end
            end
            L19_1 = L2_2
            if L5_2 then
              L6_2 = GetInteriorFromEntity
              L7_2 = L3_2
              L6_2 = L6_2(L7_2)
              L7_2 = L21_1
              if L7_2 ~= L6_2 then
                L21_1 = L6_2
                L7_2 = CreateThread
                function L8_2()
                  local L0_3, L1_3, L2_3, L3_3, L4_3, L5_3, L6_3, L7_3, L8_3, L9_3, L10_3
                  L0_3 = 1
                  L1_3 = L2_1
                  L1_3 = #L1_3
                  L2_3 = 1
                  for L3_3 = L0_3, L1_3, L2_3 do
                    L4_3 = L2_1
                    L4_3 = L4_3[L3_3]
                    L4_3 = L4_3.handle
                    if L4_3 then
                      L4_3 = DeleteEntity
                      L5_3 = L2_1
                      L5_3 = L5_3[L3_3]
                      L5_3 = L5_3.handle
                      L4_3(L5_3)
                    end
                    L4_3 = L2_1
                    L4_3 = L4_3[L3_3]
                    L4_3.handle = nil
                    L4_3 = config
                    L4_3 = L4_3.entries
                    L5_3 = L19_1
                    L4_3 = L4_3[L5_3]
                    L4_3 = L4_3.spotlights
                    if L4_3 then
                      L4_3 = 1
                      L5_3 = config
                      L5_3 = L5_3.entries
                      L6_3 = L19_1
                      L5_3 = L5_3[L6_3]
                      L5_3 = L5_3.spotlights
                      L5_3 = #L5_3
                      L6_3 = 1
                      for L7_3 = L4_3, L5_3, L6_3 do
                        L8_3 = SetModelAsNoLongerNeeded
                        L9_3 = config
                        L9_3 = L9_3.entries
                        L10_3 = L19_1
                        L9_3 = L9_3[L10_3]
                        L9_3 = L9_3.spotlights
                        L9_3 = L9_3[L7_3]
                        L9_3 = L9_3.hash
                        L8_3(L9_3)
                      end
                    end
                    L4_3 = RequestAssetModel
                    L5_3 = L2_1
                    L5_3 = L5_3[L3_3]
                    L5_3 = L5_3.hash
                    L4_3(L5_3)
                    L4_3 = L2_1
                    L4_3 = L4_3[L3_3]
                    L5_3 = CreateSpotlight
                    L6_3 = L2_1
                    L6_3 = L6_3[L3_3]
                    L5_3 = L5_3(L6_3)
                    L4_3.handle = L5_3
                    L4_3 = L50_1
                    if L4_3 then
                      L4_3 = TurnOnSpotlights
                      L4_3()
                    else
                      L4_3 = TurnOffSpotlights
                      L4_3()
                    end
                    L4_3 = SyncSpotlightColors
                    L4_3()
                  end
                end
                L7_2(L8_2)
              end
              L7_2 = Ternary
              L8_2 = config
              L8_2 = L8_2.entries
              L9_2 = L19_1
              L8_2 = L8_2[L9_2]
              L8_2 = L8_2.area
              L8_2 = L8_2.polygons
              L9_2 = IsPositionInsideArea
              L10_2 = L4_2
              L9_2 = L9_2(L10_2)
              L10_2 = true
              L7_2 = L7_2(L8_2, L9_2, L10_2)
              L8_2 = L55_1
              if L7_2 ~= L8_2 then
                L8_2 = L60_1
                if not L8_2 then
                  if L7_2 then
                    L8_2 = SyncHallArea
                    L9_2 = L19_1
                    L8_2(L9_2)
                  else
                    L8_2 = DesyncHallArea
                    L9_2 = L19_1
                    L8_2(L9_2)
                  end
                  L55_1 = L7_2
                end
              end
            end
          end
          L2_2 = L57_1
          if L2_2 then
            L2_2 = L31_1
            L2_2 = L1_2 - L2_2
            L3_2 = L70_1
            if L2_2 > L3_2 then
              L31_1 = L1_2
              L2_2 = UpdateBrowser
              L2_2()
            end
            L2_2 = L32_1
            L2_2 = L1_2 - L2_2
            L3_2 = L69_1
            if L2_2 > L3_2 then
              L32_1 = L1_2
              L2_2 = L11_1.playing
              if not L2_2 then
                L2_2 = L46_1
                if not L2_2 then
                  goto lbl_516
                end
                L2_2 = L48_1
                if L2_2 then
                  goto lbl_516
                end
              end
              L2_2 = L58_1
              ::lbl_516::
              if not L2_2 then
                L2_2 = L50_1
                if L2_2 then
                  L2_2 = TurnOffSpotlights
                  L2_2()
              end
              else
                L2_2 = L11_1.playing
                if not L2_2 then
                  L2_2 = L46_1
                  if not L2_2 then
                    goto lbl_539
                  end
                  L2_2 = L48_1
                  if L2_2 then
                    goto lbl_539
                  end
                end
                L2_2 = L58_1
                if L2_2 then
                  L2_2 = L50_1
                  if not L2_2 then
                    L2_2 = TurnOnSpotlights
                    L2_2()
                  end
                end
              end
              ::lbl_539::
              L2_2 = PlayerId
              L2_2 = L2_2()
              L3_2 = L11_1.playing
              if L3_2 then
                L3_2 = nil
                L4_2 = nil
                L3_2 = L12_1.bass
                L5_2 = L13_1.previous
                L4_2 = L5_2.bass
                L5_2 = 255
                if L4_2 >= L5_2 then
                  L4_2 = 255
                else
                  L5_2 = L66_1
                  if L4_2 <= L5_2 then
                    L4_2 = L66_1
                  end
                end
                L5_2 = GetGameTimer
                L5_2 = L5_2()
                L6_2 = 0
                L7_2 = L58_1
                if L7_2 and L3_2 >= L4_2 then
                  L7_2 = L53_1
                  if L7_2 then
                    L7_2 = L24_1
                    if L7_2 then
                      L7_2 = config
                      L7_2 = L7_2.entries
                      L8_2 = L19_1
                      L7_2 = L7_2[L8_2]
                      L7_2 = L7_2.bass
                      if L7_2 then
                        L7_2 = L24_1
                        L7_2 = L5_2 - L7_2
                        L8_2 = Ternary
                        L9_2 = config
                        L9_2 = L9_2.entries
                        L10_2 = L19_1
                        L9_2 = L9_2[L10_2]
                        L9_2 = L9_2.delayToTriggerBassEffectsAfterPlayingMs
                        L10_2 = L83_1
                        L8_2 = L8_2(L9_2, L10_2)
                        if L7_2 >= L8_2 then
                          L7_2 = L44_1
                          if L7_2 then
                            L7_2 = SceneVariable
                            L8_2 = "bassSmoke"
                            L9_2 = config
                            L9_2 = L9_2.entries
                            L10_2 = L19_1
                            L9_2 = L9_2[L10_2]
                            L9_2 = L9_2.bass
                            L9_2 = L9_2.smoke
                            L7_2 = L7_2(L8_2, L9_2)
                            if L7_2 then
                              L7_2 = L64_1
                              if L3_2 >= L7_2 then
                                L7_2 = L29_1
                                L7_2 = L5_2 - L7_2
                                L8_2 = SceneVariable
                                L9_2 = "bassSmokeCooldownMs"
                                L10_2 = config
                                L10_2 = L10_2.entries
                                L11_2 = L19_1
                                L10_2 = L10_2[L11_2]
                                L10_2 = L10_2.bass
                                L10_2 = L10_2.smoke
                                L10_2 = L10_2.cooldownMs
                                L8_2 = L8_2(L9_2, L10_2)
                                if L7_2 >= L8_2 then
                                  L29_1 = L5_2
                                  L7_2 = TriggerServerEvent
                                  L8_2 = "cs-hall:smoke"
                                  L9_2 = L19_1
                                  L10_2 = GetSmokeColor
                                  L10_2, L11_2, L12_2, L13_2, L14_2, L15_2, L16_2, L17_2, L18_2 = L10_2()
                                  L7_2(L8_2, L9_2, L10_2, L11_2, L12_2, L13_2, L14_2, L15_2, L16_2, L17_2, L18_2)
                                end
                              end
                            end
                          end
                          L7_2 = L45_1
                          if L7_2 then
                            L7_2 = SceneVariable
                            L8_2 = "bassSparklers"
                            L9_2 = config
                            L9_2 = L9_2.entries
                            L10_2 = L19_1
                            L9_2 = L9_2[L10_2]
                            L9_2 = L9_2.bass
                            L9_2 = L9_2.sparklers
                            L7_2 = L7_2(L8_2, L9_2)
                            if L7_2 then
                              L7_2 = L65_1
                              if L3_2 >= L7_2 then
                                L7_2 = L30_1
                                L7_2 = L5_2 - L7_2
                                L8_2 = SceneVariable
                                L9_2 = "bassSparklersCooldownMs"
                                L10_2 = config
                                L10_2 = L10_2.entries
                                L11_2 = L19_1
                                L10_2 = L10_2[L11_2]
                                L10_2 = L10_2.bass
                                L10_2 = L10_2.sparklers
                                L10_2 = L10_2.cooldownMs
                                L8_2 = L8_2(L9_2, L10_2)
                                if L7_2 >= L8_2 then
                                  L30_1 = L5_2
                                  L7_2 = TriggerServerEvent
                                  L8_2 = "cs-hall:sparklers"
                                  L9_2 = L19_1
                                  L10_2 = GetSparklersColor
                                  L10_2, L11_2, L12_2, L13_2, L14_2, L15_2, L16_2, L17_2, L18_2 = L10_2()
                                  L7_2(L8_2, L9_2, L10_2, L11_2, L12_2, L13_2, L14_2, L15_2, L16_2, L17_2, L18_2)
                                end
                              end
                            end
                          end
                        end
                      end
                    end
                  end
                end
                L7_2 = L50_1
                if L7_2 then
                  L7_2 = L58_1
                  if L7_2 then
                    L7_2 = L48_1
                    if L7_2 then
                      L7_2 = 1
                      L8_2 = L2_1
                      L8_2 = #L8_2
                      L9_2 = 1
                      for L10_2 = L7_2, L8_2, L9_2 do
                        L11_2 = L2_1
                        L11_2 = L11_2[L10_2]
                        L11_2 = L11_2.soundSyncType
                        L12_2 = SOUND_SYNC_TYPE
                        L12_2 = L12_2.BASS
                        if L11_2 == L12_2 then
                          L3_2 = L12_1.bass
                          L11_2 = L13_1.previous
                          L4_2 = L11_2.bass
                        else
                          L11_2 = L2_1
                          L11_2 = L11_2[L10_2]
                          L11_2 = L11_2.soundSyncType
                          L12_2 = SOUND_SYNC_TYPE
                          L12_2 = L12_2.MID
                          if L11_2 == L12_2 then
                            L3_2 = L12_1.mid
                            L11_2 = L13_1.previous
                            L4_2 = L11_2.mid
                          else
                            L11_2 = L2_1
                            L11_2 = L11_2[L10_2]
                            L11_2 = L11_2.soundSyncType
                            L12_2 = SOUND_SYNC_TYPE
                            L12_2 = L12_2.TREBLE
                            if L11_2 == L12_2 then
                              L3_2 = L12_1.treble
                              L11_2 = L13_1.previous
                              L4_2 = L11_2.treble
                            else
                              L11_2 = L2_1
                              L11_2 = L11_2[L10_2]
                              L11_2 = L11_2.soundSyncType
                              L12_2 = SOUND_SYNC_TYPE
                              L12_2 = L12_2.LOW_MID
                              if L11_2 == L12_2 then
                                L3_2 = L12_1.lowMid
                                L11_2 = L13_1.previous
                                L4_2 = L11_2.lowMid
                              else
                                L11_2 = L2_1
                                L11_2 = L11_2[L10_2]
                                L11_2 = L11_2.soundSyncType
                                L12_2 = SOUND_SYNC_TYPE
                                L12_2 = L12_2.HIGH_MID
                                if L11_2 == L12_2 then
                                  L3_2 = L12_1.highMid
                                  L11_2 = L13_1.previous
                                  L4_2 = L11_2.highMid
                                end
                              end
                            end
                          end
                        end
                        L11_2 = 255
                        if L4_2 >= L11_2 then
                          L4_2 = 255
                        else
                          L11_2 = L66_1
                          if L4_2 <= L11_2 then
                            L4_2 = L66_1
                          end
                        end
                        L11_2 = AlterColorBrightness
                        L12_2 = L2_1
                        L12_2 = L12_2[L10_2]
                        L12_2 = L12_2.currentColor
                        L13_2 = Ternary
                        L14_2 = L3_2 >= L4_2
                        L15_2 = L3_2 - L4_2
                        L16_2 = 255
                        L16_2 = L16_2 - L4_2
                        L15_2 = L15_2 / L16_2
                        L16_2 = 0.0
                        L13_2, L14_2, L15_2, L16_2, L17_2, L18_2 = L13_2(L14_2, L15_2, L16_2)
                        L11_2 = L11_2(L12_2, L13_2, L14_2, L15_2, L16_2, L17_2, L18_2)
                        L12_2 = L11_2[1]
                        L13_2 = L2_1
                        L13_2 = L13_2[L10_2]
                        L13_2 = L13_2.lastColor
                        L13_2 = L13_2[1]
                        if L12_2 == L13_2 then
                          L12_2 = L11_2[2]
                          L13_2 = L2_1
                          L13_2 = L13_2[L10_2]
                          L13_2 = L13_2.lastColor
                          L13_2 = L13_2[2]
                          if L12_2 == L13_2 then
                            L12_2 = L11_2[3]
                            L13_2 = L2_1
                            L13_2 = L13_2[L10_2]
                            L13_2 = L13_2.lastColor
                            L13_2 = L13_2[3]
                            if L12_2 == L13_2 then
                              goto lbl_800
                            end
                          end
                        end
                        L12_2 = L2_1
                        L12_2 = L12_2[L10_2]
                        L12_2 = L12_2.handle
                        if L12_2 then
                          L12_2 = SetObjectLightColor
                          L13_2 = L2_1
                          L13_2 = L13_2[L10_2]
                          L13_2 = L13_2.handle
                          L14_2 = true
                          L15_2 = L11_2[1]
                          L16_2 = L11_2[2]
                          L17_2 = L11_2[3]
                          L12_2(L13_2, L14_2, L15_2, L16_2, L17_2)
                        end
                        ::lbl_800::
                        L12_2 = L2_1
                        L12_2 = L12_2[L10_2]
                        L13_2 = {}
                        L14_2 = L11_2[1]
                        L15_2 = L11_2[2]
                        L16_2 = L11_2[3]
                        L13_2[1] = L14_2
                        L13_2[2] = L15_2
                        L13_2[3] = L16_2
                        L12_2.lastColor = L13_2
                      end
                    end
                  end
                end
              end
            end
            L2_2 = L34_1
            L2_2 = L1_2 - L2_2
            L3_2 = L73_1
            if L2_2 > L3_2 then
              L34_1 = L1_2
              L2_2 = L56_1
              if L2_2 then
                L2_2 = L55_1
                if not L2_2 then
                  L2_2 = config
                  L2_2 = L2_2.entries
                  L3_2 = L19_1
                  L2_2 = L2_2[L3_2]
                  L2_2 = L2_2.polygons
                  if not L2_2 then
                    goto lbl_871
                  end
                  L2_2 = config
                  L2_2 = L2_2.entries
                  L3_2 = L19_1
                  L2_2 = L2_2[L3_2]
                  L2_2 = L2_2.polygons
                  L2_2 = L2_2.hideReplacersOutside
                  if L2_2 then
                    goto lbl_871
                  end
                end
                L2_2 = config
                L2_2 = L2_2.entries
                L3_2 = L19_1
                L2_2 = L2_2[L3_2]
                L2_2 = L2_2.replacers
                if L2_2 then
                  L2_2 = pairs
                  L3_2 = config
                  L3_2 = L3_2.entries
                  L4_2 = L19_1
                  L3_2 = L3_2[L4_2]
                  L3_2 = L3_2.replacers
                  L2_2, L3_2, L4_2, L5_2 = L2_2(L3_2)
                  for L6_2, L7_2 in L2_2, L3_2, L4_2, L5_2 do
                    L8_2 = AddReplaceTexture
                    L9_2 = L6_2
                    L10_2 = L7_2
                    L11_2 = "browser"
                    L12_2 = "browserTexture"
                    L8_2(L9_2, L10_2, L11_2, L12_2)
                  end
                end
                L2_2 = L9_1.ready
                if L2_2 then
                  L2_2 = L9_1.draw
                  if L2_2 then
                    L2_2 = SetScaleformTexture
                    L3_2 = L9_1.handle
                    L2_2(L3_2)
                  end
                end
              end
            end
            ::lbl_871::
            L2_2 = L35_1
            L2_2 = L1_2 - L2_2
            L3_2 = L72_1
            if L2_2 > L3_2 then
              L35_1 = L1_2
              L2_2 = L53_1
              if L2_2 then
                L2_2 = L11_1.playing
                if L2_2 then
                  L2_2 = L11_1.duration
                  if L2_2 then
                    L2_2 = L11_1.duration
                    if L2_2 > 0 then
                      L2_2 = L11_1.time
                      if L2_2 > 0 then
                        L2_2 = L22_1
                        L3_2 = L11_1.time
                        if L2_2 ~= L3_2 then
                          L2_2 = L11_1.time
                          L22_1 = L2_2
                          L2_2 = TriggerServerEvent
                          L3_2 = "cs-hall:time"
                          L4_2 = L19_1
                          L5_2 = L11_1.time
                          L6_2 = false
                          L2_2(L3_2, L4_2, L5_2, L6_2)
                        end
                      end
                    end
                  end
                end
              end
            end
            L2_2 = L9_1.tick
            if L2_2 then
              L2_2 = L9_1.solid
              if L2_2 then
                L2_2 = DrawScaleformMovie_3dSolid
                L3_2 = L9_1.handle
                L4_2 = L9_1.position
                L4_2 = L4_2.x
                L5_2 = L9_1.position
                L5_2 = L5_2.y
                L6_2 = L9_1.position
                L6_2 = L6_2.z
                L7_2 = Ternary
                L8_2 = L9_1.rotation
                L8_2 = L8_2.x
                L9_2 = 0.0
                L7_2 = L7_2(L8_2, L9_2)
                L8_2 = Ternary
                L9_2 = L9_1.rotation
                L9_2 = L9_2.y
                L10_2 = 0.0
                L8_2 = L8_2(L9_2, L10_2)
                L9_2 = Ternary
                L10_2 = L9_1.rotation
                L10_2 = L10_2.z
                L11_2 = 0.0
                L9_2 = L9_2(L10_2, L11_2)
                L10_2 = 0.0
                L11_2 = 1.0
                L12_2 = 0.0
                L13_2 = Ternary
                L14_2 = L9_1.scale
                L14_2 = L14_2.x
                L15_2 = 1.0
                L13_2 = L13_2(L14_2, L15_2)
                L14_2 = Ternary
                L15_2 = L9_1.scale
                L15_2 = L15_2.y
                L16_2 = 1.0
                L14_2 = L14_2(L15_2, L16_2)
                L15_2 = Ternary
                L16_2 = L9_1.scale
                L16_2 = L16_2.z
                L17_2 = 1.0
                L15_2 = L15_2(L16_2, L17_2)
                L16_2 = 0.0
                L2_2(L3_2, L4_2, L5_2, L6_2, L7_2, L8_2, L9_2, L10_2, L11_2, L12_2, L13_2, L14_2, L15_2, L16_2)
              else
                L2_2 = DrawScaleformMovie_3d
                L3_2 = L9_1.handle
                L4_2 = L9_1.position
                L4_2 = L4_2.x
                L5_2 = L9_1.position
                L5_2 = L5_2.y
                L6_2 = L9_1.position
                L6_2 = L6_2.z
                L7_2 = Ternary
                L8_2 = L9_1.rotation
                L8_2 = L8_2.x
                L9_2 = 0.0
                L7_2 = L7_2(L8_2, L9_2)
                L8_2 = Ternary
                L9_2 = L9_1.rotation
                L9_2 = L9_2.y
                L10_2 = 0.0
                L8_2 = L8_2(L9_2, L10_2)
                L9_2 = Ternary
                L10_2 = L9_1.rotation
                L10_2 = L10_2.z
                L11_2 = 0.0
                L9_2 = L9_2(L10_2, L11_2)
                L10_2 = 0.0
                L11_2 = 1.0
                L12_2 = 0.0
                L13_2 = Ternary
                L14_2 = L9_1.scale
                L14_2 = L14_2.x
                L15_2 = L9_1.scale
                L15_2 = L15_2.x
                L15_2 = -L15_2
                L16_2 = 1.0
                L13_2 = L13_2(L14_2, L15_2, L16_2)
                L14_2 = Ternary
                L15_2 = L9_1.scale
                L15_2 = L15_2.y
                L16_2 = L9_1.scale
                L16_2 = L16_2.y
                L16_2 = -L16_2
                L17_2 = 1.0
                L14_2 = L14_2(L15_2, L16_2, L17_2)
                L15_2 = Ternary
                L16_2 = L9_1.scale
                L16_2 = L16_2.z
                L17_2 = L9_1.scale
                L17_2 = L17_2.z
                L17_2 = -L17_2
                L18_2 = 1.0
                L15_2 = L15_2(L16_2, L17_2, L18_2)
                L16_2 = 0.0
                L2_2(L3_2, L4_2, L5_2, L6_2, L7_2, L8_2, L9_2, L10_2, L11_2, L12_2, L13_2, L14_2, L15_2, L16_2)
              end
            end
          end
        end
      end
    end
    L1_2 = Wait
    L2_2 = L19_1
    if not L2_2 then
      L2_2 = 500
      if L2_2 then
        goto lbl_1015
      end
    end
    L2_2 = 0
    ::lbl_1015::
    L1_2(L2_2)
  end
end
L89_1(L90_1)
L89_1 = config
L89_1 = L89_1.debug
if L89_1 then
  function L89_1(A0_2, A1_2, A2_2, A3_2)
    local L4_2, L5_2, L6_2, L7_2, L8_2, L9_2, L10_2, L11_2, L12_2
    L4_2 = World3dToScreen2d
    L5_2 = A0_2
    L6_2 = A1_2
    L7_2 = A2_2
    L4_2, L5_2, L6_2 = L4_2(L5_2, L6_2, L7_2)
    if L4_2 then
      L7_2 = SetTextScale
      L8_2 = 0.35
      L9_2 = 0.35
      L7_2(L8_2, L9_2)
      L7_2 = SetTextFont
      L8_2 = 4
      L7_2(L8_2)
      L7_2 = SetTextProportional
      L8_2 = 1
      L7_2(L8_2)
      L7_2 = SetTextColour
      L8_2 = 255
      L9_2 = 255
      L10_2 = 255
      L11_2 = 215
      L7_2(L8_2, L9_2, L10_2, L11_2)
      L7_2 = SetTextEntry
      L8_2 = "STRING"
      L7_2(L8_2)
      L7_2 = SetTextDropshadow
      L8_2 = 0
      L9_2 = 0
      L10_2 = 0
      L11_2 = 0
      L12_2 = 255
      L7_2(L8_2, L9_2, L10_2, L11_2, L12_2)
      L7_2 = SetTextEdge
      L8_2 = 1
      L9_2 = 0
      L10_2 = 0
      L11_2 = 0
      L12_2 = 255
      L7_2(L8_2, L9_2, L10_2, L11_2, L12_2)
      L7_2 = SetTextDropShadow
      L7_2()
      L7_2 = SetTextOutline
      L7_2()
      L7_2 = SetTextCentre
      L8_2 = 1
      L7_2(L8_2)
      L7_2 = AddTextComponentString
      L8_2 = A3_2
      L7_2(L8_2)
      L7_2 = DrawText
      L8_2 = L5_2
      L9_2 = L6_2
      L7_2(L8_2, L9_2)
    end
  end
  function L90_1(A0_2, A1_2, A2_2, A3_2, A4_2)
    local L5_2, L6_2, L7_2, L8_2, L9_2, L10_2, L11_2, L12_2, L13_2, L14_2, L15_2, L16_2, L17_2, L18_2, L19_2, L20_2, L21_2, L22_2, L23_2, L24_2, L25_2, L26_2
    L5_2 = vector3
    L6_2 = A0_2.x
    L7_2 = A0_2.y
    L8_2 = A2_2.min
    L5_2 = L5_2(L6_2, L7_2, L8_2)
    L6_2 = vector3
    L7_2 = A0_2.x
    L8_2 = A0_2.y
    L9_2 = A2_2.max
    L6_2 = L6_2(L7_2, L8_2, L9_2)
    L7_2 = vector3
    L8_2 = A1_2.x
    L9_2 = A1_2.y
    L10_2 = A2_2.min
    L7_2 = L7_2(L8_2, L9_2, L10_2)
    L8_2 = vector3
    L9_2 = A1_2.x
    L10_2 = A1_2.y
    L11_2 = A2_2.max
    L8_2 = L8_2(L9_2, L10_2, L11_2)
    L9_2 = DrawPoly
    L10_2 = L5_2.x
    L11_2 = L5_2.y
    L12_2 = L5_2.z
    L13_2 = L6_2.x
    L14_2 = L6_2.y
    L15_2 = L6_2.z
    L16_2 = L7_2.x
    L17_2 = L7_2.y
    L18_2 = L7_2.z
    L19_2 = Ternary
    L20_2 = A3_2
    L21_2 = 0
    L22_2 = 255
    L19_2 = L19_2(L20_2, L21_2, L22_2)
    L20_2 = Ternary
    L21_2 = A4_2
    L22_2 = 255
    L23_2 = Ternary
    L24_2 = A3_2
    L25_2 = 165
    L26_2 = 0
    L23_2, L24_2, L25_2, L26_2 = L23_2(L24_2, L25_2, L26_2)
    L20_2 = L20_2(L21_2, L22_2, L23_2, L24_2, L25_2, L26_2)
    L21_2 = 0
    L22_2 = 125
    L9_2(L10_2, L11_2, L12_2, L13_2, L14_2, L15_2, L16_2, L17_2, L18_2, L19_2, L20_2, L21_2, L22_2)
    L9_2 = DrawPoly
    L10_2 = L6_2.x
    L11_2 = L6_2.y
    L12_2 = L6_2.z
    L13_2 = L8_2.x
    L14_2 = L8_2.y
    L15_2 = L8_2.z
    L16_2 = L7_2.x
    L17_2 = L7_2.y
    L18_2 = L7_2.z
    L19_2 = Ternary
    L20_2 = A3_2
    L21_2 = 0
    L22_2 = 255
    L19_2 = L19_2(L20_2, L21_2, L22_2)
    L20_2 = Ternary
    L21_2 = A4_2
    L22_2 = 255
    L23_2 = Ternary
    L24_2 = A3_2
    L25_2 = 165
    L26_2 = 0
    L23_2, L24_2, L25_2, L26_2 = L23_2(L24_2, L25_2, L26_2)
    L20_2 = L20_2(L21_2, L22_2, L23_2, L24_2, L25_2, L26_2)
    L21_2 = 0
    L22_2 = 125
    L9_2(L10_2, L11_2, L12_2, L13_2, L14_2, L15_2, L16_2, L17_2, L18_2, L19_2, L20_2, L21_2, L22_2)
    L9_2 = DrawPoly
    L10_2 = L7_2.x
    L11_2 = L7_2.y
    L12_2 = L7_2.z
    L13_2 = L8_2.x
    L14_2 = L8_2.y
    L15_2 = L8_2.z
    L16_2 = L6_2.x
    L17_2 = L6_2.y
    L18_2 = L6_2.z
    L19_2 = Ternary
    L20_2 = A3_2
    L21_2 = 0
    L22_2 = 255
    L19_2 = L19_2(L20_2, L21_2, L22_2)
    L20_2 = Ternary
    L21_2 = A4_2
    L22_2 = 255
    L23_2 = Ternary
    L24_2 = A3_2
    L25_2 = 165
    L26_2 = 0
    L23_2, L24_2, L25_2, L26_2 = L23_2(L24_2, L25_2, L26_2)
    L20_2 = L20_2(L21_2, L22_2, L23_2, L24_2, L25_2, L26_2)
    L21_2 = 0
    L22_2 = 125
    L9_2(L10_2, L11_2, L12_2, L13_2, L14_2, L15_2, L16_2, L17_2, L18_2, L19_2, L20_2, L21_2, L22_2)
    L9_2 = DrawPoly
    L10_2 = L7_2.x
    L11_2 = L7_2.y
    L12_2 = L7_2.z
    L13_2 = L6_2.x
    L14_2 = L6_2.y
    L15_2 = L6_2.z
    L16_2 = L5_2.x
    L17_2 = L5_2.y
    L18_2 = L5_2.z
    L19_2 = Ternary
    L20_2 = A3_2
    L21_2 = 0
    L22_2 = 255
    L19_2 = L19_2(L20_2, L21_2, L22_2)
    L20_2 = Ternary
    L21_2 = A4_2
    L22_2 = 255
    L23_2 = Ternary
    L24_2 = A3_2
    L25_2 = 165
    L26_2 = 0
    L23_2, L24_2, L25_2, L26_2 = L23_2(L24_2, L25_2, L26_2)
    L20_2 = L20_2(L21_2, L22_2, L23_2, L24_2, L25_2, L26_2)
    L21_2 = 0
    L22_2 = 125
    L9_2(L10_2, L11_2, L12_2, L13_2, L14_2, L15_2, L16_2, L17_2, L18_2, L19_2, L20_2, L21_2, L22_2)
  end
  L91_1 = CreateThread
  function L92_1()
    local L0_2, L1_2, L2_2, L3_2, L4_2, L5_2, L6_2, L7_2, L8_2, L9_2, L10_2, L11_2, L12_2, L13_2, L14_2, L15_2, L16_2, L17_2, L18_2, L19_2, L20_2, L21_2, L22_2, L23_2, L24_2, L25_2, L26_2, L27_2, L28_2, L29_2, L30_2
    while true do
      L0_2 = L19_1
      if L0_2 then
        L0_2 = 1
        L1_2 = L3_1
        L1_2 = #L1_2
        L2_2 = 1
        for L3_2 = L0_2, L1_2, L2_2 do
          L4_2 = L3_1
          L4_2 = L4_2[L3_2]
          L4_2 = L4_2.position
          L5_2 = L3_1
          L5_2 = L5_2[L3_2]
          L5_2 = L5_2.up
          L5_2 = L5_2 * 0.25
          L4_2 = L4_2 + L5_2
          L5_2 = L3_1
          L5_2 = L5_2[L3_2]
          L5_2 = L5_2.position
          L6_2 = L3_1
          L6_2 = L6_2[L3_2]
          L6_2 = L6_2.forward
          L6_2 = L6_2 * -3.0
          L5_2 = L5_2 + L6_2
          L6_2 = L3_1
          L6_2 = L6_2[L3_2]
          L6_2 = L6_2.up
          L6_2 = L6_2 * 0.5
          L5_2 = L5_2 + L6_2
          L6_2 = DrawLine
          L7_2 = L4_2.x
          L8_2 = L4_2.y
          L9_2 = L4_2.z
          L10_2 = L5_2.x
          L11_2 = L5_2.y
          L12_2 = L5_2.z
          L13_2 = 255
          L14_2 = 0
          L15_2 = 0
          L16_2 = 125
          L6_2(L7_2, L8_2, L9_2, L10_2, L11_2, L12_2, L13_2, L14_2, L15_2, L16_2)
        end
        L0_2 = 1
        L1_2 = L4_1
        L1_2 = #L1_2
        L2_2 = 1
        for L3_2 = L0_2, L1_2, L2_2 do
          L4_2 = L4_1
          L4_2 = L4_2[L3_2]
          L4_2 = L4_2.position
          L5_2 = L4_1
          L5_2 = L5_2[L3_2]
          L5_2 = L5_2.up
          L5_2 = L5_2 * 1.5
          L4_2 = L4_2 + L5_2
          L5_2 = DrawLine
          L6_2 = L4_1
          L6_2 = L6_2[L3_2]
          L6_2 = L6_2.position
          L6_2 = L6_2.x
          L7_2 = L4_1
          L7_2 = L7_2[L3_2]
          L7_2 = L7_2.position
          L7_2 = L7_2.y
          L8_2 = L4_1
          L8_2 = L8_2[L3_2]
          L8_2 = L8_2.position
          L8_2 = L8_2.z
          L9_2 = L4_2.x
          L10_2 = L4_2.y
          L11_2 = L4_2.z
          L12_2 = 255
          L13_2 = 0
          L14_2 = 255
          L15_2 = 125
          L5_2(L6_2, L7_2, L8_2, L9_2, L10_2, L11_2, L12_2, L13_2, L14_2, L15_2)
        end
        L0_2 = 1
        L1_2 = L2_1
        L1_2 = #L1_2
        L2_2 = 1
        for L3_2 = L0_2, L1_2, L2_2 do
          L4_2 = L2_1
          L4_2 = L4_2[L3_2]
          L4_2 = L4_2.position
          L5_2 = L2_1
          L5_2 = L5_2[L3_2]
          L5_2 = L5_2.up
          L5_2 = L5_2 * -0.15
          L4_2 = L4_2 + L5_2
          L5_2 = L2_1
          L5_2 = L5_2[L3_2]
          L5_2 = L5_2.position
          L6_2 = L2_1
          L6_2 = L6_2[L3_2]
          L6_2 = L6_2.forward
          L6_2 = L6_2 * -10.0
          L5_2 = L5_2 + L6_2
          L6_2 = L2_1
          L6_2 = L6_2[L3_2]
          L6_2 = L6_2.up
          L6_2 = L6_2 * -5.0
          L5_2 = L5_2 + L6_2
          L6_2 = DrawLine
          L7_2 = L4_2.x
          L8_2 = L4_2.y
          L9_2 = L4_2.z
          L10_2 = L5_2.x
          L11_2 = L5_2.y
          L12_2 = L5_2.z
          L13_2 = 255
          L14_2 = 255
          L15_2 = 0
          L16_2 = 125
          L6_2(L7_2, L8_2, L9_2, L10_2, L11_2, L12_2, L13_2, L14_2, L15_2, L16_2)
          L6_2 = L89_1
          L7_2 = L4_2.x
          L8_2 = L4_2.y
          L9_2 = L4_2.z
          L10_2 = "Sound Sync: "
          L11_2 = L2_1
          L11_2 = L11_2[L3_2]
          L11_2 = L11_2.soundSyncType
          L10_2 = L10_2 .. L11_2
          L6_2(L7_2, L8_2, L9_2, L10_2)
        end
        L0_2 = PlayerPedId
        L0_2 = L0_2()
        L1_2 = GetGameplayCamRot
        L2_2 = 2
        L1_2 = L1_2(L2_2)
        L2_2 = GetEntityMatrix
        L3_2 = L0_2
        L2_2, L3_2, L4_2, L5_2 = L2_2(L3_2)
        L6_2 = RotationToDirection
        L7_2 = L1_2
        L6_2 = L6_2(L7_2)
        L7_2 = GetEntityBoneIndexByName
        L8_2 = L0_2
        L9_2 = "BONETAG_HEAD"
        L7_2 = L7_2(L8_2, L9_2)
        L8_2 = Ternary
        L9_2 = -1 ~= L7_2
        L10_2 = GetWorldPositionOfEntityBone
        L11_2 = L0_2
        L12_2 = L7_2
        L10_2 = L10_2(L11_2, L12_2)
        L11_2 = L5_2
        L8_2 = L8_2(L9_2, L10_2, L11_2)
        L9_2 = 1
        L10_2 = L7_1
        L10_2 = #L10_2
        L11_2 = 1
        for L12_2 = L9_2, L10_2, L11_2 do
          L13_2 = L7_1
          L13_2 = L13_2[L12_2]
          L14_2 = L13_2.position
          L15_2 = Ternary
          L16_2 = L13_2.soundOffset
          L17_2 = vector3
          L18_2 = 0.0
          L19_2 = 0.0
          L20_2 = 0.0
          L17_2, L18_2, L19_2, L20_2, L21_2, L22_2, L23_2, L24_2, L25_2, L26_2, L27_2, L28_2, L29_2, L30_2 = L17_2(L18_2, L19_2, L20_2)
          L15_2 = L15_2(L16_2, L17_2, L18_2, L19_2, L20_2, L21_2, L22_2, L23_2, L24_2, L25_2, L26_2, L27_2, L28_2, L29_2, L30_2)
          L14_2 = L14_2 + L15_2
          L15_2 = L13_2.forward
          L15_2 = L15_2 * -1
          L16_2 = Ternary
          L17_2 = L13_2.directionOffset
          L18_2 = vector3
          L19_2 = 1.0
          L20_2 = 1.0
          L21_2 = 1.0
          L18_2, L19_2, L20_2, L21_2, L22_2, L23_2, L24_2, L25_2, L26_2, L27_2, L28_2, L29_2, L30_2 = L18_2(L19_2, L20_2, L21_2)
          L16_2 = L16_2(L17_2, L18_2, L19_2, L20_2, L21_2, L22_2, L23_2, L24_2, L25_2, L26_2, L27_2, L28_2, L29_2, L30_2)
          L15_2 = L15_2 * L16_2
          L16_2 = L15_2 * 15.0
          L16_2 = L14_2 + L16_2
          L17_2 = DrawLine
          L18_2 = L14_2.x
          L19_2 = L14_2.y
          L20_2 = L14_2.z
          L21_2 = L16_2.x
          L22_2 = L16_2.y
          L23_2 = L16_2.z
          L24_2 = 0
          L25_2 = 0
          L26_2 = 255
          L27_2 = 125
          L17_2(L18_2, L19_2, L20_2, L21_2, L22_2, L23_2, L24_2, L25_2, L26_2, L27_2)
          L17_2 = DrawLine
          L18_2 = L8_2.x
          L19_2 = L8_2.y
          L20_2 = L8_2.z
          L21_2 = L14_2.x
          L22_2 = L14_2.y
          L23_2 = L14_2.z
          L24_2 = 0
          L25_2 = 255
          L26_2 = 255
          L27_2 = 125
          L17_2(L18_2, L19_2, L20_2, L21_2, L22_2, L23_2, L24_2, L25_2, L26_2, L27_2)
        end
        L9_2 = L6_2 * 5.0
        L9_2 = L5_2 + L9_2
        L10_2 = L4_2 * 5.0
        L10_2 = L5_2 + L10_2
        L11_2 = DrawLine
        L12_2 = L5_2.x
        L13_2 = L5_2.y
        L14_2 = L5_2.z
        L15_2 = L9_2.x
        L16_2 = L9_2.y
        L17_2 = L9_2.z
        L18_2 = 255
        L19_2 = 125
        L20_2 = 0
        L21_2 = 125
        L11_2(L12_2, L13_2, L14_2, L15_2, L16_2, L17_2, L18_2, L19_2, L20_2, L21_2)
        L11_2 = DrawLine
        L12_2 = L5_2.x
        L13_2 = L5_2.y
        L14_2 = L5_2.z
        L15_2 = L10_2.x
        L16_2 = L10_2.y
        L17_2 = L10_2.z
        L18_2 = 0
        L19_2 = 255
        L20_2 = 0
        L21_2 = 125
        L11_2(L12_2, L13_2, L14_2, L15_2, L16_2, L17_2, L18_2, L19_2, L20_2, L21_2)
        L11_2 = config
        L11_2 = L11_2.entries
        L12_2 = L19_1
        L11_2 = L11_2[L12_2]
        L11_2 = L11_2.area
        L11_2 = L11_2.polygons
        if L11_2 then
          L11_2 = config
          L11_2 = L11_2.entries
          L12_2 = L19_1
          L11_2 = L11_2[L12_2]
          L11_2 = L11_2.area
          L11_2 = L11_2.polygons
          L11_2 = L11_2.entries
          if L11_2 then
            L11_2 = config
            L11_2 = L11_2.entries
            L12_2 = L19_1
            L11_2 = L11_2[L12_2]
            L11_2 = L11_2.area
            L11_2 = L11_2.polygons
            L11_2 = L11_2.entries
            L12_2 = 1
            L13_2 = #L11_2
            L14_2 = 1
            for L15_2 = L12_2, L13_2, L14_2 do
              L16_2 = L11_2[L15_2]
              L17_2 = 1
              L18_2 = L16_2.points
              L18_2 = #L18_2
              L19_2 = 1
              for L20_2 = L17_2, L18_2, L19_2 do
                L21_2 = IsPositionInsideArea
                L22_2 = L5_2
                L21_2 = L21_2(L22_2)
                L22_2 = IsPositionInsideArea
                L23_2 = L5_2
                L24_2 = L16_2
                L22_2 = L22_2(L23_2, L24_2)
                L23_2 = L89_1
                L24_2 = L16_2.points
                L24_2 = L24_2[L20_2]
                L24_2 = L24_2.x
                L25_2 = L16_2.points
                L25_2 = L25_2[L20_2]
                L25_2 = L25_2.y
                L26_2 = L16_2.height
                L26_2 = L26_2.min
                L27_2 = L16_2.height
                L27_2 = L27_2.max
                L28_2 = L16_2.height
                L28_2 = L28_2.min
                L27_2 = L27_2 - L28_2
                L27_2 = L27_2 / 2
                L26_2 = L26_2 + L27_2
                L27_2 = "Polygon - Point Index: "
                L28_2 = L15_2
                L29_2 = " - "
                L30_2 = L20_2
                L27_2 = L27_2 .. L28_2 .. L29_2 .. L30_2
                L23_2(L24_2, L25_2, L26_2, L27_2)
                L23_2 = L16_2.points
                L23_2 = #L23_2
                if L20_2 < L23_2 then
                  L23_2 = L90_1
                  L24_2 = L16_2.points
                  L24_2 = L24_2[L20_2]
                  L25_2 = L16_2.points
                  L26_2 = L20_2 + 1
                  L25_2 = L25_2[L26_2]
                  L26_2 = L16_2.height
                  L27_2 = L22_2
                  L28_2 = L21_2
                  L23_2(L24_2, L25_2, L26_2, L27_2, L28_2)
                end
                L23_2 = L16_2.points
                L23_2 = #L23_2
                if L23_2 > 2 then
                  L23_2 = L90_1
                  L24_2 = L16_2.points
                  L24_2 = L24_2[1]
                  L25_2 = L16_2.points
                  L26_2 = L16_2.points
                  L26_2 = #L26_2
                  L25_2 = L25_2[L26_2]
                  L26_2 = L16_2.height
                  L27_2 = L22_2
                  L28_2 = L21_2
                  L23_2(L24_2, L25_2, L26_2, L27_2, L28_2)
                end
              end
            end
          end
        end
        L11_2 = L89_1
        L12_2 = config
        L12_2 = L12_2.entries
        L13_2 = L19_1
        L12_2 = L12_2[L13_2]
        L12_2 = L12_2.area
        L12_2 = L12_2.center
        L12_2 = L12_2.x
        L13_2 = config
        L13_2 = L13_2.entries
        L14_2 = L19_1
        L13_2 = L13_2[L14_2]
        L13_2 = L13_2.area
        L13_2 = L13_2.center
        L13_2 = L13_2.y
        L14_2 = config
        L14_2 = L14_2.entries
        L15_2 = L19_1
        L14_2 = L14_2[L15_2]
        L14_2 = L14_2.area
        L14_2 = L14_2.center
        L14_2 = L14_2.z
        L15_2 = "Config Entry: "
        L16_2 = L19_1
        L15_2 = L15_2 .. L16_2
        L11_2(L12_2, L13_2, L14_2, L15_2)
      end
      L0_2 = Wait
      L1_2 = 0
      L0_2(L1_2)
    end
  end
  L91_1(L92_1)
end
L89_1 = exports
L90_1 = "CanAccessRemoteControl"
function L91_1()
  local L0_2, L1_2
  L0_2 = L57_1
  if L0_2 then
    L1_2 = L19_1
    L0_2 = L17_1
    L0_2 = L0_2[L1_2]
    if L0_2 then
      L0_2 = CanAccessUi
      L0_2 = L0_2()
    end
  end
  return L0_2
end
L89_1(L90_1, L91_1)
function L89_1(A0_2, A1_2, A2_2, A3_2)
  local L4_2, L5_2
  L4_2 = L8_1
  L5_2 = {}
  L5_2.register = A2_2
  L5_2.ticker = A3_2
  L5_2.areas = A1_2
  L4_2[A0_2] = L5_2
  L4_2 = SetScene
  L4_2()
end
RegisterScene = L89_1
L89_1 = exports
L90_1 = "RegisterScene"
L91_1 = RegisterScene
L89_1(L90_1, L91_1)
Scene = L18_1
L89_1 = exports
L90_1 = "IsUiEnabled"
function L91_1()
  local L0_2, L1_2
  L0_2 = L38_1
  return L0_2
end
L89_1(L90_1, L91_1)
L89_1 = exports
L90_1 = "Enable"
function L91_1()
  local L0_2, L1_2
  L0_2 = true
  L62_1 = L0_2
end
L89_1(L90_1, L91_1)
L89_1 = exports
L90_1 = "Disable"
function L91_1()
  local L0_2, L1_2
  L0_2 = false
  L62_1 = L0_2
  L0_2 = L19_1
  if L0_2 then
    L0_2 = DesyncHallArea
    L1_2 = L19_1
    L0_2(L1_2)
    L0_2 = DesyncArea
    L1_2 = L19_1
    L0_2(L1_2)
    L0_2 = nil
    L19_1 = L0_2
    L0_2 = false
    L56_1 = L0_2
    L0_2 = false
    L55_1 = L0_2
  end
end
L89_1(L90_1, L91_1)

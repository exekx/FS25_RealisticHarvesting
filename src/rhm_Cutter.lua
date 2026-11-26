-- EN: rhm_Cutter — vehicle specialization for cutters / headers.
--     Provides native independent header launch control and header blocking/reverse
--     visuals & animations during harvester clogging events.
-- UA: rhm_Cutter — спеціалізація техніки для жаток.
--     Забезпечує роздільний запуск жатки, а також зупинку мотовила/робочої зони
--     та реверсну анімацію шнеків і маси під час забивання/очищення комбайна.

rhm_Cutter = {}
rhm_Cutter._globalHooksInstalled = false

local function getAttachedCombineState(cutter)
    if cutter == nil then
        return false, false, nil, nil
    end

    local combine = nil
    if cutter.spec_rhm_Combine ~= nil then
        combine = cutter
    elseif cutter.spec_cutter ~= nil and cutter.spec_cutter.workAreaParameters ~= nil
        and cutter.spec_cutter.workAreaParameters.combineVehicle ~= nil
        and cutter.spec_cutter.workAreaParameters.combineVehicle.spec_rhm_Combine ~= nil then
        combine = cutter.spec_cutter.workAreaParameters.combineVehicle
    elseif cutter.getAttacherVehicle ~= nil then
        local attacher = cutter:getAttacherVehicle()
        if attacher ~= nil then
            if attacher.spec_rhm_Combine ~= nil then
                combine = attacher
            elseif attacher.rootVehicle ~= nil and attacher.rootVehicle.spec_rhm_Combine ~= nil then
                combine = attacher.rootVehicle
            end
        end
    end
    if combine == nil and cutter.rootVehicle ~= nil and cutter.rootVehicle.spec_rhm_Combine ~= nil then
        combine = cutter.rootVehicle
    end
    if combine == nil and cutter.getCombine ~= nil then
        local found = cutter:getCombine()
        if found ~= nil and found.spec_rhm_Combine ~= nil then
            combine = found
        end
    end

    local spec = combine and combine.spec_rhm_Combine
    if spec == nil or spec.isRhmCombine ~= true then
        return false, false, combine, nil
    end

    local cState = (spec.cloggingSystem and spec.cloggingSystem:getState()) or (spec.data and spec.data.clogState) or 0
    local cLevel = (spec.cloggingSystem and spec.cloggingSystem:getLevel()) or (spec.data and spec.data.clogLevel) or 0
    local spd = (combine.getLastSpeed and combine:getLastSpeed()) or 0
    local isClogged = (cState == 3) or (cLevel >= 100.0)
    local isReversing = (cLevel > 0) and (
        (spec.data and spec.data.isClogReversing == true)
        or (spec.cloggingSystem and spec.cloggingSystem.isPlayerReversing == true)
        or (spec.isHoldingReverseFeeder == true and spd < 1.2)
    )
    return isClogged, isReversing, combine, spec
end

local function installGlobalCutterHooks()
    if rhm_Cutter._globalHooksInstalled then
        return
    end
    rhm_Cutter._globalHooksInstalled = true

    if SpeedRotatingParts ~= nil and SpeedRotatingParts.getSpeedRotatingPartDirection ~= nil then
        SpeedRotatingParts.getSpeedRotatingPartDirection = Utils.overwrittenFunction(
            SpeedRotatingParts.getSpeedRotatingPartDirection,
            function(self, superFunc, speedRotatingPart)
                local baseDir = superFunc(self, speedRotatingPart)
                if type(baseDir) ~= "number" then
                    baseDir = 1
                end
                if self ~= nil and self.spec_rhm_Cutter ~= nil then
                    local isClogged, isReversing = getAttachedCombineState(self)
                    if isReversing then
                        return -math.abs(baseDir)
                    elseif isClogged then
                        return 0
                    end
                end
                return baseDir
            end
        )
    end

    if TurnOnVehicle ~= nil and TurnOnVehicle.onUpdate ~= nil then
        TurnOnVehicle.onUpdate = Utils.appendedFunction(
            TurnOnVehicle.onUpdate,
            function(self)
                if self == nil or self.spec_rhm_Cutter == nil or self.spec_cutter == nil then
                    return
                end
                local isClogged, isReversing = getAttachedCombineState(self)
                if isClogged or isReversing then
                    rhm_Cutter.applyTurnedOnReelPhase(self, isReversing)
                elseif self.spec_rhm_Cutter._wasReelControlled then
                    rhm_Cutter.restoreTurnedOnReelPhase(self)
                end
            end
        )
    end
end

function rhm_Cutter.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(Cutter, specializations)
end

function rhm_Cutter.initSpecialization()
    installGlobalCutterHooks()
end

function rhm_Cutter.registerFunctions(vehicleType)
    SpecializationUtil.registerFunction(vehicleType, "updateIndependentLaunchState", rhm_Cutter.updateIndependentLaunchState)
end

function rhm_Cutter.registerOverwrittenFunctions(vehicleType)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getIsWorkAreaActive", rhm_Cutter.getIsWorkAreaActive)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getIsSpeedRotatingPartActive", rhm_Cutter.getIsSpeedRotatingPartActive)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getIsRandomlyMovingPartActive", rhm_Cutter.getIsRandomlyMovingPartActive)
end

function rhm_Cutter.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, "onLoad", rhm_Cutter)
    SpecializationUtil.registerEventListener(vehicleType, "onPostLoad", rhm_Cutter)
    SpecializationUtil.registerEventListener(vehicleType, "onUpdateTick", rhm_Cutter)
    SpecializationUtil.registerEventListener(vehicleType, "onPostAttach", rhm_Cutter)
    SpecializationUtil.registerEventListener(vehicleType, "onPreDetach", rhm_Cutter)
end

function rhm_Cutter:getIsWorkAreaActive(superFunc, workArea)
    if workArea ~= nil and workArea.type == WorkAreaType.CUTTER then
        local isClogged, isReversing = getAttachedCombineState(self)
        if isClogged or isReversing then
            return false
        end
    end
    return superFunc(self, workArea)
end

function rhm_Cutter:getIsSpeedRotatingPartActive(superFunc, speedRotatingPart)
    local isClogged, isReversing = getAttachedCombineState(self)
    if isReversing then
        local isFolded = self.spec_foldable ~= nil and self.getIsUnfolded ~= nil and not self:getIsUnfolded()
        if not isFolded then
            return true
        end
    elseif isClogged then
        return false
    end
    return superFunc(self, speedRotatingPart)
end

function rhm_Cutter:getIsRandomlyMovingPartActive(superFunc, part)
    local isClogged, isReversing = getAttachedCombineState(self)
    if isClogged and not isReversing then
        return false
    end
    return superFunc(self, part)
end

function rhm_Cutter.applyTurnedOnReelPhase(vehicle, isReversing)
    local rhmCutterSpec = vehicle.spec_rhm_Cutter
    local turnOnSpec = vehicle.spec_turnOnVehicle
    if rhmCutterSpec == nil or turnOnSpec == nil or turnOnSpec.turnedOnAnimations == nil or vehicle.setAnimationSpeed == nil then
        return
    end
    rhmCutterSpec._wasReelControlled = true

    for _, anim in ipairs(turnOnSpec.turnedOnAnimations) do
        local name = anim ~= nil and anim.name or nil
        if name ~= nil then
            local lower = string.lower(name)
            if string.find(lower, "reel", 1, true) ~= nil or string.find(lower, "spike", 1, true) ~= nil or string.find(lower, "turn", 1, true) ~= nil then
                if anim._rhmOrigSpeed == nil then
                    anim._rhmOrigSpeed = anim.speedScale or anim.turnedOnSpeedScale or 1.0
                end
                if isReversing then
                    local revSpd = -math.max(0.25, math.abs(anim._rhmOrigSpeed) * 0.65)
                    if vehicle.playAnimation ~= nil and vehicle.getAnimationTime ~= nil then
                        vehicle:playAnimation(name, revSpd, vehicle:getAnimationTime(name), true, false)
                    end
                    vehicle:setAnimationSpeed(name, revSpd)
                else
                    vehicle:setAnimationSpeed(name, 0)
                end
            end
        end
    end
end

function rhm_Cutter.restoreTurnedOnReelPhase(vehicle)
    local rhmCutterSpec = vehicle.spec_rhm_Cutter
    local turnOnSpec = vehicle.spec_turnOnVehicle
    if rhmCutterSpec == nil or turnOnSpec == nil or turnOnSpec.turnedOnAnimations == nil or vehicle.setAnimationSpeed == nil then
        if rhmCutterSpec then rhmCutterSpec._wasReelControlled = false end
        return
    end
    local isVehicleTurnedOn = (vehicle.getIsTurnedOn ~= nil and vehicle:getIsTurnedOn() == true)
    for _, anim in ipairs(turnOnSpec.turnedOnAnimations) do
        local name = anim ~= nil and anim.name or nil
        if name ~= nil and anim._rhmOrigSpeed ~= nil then
            if isVehicleTurnedOn then
                vehicle:setAnimationSpeed(name, anim._rhmOrigSpeed)
            else
                vehicle:setAnimationSpeed(name, 0)
                if vehicle.stopAnimation ~= nil and vehicle.getIsAnimationPlaying ~= nil and vehicle:getIsAnimationPlaying(name) then
                    vehicle:stopAnimation(name, true)
                end
            end
        end
    end
    rhmCutterSpec._wasReelControlled = false
end

local function updateCutterEffectsMotion(effectTable, isClogged, isReversing)
    if type(effectTable) ~= "table" then
        return
    end
    for _, effect in pairs(effectTable) do
        if type(effect) == "table" and (effect.effectSpeedScale ~= nil or effect.effectSpeedScaleOrig ~= nil) then
            if effect._rhmOrigEffectSpeed == nil then
                local fwd = effect.effectSpeedScaleOrig or effect.effectSpeedScale
                if type(fwd) == "number" and math.abs(fwd) > 0.0001 then
                    effect._rhmOrigEffectSpeed = fwd
                end
            end

            if isReversing then
                local fwd = effect._rhmOrigEffectSpeed or effect.effectSpeedScaleOrig or 0.25
                effect.effectSpeedScale = -math.abs(fwd) * 0.35
                effect._rhmReversed = true
            elseif isClogged then
                effect.effectSpeedScale = 0
                effect._rhmReversed = true
            elseif effect._rhmReversed then
                if effect._rhmOrigEffectSpeed ~= nil then
                    effect.effectSpeedScale = effect._rhmOrigEffectSpeed
                elseif effect.effectSpeedScaleOrig ~= nil then
                    effect.effectSpeedScale = effect.effectSpeedScaleOrig
                end
                effect._rhmReversed = false
            end
        end
    end
end

function rhm_Cutter:onUpdateTick(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
    if not self.isClient then
        return
    end
    local cutterSpec = self.spec_cutter
    local rhmCutterSpec = self.spec_rhm_Cutter
    if cutterSpec == nil or rhmCutterSpec == nil then
        return
    end

    local isClogged, isReversing, _, combineSpec = getAttachedCombineState(self)
    local machineType = (combineSpec and combineSpec.machineType) or "grain"

    -- Native grain reel lifecycle control when clogged or clearing
    if machineType == "grain" then
        if isClogged and not isReversing then
            if not rhmCutterSpec._nativeReelStopped then
                if self.onStopReel ~= nil then
                    self:onStopReel()
                end
                rhmCutterSpec._nativeReelStopped = true
            end
            if self.reelStarted ~= nil then self.reelStarted = false end
            if cutterSpec.reelStarted ~= nil then cutterSpec.reelStarted = false end

            if Utils ~= nil and Utils.updateRotationNodes ~= nil then
                if self.cutterTurnedOnRotationNodes ~= nil then
                    Utils.updateRotationNodes(self.cutterTurnedOnRotationNodes, dt or 0, false)
                end
                if cutterSpec.cutterTurnedOnRotationNodes ~= nil and cutterSpec.cutterTurnedOnRotationNodes ~= self.cutterTurnedOnRotationNodes then
                    Utils.updateRotationNodes(cutterSpec.cutterTurnedOnRotationNodes, dt or 0, false)
                end
            end
            if Utils ~= nil and Utils.updateScrollers ~= nil then
                if self.cutterTurnedOnScrollers ~= nil then
                    Utils.updateScrollers(self.cutterTurnedOnScrollers, dt or 0, false)
                end
                if cutterSpec.cutterTurnedOnScrollers ~= nil and cutterSpec.cutterTurnedOnScrollers ~= self.cutterTurnedOnScrollers then
                    Utils.updateScrollers(cutterSpec.cutterTurnedOnScrollers, dt or 0, false)
                end
            end
        elseif rhmCutterSpec._nativeReelStopped and not isClogged then
            local shouldRestart = self.getIsTurnedOn ~= nil and self:getIsTurnedOn()
            if shouldRestart then
                if self.onStartReel ~= nil then
                    self:onStartReel()
                end
                if self.reelStarted ~= nil then self.reelStarted = true end
                if cutterSpec.reelStarted ~= nil then cutterSpec.reelStarted = true end
            else
                if self.onStopReel ~= nil then
                    self:onStopReel()
                end
                if self.reelStarted ~= nil then self.reelStarted = false end
                if cutterSpec.reelStarted ~= nil then cutterSpec.reelStarted = false end
            end
            rhmCutterSpec._nativeReelStopped = false
        end
    end

    -- Control visible crop motion effects on cutter bar & feeder pickup
    if cutterSpec.cutterEffects ~= nil then
        if isReversing and g_effectManager ~= nil and cutterSpec.lastValidInputFruitType ~= nil and cutterSpec.lastValidInputFruitType ~= FruitType.UNKNOWN then
            g_effectManager:startEffects(cutterSpec.cutterEffects)
            rhmCutterSpec._startedReverseCutterFx = true
        elseif rhmCutterSpec._startedReverseCutterFx and not isReversing and g_effectManager ~= nil then
            g_effectManager:stopEffects(cutterSpec.cutterEffects)
            rhmCutterSpec._startedReverseCutterFx = false
        end
        updateCutterEffectsMotion(cutterSpec.cutterEffects, isClogged, isReversing)
    end
    if cutterSpec.fillEffects ~= nil then
        updateCutterEffectsMotion(cutterSpec.fillEffects, isClogged, isReversing)
    end
end

function rhm_Cutter:onLoad(savegame)
    local spec = self.spec_rhm_Cutter
    if spec == nil then
        spec = {}
        self.spec_rhm_Cutter = spec
    end

    spec.originalTurnedOnByAttacherVehicle = true
    if self.spec_turnOnVehicle ~= nil then
        spec.originalTurnedOnByAttacherVehicle = self.spec_turnOnVehicle.turnedOnByAttacherVehicle
    end
end

function rhm_Cutter:onPostLoad(savegame)
    self:updateIndependentLaunchState()
end

function rhm_Cutter:onPostAttach(attacherVehicle, inputJointDescIndex, jointDescIndex)
    self:updateIndependentLaunchState(attacherVehicle)
end

function rhm_Cutter:onPreDetach(attacherVehicle, implement)
    local spec = self.spec_rhm_Cutter
    if spec and self.spec_turnOnVehicle and spec.originalTurnedOnByAttacherVehicle ~= nil then
        self.spec_turnOnVehicle.turnedOnByAttacherVehicle = spec.originalTurnedOnByAttacherVehicle
    end
end

function rhm_Cutter:updateIndependentLaunchState(attacherVehicle)
    local spec = self.spec_rhm_Cutter
    if not spec or not self.spec_turnOnVehicle then
        return
    end

    local isIndependentLaunchEnabled = false
    if g_realisticHarvestManager and g_realisticHarvestManager.settings then
        isIndependentLaunchEnabled = g_realisticHarvestManager.settings.enableIndependentLaunch == true
    end

    local carrier = attacherVehicle or (self.getRootVehicle and self:getRootVehicle())
    local isAttachedToCombine = false
    if carrier and carrier.spec_rhm_Combine ~= nil then
        isAttachedToCombine = true
    elseif self.getAttacherVehicle and self:getAttacherVehicle() then
        local directAttacher = self:getAttacherVehicle()
        if directAttacher and (directAttacher.spec_rhm_Combine ~= nil or (directAttacher.getRootVehicle and directAttacher:getRootVehicle().spec_rhm_Combine ~= nil)) then
            isAttachedToCombine = true
        end
    end
    if not isAttachedToCombine and carrier and RHM_Api and RHM_Api.findCombine then
        local combine = RHM_Api.findCombine(carrier)
        if combine ~= nil and (combine.spec_rhm_Combine ~= nil or combine.spec_combine ~= nil) then
            isAttachedToCombine = true
        end
    end

    if isIndependentLaunchEnabled and isAttachedToCombine then
        self.spec_turnOnVehicle.turnedOnByAttacherVehicle = false
    else
        if spec.originalTurnedOnByAttacherVehicle ~= nil then
            self.spec_turnOnVehicle.turnedOnByAttacherVehicle = spec.originalTurnedOnByAttacherVehicle
        end
    end
end

rhm_log("RHM [Cutter]: RHM: rhm_Cutter specialization loaded!")

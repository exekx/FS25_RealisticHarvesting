-- EN: Input utility for managing camera rotation and zoom states during GUI interactions.
-- UA: Утиліта вводу для керування обертанням та масштабуванням камери під час взаємодії з GUI.
RHMInputUtil = {}

-- EN: Enable or disable camera rotation for all cameras on a vehicle.
--     Saves original isRotatable states and restores them cleanly.
--     Does NOT destroy camera.rotSpeed, preserving automated driver control states.
--     Strictly preserves allowTranslation = false on indoor cameras to prevent building collision clipping.
-- UA: Вмикає або вимикає обертання камери для всіх камер транспортного засобу.
--     Зберігає оригінальні стани isRotatable та чисто їх відновлює.
--     НЕ обнуляє camera.rotSpeed, зберігаючи коректний стан зовнішніх систем керування.
--     Суворо підтримує allowTranslation = false для салонних камер для запобігання колізійному зсуву в будівлях.
function RHMInputUtil.setCameraRotation(vehicle, enableRotation, savedRotatableInfo)
    if not vehicle or not vehicle.spec_enterable or not vehicle.spec_enterable.cameras then
        return
    end

    if not savedRotatableInfo then
        savedRotatableInfo = {}
    end

    for _, camera in pairs(vehicle.spec_enterable.cameras) do
        local isIndoor = camera.isInside or (camera.rotateNode ~= nil and camera.rotateNode == camera.cameraNode)
        if enableRotation then
            -- EN: Restore original rotation state (or default true)
            -- UA: Відновлюємо оригінальний стан обертання (або true за замовчуванням)
            local isRotatable = true
            if savedRotatableInfo[camera] ~= nil then
                isRotatable = savedRotatableInfo[camera]
            end
            camera.isRotatable = isRotatable

            -- EN: Ensure indoor cameras NEVER have allowTranslation enabled (prevents building collision glitch)
            -- UA: Гарантуємо, що салонні камери НІКОЛИ не мають увімкненого allowTranslation (запобігає багу колізій у будівлях)
            if isIndoor then
                camera.allowTranslation = false
                if camera.origTransX ~= nil and camera.origTransY ~= nil and camera.origTransZ ~= nil then
                    camera.transX = camera.origTransX
                    camera.transY = camera.origTransY
                    camera.transZ = camera.origTransZ
                    if camera.cameraNode and entityExists(camera.cameraNode) then
                        setTranslation(camera.cameraNode, camera.origTransX, camera.origTransY, camera.origTransZ)
                    end
                end
            else
                camera.allowTranslation = true
            end
            camera.allowZoom = true

            -- EN: Safety recover rotSpeed in case it was zeroed by older versions
            -- UA: Безпечне відновлення rotSpeed якщо він був обнулений старими версіями
            if camera.rotSpeed == 0 and camera._rhmSavedRotSpeed then
                camera.rotSpeed = camera._rhmSavedRotSpeed
                camera._rhmSavedRotSpeed = nil
            end
            savedRotatableInfo[camera] = nil
        else
            -- EN: Save previous state and disable rotation cleanly
            -- UA: Зберігаємо попередній стан та чисто вимикаємо обертання
            if savedRotatableInfo[camera] == nil then
                savedRotatableInfo[camera] = camera.isRotatable
            end
            camera.isRotatable = false
        end
    end

    return savedRotatableInfo
end

-- EN: Enable or disable camera zoom (mouse wheel) for all cameras on a vehicle.
-- UA: Вмикає або вимикає масштабування камери (колесо миші) для всіх камер транспортного засобу.
function RHMInputUtil.setCameraZoom(vehicle, enableZoom, savedZoomInfo)
    if not vehicle or not vehicle.spec_enterable or not vehicle.spec_enterable.cameras then
        return
    end

    if not savedZoomInfo then
        savedZoomInfo = {}
    end

    for _, camera in pairs(vehicle.spec_enterable.cameras) do
        local isIndoor = camera.isInside or (camera.rotateNode ~= nil and camera.rotateNode == camera.cameraNode)
        if isIndoor then
            -- EN: Indoor cameras never allow translation or translation-based zoom
            -- UA: Салонні камери ніколи не мають трансляції або зуму на основі зміщення
            camera.allowTranslation = false
        else
            if enableZoom then
                local allowTrans = true
                if savedZoomInfo[camera] ~= nil then
                    allowTrans = savedZoomInfo[camera]
                end
                camera.allowTranslation = allowTrans
                camera.allowZoom = true
                savedZoomInfo[camera] = nil
            else
                if savedZoomInfo[camera] == nil then
                    savedZoomInfo[camera] = (camera.allowTranslation ~= nil) and camera.allowTranslation or true
                end
                camera.allowTranslation = false
                camera.allowZoom = false
            end
        end
    end

    return savedZoomInfo
end

rhm_log("RHM [UI]: [OK] RHMInputUtil loaded")

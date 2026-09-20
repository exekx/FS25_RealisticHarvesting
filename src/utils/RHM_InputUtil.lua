-- EN: Input utility for managing camera rotation and zoom states during GUI interactions.
-- UA: Утиліта вводу для керування обертанням та масштабуванням камери під час взаємодії з GUI.
RHMInputUtil = {}

-- EN: Enable or disable camera rotation for all cameras on a vehicle.
--     Saves original isRotatable states and restores them cleanly.
--     Does NOT destroy camera.rotSpeed, preserving third-party automated driver control states.
-- UA: Вмикає або вимикає обертання камери для всіх камер транспортного засобу.
--     Зберігає оригінальні стани isRotatable та чисто їх відновлює.
--     НЕ обнуляє camera.rotSpeed, зберігаючи коректний стан зовнішніх систем керування.
function RHMInputUtil.setCameraRotation(vehicle, enableRotation, savedRotatableInfo)
    if not vehicle or not vehicle.spec_enterable or not vehicle.spec_enterable.cameras then
        return
    end

    if not savedRotatableInfo then
        savedRotatableInfo = {}
    end

    for _, camera in pairs(vehicle.spec_enterable.cameras) do
        if enableRotation then
            -- EN: Restore original rotation state (or default true)
            -- UA: Відновлюємо оригінальний стан обертання (або true за замовчуванням)
            local isRotatable = true
            if savedRotatableInfo[camera] ~= nil then
                isRotatable = savedRotatableInfo[camera]
            end
            camera.isRotatable = isRotatable
            camera.allowTranslation = true
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
        if enableZoom then
            camera.allowZoom = true
            savedZoomInfo[camera] = nil
        else
            if savedZoomInfo[camera] == nil then
                savedZoomInfo[camera] = camera.allowZoom
            end
            camera.allowZoom = false
        end
    end

    return savedZoomInfo
end

rhm_log("RHM [UI]: [OK] RHMInputUtil loaded")

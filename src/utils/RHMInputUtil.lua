---@class RHMInputUtil
-- EN: Input utility for managing camera rotation and zoom states during HUD drag or GUI interactions.
-- UA: Утиліта вводу для керування обертанням та масштабуванням камери під час перетягування HUD або взаємодії з GUI.
RHMInputUtil = {}

-- EN: Enable or disable camera rotation for all cameras on a vehicle.
--     Used to block camera rotation when the mouse cursor is shown (e.g. during HUD dragging).
--     Saves original camera states to a table so they can be restored later.
-- UA: Вмикає або вимикає обертання камери для всіх камер транспортного засобу.
--     EN: Used to block the camera while showing the mouse cursor (e.g., when dragging the HUD).
--     UA: Використовується для блокування камери під час показу курсору миші (наприклад, при перетягуванні HUD).
--     EN: Saves original camera states into a table so they can be restored later.
--     UA: Зберігає оригінальні стани камер у таблицю, щоб їх можна було відновити пізніше.
---@param vehicle table EN: The vehicle whose cameras to control / UA: Транспортний засіб з камерами
---@param enableRotation boolean EN: True to enable rotation, false to disable / UA: True — увімкнути, false — вимкнути
---@param savedRotatableInfo table|nil EN: Table to store original camera states / UA: Таблиця для збереження оригінальних станів камер
function RHMInputUtil.setCameraRotation(vehicle, enableRotation, savedRotatableInfo)
    if not vehicle or not vehicle.spec_enterable then
        return
    end

    if not savedRotatableInfo then
        savedRotatableInfo = {}
    end

    for i, camera in pairs(vehicle.spec_enterable.cameras) do
        if enableRotation then
            -- EN: Restore original rotation setting if it was saved previously.
            -- UA: Відновлюємо оригінальне налаштування обертання, якщо воно було збережено.
            local isRotatable = savedRotatableInfo[camera]
            if isRotatable ~= nil then
                camera.isRotatable = isRotatable
                print(string.format("RHM: Camera %d restore isRotatable: %s", i, tostring(isRotatable)))
            else
                camera.isRotatable = true
            end
        else
            -- EN: Save original rotation setting and disable camera rotation.
            -- UA: Зберігаємо оригінальне налаштування обертання і вимикаємо обертання камери.
            print(string.format("RHM: Camera %d disable rotation, current: %s", i, tostring(camera.isRotatable)))
            savedRotatableInfo[camera] = camera.isRotatable
            camera.isRotatable = false
        end
    end

    return savedRotatableInfo
end

-- EN: Enable or disable camera zoom (mouse wheel) for all cameras on a vehicle.
--     Used to block camera zoom when the GUI needs to capture scroll wheel events.
--     Saves original zoom states to a table so they can be restored later.
-- UA: Вмикає або вимикає масштабування камери (колесо миші) для всіх камер транспортного засобу.
--     EN: Used to block zoom when the GUI needs to intercept scrolling.
--     UA: Використовується для блокування зуму, коли GUI потребує перехоплення прокрутки.
--     EN: Saves original states to a table for later restoration.
--     UA: Зберігає оригінальні стани у таблицю для подальшого відновлення.
---@param vehicle table EN: The vehicle whose cameras to control / UA: Транспортний засіб з камерами
---@param enableZoom boolean EN: True to enable zoom, false to disable / UA: True — увімкнути, false — вимкнути
---@param savedZoomInfo table|nil EN: Table to store original camera zoom states / UA: Таблиця для збереження оригінальних станів зуму
function RHMInputUtil.setCameraZoom(vehicle, enableZoom, savedZoomInfo)
    if not vehicle or not vehicle.spec_enterable then
        return
    end

    if not savedZoomInfo then
        savedZoomInfo = {}
    end

    for i, camera in pairs(vehicle.spec_enterable.cameras) do
        if enableZoom then
            -- EN: Restore original zoom (translation) state if it was saved.
            -- UA: Відновлюємо оригінальний стан масштабування, якщо він був збережений.
            local allowTranslation = savedZoomInfo[camera]
            if allowTranslation ~= nil then
                camera.allowTranslation = allowTranslation
                print(string.format("RHM: Camera %d restore allowTranslation: %s", i, tostring(allowTranslation)))
            else
                camera.allowTranslation = true
            end
        else
            -- EN: Save original zoom state and disable camera zoom.
            -- UA: Зберігаємо оригінальний стан масштабування і вимикаємо зум камери.
            print(string.format("RHM: Camera %d disable zoom, current: %s", i, tostring(camera.allowTranslation)))
            savedZoomInfo[camera] = camera.allowTranslation
            camera.allowTranslation = false
        end
    end

    return savedZoomInfo
end

print("[OK] RHMInputUtil loaded")

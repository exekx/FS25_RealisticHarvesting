---@class RHMInputUtil
RHMInputUtil = {}

--- Enable/disable camera rotation when a vehicle is selected. 
--- Disables camera rotation per mouse when we enable the mouse cursor so it can be used to click controls on a GUI
---@param vehicle table The vehicle whose cameras to control
---@param enableRotation boolean True to enable rotation, false to disable
---@param savedRotatableInfo table|nil Optional table to save/restore original camera rotation states
function RHMInputUtil.setCameraRotation(vehicle, enableRotation, savedRotatableInfo)
    if not vehicle or not vehicle.spec_enterable then
        return
    end
    
    if not savedRotatableInfo then
        savedRotatableInfo = {}
    end
    
    for i, camera in pairs(vehicle.spec_enterable.cameras) do
        if enableRotation then
            -- Restore original setting if exists
            local isRotatable = savedRotatableInfo[camera]
            if isRotatable ~= nil then
                camera.isRotatable = isRotatable
                print(string.format("RHM: Camera %d restore isRotatable: %s", i, tostring(isRotatable)))
            else
                camera.isRotatable = true
            end
        else
            -- Save original rotatable setting and disable
            print(string.format("RHM: Camera %d disable rotation, current: %s", i, tostring(camera.isRotatable)))
            savedRotatableInfo[camera] = camera.isRotatable
            camera.isRotatable = false
        end
    end
    
    return savedRotatableInfo
end

--- Enable/disable camera zoom/translation when GUI is active
--- Disables camera zoom via mouse wheel when GUI needs wheel events
---@param vehicle table The vehicle whose cameras to control
---@param enableZoom boolean True to enable zoom, false to disable
---@param savedZoomInfo table|nil Optional table to save/restore original camera zoom states
function RHMInputUtil.setCameraZoom(vehicle, enableZoom, savedZoomInfo)
    if not vehicle or not vehicle.spec_enterable then
        return
    end
    
    if not savedZoomInfo then
        savedZoomInfo = {}
    end
    
    for i, camera in pairs(vehicle.spec_enterable.cameras) do
        if enableZoom then
            -- Restore original setting if exists
            local allowTranslation = savedZoomInfo[camera]
            if allowTranslation ~= nil then
                camera.allowTranslation = allowTranslation
                print(string.format("RHM: Camera %d restore allowTranslation: %s", i, tostring(allowTranslation)))
            else
                camera.allowTranslation = true
            end
        else
            -- Save original zoom setting and disable
            print(string.format("RHM: Camera %d disable zoom, current: %s", i, tostring(camera.allowTranslation)))
            savedZoomInfo[camera] = camera.allowTranslation
            camera.allowTranslation = false
        end
    end
    
    return savedZoomInfo
end

print("[OK] RHMInputUtil loaded")

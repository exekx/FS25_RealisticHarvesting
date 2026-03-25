-- EN: rhm_Cutter — overrides the Cutter.onLoad function to support independent header (header)
--     launch from the combine. When independent launch is enabled, prevents the cutter from
--     starting automatically when the combine's thresher is turned on.
-- UA: rhm_Cutter — перевизначає функцію Cutter.onLoad для підтримки роздільного запуску жатки
--     від комбайна. Коли роздільний запуск увімкнено, запобігає автоматичному увімкненню жатки
--     при включенні молотарки комбайна.

rhm_Cutter = {}

-- EN: Override of Cutter.onLoad — called when any cutter (header) is loaded.
--     If the independent launch feature is active in settings, disables the flag
--     that makes the cutter turn on automatically via the attacher vehicle (combine).
-- UA: Перевизначення Cutter.onLoad — викликається при завантаженні будь-якої жатки.
--     Якщо функція роздільного запуску активна в налаштуваннях, вимикає прапорець,
--     що змушує жатку автоматично увімкнутись через причіпний транспорт (комбайн).
function rhm_Cutter:onLoad(superFunc, savegame)
    superFunc(self, savegame)

    -- EN: Check if independent header launch is enabled in the global settings.
    -- UA: Перевіряємо чи увімкнена функція роздільного запуску в глобальних налаштуваннях.
    local isIndependentLaunchEnabled = false
    if g_realisticHarvestManager and g_realisticHarvestManager.settings then
        isIndependentLaunchEnabled = g_realisticHarvestManager.settings.enableIndependentLaunch
    end

    local spec = self.spec_turnOnVehicle
    if spec and isIndependentLaunchEnabled then
        -- EN: CRITICAL: Disable auto-start via the attacher vehicle.
        --     Without this, the header would automatically start when the combine starts,
        --     bypassing the independent launch feature entirely.
        -- UA: КРИТИЧНО: Вимикаємо автозапуск через причіпний транспорт.
        --     Без цього жатка автоматично запускалася б разом з комбайном,
        --     повністю обходячи функцію роздільного запуску.
        spec.turnedOnByAttacherVehicle = false
    end
end

-- EN: Apply the onLoad override to all Cutter instances in the game.
-- UA: Застосовуємо перевизначення onLoad до всіх екземплярів Cutter у грі.
Cutter.onLoad = Utils.overwrittenFunction(Cutter.onLoad, rhm_Cutter.onLoad)

rhm_log("RHM [Combine]: RHM: rhm_Cutter.lua loaded!")

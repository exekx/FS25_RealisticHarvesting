-- EN: Centralized debug logging system for the Realistic Harvesting mod.
--     All output is gated behind the FS25 Developer Warnings setting (rhm_log in main.lua).
--     No per-module toggles or master switch — devWarnings controls everything.
-- UA: Централізована система дебаг-логів для мода Realistic Harvesting.
--     Весь вивід захищений налаштуванням Developer Warnings у FS25 (rhm_log у main.lua).
--     Немає перемикачів по модулях або головного вимикача — devWarnings керує всім.
RHM_Debug = {}

-- EN: Prints a debug message tagged with the module name.
--     Output is only visible when FS25 Developer Warnings (devWarnings) is enabled.
-- UA: Виводить дебаг-повідомлення з тегом модуля.
--     Вивід видимий лише коли увімкнено Developer Warnings у FS25 (devWarnings).
function RHM_Debug.log(moduleName, message)
    rhm_log(string.format("RHM [%s]: %s", moduleName, message))
end

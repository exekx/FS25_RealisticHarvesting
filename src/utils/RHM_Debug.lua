---@class RHM_Debug
--- Система централізованого управління дебаг-логами для Realistic Harvesting
RHM_Debug = {}

-- Головний вимикач. Якщо false - всі модулі мовчать, незалежно від їхніх індивідуальних налаштувань.
RHM_Debug.MASTER_ENABLE = true

-- Налаштування по окремих модулях:
RHM_Debug.Modules = {
    -- Основний менеджер (завантаження гри, HUD, ініціалізація)
    Manager = false,
    
    -- Логіка комбайна (відбір культур, обмеження швидкості)
    Combine = true,
    
    -- Калькулятор навантаження (Yield, Crop types, Load % і математика)
    LoadCalculator = true,
    
    -- Пам'ять комбайна (зміна налаштувань вентилятора, ротора і тд)
    CombineMemory = false,
    
    -- Мережеві події (обмін пакетами між сервером та клієнтом)
    Network = false,
    
    -- Інтерфейс меню (відкриття налаштувань, кліки)
    UI = false,
}

--- Перевіряє чи дозволено виведення логів для конкретного модуля
---@param moduleName string Назва модуля (наприклад, "Combine")
---@return boolean
function RHM_Debug.isEnabled(moduleName)
    if not RHM_Debug.MASTER_ENABLE then
        return false
    end
    
    local isEnabled = RHM_Debug.Modules[moduleName]
    if isEnabled == nil then
        return false -- Якщо модуль не знайдено, лог вимкнено
    end
    
    return isEnabled
end

--- Функція для зручного виведення дебагу (опціонально)
---@param moduleName string
---@param message string
function RHM_Debug.log(moduleName, message)
    if RHM_Debug.isEnabled(moduleName) then
        print(string.format("RHM [%s]: %s", moduleName, message))
    end
end

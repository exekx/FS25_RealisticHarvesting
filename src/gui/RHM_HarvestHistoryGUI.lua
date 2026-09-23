-- ============================================================================
-- RHM_HarvestHistoryGUI.lua
-- Realistic Harvesting Mod - Fullscreen Native TabbedMenu Controller
-- ============================================================================
-- Technical architecture:
--   Inherits from GIANTS Engine 10 native TabbedMenu.
--   Provides a full-screen, gamepad/mouse/keyboard compatible multi-tab UI
--   with complete HUD suppression and zero rendering conflicts.
-- ============================================================================

RHM_HarvestHistoryGUI = {}
local HarvestHistoryGUI_mt = Class(RHM_HarvestHistoryGUI, TabbedMenu)

function RHM_HarvestHistoryGUI.new(messageCenter, l18n, inputManager)
    local self = TabbedMenu.new(nil, HarvestHistoryGUI_mt, messageCenter, l18n, inputManager)
    self.messageCenter = messageCenter
    self.l18n = l18n
    self.inputManager = g_inputBinding
    return self
end

function RHM_HarvestHistoryGUI:onGuiSetupFinished()
    RHM_HarvestHistoryGUI:superClass().onGuiSetupFinished(self)
    self.clickBackCallback = self:makeSelfCallback(self.onButtonBack)

    if self.pageTrip then self.pageTrip:initialize() end
    if self.pageAnalytics then self.pageAnalytics:initialize() end
    if self.pageFleet then self.pageFleet:initialize() end

    self:setupPages()
    self:setupMenuButtonInfo()
end

function RHM_HarvestHistoryGUI:setupPages()
    local pages = {
        { self.pageTrip, 'gui.icon_ingameMenu_prices' },
        { self.pageAnalytics, 'gui.icon_ingameMenu_finances' },
        { self.pageFleet, 'gui.icon_ingameMenu_calendar' }
    }

    for idx, thisPage in ipairs(pages) do
        local page, sliceId = unpack(thisPage)
        if page then
            self:registerPage(page, idx)
            self:addPageTab(page, nil, nil, sliceId)
        end
    end

    self:rebuildTabList()
end

function RHM_HarvestHistoryGUI:setupMenuButtonInfo()
    local onButtonBackFunction = self.clickBackCallback

    self.defaultMenuButtonInfo = {
        {
            inputAction = InputAction.MENU_BACK,
            text = g_i18n:getText("button_back"),
            callback = onButtonBackFunction
        }
    }

    self.defaultMenuButtonInfoByActions[InputAction.MENU_BACK] = self.defaultMenuButtonInfo[1]
    self.defaultButtonActionCallbacks = {
        [InputAction.MENU_BACK] = onButtonBackFunction,
    }
end

function RHM_HarvestHistoryGUI:onOpen()
    RHM_HarvestHistoryGUI:superClass().onOpen(self)
    self.isOpen = true
    self:refreshCurrentPage()
end

function RHM_HarvestHistoryGUI:onClose()
    self.isOpen = false
    RHM_HarvestHistoryGUI:superClass().onClose(self)
end

function RHM_HarvestHistoryGUI:onClickBack()
    self:exitMenu()
end

function RHM_HarvestHistoryGUI:onButtonBack()
    self:exitMenu()
end

function RHM_HarvestHistoryGUI:exitMenu()
    g_gui:showGui("")
end

function RHM_HarvestHistoryGUI:getCurrentPage()
    if self.currentPage ~= nil and type(self.currentPage) == "table" then
        return self.currentPage
    end
    if self.pages and self.currentPageIndex and self.pages[self.currentPageIndex] then
        local entry = self.pages[self.currentPageIndex]
        return entry.page or entry
    end
    if self.pageTrip and self.pageTrip.getIsVisible and self.pageTrip:getIsVisible() then
        return self.pageTrip
    elseif self.pageAnalytics and self.pageAnalytics.getIsVisible and self.pageAnalytics:getIsVisible() then
        return self.pageAnalytics
    elseif self.pageFleet and self.pageFleet.getIsVisible and self.pageFleet:getIsVisible() then
        return self.pageFleet
    end
    return nil
end

function RHM_HarvestHistoryGUI:refreshCurrentPage()
    local currentPage = self:getCurrentPage()
    if currentPage then
        if currentPage.updateData then
            currentPage:updateData()
        elseif currentPage.updateTables then
            currentPage:updateTables()
        elseif currentPage.updateControls then
            currentPage:updateControls()
        end
    end
end

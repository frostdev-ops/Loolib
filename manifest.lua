-- Loolib/manifest.lua
-- Build-time module family definitions and preset configurations.
-- Evaluated by package.sh using standalone Lua (lua 5.1+).
-- No WoW APIs, no require(), pure data only.

return {
    families = {
        -- CORE families (core=true, always included regardless of preset)
        -- These match exactly the 27 files currently in loolib.toc
        { id = "libstub",   core = true,  deps = {},                                  files = { "LibStub/LibStub.lua" } },
        { id = "core",      core = true,  deps = { "libstub" },                       files = { "Core/Loolib.lua", "Core/Mixin.lua", "Core/TableUtil.lua", "Core/FunctionUtil.lua", "Core/Constants.lua", "Core/Timer.lua", "Core/Addon.lua", "Core/Compat.lua", "Compat/GlobalBridge.lua" } },
        { id = "events",    core = true,  deps = { "core" },                          files = { "Events/CallbackRegistry.lua", "Events/EventRegistry.lua", "Events/EventFrame.lua", "Events/Bucket.lua" } },
        { id = "data",      core = true,  deps = { "core" },                          files = { "Data/DataProvider.lua", "Data/SavedVariables.lua" } },
        { id = "comm",      core = true,  deps = { "core" },                          files = { "Comm/Serializer.lua", "Comm/Compressor.lua", "Comm/AddonMessage.lua" } },
        { id = "config",    core = true,  deps = { "core", "events", "data" },        files = { "Config/ConfigTypes.lua", "Config/ConfigRegistry.lua", "Config/ConfigCmd.lua", "Config/ProfileOptions.lua", "Config/ConfigDialog.lua", "Config/Config.lua" } },
        { id = "ui-dialog", core = true,  deps = { "core" },                          files = { "UI/Templates/Dialog.lua" } },
        { id = "utils",     core = true,  deps = { "core" },                          files = { "Utils/SecretUtil.lua" } },

        -- OPTIONAL families (core=false, selected by preset)
        { id = "core-ext",      core = false, deps = { "core" },                                            files = { "Core/TempTable.lua", "Core/Console.lua", "Core/Hook.lua", "Core/Locale.lua" } },
        { id = "data-ext",      core = false, deps = { "core", "data" },                                    files = { "Data/Migration.lua", "Data/ProfileManager.lua" } },
        { id = "debug",         core = false, deps = { "core" },                                            files = { "Debug/Logger.lua", "Debug/Dump.lua", "Debug/ErrorHandler.lua" } },
        { id = "utils-ext",     core = false, deps = { "core" },                                            files = { "Utils/Transmog.lua" } },
        { id = "ui-pool",       core = false, deps = { "core" },                                            files = { "UI/Pool/PoolResetters.lua", "UI/Pool/ObjectPool.lua", "UI/Pool/FramePool.lua", "UI/Pool/PoolCollection.lua" } },
        { id = "ui-core",       core = false, deps = { "core" },                                            files = { "UI/Core/AnchorUtil.lua", "UI/Core/FrameUtil.lua", "UI/Core/RegionUtil.lua", "UI/Core/WindowUtil.lua" } },
        { id = "ui-theme",      core = false, deps = { "core", "events" },                                  files = { "UI/Theme/ThemeManager.lua", "UI/Theme/ThemeDefault.lua", "UI/Theme/ThemeDark.lua", "UI/Theme/ThemeMinimal.lua" } },
        { id = "ui-layout",     core = false, deps = { "core" },                                            files = { "UI/Layout/LayoutBase.lua", "UI/Layout/LayoutBuilder.lua", "UI/Layout/VerticalLayout.lua", "UI/Layout/HorizontalLayout.lua", "UI/Layout/GridLayout.lua", "UI/Layout/FlowLayout.lua" } },
        { id = "ui-templates",  core = false, deps = { "core", "events", "ui-pool" },                       files = { "UI/Templates/Templates.lua", "UI/Templates/Tooltip.lua", "UI/Templates/Dropdown.lua", "UI/Templates/ColorSwatch.lua", "UI/Templates/ScrollableList.lua", "UI/Templates/TabbedPanel.lua" } },
        { id = "ui-widgets",    core = false, deps = { "core", "events" },                                  files = { "UI/Widgets/WidgetMod.lua", "UI/Widgets/EnhancedDropdown.lua", "UI/Widgets/EnhancedSlider.lua", "UI/Widgets/PopupMenu.lua" } },
        { id = "ui-appearance", core = false, deps = { "core", "events", "ui-theme" },                      files = { "UI/Appearance/Appearance.lua" } },
        { id = "ui-factory",    core = false, deps = { "core", "ui-pool", "ui-core", "ui-theme" },          files = { "UI/Factory/FrameFactory.lua", "UI/Factory/WidgetBuilder.lua" } },
        { id = "ui-dragdrop",   core = false, deps = { "core", "events", "ui-templates" },                  files = { "UI/DragDrop/DragContext.lua", "UI/DragDrop/DraggableMixin.lua", "UI/DragDrop/DragGhost.lua", "UI/DragDrop/DropTargetMixin.lua", "UI/DragDrop/ReorderableMixin.lua" } },
        { id = "ui-note",       core = false, deps = { "core", "events" },                                  files = { "UI/Note/NoteParser.lua", "UI/Note/NoteMarkup.lua", "UI/Note/NoteRenderer.lua", "UI/Note/NoteTimer.lua", "UI/Note/NoteFrame.lua" } },
        { id = "ui-canvas",     core = false, deps = { "core", "events", "ui-note" },                       files = { "UI/Canvas/CanvasElement.lua", "UI/Canvas/CanvasShape.lua", "UI/Canvas/CanvasBrush.lua", "UI/Canvas/CanvasIcon.lua", "UI/Canvas/CanvasImage.lua", "UI/Canvas/CanvasText.lua", "UI/Canvas/CanvasGroup.lua", "UI/Canvas/CanvasSelection.lua", "UI/Canvas/CanvasZoom.lua", "UI/Canvas/CanvasToolbar.lua", "UI/Canvas/CanvasHistory.lua", "UI/Canvas/CanvasSync.lua", "UI/Canvas/CanvasFrame.lua" } },
    },

    presets = {
        minimal  = { description = "Core library only (current default)", families = {} },
        embedded = { description = "Embedded addon baseline", families = {} },
        full     = { description = "All Loolib modules", families = { "core-ext", "data-ext", "debug", "utils-ext", "ui-pool", "ui-core", "ui-theme", "ui-layout", "ui-templates", "ui-widgets", "ui-appearance", "ui-factory", "ui-dragdrop", "ui-note", "ui-canvas" } },
        canvas   = { description = "Canvas drawing with full UI stack", families = { "ui-pool", "ui-core", "ui-theme", "ui-templates", "ui-note", "ui-canvas" } },
    },
}

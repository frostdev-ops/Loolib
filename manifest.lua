-- Loolib/manifest.lua
-- Build-time module family definitions and preset configurations.
-- Evaluated by builder.py (Python 3.8+) or package.sh via standalone Lua (lua 5.1+).
-- No WoW APIs, no require(), pure data only.

return {
    families = {
        -- CORE families (core=true, always included regardless of preset)
        { id = "libstub",   core = true,  deps = {},                                  description = "LibStub versioned library registry",                                              files = { "LibStub/LibStub.lua" } },
        { id = "core",      core = true,  deps = { "libstub" },                       description = "Core framework: mixins, utilities, constants, timers, addon lifecycle, compat",  files = { "Core/Loolib.lua", "Core/Mixin.lua", "Core/TableUtil.lua", "Core/FunctionUtil.lua", "Core/Constants.lua", "Core/Timer.lua", "Core/Addon.lua", "Core/Compat.lua", "Compat/GlobalBridge.lua" } },
        { id = "events",    core = true,  deps = { "core" },                          description = "Event system: CallbackRegistry, EventRegistry, EventFrame, bucket events",       files = { "Events/CallbackRegistry.lua", "Events/EventRegistry.lua", "Events/EventFrame.lua", "Events/Bucket.lua" } },
        { id = "data",      core = true,  deps = { "core", "events" },                description = "Data layer: DataProvider collection type and SavedVariables persistence",        files = { "Data/DataProvider.lua", "Data/SavedVariables.lua" } },
        { id = "comm",      core = true,  deps = { "core" },                          description = "Addon communication: serializer, compressor, addon message transport",           files = { "Comm/Serializer.lua", "Comm/Compressor.lua", "Comm/ExportCodec.lua", "Comm/AddonMessage.lua" } },
        { id = "config",    core = true,  deps = { "core", "events", "data" },        description = "Configuration system: types, registry, slash commands, profiles, dialog",       files = { "Config/ConfigTypes.lua", "Config/ConfigRegistry.lua", "Config/ConfigCmd.lua", "Config/ProfileOptions.lua", "Config/ConfigDialog.lua", "Config/Config.lua" } },
        { id = "ui-dialog", core = true,  deps = { "core" },                          description = "Modal dialog template (StaticPopup replacement)",                                files = { "UI/Templates/Dialog.lua" } },
        { id = "utils",     core = true,  deps = { "core" },                          description = "Core utilities: SecretUtil for sensitive data masking",                          files = { "Utils/SecretUtil.lua" } },

        -- OPTIONAL families (core=false, selected by preset)
        { id = "core-ext",      core = false, deps = { "core" },                                            description = "Core extensions: TempTable pooling, Console output, Hook system, Locale, WindowManager", files = { "Core/TempTable.lua", "Core/Console.lua", "Core/Hook.lua", "Core/Locale.lua", "Core/WindowManager.lua" } },
        { id = "data-ext",      core = false, deps = { "core", "data" },                                    description = "Data extensions: SavedVariables migration system and profile manager",                files = { "Data/Migration.lua", "Data/ProfileManager.lua" } },
        { id = "debug",         core = false, deps = { "core" },                                            description = "Debug tools: structured Logger, Dump inspector, ErrorHandler",                       files = { "Debug/Logger.lua", "Debug/Dump.lua", "Debug/ErrorHandler.lua" } },
        { id = "utils-ext",     core = false, deps = { "core" },                                            description = "Extended utilities: Transmog collection helpers",                                    files = { "Utils/Transmog.lua" } },
        { id = "ui-pool",       core = false, deps = { "core" },                                            description = "Frame pooling: ObjectPool, FramePool, PoolCollection, pool resetters",               files = { "UI/Pool/PoolResetters.lua", "UI/Pool/ObjectPool.lua", "UI/Pool/FramePool.lua", "UI/Pool/PoolCollection.lua" } },
        { id = "ui-core",       core = false, deps = { "core", "ui-theme" },                                description = "UI core utilities: AnchorUtil, FrameUtil, RegionUtil, WindowUtil, StyleUtil",         files = { "UI/Core/AnchorUtil.lua", "UI/Core/FrameUtil.lua", "UI/Core/RegionUtil.lua", "UI/Core/StyleUtil.lua", "UI/Core/WindowUtil.lua" } },
        { id = "ui-theme",      core = false, deps = { "core", "events" },                                  description = "Theme system: ThemeManager, Default/Dark/Minimal themes, color/font helpers",        files = { "UI/Theme/ThemeManager.lua", "UI/Theme/ThemeDefault.lua", "UI/Theme/ThemeDark.lua", "UI/Theme/ThemeMinimal.lua" } },
        { id = "ui-layout",     core = false, deps = { "core" },                                            description = "Layout engine: Vertical, Horizontal, Grid, Flow layouts with fluent builder",        files = { "UI/Layout/LayoutBase.lua", "UI/Layout/LayoutBuilder.lua", "UI/Layout/VerticalLayout.lua", "UI/Layout/HorizontalLayout.lua", "UI/Layout/GridLayout.lua", "UI/Layout/FlowLayout.lua" } },
        { id = "ui-templates",  core = false, deps = { "core", "events", "ui-pool" },                       description = "UI templates: Tooltip, Dropdown, ColorSwatch, ScrollableList, TabbedPanel",          files = { "UI/Templates/Templates.lua", "UI/Templates/Tooltip.lua", "UI/Templates/Dropdown.lua", "UI/Templates/ColorSwatch.lua", "UI/Templates/ScrollableList.lua", "UI/Templates/TabbedPanel.lua" } },
        { id = "ui-widgets",    core = false, deps = { "core", "events" },                                  description = "Enhanced widgets: WidgetMod, EnhancedDropdown, EnhancedSlider, PopupMenu",           files = { "UI/Widgets/WidgetMod.lua", "UI/Widgets/EnhancedDropdown.lua", "UI/Widgets/EnhancedSlider.lua", "UI/Widgets/PopupMenu.lua" } },
        { id = "ui-appearance", core = false, deps = { "core", "events", "ui-theme" },                      description = "Frame appearance system: backdrop, border, and skin application",                    files = { "UI/Appearance/Appearance.lua" } },
        { id = "ui-factory",    core = false, deps = { "core", "ui-pool", "ui-core", "ui-theme" },          description = "Frame factory and widget builder: pooled frame creation with fluent API",             files = { "UI/Factory/FrameFactory.lua", "UI/Factory/WidgetBuilder.lua" } },
        { id = "ui-dragdrop",   core = false, deps = { "core", "events", "ui-templates" },                  description = "Drag-and-drop system: DragContext, DraggableMixin, DragGhost, DropTarget, Reorder",   files = { "UI/DragDrop/DragContext.lua", "UI/DragDrop/DraggableMixin.lua", "UI/DragDrop/DragGhost.lua", "UI/DragDrop/DropTargetMixin.lua", "UI/DragDrop/ReorderableMixin.lua" } },
        { id = "ui-note",       core = false, deps = { "core", "events" },                                  description = "Note markup system: parser, conditional markup, renderer, timers, NoteFrame",        files = { "UI/Note/NoteParser.lua", "UI/Note/NoteMarkup.lua", "UI/Note/NoteRenderer.lua", "UI/Note/NoteTimer.lua", "UI/Note/NoteFrame.lua" } },
        { id = "ui-canvas",     core = false, deps = { "core", "events", "comm", "ui-note" },               description = "Canvas drawing: elements, shapes, brush, icons, images, text, groups, sync, history", files = { "UI/Canvas/CanvasElement.lua", "UI/Canvas/CanvasShape.lua", "UI/Canvas/CanvasBrush.lua", "UI/Canvas/CanvasIcon.lua", "UI/Canvas/CanvasImage.lua", "UI/Canvas/CanvasText.lua", "UI/Canvas/CanvasGroup.lua", "UI/Canvas/CanvasSelection.lua", "UI/Canvas/CanvasZoom.lua", "UI/Canvas/CanvasToolbar.lua", "UI/Canvas/CanvasHistory.lua", "UI/Canvas/CanvasSync.lua", "UI/Canvas/CanvasFrame.lua" } },
    },

    presets = {
        dev      = { description = "Loothing development build (loothing + debug)", families = { "core-ext", "debug" } },
        minimal  = { description = "Core library only (current default)", families = {} },
        embedded = { description = "Embedded addon baseline", families = {} },
        loothing = { description = "Loothing loot council addon runtime requirements", families = { "core-ext", "ui-theme", "ui-core" } },
        full     = { description = "All Loolib modules", families = { "core-ext", "data-ext", "debug", "utils-ext", "ui-pool", "ui-core", "ui-theme", "ui-layout", "ui-templates", "ui-widgets", "ui-appearance", "ui-factory", "ui-dragdrop", "ui-note", "ui-canvas" } },
        canvas   = { description = "Canvas drawing with full UI stack", families = { "ui-pool", "ui-core", "ui-theme", "ui-templates", "ui-note", "ui-canvas" } },
    },
}

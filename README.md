# Loolib

A comprehensive addon library for World of Warcraft 12.0+ (Midnight). Provides reusable UI components, event handling, data persistence, communication utilities, and more via the LibStub pattern.

**Version**: 1.0.0 | **Interface**: 120000 | **License**: MIT

---

## Modules

| Module | Description |
|---|---|
| **Core** | LibStub registration, mixin system, table/function utilities, timers, constants |
| **Events** | CallbackRegistry, EventRegistry, EventFrame, bucketed event batching |
| **Comm** | Addon message transport, serializer, compressor with encoding pipeline |
| **Data** | SavedVariables wrapper, profile manager, data providers, migration helpers |
| **Config** | AceConfig-style configuration system with dialog UI and slash command support |
| **UI/Core** | AnchorUtil, FrameUtil, RegionUtil, WindowUtil |
| **UI/Pool** | Object pools and frame pools with custom resetters |
| **UI/Theme** | Theme manager with Default, Dark, and Minimal themes |
| **UI/Layout** | Vertical, horizontal, grid, and flow layout managers |
| **UI/Factory** | FrameFactory and fluent WidgetBuilder |
| **UI/Widgets** | EnhancedSlider, EnhancedDropdown, PopupMenu, WidgetMod |
| **UI/Templates** | ScrollableList, TabbedPanel, Tooltip, Dialog, Dropdown, ColorSwatch |
| **UI/DragDrop** | Draggable, DropTarget, ReorderableMixin, DragGhost |
| **UI/Note** | Conditional note markup parser, renderer, and frame |
| **UI/Canvas** | Sketch/drawing system with shapes, text, icons, zoom, history, and sync |
| **Utils** | Transmog utilities |
| **Debug** | Logger, error handler, table dumper |

---

## Requirements

- World of Warcraft 12.0+ (Midnight, Interface 120000)
- No external dependencies

---

## Installation

1. Place the `Loolib/` folder in `World of Warcraft/_retail_/Interface/AddOns/`
2. List it as a dependency in your addon's TOC:

```
## Dependencies: Loolib
```

---

## Usage

```lua
local Loolib = LibStub("Loolib")

-- Access a module
local Events = Loolib:GetModule("Events")

-- Register a callback
Events:RegisterCallback("MyEvent", function(data)
    print("received:", data)
end, self)
```

Full documentation for each module is in the [`docs/`](docs/) directory.

---

## License

MIT

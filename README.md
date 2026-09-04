# Simple Power Menu

A compact power menu. It adds a power icon and implements a small native
popover under the bar. That's it.

![Simple Power Menu open beneath the power icon](preview.png)

## Features

- Menu: Screensaver, Sleep, Lock, Restart, and Shut down
- Options: Right-click to toggle actions or drag the grip to reorder them
- Follows the active Omarchy theme and bar position

## Requirements

- Omarchy Quattro with shell-plugin support

There are no external services, network calls, or additional runtime
dependencies. The plugin invokes fixed Omarchy and systemd commands for the
five menu actions.

## Installation

```bash
omarchy plugin add https://github.com/jordanneenan/simple-power-menu.git --enable
```

The manifest places the widget in the right section of the bar by default.
You can move it later with:

```bash
omarchy bar move io.github.jordanneenan.simple-power-menu --section right
```

## Usage

### Run an action

1. Left-click the power icon.
2. Select **Screensaver**, **Sleep**, **Lock**, **Restart**, or **Shut down**.

Only actions enabled in the customization menu appear here. Restart and shut
down take effect immediately after selection.

### Customize the menu

1. Right-click the power icon to open the complete action list.
2. Use the checkbox on the right of each label to show or hide that action in
   the normal left-click menu.
3. Drag the three-line grip on the left of a row to change its position.
4. Keep editing as needed; visibility and order are applied and saved
   immediately.

All five actions are enabled on first install. You can hide every action if you
want an empty menu; right-clicking the icon always reopens the complete list so
you can restore one. The choices persist across Omarchy and computer restarts.

Both menus support the mouse and keyboard: use the up and down arrow keys,
press Enter to activate or toggle the selected item, and press Escape to close.

## Security and behavior

Like all Omarchy shell plugins, Simple Power Menu runs unsandboxed with the
current user's permissions. It executes an action only after the user selects
it. Every executable and argument is a fixed absolute argv entry in the source;
settings cannot supply commands, no shell interprets them, and executable
resolution does not depend on `PATH`.

Each action runs under `/usr/bin/timeout` in its own managed process group with
a 30-second deadline. At the deadline the complete group receives `TERM`, then
`KILL` two seconds later if anything remains. The plugin does not use the
network, request elevated privileges, or run background services.

When the user changes the right-click checklist, the plugin asks Omarchy's
configuration owner to write only the `visibleActions` and `actionOrder` arrays
in this widget's existing bar entry. It does not read or store personal
information.

## Removal

```bash
omarchy plugin remove io.github.jordanneenan.simple-power-menu
```

## Development

Validate a local checkout with:

```bash
omarchy plugin validate .
/usr/lib/qt6/bin/qmllint -I "$OMARCHY_PATH/shell" BarWidget.qml Panel.qml
```

After changing QML, rescan local plugins with:

```bash
omarchy-shell shell rescanPlugins
```

## License

[MIT](LICENSE)

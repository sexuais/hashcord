# Hashcord

Hashcord is the JavaScript client bundle loaded by HashcordTweak in Discord for iOS.

## Build

From this directory, install dependencies and build the bundle:

```sh
bun install
bun run build
```

The build writes `dist/hashcord.js`. Run `bun run serve` to serve the live bundle at `http://localhost:4040/hashcord.js`.

The native loader and Debian package are maintained in the sibling `HashcordTweak` directory. See the repository root README for the complete build and installation workflow.

Hashcord preserves the Bunny, Vendetta, and Pyoncord loader contracts used by existing plugins. Those compatibility identifiers are intentionally unchanged.
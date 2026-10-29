<p align="center">
    <h1 align="center">OwnGoal Stripe</h1>
</p>

OwnGoal Stripe is a cross-compilation *OS bootstrap maintained by OwnGoal Studio for the Relaxin jailbreak. It provides a large set of consistently up-to-date *nix tools cross compiled for Darwin-based platforms, packaged for RootHide on iOS and tvOS.

## Supported platforms

| Build target | Debian architecture | Mach-O architecture |
| --- | --- | --- |
| `iphoneos-arm64-roothide` | `iphoneos-arm64e` | arm64 |
| `appletvos-arm64-roothide` | `appletvos-arm64e` | arm64 |

The `arm64e` suffix in the Debian architecture is RootHide's package-architecture naming. It does not mean the binaries carry an arm64e slice.

Packages retain RootHide compatibility. Ordinary Procursus packages are not interchangeable with them.

## Building

See [docs/building.md](./docs/building.md) for Linux and [docs/building-macos.md](./docs/building-macos.md) for macOS. The `bootstrap` target builds the required packages from source and produces the Bootstrap archive for the selected platform. On Linux, `make repository` incrementally archives the built iOS packages into a local APT source and verifies it. See [docs/adding-a-package.md](./docs/adding-a-package.md) to add a package to the source.

## Contributing

Contributions (Issues or Pull Requests) are welcome. Check out the [contribution guidelines](./CONTRIBUTING.md) before helping out.

## Relationship to Procursus

OwnGoal Stripe is an independent fork of the Procursus build system. The build system, package recipes, and documentation originate with the Procursus Team and the RootHide project; see [Credits](#credits).

## Credits

Build system created by [Diatrus](https://twitter.com/Diatrus) and [Kirb](https://twitter.com/hbkirb). Built better by all our wonderful contributors. Made worth it by people like you!

Thank you to Macstadium for sponsoring us through their open source program!

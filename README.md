### TrinketHotSwap
TrinketHotSwap was built to automatically swap your trinkets based on whether or not they're on cooldown, so that you don't have to think about it. It supports both on-use and proc-based trinkets with an internal cooldown. Partial support for this already exists in both ItemRack and TrinketMenu, however both frequently fail, unlike its predecessors this was developed with a single purpose...

### Setup
Each trinket is currently tracked by a separate instance of the `Trinket Template` WeakAura. You will manually have to fill in the information in the Custom Options tab in order for the WeakAura to work, as per the picture below (which is setup for [Shard of Contempt](https://tbc.wowhead.com/item=34472/shard-of-contempt)). All fields are required.

In order to add more trinkets, simply duplicate the `Trinket Template` and fill in the custom options.

### Features
- Auto-swap on combat drop (PLAYER\_REGEN\_ENABLED event)
- Timer-based out of combat swapping (can be enabled in the custom options of the `Receiver`
- Supports on-use trinkets
- Supports proc-based trinkets

### Gotchas
- Currently only swaps trinkets into your second trinket slot (#14)
- Only works for trinkets that buff you (i.e not trinkets that damage an enemy)
- Priority order field values **MUST** be unique (i.e start at 1, 2, 3 and so on)
- By default will only make a swap when you drop combat

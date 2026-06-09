# Plugin Safety Rules

## NEVER use `marketplace remove` to update a marketplace

`claude plugin marketplace remove` is destructive — it removes the marketplace config AND all
associated `enabledPlugins` entries in settings.json. Running it will unconfigure all 40+ plugins
from that marketplace instantly.

Use this ONLY if you intend to completely remove a marketplace and all its plugins.

### To update a marketplace URL or switch branches:

- Use `claude plugin marketplace update` (non-destructive)
- Or edit the marketplace source in settings.json directly

### If you accidentally run remove:

```bash
git checkout HEAD -- .claude/settings.json
```

Then re-add the marketplace.

## Reference

This rule comes from a real incident: running `marketplace remove` unconfigured every plugin from that marketplace at once.

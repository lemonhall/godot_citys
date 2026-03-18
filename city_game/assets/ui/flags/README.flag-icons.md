# Flag Assets

The country flag assets in `4x3/*.svg` are vendored from [`lipis/flag-icons`](https://github.com/lipis/flag-icons).

- Upstream license: MIT
- Local license copy: `LICENSE.flag-icons.txt`
- Purpose: render deterministic country flag icons in the Godot radio browser instead of relying on platform emoji fallback behavior

The `_unknown.svg` asset is a local fallback placeholder used when a country code does not have a matching upstream flag file.

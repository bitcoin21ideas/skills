# Example: the secret scan stops a commit

Shows Step 2's content scan catching a secret-shaped string inside a staged
file, refusing to print it, and offering remediation *before* anything is
committed.

## Starting state

Something is already staged:

```
$ git diff --cached --stat
 config/settings.json | 3 +++
```

The staged diff adds:

```json
"apiKey": "AKIA1234567890ABCDEF"
```

## What the skill does

The Step 2 scan runs over the staged diff and matches the AWS access-key-ID
pattern (`AKIA…`). The skill **does not print the value**. It reports the hit by
location and pattern only, and puts the commit on hold:

> ⚠️ Possible secret in `config/settings.json:14` — matched pattern `AKIA…`
> (AWS access key ID). I won't print the value. Before committing, pick one:
>
> 1. Move it to an env var / ignored config (preferred)
> 2. Replace with `<REDACTED>` (docs only, never source)
> 3. Override after explicit confirmation
>
> Commit is on hold until this is resolved.

No commit happens until you choose. This is why the skill scans the **diff**, not
just filenames: a real key pasted into an otherwise-ordinary tracked file is the
most common way secrets leak into history.

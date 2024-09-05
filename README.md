# An adequately-built, fast LookML parser

Created without knowledge of parsers or the language its written in, this parser has only one goal: be faster than lkml. 

[Read More](https://alhan.co/g/zig-lookml-parser)

## Usage

Assuming you have Zig installed, build the zig executable:
```bash
zig build-exe main.zig -O ReleaseFast
```

Use it inside of Python:
```python
import json
import subprocess

view_as_json = subprocess.check_output(["./main", "customer.view.lkml"]).decode('utf-8')
view_as_dict = json.loads(view_as_json)
```

## What's missing today

- Testing
- Edge case handling
- Parametrization
- Advanced features
- Ability to handle files other than view files



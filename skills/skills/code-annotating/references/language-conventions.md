# Language Conventions

Write comments in the standard documentation form of each language:

| Language | Class/type level | Method/function level | Field level | Line level |
|---|---|---|---|---|
| Java | Javadoc `/** */` | Javadoc with `@param` / `@return` / `@throws` | Field Javadoc | `//` |
| Python | Class docstring | Function docstring with params/returns/raises — match the project's existing style (Google / NumPy / reST); default to Google style if none | Attribute comments | `#` |
| Go | godoc `//` above the declaration, starting with the identifier name | same | Struct field `//` | `//` |
| Rust | `///` rustdoc (`//!` for module level) | `///` | Struct field `///` | `//` |
| JS / TS / React / Vue | Component/class JSDoc·TSDoc `/** */` | JSDoc with `@param` / `@returns` | Interface / props property comments | `//` (Vue templates: `<!-- -->` on key blocks, Detailed density only) |
| Other | the language's standard doc-comment convention | same | same | same |

"Field" generalizes across languages: Java field, TS interface property, Go/Rust struct field, Python class attribute, Vue props.

If the project has its own documented comment conventions (e.g. Alibaba Java guidelines), follow them on top of the table above.

Reminder from the main skill rules: never add authorship metadata in any convention — no Javadoc `@author` / `@date`, no `Author:` lines in docstrings, nor equivalents; keep existing authorship tags untouched.

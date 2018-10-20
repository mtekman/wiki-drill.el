## wiki-drill.el

[![MELPA](http://melpa.org/packages/wiki-drill-badge.svg)](http://melpa.org/#/wiki-drill)

Use the Wikipedia summaries from jozefg's [wiki-summary](https://github.com/jozefg/wiki-summary.el) package and generates 
org-drill entries from them.

This exports the functions:

 * `wiki-drill` which will interactively prompt you for a Wikipedia article and inserts into `wiki-drill--file`

By default, the drill sections go into "~/wiki-drill-inputs.org" which acts as an inbox. It is then up to the user to refile the section into the appropriate org file. 
This file location can be overriden by using the `M-x customize-variable`.

The following variables can overridden:

 | Custom Variables | Value | Notes
 |------------------|-------|-------
 | `wiki-drill--file` | "~/wiki-drill-inputs.org" | File where `:drill:`s goes
 | `wiki-drill--custom-clozer` | nil | Custom [clozer types](https://orgmode.org/worg/org-contrib/org-drill.html) 
 | `wiki-drill--binding-clozer-mark` | "C-b" | Mark regions of text binding
 | `wiki-drill--binding-submit` | "C-c C-c" | Submit text binding

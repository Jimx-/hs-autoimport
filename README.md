# hs-autoimport

hs-autoimport is an Emacs package that adds missing import statements automatically for identifiers in Haskell source files.

It looks for modules with the desired symbol on Hoogle and display a list of all candidate modules. An import statement is added after the user selects which module to import.

It can create import statement for the whole module or just import the selected identifier.

![](https://i.imgur.com/REYneG5.gif)

## Installation

Add the following to your `init.el`

```lisp
(add-to-list 'load-path "/path/to/hs-autoimport")
(require 'hs-autoimport)
```

## Commands

`hs-autoimport-import-module` imports the whole module for the identifier at point/in the region.

`hs-autoimport-import-symbol` imports only the identifier at point/in the region.

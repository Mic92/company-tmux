# company-tmux

This package will add a [company](https://company-mode.github.io/) source that completes
keywords with content of tmux panes.

## Usage

```emacs
(require 'company-tmux)
(company-tmux-setup) ; will add company-tmux to company-backends list
```

## Usage in spacemacs

First add it to `dotspacemacs-additional-packages`:

```emacs
   (setq-default dotspacemacs-additional-packages '((company-tmux :location (recipe :fetcher github :repo "Mic92/company-tmux"))))
```

The only reliable way in spacemacs to enable this source globally, that I found,
was to add it to `spacemacs-default-company-backends`.

```emacs
   (setq-default dotspacemacs-configuration-layers '(
     (auto-completion :variables
                      spacemacs-default-company-backends '(company-dabbrev-code company-gtags company-etags company-keywords company-tmux))
   ))
```

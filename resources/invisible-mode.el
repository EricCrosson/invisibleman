;; An extremely minimal minor-mode for Invisible man files

(when (require 'generic-x)
  (define-generic-mode
      'invisible-mode			;name of mode
    '(";")			;comments
    '("do_exit" "prompt" "search" "config" "help_message" "connect"
      "direct" "disconnect" "parsefile" "run_block") ;some keywords
    '(("\"*\""		        .	font-lock-string-face)) ;operators
    '("[.]*auto$")			;default file type
    ;; 'backtrace-mode-hook		;other functions to call
    "A mode to view /var/log/message files with."))

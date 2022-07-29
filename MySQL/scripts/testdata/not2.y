not2:
          '!' { push_deprecated_warn(YYTHD, "!", "NOT"); }
        | NOT2_SYM
        ;

---

not2:

    '!' {
        res = new IR(kNot2, OP3("!", "", ""));
        $$ = res;
    }

    | NOT2_SYM {
        res = new IR(kNot2, OP3("NOT2_SYM", "", ""));
        $$ = res;
    }

;

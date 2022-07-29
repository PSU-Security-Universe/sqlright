opt_set_var_ident_type:
          /* empty */     { $$=OPT_DEFAULT; }
        | PERSIST_SYM '.' { $$=OPT_PERSIST; }
        | PERSIST_ONLY_SYM '.' {$$=OPT_PERSIST_ONLY; }
        | GLOBAL_SYM '.'  { $$=OPT_GLOBAL; }
        | LOCAL_SYM '.'   { $$=OPT_SESSION; }
        | SESSION_SYM '.' { $$=OPT_SESSION; }
         ;
---

opt_set_var_ident_type:

    /* empty */ {
        res = new IR(kOptSetVarIdentType, OP3("", "", ""));
        $$ = res;
    }

    | PERSIST_SYM '.' {
        res = new IR(kOptSetVarIdentType, OP3("PERSIST .", "", ""));
        $$ = res;
    }

    | PERSIST_ONLY_SYM '.' {
        res = new IR(kOptSetVarIdentType, OP3("PERSIST_ONLY .", "", ""));
        $$ = res;
    }

    | GLOBAL_SYM '.' {
        res = new IR(kOptSetVarIdentType, OP3("GLOBAL .", "", ""));
        $$ = res;
    }

    | LOCAL_SYM '.' {
        res = new IR(kOptSetVarIdentType, OP3("LOCAL .", "", ""));
        $$ = res;
    }

    | SESSION_SYM '.' {
        res = new IR(kOptSetVarIdentType, OP3("SESSION .", "", ""));
        $$ = res;
    }

;

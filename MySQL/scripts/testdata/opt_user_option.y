opt_user_option:
          {
            /* empty */
          }
        | USER EQ TEXT_STRING_sys
          {
            Lex->slave_connection.user= $3.str;
          }
        ;

---

opt_user_option:

    {} {
        res = new IR(kOptUserOption, OP3("", "", ""));
        $$ = res;
    }

    | USER EQ TEXT_STRING_sys {
        auto tmp1 = $3;
        res = new IR(kOptUserOption, OP3("USER =", "", ""), tmp1);
        $$ = res;
    }

;

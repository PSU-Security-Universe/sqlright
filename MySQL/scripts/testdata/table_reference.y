table_reference:
          table_factor { $$= $1; }
        | joined_table { $$= $1; }
        | '{' OJ_SYM esc_table_reference '}'
          {
            /*
              The ODBC escape syntax for Outer Join.

              All productions from table_factor and joined_table can be escaped,
              not only the '{LEFT | RIGHT} [OUTER] JOIN' syntax.
            */
            $$ = $3;
          }
        ;

---

table_reference:

    table_factor {
        auto tmp1 = $1;
        res = new IR(kTableReference, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | joined_table {
        auto tmp1 = $1;
        res = new IR(kTableReference, OP3("", "", ""), tmp1);
        $$ = res;
    }

    | '{' OJ_SYM esc_table_reference '}' {
        auto tmp1 = $3;
        res = new IR(kTableReference, OP3("{ OJ", "}", ""), tmp1);
        $$ = res;
    }

;

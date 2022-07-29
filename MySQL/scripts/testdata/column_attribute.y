column_attribute:
        opt_constraint_name check_constraint
          /* See the next branch for [NOT] ENFORCED. */
          {
            $$= NEW_PTN PT_check_constraint_column_attr($1, $2);
          }
        | constraint_enforcement
          /*
            This branch is needed to workaround the need of a lookahead of 2 for
            the grammar:

             { [NOT] NULL | CHECK(...) [NOT] ENFORCED } ...

            Note: the column_attribute_list rule rejects all unexpected
                  [NOT] ENFORCED sequences.
          */
          {
            $$ = NEW_PTN PT_constraint_enforcement_attr($1);
          }
        ;

---

column_attribute:

    opt_constraint_name check_constraint {
        auto tmp1 = $1;
        auto tmp2 = $2;
        res = new IR(kColumnAttribute, OP3("", "", ""), tmp1, tmp2);
        $$ = res;
    }

    | constraint_enforcement {
        auto tmp1 = $1;
        res = new IR(kColumnAttribute, OP3("", "", ""), tmp1);
        $$ = res;
    }

;

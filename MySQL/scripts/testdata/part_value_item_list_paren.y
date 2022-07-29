part_value_item_list_paren:
          '('
          {
            /*
              This empty action is required because it resolves 2 reduce/reduce
              conflicts with an anonymous row expression:

              -> simple_expr:
                        ...
                      | '(' expr ',' expr_list ')'
            */
          }
          part_value_item_list ')'
          {
            $$= NEW_PTN PT_part_value_item_list_semicolon_indexparen($3, @4);
          }
        ;

---

part_value_item_list_paren:

    '(' {} part_value_item_list ')' {
        auto tmp1 = $3;
        res = new IR(kPartValueItemListParen, OP3("(", ")", ""), tmp1);
        $$ = res;
    }

;

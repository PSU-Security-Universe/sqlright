import pytest
from pygments import highlight
from pygments.formatters.terminal256 import Terminal256Formatter
from pygments.lexers import get_lexer_by_name
from pygments.styles import get_style_by_name
from translate import translate


def render_code(code):
    lexer = get_lexer_by_name("c++", stripall=True)
    style = get_style_by_name("paraiso-dark")
    print()
    print(highlight(code, lexer, formatter=Terminal256Formatter(style=style)))


def _test(data, expect):
    actual = translate(data)
    render_code(actual)
    assert expect.strip() == actual.strip()


@pytest.mark.parametrize(
    "statement",
    [
        "sql_statement",
        "part_value_item_list_paren",
        "sp_proc_stmt_statement",
        "standalone_alter_commands",
        "opt_user_option",
        "opt_window_frame_clause",
        "opt_set_var_ident_type",
        "not2",
        "table_reference",
        "column_attribute",
        "window_func_call",
    ],
)
def test_statement(statement):
    testcase = f"testdata/{statement}.y"
    with open(testcase) as f:
        testdata = f.read()
    data, expect = testdata.split("---")

    _test(data, expect)

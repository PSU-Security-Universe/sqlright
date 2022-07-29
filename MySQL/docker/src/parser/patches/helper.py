#!/bin/python3
from pathlib import Path

sql_yacc = Path(__file__).parent / "sql/sql_yacc.yy"

def correct_push_back():
    with open(sql_yacc) as f:
        contents = f.readlines()

    fixed_contents = []
    lineno = 0 
    while (lineno < len(contents)-1):
        line = contents[lineno]
        if "new IR(" not in line:
            fixed_contents.append(line)
            lineno += 1
            continue

        next_line = contents[lineno+1]
        if "ir_vec.push_back" in next_line:
            fixed_contents.append(line)
            fixed_contents.append(next_line)
            lineno += 2
            continue
            
        tmpx = line[line.find("auto")+4: line.find("=")].strip()
        print(lineno, line, "->", next_line, "->", tmpx)

        push_back_stmt = " "*4*2 + f"ir_vec.push_back({tmpx});\n"
        fixed_contents.append(line)
        fixed_contents.append(push_back_stmt)
        fixed_contents.append(next_line)
        lineno += 2

    with open("fixed_sql_yacc.yy", 'w') as f:
        for line in fixed_contents:
            f.write(line)

def main():
    correct_push_back()

if __name__ == "__main__":
    main()
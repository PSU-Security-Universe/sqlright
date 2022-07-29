import os
import re
import sys
import click

def handle_line(line, s):

    expr = r'\b' + r'{}'.format(s) + r'\b'
    line = line.strip()
    if not line.startswith("|"):
        return False, ""

    if re.search(expr, line) == None:
        return False, ""

    print(line)

    if not line.endswith("{"):
        print("------ bad line, should fix it")

    tokens = line.split()
    matched_indices = []
    for index in range(0, len(tokens)):
        token = tokens[index]
        if re.search(expr, token) != None:
            print (index, token)
            matched_indices.append(index)

    return True, matched_indices

@click.command()
@click.option("-i", "--input", default="bison_parser.y")
@click.option("-o", "--output", default="bison_parser_fixed.y")
@click.option("-t", "--token", required=True, type=str)
@click.option("--start-from", required=True, type=int)
def run(input, output, token, start_from):

    matched = False
    matched_indices = []
    with open(input, "r") as infile:
        with open(output, "w") as outfile:
            line_no = 0
            for line in infile:
                line_no += 1
                if line_no < start_from:
                    outfile.write(line)
                else:
                    toremove = []

                    if len(matched_indices) != 0 and "}" in line:
                        print ("unresolved index")
                    for index in matched_indices:
                        tindex = "$" + str(index)
                        if tindex in line:
                            print ("found matched index", line.strip())
                            toremove.append(index)
                            #print("adding", str(index), "to remove list")
                            if "auto tmp" not in line:
                                outfile.write(line)
                            else:
                                createIR = " new IR(kIdentifier, string(" + \
                                        tindex + \
                                        "), kDataFixLater, 0, kFlagUnknown)"
                                line = line.replace(tindex, createIR)
                                print (line)
                                outfile.write(line)
                                outfile.write("free(" + tindex + ");\n")

                    for index in toremove:
                        matched_indices.remove(index)
                        #print("removing $" + str(index))

                    if len(toremove) == 0:
                        outfile.write(line)

                    if len(matched_indices) == 0:
                        matched, matched_indices = handle_line(line, token)


if __name__ == "__main__":
    run()

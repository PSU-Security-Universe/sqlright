import os
import re
import click
import json
import shutil
import subprocess
from pathlib import Path
from loguru import logger


POSTGRE_INSTALL_DIR = Path("/data/liusong/postgres_verify/build")

@click.group()
def cli():
    """Parser CLI for SQLite3."""
    pass


class OracleQuery(object):
    def __init__(self, query: str, result: str = ""):
        self.query = query.strip()
        self.result = result


class OracleQueryGroup(object):
    def __init__(self, first: OracleQuery, second: OracleQuery):
        self.first = first
        self.second = second

    @property
    def is_different_result(self):
        if not self.first.result and not self.second.result:
            return False

        if self.first.result.startswith("Error") and self.second.result.startswith(
            "Error"
        ):
            return False
        
        if ("\n" in self.first.result or "\n" in self.second.result):
            return self.first.result != self.second.result
        
        if self.first.result == "" and self.second.result == "":
            return False
        elif self.first.result != "" and self.second.result == "":
            return True
        elif self.first.result == "" and self.second.result != "":
            return True

        return float(self.first.result) != float(self.second.result)


class MinimizeTarget(object):
    def __init__(
        self,
        database_query: str,
        oracle_queries: OracleQueryGroup,
        buggy_commit="",
        correct_commit="",
    ):
        self.database_query = database_query
        self.oracle_queries = oracle_queries
        self.buggy_commit = buggy_commit
        self.correct_commit = correct_commit

    @property
    def first_oracle(self):
        return self.oracle_queries.first.query

    @property
    def first_query(self):
        return self.database_query + "\n" + self.first_oracle

    @property
    def first_result(self):
        return self.oracle_queries.first.result

    @property
    def second_oracle(self):
        return self.oracle_queries.second.query

    @property
    def second_query(self):
        return self.database_query + "\n" + self.second_oracle

    @property
    def second_result(self):
        return self.oracle_queries.second.result

    @property
    def is_different_result(self):
        return self.oracle_queries.is_different_result

    def dumps(self):
        obj = {
            "database_query": self.database_query,
            "first_result": self.first_result,
            "second_result": self.second_result,
            "first_oracle": self.first_oracle,
            "second_oracle": self.second_oracle,
            "buggy_commit": self.buggy_commit,
            "correct_commit": self.correct_commit,
        }
        return json.dumps(obj, indent=2)
    
    def dump_sql(self):
        obj = [
            "-- database query",
            self.database_query,
            "",
            "-- oracle query",
            self.first_oracle,
            self.second_oracle,
            "",
            "-- first result: {}".format(self.first_result.replace("\n", " ")),
            "-- second result: {}".format(self.second_result.replace("\n", " ")),
            "",
            "-- buggy_commit: {}".format(self.buggy_commit),
            "-- correct_commit: {}".format(self.correct_commit)
        ]
        return obj


def substr(string, start, stop=""):
    if not stop:
        result = string[string.find(start) + len(start) :]
    else:
        result = string[string.find(start) + len(start) : string.find(stop)]

    return result.strip()




def copy_new_data_dir():
    initdb = POSTGRE_INSTALL_DIR / "bin/initdb"
    postgre_binary = POSTGRE_INSTALL_DIR / "bin/postgres"
    data_dir = POSTGRE_INSTALL_DIR / "data"
    data_backup_dir = POSTGRE_INSTALL_DIR / "data.bak"
    
    if data_backup_dir.exists():
        # use exists data backup.
        os.system(f"rsync -avz -q -hH --delete {data_backup_dir}/ {data_dir}")
        return 
    
    if data_dir.exists():
        shutil.rmtree(data_dir)

    # create data directory layout
    initdb_cmd = "{} -D {}".format(initdb.absolute(), data_dir.absolute())
    print(f"Initialize the data directory layout: {initdb_cmd}")
    os.system(initdb_cmd)
    if not data_dir.exists():
        print("[x] Failed to initialize data directory.")
        return

    # create database x
    current_run_cmd_list = [str(), "--single", "-D", str(), "template0"]
    print("Run the postgre in single mode: {}".format(" ".join(current_run_cmd_list)))

    create_database_command = 'echo "create database x" | {} --single -D {} template0'.format(postgre_binary.absolute(), data_dir.absolute())
    print(create_database_command)

    try:
        subprocess.check_output(create_database_command, shell=True)
        os.system(f"cp -r {data_dir} {data_backup_dir}")
    except Exception as e:
        logger.exception(e)

def retrive_all_results(result_str):
    if (
        result_str.count("first_result") < 1
        or result_str.count("second_result") < 1
        # or is_string_only_whitespace(result_str)
        or result_str == ""
    ):
        return (
            None,
            RESULT.ALL_ERROR,
        )  # Missing the outputs from the opt or the unopt. Returnning None implying errors.

    result_lines = result_str.splitlines()
    
    # Grab all the opt results.
    opt_results = []
    begin_idx = []
    end_idx = []  

    for idx, line in enumerate(result_lines):
        if "BEGIN VERI 0" in line:
            begin_idx.append(idx)

    for idx, line in enumerate(result_lines):
        if "END VERI 0" in line:
            end_idx.append(idx)

    if len(begin_idx) != len(end_idx):
        print("[!] the number of 'BEGIN VERI 0' is not equal to the number of 'END VERI 0'.")
    
    for i in range(len(begin_idx)):
        current_opt_result_lines = result_lines[begin_idx[i]+1 : end_idx[i]]
        # strip 
        current_opt_result_lines = [line.strip() for line in current_opt_result_lines if line.strip().startswith('1:')]
        if not current_opt_result_lines:
            current_opt_result_int = [-1]
            opt_results.append(current_opt_result_int)
            continue 

        current_opt_result_lines = [line[line.find("=", 1)+1: line.find('(')] for line in current_opt_result_lines]
        current_opt_result_lines = [line.strip().strip('"') for line in current_opt_result_lines]
        # print(current_opt_result_lines)
        # print()
        # input()
        
        try:
            current_opt_result_int = [int(num) for num in current_opt_result_lines]
        except ValueError:
            current_opt_result_int = [-1]
        opt_results.append(current_opt_result_int)
    
    

    # Grab all the unopt results.
    unopt_results = []
    begin_idx = []
    end_idx = []

    for idx, line in enumerate(result_lines):
        if "BEGIN VERI 1" in line:
            begin_idx.append(idx)

    for idx, line in enumerate(result_lines):
        if "END VERI 1" in line:
            end_idx.append(idx)
            
    if len(begin_idx) != len(end_idx):
        print("[!] the number of 'BEGIN VERI 0' is not equal to the number of 'END VERI 0'.")
    
    for i in range(len(begin_idx)):
        current_unopt_result_lines = result_lines[begin_idx[i]+1 : end_idx[i]]
        # strip 
        current_unopt_result_lines = [line.strip() for line in current_unopt_result_lines if line.strip().startswith('1:')]
        if not current_unopt_result_lines:
            current_unopt_result_int = [-1]
            unopt_results.append(current_unopt_result_int)
            continue 

        current_unopt_result_lines = [line[line.find("=", 1)+1: line.find('(')] for line in current_unopt_result_lines]
        current_unopt_result_lines = [line.strip().strip('"') for line in current_unopt_result_lines]
        # print(current_unopt_result_lines)
        # print()
        # input()
        
        try:
            # Add 0.0001 to avoid inaccurate float to int transform. Transform are towards 0.
            current_unopt_result_int = [int(float(num) + 0.0001) for num in current_unopt_result_lines]
        except ValueError:
            current_unopt_result_int = [-1]
        unopt_results.append(current_unopt_result_int)

    all_results_out = []
    for i in range(min(len(opt_results), len(unopt_results))):
        cur_results_out = [opt_results[i], unopt_results[i]]
        all_results_out.append(cur_results_out)

    # pprint(all_results_out)
    return all_results_out, RESULT.PASS



@cli.command()
@click.argument("report", type=click.Path(exists=True))
@click.option(
    "-o",
    "--output",
    help="output directory.",
    default="simplified_reports",
    type=click.Path(),
)
def parse_bug_report(report, output):
    output = Path(output)
    output.mkdir(parents=True, exist_ok=True)
    with open(report) as f:
        contents = f.read()

    complete_query = contents[
        contents.find("Query:") + len("Query:") : contents.find("Result string:")
    ]
    complete_query = complete_query.strip()

    database_query = complete_query[: complete_query.find("SELECT 'BEGIN VERI 0';")]
    database_query = [
        query.strip()
        for query in database_query.splitlines()
        if not query.strip().upper().startswith("SELECT")
    ]
    database_query = "\n".join(database_query).strip()

    oracle_query_group = complete_query[complete_query.find("SELECT 'BEGIN VERI 0';") :]
    oracle_query_group = oracle_query_group.splitlines()

    result_string = contents[
        contents.find("Result string:")
        + len("Result string:") : contents.find("Final_res:")
    ]
    # remove error message of database query.
    result_string = result_string[result_string.find("BEGIN VERI 0") :]
    result_string = result_string.strip().splitlines()
    # print(result_string)
    
    begin_veri_0_indexes = [idx for idx, line in enumerate(result_string) if "BEGIN VERI 0" in line]
    end_veri_0_indexes = [idx for idx, line in enumerate(result_string) if "END VERI 0" in line]
    begin_veri_1_indexes = [idx for idx, line in enumerate(result_string) if "BEGIN VERI 1" in line]
    end_veri_1_indexes = [idx for idx, line in enumerate(result_string) if "END VERI 1" in line]
    

    oracle_queries = []
    i = 0
    j = 0
    while i < len(oracle_query_group):
        if "SELECT 'BEGIN VERI 0'" in oracle_query_group[i]:

            first_oracle_result = "\n".join(result_string[begin_veri_0_indexes[j]+1:end_veri_0_indexes[j]]).strip()
            first_oracle_query = OracleQuery(
                oracle_query_group[i + 1].strip(), first_oracle_result
            )

            second_oracle_result = "\n".join(result_string[begin_veri_1_indexes[j]+1:end_veri_1_indexes[j]]).strip()
            second_oracle_query = OracleQuery(
                oracle_query_group[i + 4].strip(), second_oracle_result
            )

            oracle_group = OracleQueryGroup(first_oracle_query, second_oracle_query)
            oracle_queries.append(oracle_group)

            i += 5
            j += 1
        
        i += 1

    minimize_targets = [
        MinimizeTarget(database_query, oq)
        for oq in oracle_queries
        if oq.is_different_result
    ]

    max_bug_num = max([int(bug.stem.split('_',1)[-1]) for bug in output.glob("*.sql")] + [0])

    for idx, target in enumerate(minimize_targets):
        print(
            "first {} <=> second {}".format(target.first_result, target.second_result)
        )

        print()

        print("first query:")
        print(target.first_query)

        print()

        print("second query:")
        print(target.second_query)

        print()
        
        output_json = output / "bug_{}.json".format(str(max_bug_num + 1 + idx))
        with open(output_json, "w") as f:
            f.write(target.dumps())
        
        output_sql = output /  "bug_{}.sql".format(str(max_bug_num + 1 + idx))
        with open(output_sql, "w") as f:
            for line in target.dump_sql():
                f.write(line + "\n")
            

    print("Total {} oracle queries.".format(len(minimize_targets)))

@cli.command()
@click.argument("folder", type=click.Path(exists=True))
@click.option(
    "-o",
    "--output",
    help="output directory.",
    default="simplified_reports",
    type=click.Path(),
)
@click.pass_context
def parse_bug_folder(ctx, folder, output):
    folder = Path(folder)
    for bug_file in folder.rglob("*"):
        if bug_file.is_dir():
            continue

        ctx.invoke(parse_bug_report, report=bug_file, output=output)


def check_postgre_oracle(database_query, first_oracle, second_oracle):

    current_unopt_result_int = [-1]
    current_opt_result_int = [-1]
    

    full_query = (
        database_query
        + "\n"
        + "select 'first_result';"
        + "\n"
        + first_oracle
        + "\n"
        + "select 'second_result';"
        + "\n"
        + second_oracle
    )

    copy_new_data_dir()
    current_run_cmd_list = [str(POSTGRE_INSTALL_DIR / "bin/postgres"), "--single", "-D", str(POSTGRE_INSTALL_DIR / "data"), "x"]
    child = subprocess.Popen(
        current_run_cmd_list,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        stdin=subprocess.PIPE,
        errors="replace",
    )
    try:
        output = child.communicate(full_query, timeout=3)[0]
    except subprocess.TimeoutExpired:
        child.kill()
        print("ERROR: Postgre time out. \n")
        return (current_opt_result_int, current_unopt_result_int)

    if (
        child.returncode != 0 and child.returncode != 1
    ):  # 1 is the default return code if we terminate the Postgre.
        child.kill()
        return (current_opt_result_int, current_unopt_result_int)  # Is segmentation fault
    child.kill()

    print(output)
    first_result = output[
        output.find("first_result")
        + len("first_result") : output.find("second_result")
    ]
    second_result = output[output.find("second_result") + len("second_result") :]

    first_result = first_result.strip().splitlines()
    current_opt_result_lines = [line.strip() for line in first_result if line.strip().startswith('1:')]
    if current_opt_result_lines:
        current_opt_result_lines = [line[line.find("=", 1)+1: line.find('(')] for line in current_opt_result_lines]
        current_opt_result_lines = [line.strip().strip('"') for line in current_opt_result_lines]
        current_opt_result_lines = [num for num in current_opt_result_lines if num]
        if not current_opt_result_lines:
            return (-1, -1)
            
        try:
            print("Current opt result lines")
            print(current_opt_result_lines)
            
            # Add 0.0001 to avoid inaccurate float to int transform. Transform are towards 0.
            current_opt_result_int = [int(float(num) + 0.0001) for num in current_opt_result_lines]
        except ValueError:
            current_opt_result_int = [-1]

    second_result = second_result.strip().splitlines()
    current_unopt_result_lines = [line.strip() for line in second_result if line.strip().startswith('1:')]
    if current_unopt_result_lines:
        current_unopt_result_lines = [line[line.find("=", 1)+1: line.find('(')] for line in current_unopt_result_lines]
        current_unopt_result_lines = [line.strip().strip('"') for line in current_unopt_result_lines]
        current_unopt_result_lines = [num for num in current_unopt_result_lines if num]
        if not current_unopt_result_lines:
            return (-1, -1)

        try:
            print("Current unopt result lines")
            print(current_unopt_result_lines)

            # Add 0.0001 to avoid inaccurate float to int transform. Transform are towards 0.
            current_unopt_result_int = [int(float(num) + 0.0001) for num in current_unopt_result_lines]
        except ValueError:
            current_unopt_result_int = [-1]
    
    return (current_opt_result_int, current_unopt_result_int)


def minimize_database_query(database_query, first_oracle, second_oracle):
    database_query = database_query.splitlines()
    database_query_size = len(database_query)
    stop_minimize = False
    while True:

        prev_queries_size = len(database_query)
        for i in reversed(range(len(database_query))):
            temp_database_query = database_query[:i] + database_query[i + 1 :]
            temp_database_query = "\n".join(temp_database_query)
            first_result, second_result = check_postgre_oracle(
                temp_database_query, first_oracle, second_oracle
            )

            removable = first_result != second_result
            if removable:
                logger.debug("one removable query: {}".format(database_query[i]))
                database_query.pop(i)
                break

        if prev_queries_size == len(database_query):
            stop_minimize += 1

        if stop_minimize > 12:
            break

    logger.info("Minimized {} queries".format(database_query_size - prev_queries_size))

    return "\n".join(database_query)


@cli.command()
@click.argument("report", type=click.Path(exists=True))
@click.option(
    "-o",
    "--output",
    help="output path of generated json file.",
    type=click.Path(),
)
def parse_unique_report(report, output):

    with open(report) as f:
        contents = f.read()

    database_query = substr(contents, "Query 0:", 'SELECT "--------- 1')
    database_query = [
        line.strip()
        for line in database_query.splitlines()
        if not line.strip().upper().startswith("SELECT")
    ]
    database_query = "\n".join(database_query).strip()

    print("database query: ")
    print(database_query)

    oracle_query = substr(contents, 'SELECT "--------- 1', "Last Buggy Result Num")

    oracle_queries = oracle_query.split(";")
    first_oracle = oracle_queries[0].strip() + ";"
    second_oracle = oracle_queries[1].strip() + ";"
    print("oracle query:")
    print(first_oracle)
    print(second_oracle)

    first_result, second_result = check_postgre_oracle(
        database_query, first_oracle, second_oracle
    )
    if first_result == second_result:
        logger.warning("[!] Cannot reproduce this bug")
        with open("not_reproduce.txt", "a") as f:
            f.write(str(report) + "\n")
        return

    original_database_query = database_query
    database_query = minimize_database_query(
        database_query, first_oracle, second_oracle
    )

    first_result, second_result = check_postgre_oracle(
        database_query, first_oracle, second_oracle
    )
    print("oracle query result:")
    print(first_result, second_result)

    buggy_commit = substr(contents, "First buggy commit ID:", "First correct")
    correct_commit = substr(contents, "First correct (or crashing) commit ID:")

    print("commit:")
    print(buggy_commit)
    print(correct_commit)

    print()

    target = {
        "original_database_query": original_database_query,
        "database_query": database_query,
        "first_result": first_result,
        "second_result": second_result,
        "first_oracle": first_oracle,
        "second_oracle": second_oracle,
        "buggy_commit": buggy_commit,
        "correct_commit": correct_commit,
    }

    output = output or Path(report).with_suffix(".json")
    with open(output, "w") as f:
        json.dump(target, f, indent=2, sort_keys=True)

    sql_output = Path(report).with_suffix(".sql")
    with open(sql_output, "w") as f:
        f.write("-- database query:\n" + database_query + "\n\n")
        f.write("-- oracle query:\n" + first_oracle + "\n" + second_oracle + "\n\n")
        f.write("-- first result: {}\n".format(first_result))
        f.write("-- second result: {}\n".format(second_result))


@cli.command()
@click.argument("folder", type=click.Path(exists=True))
@click.pass_context
def parse_unique_folder(ctx, folder):
    folder = Path(folder)
    for bug_file in folder.rglob("*"):
        if bug_file.suffix or bug_file.is_dir():
            continue

        ctx.invoke(parse_unique_report, report=bug_file, output=None)


if __name__ == "__main__":
    # parse_bug_report()
    # parse_unique_report()
    # parse_unique_folder()
    cli()

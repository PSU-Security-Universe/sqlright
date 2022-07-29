import os
import click
import json
from pathlib import Path
from loguru import logger


SQLITE_BINARY = "/data/liusong/Squirrel_DBMS/sqlite_build/latest/sqlite/sqlite3"


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
        if self.first.result.startswith("Error") and self.second.result.startswith(
            "Error"
        ):
            return False

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


def substr(string, start, stop=""):
    if not stop:
        result = string[string.find(start) + len(start) :]
    else:
        result = string[string.find(start) + len(start) : string.find(stop)]

    return result.strip()


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

    oracle_queries = []
    i = 0
    while i < len(oracle_query_group):
        if "SELECT 'BEGIN VERI 0'" in oracle_query_group[i]:
            first_oracle_result = result_string[i + 1].strip()
            first_oracle_query = OracleQuery(
                oracle_query_group[i + 1].strip(), first_oracle_result
            )

            second_oracle_result = result_string[i + 4].strip()
            second_oracle_query = OracleQuery(
                oracle_query_group[i + 4].strip(), second_oracle_result
            )

            oracle_group = OracleQueryGroup(first_oracle_query, second_oracle_query)
            oracle_queries.append(oracle_group)
            i += 5

        i += 1

    minimize_targets = [
        MinimizeTarget(database_query, oq)
        for oq in oracle_queries
        if oq.is_different_result
    ]

    if not os.path.exists(output):
        os.mkdir(output)

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

        with open(os.path.join(output, str(idx + 1) + ".json"), "w") as f:
            f.write(target.dumps())

    print("Total {} oracle queries.".format(len(minimize_targets)))


def check_sqlite_oracle(database_query, first_oracle, second_oracle):

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

    temp_file = ".temp_query"
    with open(temp_file, "w") as f:
        f.write(full_query)
        f.flush()

        cmd = "{} < {}".format(SQLITE_BINARY, temp_file)
        output = os.popen(cmd).read()

        print(output)
        first_result = output[
            output.find("first_result")
            + len("first_result") : output.find("second_result")
        ]
        second_result = output[output.find("second_result") + len("second_result") :]

        first_result = first_result.strip()
        second_result = second_result.strip()

        first_result = int(float(first_result)) if first_result else 0
        second_result = int(float(second_result)) if second_result else 0

        return (first_result, second_result)


def minimize_database_query(database_query, first_oracle, second_oracle):
    database_query = database_query.splitlines()
    database_query_size = len(database_query)
    stop_minimize = False
    while True:

        prev_queries_size = len(database_query)
        for i in reversed(range(len(database_query))):
            temp_database_query = database_query[:i] + database_query[i + 1 :]
            temp_database_query = "\n".join(temp_database_query)
            first_result, second_result = check_sqlite_oracle(
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

    first_result, second_result = check_sqlite_oracle(
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

    first_result, second_result = check_sqlite_oracle(
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
        f.write(
            "-- oracle query:\n"
            + "SELECT 'BEGIN VERI 0';\n"
            + first_oracle
            + "\n"
            + "SELECT 'END VERI 0';\n"
            + "SELECT 'BEGIN VERI 1';\n"
            + second_oracle
            + "\n"
            + "SELECT 'END VERI 1';\n"
            + "\n\n"
        )
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

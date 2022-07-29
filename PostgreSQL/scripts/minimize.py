import os
import sys
import json
import click
import hashlib
import itertools
import shutil
from pathlib import Path
from loguru import logger
from rich.progress import track
from collections import defaultdict
from tempfile import NamedTemporaryFile
from multiprocessing import Pool
from multiprocessing import cpu_count


valid_data_type = ("NUM", "TEXT", "DOUBLE")
bug_reports = Path("/data/liusong/Squirrel_DBMS/SQLite/second_unique_reports")
sqlite_binary = "/data/liusong/sqlite_latest/sqlite3"
query_minimizer = Path("/data/liusong/Squirrel_DBMS/SQLite/query-minimizer")
fuzz_work_dir = Path("/data/liusong/Squirrel_DBMS/SQLite/fuzz_root")


@click.group()
def cli():
    """SQLite Query Minimizer CLI."""
    pass


@cli.group()
def eval():
    """Evaluate whether if provided query is false positive."""
    pass


@cli.command()
@click.argument("reports", type=click.Path(exists=True))
def dedup(reports):
    """De-duplicate query by md5sum."""
    reports = Path(reports)
    unique_reports = dict()
    all_report_files = [
        report
        for report in reports.rglob("*")
        # skip directory and files with suffix.
        if not report.is_dir() and report.suffix
    ]

    def md5sum(string):
        """Get the md5 hash value of string."""
        return hashlib.md5(string.encode("utf-8")).hexdigest()

    duplicate = defaultdict(list)
    for report in track(all_report_files):
        report_batch = report.parent.name

        with open(report) as f:
            content = f.readlines()
            # skip the first line(contains the report id)
            content = "\n".join(content[1:])

        md5 = md5sum(content)
        if md5 not in unique_reports:
            unique_reports[md5] = report
            continue

        duplicate[report].append(unique_reports[md5])

    for report, dup_reports in duplicate.items():
        logger.debug("[-] Report:\t{}".format(report))
        for r in dup_reports:
            logger.debug(" " * 4 + "Duplicate:\t{}".format(r))

    logger.info("Complete running deduplicate task for {}".format(reports))


def get_possible_minimize_query(query):
    result = set()
    result.add(query)

    with NamedTemporaryFile("w+t", delete=True) as f:
        f.write(query)
        f.flush()

        command = "{} -r {}".format(query_minimizer, f.name)
        output = os.popen(command).read()
        result |= get_queries_from_string(output)

    return result


def get_queries_from_string(output):
    queries = set()
    for line in output.splitlines():
        if not line.startswith("[+]"):
            continue

        query = line[len("[+]") :].strip()
        if not query or query == ";":
            continue

        queries.add(query)

    return queries


def ensure_safe(query):
    query = query.strip()
    return query if query.endswith(";") else query + ";"


def run_sqlite_query(database_query, first_oracle, second_oracle):

    safe_database_query = [
        query if query.endswith(";") else query + ";"
        for query in database_query.splitlines()
    ]
    safe_database_query = "\n".join(safe_database_query)

    full_query = (
        database_query
        + "\n"
        + "select 'first_result';"
        + "\n"
        + ensure_safe(first_oracle)
        + "\n"
        + "select 'second_result';"
        + "\n"
        + ensure_safe(second_oracle)
    )

    # print("##################333")
    # print(full_query)
    # print("second: ", second_oracle if second_oracle.endswith(";") else second_oracle+";")
    # print("##################222")

    with NamedTemporaryFile("w+t", delete=False) as f:
        f.write(full_query)
        f.flush()

        cmd = "{} < {}".format(sqlite_binary, f.name)
        output = os.popen(cmd).read()
        # print(output)

        first_result = output[
            output.find("first_result")
            + len("first_result") : output.find("second_result")
        ]
        second_result = output[output.find("second_result") + len("second_result") :]

        first_result = first_result.strip()
        second_result = second_result.strip()

        try:
            first_result = int(float(first_result)) if first_result else 0
        except:
            first_result = 0

        try:
            second_result = int(float(second_result)) if second_result else 0
        except:
            second_result = 0

        return (first_result, second_result)


def shrink_database_queries(
    database_query, minimize_index, minimize_queries, first_oracle, second_oracle
):
    removable_indexes = []
    for idx, query in enumerate(minimize_queries):
        # print(minimize_index)
        # print("\n".join(database_query[:minimize_index]))
        # print("\n".join(database_query[minimize_index+1:]))
        # print(query)
        new_database_query = (
            "\n".join(database_query[:minimize_index])
            + query
            + "\n".join(database_query[minimize_index + 1 :])
        )
        first_result, second_result = run_sqlite_query(
            new_database_query, first_oracle, second_oracle
        )

        removable = first_result != second_result
        if removable:
            removable_indexes.append(idx)

    minimize_database_query = [
        query
        for idx, query in enumerate(minimize_queries)
        if idx not in removable_indexes
    ]
    logger.debug(
        "shrinked {} database queries ({}/{}).".format(
            len(minimize_queries) - len(minimize_database_query),
            len(minimize_database_query),
            len(minimize_queries),
        )
    )
    return minimize_database_query


def shrink_first_oracle_queries(database_query, first_oracle_queries, second_oracle):
    removable_indexes = []
    for idx, query in enumerate(first_oracle_queries):
        first_result, second_result = run_sqlite_query(
            database_query, query, second_oracle
        )
        removable = first_result != second_result
        if removable:
            removable_indexes.append(idx)

    minimize_first_oracle_query = [
        query
        for idx, query in enumerate(first_oracle_queries)
        if idx not in removable_indexes
    ]
    logger.debug(
        "shrinked {} first oracle queries ({}/{}).".format(
            len(first_oracle_queries) - len(minimize_first_oracle_query),
            len(minimize_first_oracle_query),
            len(first_oracle_queries),
        )
    )
    return minimize_first_oracle_query


def shrink_second_oracle_queries(database_query, first_oracle, second_oracle_queries):
    removable_indexes = []
    for idx, query in enumerate(second_oracle_queries):
        first_result, second_result = run_sqlite_query(
            database_query, first_oracle, query
        )
        removable = first_result != second_result
        if removable:
            removable_indexes.append(idx)

    minimize_second_oracle_query = [
        query
        for idx, query in enumerate(second_oracle_queries)
        if idx not in removable_indexes
    ]
    logger.debug(
        "shrinked {} second oracle queries ({}/{}).".format(
            len(second_oracle_queries) - len(minimize_second_oracle_query),
            len(minimize_second_oracle_query),
            len(second_oracle_queries),
        )
    )
    return minimize_second_oracle_query


def run_minimizer_single_cpu(report):
    outdir = report.with_suffix(".min")
    outdir.mkdir(exist_ok=True)

    with open(report) as f:
        json_report = json.load(f)
        database_queries = json_report["database_query"].splitlines()
        truth_database_queries = database_queries
        first_oracle = json_report["first_oracle"]
        second_oracle = json_report["second_oracle"]

    minimize_database_queries = []
    for query_index, query in enumerate(database_queries):

        minimize_queries = get_possible_minimize_query(query)
        minimize_queries = shrink_database_queries(
            database_queries, query_index, minimize_queries, first_oracle, second_oracle
        )
        minimize_database_queries.append(minimize_queries)
        logger.warning(len(minimize_queries))

    # first_oracle_queries = get_possible_minimize_query(first_oracle)
    # first_oracle_queries = shrink_first_oracle_queries(
    #     json_report["database_query"],
    #     first_oracle_queries,
    #     json_report["second_oracle"],
    # )
    first_oracle_queries = [first_oracle]
    # second_oracle_queries = get_possible_minimize_query(second_oracle)
    # second_oracle_queries = shrink_second_oracle_queries(
    #     json_report["database_query"],
    #     json_report["first_oracle"],
    #     second_oracle_queries,
    # )
    second_oracle_queries = [second_oracle]

    for idx, query in enumerate(truth_database_queries):
        if query not in minimize_database_queries[idx]:
            minimize_database_queries[idx].append(query)

    if json_report["first_oracle"] not in first_oracle_queries:
        first_oracle_queries.append(json_report["first_oracle"])

    if json_report["second_oracle"] not in second_oracle_queries:
        second_oracle_queries.append(json_report["second_oracle"])

    # print(len(first_oracle_queries), len(second_oracle_queries))
    # db_count = 0
    # for a in minimize_database_queries:
    #     db_count += len(a)
    #     print(len(a))

    # input()
    # print(*minimize_database_queries)
    # input()
    # print(first_oracle_queries)
    # input()
    # print(second_oracle_queries)
    # input()

    cnt = 0
    results = []
    for selected_queries in itertools.product(
        *minimize_database_queries, first_oracle_queries, second_oracle_queries
    ):

        # print(cnt)
        cnt += 1

        database_query = selected_queries[:-2]
        database_query = "\n".join(database_query)

        first_oracle = selected_queries[-2]
        second_oracle = selected_queries[-1]

        # truth_database_query = "CREATE TABLE v0 ( c1 INTEGER PRIMARY KEY );\nINSERT INTO v0 VALUES ( 127 );\nALTER TABLE v0 ADD COLUMN c14 INT NOT NULL ON CONFLICT ABORT AS( max ( 18446744073709551615, hex ( 9223372036854775807 ), NULL, NULL ) );"
        # truth_first_oracle = "SELECT COUNT ( * ) FROM v0 AS a21 WHERE a21.c14 IN ( SELECT a22.c14 FROM v0 AS a22 );"
        # truth_second_oracle = "SELECT TOTAL ( CAST ( a21.c14 IN ( SELECT a22.c14 FROM v0 AS a22 ) AS BOOL ) != 0 ) FROM v0 AS a21;"
        # if database_query.strip() == truth_database_query:
        #     logger.warning("!!!!!!!!!!!")
        first_result, second_result = run_sqlite_query(
            database_query, first_oracle, second_oracle
        )
        # input()

        removable = first_result != second_result
        if removable:
            full_query = (
                "-- database query\n"
                + database_query
                + "\n"
                + "-- oracle query\n"
                + first_oracle
                + "\n"
                + second_oracle
                + "\n"
                + "-- first result: "
                + str(first_result)
                + "\n"
                + "-- second result: "
                + str(second_result)
            )
            results.append(full_query)
            logger.debug("one minimize query:\n{}".format(full_query))

            # sys.exit(0)
        # break

    for idx, query in enumerate(results):
        output = outdir / "min_{}.sql".format(idx)
        with open(output, "w") as f:
            f.write(query)


def run_minimizer_multiple_cpu(reports):
    reports = Path(reports)
    json_bug_reports = [report for report in reports.rglob("*.json")]

    with Pool(cpu_count()) as p:
        result = p.map_async(run_minimizer_single_cpu, json_bug_reports)
        result.get()


@cli.command()
@click.argument("reports", type=click.Path(exists=True))
def run(reports):
    """Run the query minimizer."""
    reports = Path(reports)

    if reports.is_dir():
        run_minimizer_multiple_cpu(reports)
    else:
        run_minimizer_single_cpu(reports)

    logger.info("Complete running query minimizer for {}".format(reports))


@eval.command()
def view_affinity():
    """FP: view affinity."""
    count = 0
    notsure = 0

    def parse_table_query(create_table_queries):
        table_dict = {}
        for table_query in create_table_queries:
            table_name = table_query.split()[2]
            table_type = table_query.split()[5]

            # print(table_name, table_type)
            if table_type not in available_type:
                continue

            table_dict[table_name] = table_type

        return table_dict

    # unique_reports = [Path('unique_reports/report1/bug_1.json')]
    for file in unique_reports.rglob("*.json"):
        # for file in unique_reports:
        if file.is_dir():
            continue

        with open(file) as f:
            data = json.load(f)
        # print(file)

        database_query = data["database_query"].splitlines()
        oracle_query = data["first_oracle"]

        # print(database_query)

        create_table_queries = [
            line for line in database_query if line.startswith("CREATE TABLE ")
        ]
        create_view_query = [
            line
            for line in database_query
            if line.startswith("CREATE VIEW ")
            if "UNION" in line
        ]

        if not create_table_queries:
            continue

        # print(create_table_queries)
        table_dict = parse_table_query(create_table_queries)
        # print()

        for view_query in create_view_query:
            view_name = view_query.split()[2]
            query_before_union, query_after_union = view_query.split("UNION", 1)

            if "FROM" not in query_before_union or "FROM" not in query_after_union:
                continue

            first_table_name = query_before_union.split()[
                query_before_union.split().index("FROM") + 1
            ]
            second_table_name = query_after_union.split()[
                query_after_union.split().index("FROM") + 1
            ]

            if not first_table_name or not second_table_name:
                continue

            if first_table_name not in table_dict:
                print(
                    "[!] {} not in table dict: {}".format(
                        first_table_name, file.with_suffix("")
                    )
                )
                notsure += 1
                continue

            if second_table_name not in table_dict:
                print(
                    "[!] {} not in table dict: {}".format(
                        second_table_name, file.with_suffix("")
                    )
                )
                notsure += 1
                continue

            if (
                table_dict[first_table_name] != table_dict[second_table_name]
                and "FROM {}".format(view_name) in oracle_query
            ):
                analysis_report = file.with_suffix(".txt")
                print("[+] FP1:", file.with_suffix(""), "Reports:", analysis_report)

                f = open(analysis_report, "w")
                f.write("View collision(auto detected)\n\n")

                print("\t=> Table: ")
                f.write("=> Table: \n")
                for table_query in create_table_queries:
                    print("\t=>", table_query)
                    f.write(f"=> {table_query}\n")

                print()
                f.write("\n")
                print("\t=> View:")
                f.write("=> View:\n")
                print("\t=>", view_query)
                f.write(f"=> {view_query}\n")
                print()
                f.write("\n")

                print("\t=> Oracle:")
                f.write("=> Oracle:\n")
                print("\t=>", oracle_query)
                f.write(f"=> {oracle_query}\n")
                print()

                f.close()
                count += 1

                # dest = Path('fp1') / file.parent.name
                # os.system("mv {} {}".format(file, dest))

    print(f"Total: {count}, Not sure: {notsure}")


@eval.command()
def rtree_compare():
    """FP: create table using rtree and compare its member."""
    count = 0
    notsure = 0
    # unique_reports = [Path('unique_reports/report1/bug_1.json')]
    for file in unique_reports.rglob("*.json"):
        if file.is_dir():
            continue

        with open(file) as f:
            data = json.load(f)

        database_query = data["database_query"].splitlines()
        oracle_query = data["first_oracle"]

        rtree_table_query = [
            query
            for query in database_query
            if query.startswith("CREATE") and "rtree" in query
        ]

        if not rtree_table_query:
            continue

        rtree_table_query = rtree_table_query[0]

        rtree_table_name = rtree_table_query.split()[3]

        if not rtree_table_name.startswith("v"):
            print(
                "[!] {} is not a valid rtree table name: {}".format(
                    rtree_table_name, file.with_suffix("")
                )
            )
            notsure += 1
            continue

        if "FROM {}".format(rtree_table_name) not in oracle_query:
            print(
                "[!] {} not used in oracle query: {}".format(
                    rtree_table_name, file.with_suffix("")
                )
            )
            notsure += 1
            continue

        rtree_table_members = rtree_table_query[
            rtree_table_query.find("(") + 1 : rtree_table_query.find(")")
        ]
        rtree_table_members = [v.strip() for v in rtree_table_members.split(",")]

        analysis_report = file.with_suffix(".txt")
        print("[+] FP2:", file.with_suffix(""), "Reports:", analysis_report)
        f = open(analysis_report, "w")
        f.write("Compare rtree member with large number(auto detected)\n\n")

        print("\t=> rtree table:", rtree_table_name, "=> members:", rtree_table_members)
        f.write(f"=> rtree query: {rtree_table_query}\n")
        f.write(f"=> rtree table: {rtree_table_name}\n")
        f.write(f"=> members: {rtree_table_members}\n")

        f.write("\n")
        print("\t=>", oracle_query)
        f.write(f"=> Oracle:\n=> {oracle_query}\n")
        print()

        count += 1

    print(f"Total: {count}, Not sure: {notsure}")


@cli.command()
@click.argument("reports", type=click.Path(exists=True))
def seperate(reports):
    """Seperate the bug reports into multiple folder groups."""
    reports = Path(reports)
    report_files = [file for file in reports.rglob("*") if file.is_file()]
    reports_nums = len(report_files)

    sqlright = Path("/data/liusong/postgres_bisect")
    sqlites = [
        sqlright / str(i) / "Squirrel_Postgre/PostgreSQL" for i in range(10)
    ]
    group_nums = len(sqlites)
    batch_nums = int(reports_nums / group_nums)
    print(f"[+] Total {reports_nums} reports and batch size is {batch_nums}.")

    # delete and recreate bug_samples and unique_bug_output
    for sqlite in sqlites:
        bug_samples = sqlite / "Bug_Analysis/bug_samples"
        unique_bug_output = sqlite / "Bug_Analysis/unique_bug_output"

        if bug_samples.exists():
            shutil.rmtree(bug_samples)
        if unique_bug_output.exists():
            shutil.rmtree(unique_bug_output)

        bug_samples.mkdir()
        unique_bug_output.mkdir()
    print("[*] Clean the bug_samples and unique_bug_output folder.")

    for i in range(group_nums):
        if i == group_nums - 1:
            batch_reports = report_files[i * batch_nums :]
        else:
            batch_reports = report_files[i * batch_nums : (i + 1) * batch_nums]

        outdir = sqlites[i] / "Bug_Analysis/bug_samples"
        for report in track(
            batch_reports, description=f"[+] Copy {i} batch of reports"
        ):
            os.system(f"cp {report} {outdir}")


@cli.command()
@click.argument("outdir", type=click.Path())
def collect(outdir):
    outdir = Path(outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    sqlright = Path("/data/liusong/postgres_bisect")
    sqlites = [
        sqlright / str(i) / "Squirrel_Postgre/PostgreSQL" for i in range(10)
    ]

    index = 0
    for sqlite in sqlites:
        unique_bug_reports = sqlite / "Bug_Analysis/unique_bug_output"
        for report in unique_bug_reports.rglob("*"):
            output = outdir / f"bug_{index}"
            os.system(f"cp {report} {output}")
            index += 1

    print(f"Total {index} unique reports.")


# TODO(vancir): recognize rtree fp after classification by similarity
# TODO(vancir): recognize view affinity fp after classification by similarity

if __name__ == "__main__":
    cli()

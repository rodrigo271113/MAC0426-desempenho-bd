#!/usr/bin/env python3
"""
benchmark.py — MySQL vs PostgreSQL Performance Benchmark
StackOverflow Database  (USP – Banco de Dados – Projeto 1)

Usage
-----
  python benchmark.py --scenario 1 --mysql-password SECRET --pg-password SECRET

Each of the 13 benchmark queries is executed N_RUNS=20 times per database.
Results (mean, stddev, min, max in ms) are written to:
    results/scenario_<N>_results.csv

Scenarios
---------
  1 – No secondary indexes  (PKs only)
  2 – Single-column B-tree indexes
  3 – Composite B-tree indexes
  4 – Composite + Full-text / Trigram indexes

Apply the matching SQL files from the sql/ directory before running each
scenario; the script itself never alters indexes.
"""

import argparse
import csv
import random
import statistics
import sys
import time
from pathlib import Path

import mysql.connector
import psycopg2

# ══════════════════════════════════════════════════════════════════════════════
#  Configuration  — edit here or pass via CLI arguments
# ══════════════════════════════════════════════════════════════════════════════

MYSQL_CFG: dict = {
    "host":     "localhost",
    "port":     3306,
    "user":     "root",
    "password": "",           # override via --mysql-password
    "database": "StackOverflow",
}

PG_CFG: dict = {
    "host":     "localhost",
    "port":     5432,
    "user":     "postgres",
    "password": "",           # override via --pg-password
    "dbname":   "StackOverflow",
}

N_RUNS      = 20
RESULTS_DIR = Path("results")

# ══════════════════════════════════════════════════════════════════════════════
#  DB helpers
# ══════════════════════════════════════════════════════════════════════════════

def mysql_connect():
    conn = mysql.connector.connect(**MYSQL_CFG)
    conn.autocommit = True
    return conn


def pg_connect():
    conn = psycopg2.connect(**PG_CFG)
    conn.autocommit = True
    return conn


def silent_exec(cursor, sql: str, params=None) -> None:
    """Execute SQL ignoring any errors (used in teardown / cleanup)."""
    try:
        if params is not None:
            cursor.execute(sql, params)
        else:
            cursor.execute(sql)
        try:
            cursor.fetchall()
        except Exception:
            pass
    except Exception:
        pass


def timed_exec(cursor, sql: str, params=None) -> float:
    """Execute sql, fetch all results, return elapsed time in **milliseconds**."""
    t0 = time.perf_counter()
    if params is not None:
        cursor.execute(sql, params)
    else:
        cursor.execute(sql)
    try:
        cursor.fetchall()
    except Exception:
        pass
    return (time.perf_counter() - t0) * 1_000.0


def calc_stats(times: list) -> dict:
    return {
        "mean_ms":   round(statistics.mean(times), 4),
        "stddev_ms": round(statistics.stdev(times) if len(times) > 1 else 0.0, 4),
        "min_ms":    round(min(times), 4),
        "max_ms":    round(max(times), 4),
    }

# ══════════════════════════════════════════════════════════════════════════════
#  Pre-fetch sample IDs so parameterised queries always hit real rows
# ══════════════════════════════════════════════════════════════════════════════

def prefetch(conn, db_type: str, n: int) -> dict:
    """Return dicts with lists of real Post IDs and User IDs from the DB."""
    cur = conn.cursor()
    s: dict = {}
    if db_type == "mysql":
        cur.execute(f"SELECT Id FROM Posts ORDER BY RAND() LIMIT {n * 3}")
        s["post_ids"] = [r[0] for r in cur.fetchall()]
        cur.execute(f"SELECT Id FROM Users WHERE Id > 0 ORDER BY RAND() LIMIT {n * 3}")
        s["user_ids"] = [r[0] for r in cur.fetchall()]
    else:  # postgres
        cur.execute(f'SELECT "Id" FROM "Posts" ORDER BY RANDOM() LIMIT {n * 3}')
        s["post_ids"] = [r[0] for r in cur.fetchall()]
        cur.execute(f'SELECT "Id" FROM "Users" WHERE "Id" > 0 ORDER BY RANDOM() LIMIT {n * 3}')
        s["user_ids"] = [r[0] for r in cur.fetchall()]
    cur.close()
    return s

# ══════════════════════════════════════════════════════════════════════════════
#  INSERT / DELETE helpers — used by Q01 and Q02
# ══════════════════════════════════════════════════════════════════════════════

# Shared INSERT SQL (Users table, benchmark-tagged display name)
_INS_M = (
    "INSERT INTO Users "
    "(Id, Reputation, CreationDate, DisplayName, LastAccessDate, Views, UpVotes, DownVotes) "
    "VALUES (%s, %s, %s, %s, %s, %s, %s, %s)"
)
_INS_PG = (
    'INSERT INTO "Users" '
    '("Id","Reputation","CreationDate","DisplayName","LastAccessDate","Views","UpVotes","DownVotes") '
    "VALUES (%s, %s, %s, %s, %s, %s, %s, %s)"
)
_INS_PG_RET = _INS_PG + ' RETURNING "Id"'


import time
_bench_id_counter = int(time.time() * 1000) % 1000000000 + 1000000000

def _row_vals(label: str) -> tuple:
    """Parameter tuple for one benchmark INSERT into Users."""
    global _bench_id_counter
    _bench_id_counter += 1
    return (_bench_id_counter, 1, "2024-01-01 00:00:00", label, "2024-01-01 00:00:00", 0, 0, 0)


def pre_insert_rows(conn, db_type: str, n: int, prefix: str) -> list:
    """Insert n benchmark rows and return their new PKs (used by DELETE bench)."""
    cur = conn.cursor()
    ids = []
    for i in range(n):
        vals = _row_vals(f"{prefix}{i}")
        the_id = vals[0]
        if db_type == "mysql":
            cur.execute(_INS_M, vals)
            ids.append(the_id)
        else:
            cur.execute(_INS_PG_RET, vals)
            ids.append(cur.fetchone()[0])
    cur.close()
    return ids


def cleanup_bench_users(conn, db_type: str) -> None:
    """Remove any lingering benchmark rows created during this run."""
    cur = conn.cursor()
    if db_type == "mysql":
        silent_exec(cur, "DELETE FROM Users WHERE DisplayName LIKE '__bench_%'")
    else:
        silent_exec(cur, "DELETE FROM \"Users\" WHERE \"DisplayName\" LIKE '__bench_%'")
    cur.close()

# ══════════════════════════════════════════════════════════════════════════════
#  Core benchmark runner
# ══════════════════════════════════════════════════════════════════════════════

def run_benchmarks(conn, db_type: str, samples: dict, scenario: int,
                   n_runs: int = N_RUNS) -> list:
    """
    Execute all 13 benchmark queries n_runs times each.
    Returns a list of result dicts with timing statistics.
    """
    M    = (db_type == "mysql")
    pids = (samples["post_ids"] * 4)[:n_runs]   # ensure we have n_runs entries
    uids = (samples["user_ids"] * 4)[:n_runs]
    records = []

    def run_query(name: str, category: str, sql: str, params_list: list) -> None:
        """Execute sql n_runs times, collect timings, print summary, store result."""
        times = []
        tag   = f"[{db_type:8s}] {name[:52]:52s}"
        print(f"  {tag} ", end="", flush=True)
        for p in params_list:
            cur = conn.cursor()
            ms  = timed_exec(cur, sql, p)
            times.append(ms)
            cur.close()
        s = calc_stats(times)
        print(
            f"mean={s['mean_ms']:8.2f}ms  "
            f"sd={s['stddev_ms']:7.2f}  "
            f"min={s['min_ms']:7.2f}  "
            f"max={s['max_ms']:7.2f}"
        )
        records.append({"query": name, "category": category, "db": db_type, **s})

    # ── Q01: INSERT ──────────────────────────────────────────────────────────
    run_query(
        "Q01 INSERT – new user row",
        "Insert/Delete/Update",
        _INS_M if M else _INS_PG,
        [_row_vals(f"__bench_ins_{i}") for i in range(n_runs)],
    )
    cleanup_bench_users(conn, db_type)

    # ── Q02: DELETE ──────────────────────────────────────────────────────────
    del_ids = pre_insert_rows(conn, db_type, n_runs, prefix="__bench_del_")
    run_query(
        "Q02 DELETE – remove user row by PK",
        "Insert/Delete/Update",
        "DELETE FROM Users WHERE Id = %s" if M
        else 'DELETE FROM "Users" WHERE "Id" = %s',
        [(i,) for i in del_ids],
    )
    cleanup_bench_users(conn, db_type)  # safety net

    # ── Q02b: DELETE (non-PK) ────────────────────────────────────────────────
    pre_insert_rows(conn, db_type, n_runs, prefix="__bench_delnpk_")
    run_query(
        "Q02b DELETE – remove user row by non-PK (DisplayName)",
        "Insert/Delete/Update",
        "DELETE FROM Users WHERE DisplayName = %s" if M
        else 'DELETE FROM "Users" WHERE "DisplayName" = %s',
        [(f"__bench_delnpk_{i}",) for i in range(n_runs)],
    )
    cleanup_bench_users(conn, db_type)  # safety net

    # ── Q03: UPDATE ──────────────────────────────────────────────────────────
    uid_upd = uids[0]
    run_query(
        "Q03 UPDATE – change user Reputation by PK",
        "Insert/Delete/Update",
        "UPDATE Users SET Reputation = %s WHERE Id = %s" if M
        else 'UPDATE "Users" SET "Reputation" = %s WHERE "Id" = %s',
        [(random.randint(1, 99_999), uid_upd) for _ in range(n_runs)],
    )

    # ── Q03b: UPDATE (non-PK) ────────────────────────────────────────────────
    pre_insert_rows(conn, db_type, n_runs, prefix="__bench_updnpk_")
    run_query(
        "Q03b UPDATE – change user Reputation by non-PK (DisplayName)",
        "Insert/Delete/Update",
        "UPDATE Users SET Reputation = %s WHERE DisplayName = %s" if M
        else 'UPDATE "Users" SET "Reputation" = %s WHERE "DisplayName" = %s',
        [(random.randint(1, 99_999), f"__bench_updnpk_{i}") for i in range(n_runs)],
    )
    cleanup_bench_users(conn, db_type)  # safety net

    # ── Q04: PK single ───────────────────────────────────────────────────────
    run_query(
        "Q04 SELECT by PK – single key (Posts)",
        "PK Lookup",
        "SELECT * FROM Posts WHERE Id = %s" if M
        else 'SELECT * FROM "Posts" WHERE "Id" = %s',
        [(pid,) for pid in pids],
    )

    # ── Q05: PK range ────────────────────────────────────────────────────────
    run_query(
        "Q05 SELECT by PK – range Id BETWEEN ? AND ?+500",
        "PK Range",
        "SELECT * FROM Posts WHERE Id BETWEEN %s AND %s" if M
        else 'SELECT * FROM "Posts" WHERE "Id" BETWEEN %s AND %s',
        [(pid, pid + 500) for pid in pids],
    )

    # ── Q06: Non-key single ──────────────────────────────────────────────────
    run_query(
        "Q06 SELECT non-key single – Location='United States'",
        "Non-key Single Condition",
        ("SELECT Id, DisplayName, Reputation, Location "
         "FROM Users WHERE Location = 'United States'") if M
        else
        ("SELECT \"Id\",\"DisplayName\",\"Reputation\",\"Location\" "
         "FROM \"Users\" WHERE \"Location\" = 'United States'"),
        [None] * n_runs,
    )

    # ── Q07: Non-key compound ────────────────────────────────────────────────
    run_query(
        "Q07 SELECT non-key compound – PostTypeId+Score+ViewCount",
        "Non-key Compound Condition",
        ("SELECT Id, Title, Score, ViewCount FROM Posts "
         "WHERE PostTypeId = 1 AND Score > 50 AND ViewCount > 1000") if M
        else
        ("SELECT \"Id\",\"Title\",\"Score\",\"ViewCount\" FROM \"Posts\" "
         "WHERE \"PostTypeId\" = 1 AND \"Score\" > 50 AND \"ViewCount\" > 1000"),
        [None] * n_runs,
    )

    # ── Q08: LIKE ────────────────────────────────────────────────────────────
    # Infix search; benefits from pg_trgm GIN index in Scenario 4 (PostgreSQL)
    run_query(
        "Q08 SELECT LIKE – Tags LIKE '%<python>%'",
        "LIKE Pattern",
        "SELECT Id, Title, Tags FROM Posts WHERE Tags LIKE '%<python>%' LIMIT 500" if M
        else "SELECT \"Id\",\"Title\",\"Tags\" FROM \"Posts\" WHERE \"Tags\" LIKE '%<python>%' LIMIT 500",
        [None] * n_runs,
    )

    # ── Q09: 2-table JOIN ────────────────────────────────────────────────────
    run_query(
        "Q09 JOIN – Posts × Users (Score > 50)",
        "2-table JOIN",
        ("SELECT p.Id, p.Title, p.Score, u.DisplayName, u.Reputation "
         "FROM Posts p JOIN Users u ON p.OwnerUserId = u.Id "
         "WHERE p.PostTypeId = 1 AND p.Score > 50 "
         "AND p.OwnerUserId IS NOT NULL LIMIT 500") if M
        else
        ("SELECT p.\"Id\",p.\"Title\",p.\"Score\",u.\"DisplayName\",u.\"Reputation\" "
         "FROM \"Posts\" p JOIN \"Users\" u ON p.\"OwnerUserId\" = u.\"Id\" "
         "WHERE p.\"PostTypeId\" = 1 AND p.\"Score\" > 50 "
         "AND p.\"OwnerUserId\" IS NOT NULL LIMIT 500"),
        [None] * n_runs,
    )

    # ── Q10: 3-table JOIN ────────────────────────────────────────────────────
    run_query(
        "Q10 JOIN – Comments × Posts × Users (c.Score > 3)",
        "3-table JOIN",
        ("SELECT c.Id, c.Text, p.Title, u.DisplayName "
         "FROM Comments c "
         "JOIN Posts p ON c.PostId = p.Id "
         "JOIN Users u ON p.OwnerUserId = u.Id "
         "WHERE p.PostTypeId = 1 AND c.Score > 3 "
         "AND p.OwnerUserId IS NOT NULL LIMIT 500") if M
        else
        ("SELECT c.\"Id\",c.\"Text\",p.\"Title\",u.\"DisplayName\" "
         "FROM \"Comments\" c "
         "JOIN \"Posts\" p ON c.\"PostId\" = p.\"Id\" "
         "JOIN \"Users\" u ON p.\"OwnerUserId\" = u.\"Id\" "
         "WHERE p.\"PostTypeId\" = 1 AND c.\"Score\" > 3 "
         "AND p.\"OwnerUserId\" IS NOT NULL LIMIT 500"),
        [None] * n_runs,
    )

    # ── Q11: Subquery ────────────────────────────────────────────────────────
    run_query(
        "Q11 Subquery – users with above-avg question score",
        "Subquery",
        ("SELECT Id, DisplayName, Reputation FROM Users "
         "WHERE Id IN ("
         "  SELECT OwnerUserId FROM Posts "
         "  WHERE Score > (SELECT AVG(Score) FROM Posts WHERE PostTypeId = 1) "
         "  AND PostTypeId = 1 AND OwnerUserId IS NOT NULL"
         ") LIMIT 500") if M
        else
        ("SELECT \"Id\",\"DisplayName\",\"Reputation\" FROM \"Users\" "
         "WHERE \"Id\" IN ("
         "  SELECT \"OwnerUserId\" FROM \"Posts\" "
         "  WHERE \"Score\" > (SELECT AVG(\"Score\") FROM \"Posts\" WHERE \"PostTypeId\" = 1) "
         "  AND \"PostTypeId\" = 1 AND \"OwnerUserId\" IS NOT NULL"
         ") LIMIT 500"),
        [None] * n_runs,
    )

    # ── Q12: GROUP BY + Aggregations ─────────────────────────────────────────
    run_query(
        "Q12 GROUP BY PostTypeId – count/avg/min/max/sum",
        "Aggregation (GROUP BY)",
        ("SELECT PostTypeId, COUNT(*) AS n, "
         "AVG(Score) AS avg_sc, MIN(Score) AS min_sc, MAX(Score) AS max_sc, "
         "SUM(ViewCount) AS sum_vc "
         "FROM Posts GROUP BY PostTypeId ORDER BY n DESC") if M
        else
        ("SELECT \"PostTypeId\", COUNT(*) AS n, "
         "AVG(\"Score\") AS avg_sc, MIN(\"Score\") AS min_sc, MAX(\"Score\") AS max_sc, "
         "SUM(\"ViewCount\") AS sum_vc "
         "FROM \"Posts\" GROUP BY \"PostTypeId\" ORDER BY n DESC"),
        [None] * n_runs,
    )

    # ── Q13: Full-text / pattern search on Body ───────────────────────────────
    # Scenarios 1-3: slow LIKE scan (shows the cost without FT index)
    # Scenario  4:   real FT operators that use the index created by scenario_4 SQL
    if scenario < 4:
        sql_ft = (
            "SELECT Id, Title FROM Posts WHERE Body LIKE '%python%' LIMIT 200" if M
            else "SELECT \"Id\",\"Title\" FROM \"Posts\" WHERE \"Body\" LIKE '%python%' LIMIT 200"
        )
        q13_name = "Q13 Full-text (LIKE fallback) – Body LIKE '%python%'"
    else:
        sql_ft = (
            ("SELECT Id, Title FROM Posts "
             "WHERE MATCH(Body) AGAINST ('python error' IN NATURAL LANGUAGE MODE) LIMIT 200") if M
            else
            ("SELECT \"Id\",\"Title\" FROM \"Posts\" "
             "WHERE to_tsvector('english',\"Body\") "
             "@@ plainto_tsquery('english','python error') LIMIT 200")
        )
        q13_name = "Q13 Full-text search – Body MATCH/tsvector 'python error'"

    run_query(q13_name, "Full-text / LIKE", sql_ft, [None] * n_runs)

    return records

# ══════════════════════════════════════════════════════════════════════════════
#  Main
# ══════════════════════════════════════════════════════════════════════════════

SCENARIO_LABELS = {
    1: "No Secondary Indexes",
    2: "Single-Column B-tree Indexes",
    3: "Composite B-tree Indexes",
    4: "Composite + Full-Text / Trigram Indexes",
}


def main() -> None:
    ap = argparse.ArgumentParser(
        description="MySQL vs PostgreSQL Benchmark — StackOverflow DB"
    )
    ap.add_argument(
        "--scenario", type=int, choices=[1, 2, 3, 4], required=True,
        help="Index scenario (1=no secondary indexes, 2=single-col, 3=composite, 4=+fulltext)"
    )
    ap.add_argument("--mysql-password", default="", metavar="PWD",
                    help="MySQL root (or other user) password")
    ap.add_argument("--pg-password",    default="", metavar="PWD",
                    help="PostgreSQL postgres (or other user) password")
    ap.add_argument("--mysql-host",     default="localhost")
    ap.add_argument("--pg-host",        default="localhost")
    ap.add_argument("--mysql-user",     default="root")
    ap.add_argument("--pg-user",        default="postgres")
    ap.add_argument("--mysql-db",       default="StackOverflow")
    ap.add_argument("--pg-db",          default="StackOverflow")
    args = ap.parse_args()

    MYSQL_CFG.update(
        password=args.mysql_password,
        host=args.mysql_host,
        user=args.mysql_user,
        database=args.mysql_db,
    )
    PG_CFG.update(
        password=args.pg_password,
        host=args.pg_host,
        user=args.pg_user,
        dbname=args.pg_db,
    )

    RESULTS_DIR.mkdir(exist_ok=True)

    scenario = args.scenario
    bar = "═" * 75
    print(f"\n{bar}")
    print(f"  MySQL vs PostgreSQL Benchmark — StackOverflow DB")
    print(f"  Scenario {scenario}: {SCENARIO_LABELS[scenario]}")
    print(f"  Runs per query : {N_RUNS}   |   {time.strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"{bar}\n")

    all_results = []

    for db_type, connect_fn in [("mysql", mysql_connect), ("postgres", pg_connect)]:
        print(f"── {db_type.upper()} {'─' * 60}")
        try:
            conn = connect_fn()
        except Exception as exc:
            print(f"  ✗ ERROR connecting to {db_type}: {exc}\n")
            sys.exit(1)
        print(f"  ✓ Connected\n")

        samples = prefetch(conn, db_type, N_RUNS)
        results = run_benchmarks(conn, db_type, samples, scenario, N_RUNS)
        all_results.extend(results)
        conn.close()
        print()

    # Write CSV
    csv_path = RESULTS_DIR / f"scenario_{scenario}_results.csv"
    fieldnames = ["query", "category", "db", "mean_ms", "stddev_ms", "min_ms", "max_ms"]
    with open(csv_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(all_results)

    print(f"{bar}")
    print(f"  ✓ Results saved → {csv_path}")
    print(f"  Total rows : {len(all_results)} (13 queries × 2 databases)")
    print(f"{bar}\n")


if __name__ == "__main__":
    main()

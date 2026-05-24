# MySQL vs PostgreSQL Performance Benchmark Suite
### Análise de Desempenho de Bancos de Dados


This repository contains a benchmarking suite designed to evaluate and compare the performance of **MySQL/MariaDB** and **PostgreSQL** across all required relational database operations using the **StackOverflow** database.

The suite evaluates 13 distinct queries representing various workload patterns across **4 indexing scenarios**, executing each query **20 times** on both database management systems (DBMS) to produce comprehensive execution statistics.

---

## 📂 File Structure

```
/
├── benchmark.py                     # Main Python benchmark controller
├── boxplot.py                       # Boxplot generator
├── requirements.txt                 # Python dependencies
├── README.md                        # Documentation & guides
└── sql/                             # SQL scripts for scenario setup
    ├── scenario_1_no_index_mysql.sql
    ├── scenario_1_no_index_postgres.sql
    ├── scenario_2_single_index_mysql.sql
    ├── scenario_2_single_index_postgres.sql
    ├── scenario_3_composite_index_mysql.sql
    ├── scenario_3_composite_index_postgres.sql
    ├── scenario_4_fulltext_index_mysql.sql
    └── scenario_4_fulltext_index_postgres.sql
```

---

## 🛠️ Requirements & Installation

1. **Python 3.8+** must be installed.
2. Install the necessary database connectors:
   ```bash
   pip install -r requirements.txt
   ```
3. Ensure both database servers are running locally:
   - **PostgreSQL** (default port `5432`, admin user `postgres`)
   - **MySQL / MariaDB** (default port `3306`, admin user `root`)

---

## 🗄️ Database Setup

Before running the benchmark, you must restore the `StackOverflow` database on both DBMSs.

---

## 📊 Indexing Scenarios

The suite evaluates performance across **four scenarios**, progressively optimizing query pathways:

| Scenario | Description | Setup Script (MySQL) | Setup Script (PostgreSQL) |
| :--- | :--- | :--- | :--- |
| **1. No Secondary Indexes** | Baselines performance with Primary Keys only. Drops all secondary indexes. | `sql/scenario_1_no_index_mysql.sql` | `sql/scenario_1_no_index_postgres.sql` |
| **2. Single-Column B-tree** | Adds B-tree indexes to all commonly filtered fields (e.g. `Location`, `Score`, `OwnerUserId`). | `sql/scenario_2_single_index_mysql.sql` | `sql/scenario_2_single_index_postgres.sql` |
| **3. Composite B-tree** | Creates multi-column B-tree indexes tailored to compound `WHERE` and `JOIN` clauses. | `sql/scenario_3_composite_index_mysql.sql` | `sql/scenario_3_composite_index_postgres.sql` |
| **4. Composite + Full-Text** | Adds MySQL `FULLTEXT` (on `Body`/`Tags`) and PG `pg_trgm` (trigram GIN) + functional GIN index (on `to_tsvector`) for fast text searches. | `sql/scenario_4_fulltext_index_mysql.sql` | `sql/scenario_4_fulltext_index_postgres.sql` |

---

## 🚀 Running the Benchmarks

To run the benchmarking suite, apply the setup SQL script for your chosen scenario to both database engines, and then execute the benchmark runner specifying the scenario number.

### Step 1: Apply Index Scenario
For example, to run the **No Secondary Indexes (Scenario 1)** baseline:
```bash
# Apply to MySQL
mysql -u root -p StackOverflow < sql/scenario_1_no_index_mysql.sql

# Apply to PostgreSQL
psql -h localhost -U postgres -d StackOverflow -f sql/scenario_1_no_index_postgres.sql
```

### Step 2: Execute Benchmark Controller
Run `benchmark.py` and pass the corresponding scenario number along with the passwords for database authentication:
```bash
python benchmark.py --scenario 1 --mysql-password MY_MYSQL_PASS --pg-password MY_POSTGRES_PASS
```

### Script Arguments

| Parameter | Type | Required | Description |
| :--- | :--- | :--- | :--- |
| `--scenario` | `int` | Yes | Scenario ID to run (`1`, `2`, `3`, or `4`). |
| `--mysql-password`| `str` | Yes | Password for MySQL `root` user. |
| `--pg-password` | `str` | Yes | Password for PostgreSQL `postgres` user. |
| `--runs` | `int` | No | Number of execution runs per query (default: `20`). |
| `--mysql-user` | `str` | No | Username for MySQL (default: `root`). |
| `--pg-user` | `str` | No | Username for PostgreSQL (default: `postgres`). |

---

## 📈 Benchmark Outputs & Results

For each run, the benchmark suite will:
1. Print real-time progress indicators to the terminal.
2. Render a summary table of the query execution times for both engines.
3. Automatically create a `results/` directory.
4. Output a CSV file named `results/scenario_N_results.csv` containing detailed execution stats:
   - `Scenario`: Scenario name
   - `Query`: Name/Id of the query
   - `Category`: Category of operation (e.g. JOIN, PK Lookup, Full-text)
   - `Database`: `MySQL` or `PostgreSQL`
   - `Mean (ms)`: Average execution time across all runs
   - `StdDev (ms)`: Standard deviation of execution times
   - `Min (ms)`: Minimum execution time observed
   - `Max (ms)`: Maximum execution time observed

---

## 📝 Query Set Details

The suite performs 13 distinct queries:
- **Q01**: `INSERT` into `Users` (cleanup handled automatically).
- **Q02**: `DELETE` by PK (pre-insert of test records handled automatically).
- **Q03**: `UPDATE` `Reputation` of a user.
- **Q04**: `PK Lookup` of a Post (`SELECT * WHERE Id = ?`).
- **Q05**: `PK Range` search on Post (`WHERE Id BETWEEN ? AND ? + 500`).
- **Q06**: Non-key attribute exact query (`WHERE Location = 'United States'`).
- **Q07**: Non-key compound query (`WHERE PostTypeId = 1 AND Score > 50 AND ViewCount > 1000`).
- **Q08**: String pattern matching using `LIKE` (`WHERE Tags LIKE '%<python>%'`).
- **Q09**: 2-table `JOIN` (`Posts` JOIN `Users` ON `OwnerUserId`).
- **Q10**: 3-table `JOIN` (`Comments` JOIN `Posts` JOIN `Users`).
- **Q11**: Subquery involving aggregates (`WHERE Id IN (Posts with score > average score)`).
- **Q12**: Grouping & aggregation (`GROUP BY PostTypeId` with `COUNT`, `AVG`, `MIN`, `MAX`, `SUM`).
- **Q13**: Full-Text Search on large body texts. (Uses slow table scan on scenarios 1–3, and utilizes `MATCH AGAINST` on MySQL / `tsvector` on PostgreSQL in scenario 4).

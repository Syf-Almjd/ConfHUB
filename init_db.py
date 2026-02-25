import oracledb
import re

DB_USER     = "SYSTEM"
DB_PASSWORD = "password123"
DB_DSN      = "localhost:1521/xe"

def execute_schema():
    print("Connecting to Oracle...")
    try:
        conn = oracledb.connect(user=DB_USER, password=DB_PASSWORD, dsn=DB_DSN)
        cur = conn.cursor()
    except Exception as e:
        print(f"Connection failed: {e}")
        return

    # Drop existing objects (optional cleanup)
    print("Dropping existing objects to start fresh...")
    drop_statements = [
        "DROP PROCEDURE proc_get_accepted_articles",
        "DROP PROCEDURE proc_register_member",
        "DROP PROCEDURE proc_register_author",
        "DROP PROCEDURE proc_register_sponsor",
        "DROP FUNCTION func_get_article_scores",
        "DROP PROCEDURE proc_assign_reviewer",
        "DROP PROCEDURE proc_submit_article",
        "DROP PROCEDURE proc_register_conference",
        "DROP TRIGGER trg_reviewer_must_organize",
        "DROP TRIGGER trg_reviewer_not_author",
        "DROP TRIGGER trg_reviewer_count",
        "DROP TRIGGER trg_global_score",
        "DROP TRIGGER trg_score_range",
        "DROP TRIGGER trg_funding_positive",
        "DROP TRIGGER trg_non_organizer_one_conference",
        # legacy trigger names (safe to ignore if already dropped)
        "DROP TRIGGER trg_contact_author_is_writer",
        "DROP TRIGGER trg_industrial_paper_required",
        "DROP TRIGGER trg_local_member_one_conference",
        "DROP TRIGGER trg_article_single_conference",
        "DROP TABLE Funds CASCADE CONSTRAINTS",
        "DROP TABLE AssignedTo CASCADE CONSTRAINTS",
        "DROP TABLE Submits CASCADE CONSTRAINTS",
        "DROP TABLE Writes CASCADE CONSTRAINTS",
        "DROP TABLE Organizes CASCADE CONSTRAINTS",
        "DROP TABLE Score CASCADE CONSTRAINTS",
        "DROP TABLE Article CASCADE CONSTRAINTS",
        "DROP TABLE Sponsor CASCADE CONSTRAINTS",
        "DROP TABLE Author CASCADE CONSTRAINTS",
        "DROP TABLE Member CASCADE CONSTRAINTS",
        "DROP TABLE Conference CASCADE CONSTRAINTS",
        # legacy tables (safe to ignore if already dropped)
        "DROP TABLE BelongsTo CASCADE CONSTRAINTS",
        "DROP TABLE Covers CASCADE CONSTRAINTS",
        "DROP TABLE IndustrialPaper CASCADE CONSTRAINTS",
        "DROP TABLE ResearchArea CASCADE CONSTRAINTS",
        "DROP TYPE ScoreTY FORCE",
        "DROP TYPE ArticleTY FORCE",
        "DROP TYPE SponsorTY FORCE",
        "DROP TYPE AuthorTY FORCE",
        "DROP TYPE MemberTY FORCE",
        "DROP TYPE ConferenceTY FORCE",
        # legacy types (safe to ignore if already dropped)
        "DROP TYPE IndustrialPaperTY FORCE",
        "DROP TYPE ResearchAreaTY FORCE"
    ]
    for drop_sql in drop_statements:
        try:
            cur.execute(drop_sql)
        except oracledb.DatabaseError as e:
            pass

    print("Executing schema.sql...")
    with open("schema.sql", "r") as f:
        schema_sql = f.read()

    statements = []
    current_stmt = []
    in_plsql = False
    
    for line in schema_sql.splitlines():
        if not current_stmt and not line.strip():
            continue
            
        upper_line = line.strip().upper()
        
        if upper_line.startswith("CREATE OR REPLACE TRIGGER") or \
           upper_line.startswith("CREATE OR REPLACE PROCEDURE") or \
           upper_line.startswith("CREATE OR REPLACE FUNCTION") or \
           upper_line.startswith("CREATE OR REPLACE TYPE") or \
           upper_line.startswith("DECLARE") or \
           upper_line.startswith("BEGIN"):
            in_plsql = True

        if line.strip() == '/':
            stmt_text = '\n'.join(current_stmt).strip()
            if stmt_text:
                statements.append(stmt_text)
            current_stmt = []
            in_plsql = False
        elif not in_plsql and line.strip().endswith(';'):
            current_stmt.append(line)
            stmt_text = '\n'.join(current_stmt).strip()
            if stmt_text:
                statements.append(stmt_text)
            current_stmt = []
        else:
            if line.strip() or current_stmt:
                current_stmt.append(line)
                
    # Add any remaining statement
    stmt_text = '\n'.join(current_stmt).strip()
    if stmt_text:
        statements.append(stmt_text)
        
    for stmt in statements:
        if not stmt or stmt.startswith('-- 4.'):
            continue
            
        if stmt.rstrip().endswith(';'):
            # Strip leading SQL comment lines to correctly detect statement type
            effective = '\n'.join(
                l for l in stmt.splitlines() if not l.strip().startswith('--')
            ).strip().upper()
            # Strip the final semicolon for DDL/DML statements so python-oracledb accepts them
            # (PL/SQL blocks end with END name; but their `;` is meaningful syntax — keep it)
            if effective.startswith("CREATE TABLE") or \
               effective.startswith("CREATE OR REPLACE TYPE ") or \
               effective.startswith("CREATE INDEX ") or \
               effective.startswith("INSERT INTO "):
                stmt = stmt.rstrip()[:-1]

        try:
            cur.execute(stmt)
        except oracledb.DatabaseError as e:
            err_obj, = e.args
            print(f"❌ ERROR: {err_obj.message}")
            print(f"   Failed statement (first 300 chars):\n   {stmt[:300]}")
            if "compiled with errors" in err_obj.message or "invalid" in err_obj.message:
                cur.execute("SELECT name, type, line, position, text FROM user_errors")
                for err in cur.fetchall():
                    print(f"   Compile Error in {err[0]} ({err[1]}) Line {err[2]}: {err[4]}")
                    
                # We can also clean up user_errors to only focus on the current statement's object but this is mostly informational

    print("\nExecuting test_data.sql...")
    try:
        with open("test_data.sql", "r") as f:
            test_sql = f.read()
            
        for stmt in test_sql.split(';'):
            clean_stmt = "\n".join([line for line in stmt.split('\n') if not line.strip().startswith('--')]).strip()
            if clean_stmt and not clean_stmt.lower().startswith("commit"):
                try:
                    cur.execute(clean_stmt)
                except oracledb.DatabaseError as e:
                    print(f"Test Data Warning: {e}")
        conn.commit()
        print("✅ Test data inserted.")
    except Exception as e:
        print(f"Test data error: {e}")

    print("\nChecking validation status...")
    cur.execute("SELECT object_name, object_type, status FROM user_objects WHERE status = 'INVALID'")
    invalids = cur.fetchall()
    if invalids:
        print("⚠️ The following objects are INVALID:")
        for inv in invalids:
            print(f" - {inv[0]} ({inv[1]})")
    else:
        print("✅ All Oracle objects compiled successfully!")

    conn.close()

if __name__ == "__main__":
    execute_schema()

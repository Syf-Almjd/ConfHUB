from flask import Flask, render_template, request, redirect, url_for, flash
from dotenv import load_dotenv
import os
import oracledb

# Load environment variables from .env file
load_dotenv()

app = Flask(__name__)
app.secret_key = os.getenv("SECRET_KEY", "fallback_secret_key")

# ---------------------------------------------------------------
# Oracle connection settings for gvenzl/oracle-xe:21-slim Docker image
#
# The gvenzl image exposes TWO service names:
#   - "xe"      => CDB$ROOT (the container database root) — tables go here
#                  when you run SQL as SYSTEM without switching to a PDB
#   - "XEPDB1"  => Pluggable DB — use this if you created a PDB user
#
# For SYSTEM user, use "xe" (CDB root). Schema objects created via
# SQL*Plus / sqlplus as SYSTEM land in CDB$ROOT = service "xe".
#
#   docker run -d -p 1521:1521 \
#     -e ORACLE_PASSWORD=password123 \
#     --name oracle-xe gvenzl/oracle-xe:21-slim
#
# ---------------------------------------------------------------
# Database configuration - values loaded from .env file
DB_USER     = os.getenv("DB_USER", "SYSTEM")
DB_PASSWORD = os.getenv("DB_PASSWORD", "")
# Use "xe" for CDB (SYSTEM user default), or "XEPDB1" for PDB user
DB_DSN      = os.getenv("DB_DSN", "localhost:1521/xe")

def get_db_connection():
    """Open and return a python-oracledb thin-mode connection, or (None, err)."""
    try:
        # thin=True means NO Oracle Instant Client libraries required locally
        connection = oracledb.connect(
            user=DB_USER,
            password=DB_PASSWORD,
            dsn=DB_DSN
        )
        return connection
    except Exception as e:
        print(f"[DB ERROR] {e}")
        return None, str(e)

def _conn():
    """Return (conn, error_str). conn is None on failure."""
    result = get_db_connection()
    if isinstance(result, tuple):
        return result          # (None, error_msg)
    return result, None        # (conn, None)


@app.route("/test_connection")
def test_connection():
    """Diagnostic route — visit /test_connection to verify Oracle is reachable."""
    conn, err = _conn()
    if conn:
        ver = conn.version
        conn.close()
        return f"""
        <html><body style='font-family:sans-serif;background:#0a0a0a;color:#00ff88;padding:40px'>
        <h2>✅ Connected successfully!</h2>
        <p><b>Oracle version:</b> {ver}</p>
        <p><b>DSN:</b> {DB_DSN} &nbsp; <b>User:</b> {DB_USER}</p>
        <p><a href="/" style='color:#fff'>← Back to Dashboard</a></p>
        </body></html>
        """
    return f"""
    <html><body style='font-family:sans-serif;background:#0a0a0a;color:#ff4d4d;padding:40px'>
    <h2>❌ Connection FAILED</h2>
    <p><b>DSN:</b> {DB_DSN}</p>
    <p><b>User:</b> {DB_USER}</p>
    <p><b>Error:</b> {err}</p>
    <hr style='border-color:#333'>
    <h3 style='color:#fff'>Likely fix for gvenzl/oracle-xe:21-slim:</h3>
    <ul style='color:#aaa'>
      <li>Make sure Docker container is running: <code>docker ps | grep oracle-xe</code></li>
      <li>Wait ~60s for Oracle to fully start after first launch</li>
      <li>If still failing, try changing DB_DSN to <code>localhost:1521/XEPDB1</code> in app.py</li>
      <li>Check container logs: <code>docker logs oracle-xe</code></li>
    </ul>
    <p><a href="/" style='color:#fff'>← Back to Dashboard</a></p>
    </body></html>
    """

@app.route("/")
def index():
    conn, conn_err = _conn()
    stats = {
        "conferences": 0,
        "articles": 0,
        "members": 0,
        "sponsors": 0
    }
    recent_conferences = []
    
    if conn:
        cur = None
        try:
            cur = conn.cursor()
            # Get stats
            cur.execute("SELECT COUNT(*) FROM Conference")
            stats["conferences"] = cur.fetchone()[0]
            
            cur.execute("SELECT COUNT(*) FROM Article")
            stats["articles"] = cur.fetchone()[0]
            
            cur.execute("SELECT COUNT(*) FROM Member")
            stats["members"] = cur.fetchone()[0]
            
            cur.execute("SELECT COUNT(*) FROM Sponsor")
            stats["sponsors"] = cur.fetchone()[0]
            
            # Get recent conferences
            cur.execute("SELECT acronym, name, venue FROM (SELECT * FROM Conference ORDER BY acronym DESC) WHERE ROWNUM <= 5")
            recent_conferences = cur.fetchall()
            
        except Exception as e:
            print(f"Error fetching dashboard stats: {e}")
        finally:
            if cur: cur.close()
            conn.close()
            
    return render_template("index.html", stats=stats, recent_conferences=recent_conferences)

@app.route("/register_conference", methods=["GET", "POST"])
def register_conference():
    if request.method == "POST":
        acronym = request.form.get("acronym", "").strip()
        name    = request.form.get("name", "").strip()
        url_val = request.form.get("url", "").strip()
        venue   = request.form.get("venue", "").strip()
        
        conn, conn_err = _conn()
        if not conn:
            flash(f"Database connection failed: {conn_err}", "danger")
            return redirect(url_for("register_conference"))
        
        cur = None
        try:
            cur = conn.cursor()
            cur.callproc("proc_register_conference", [acronym, name, url_val, venue])
            conn.commit()
            flash(f"Conference {acronym} registered successfully!", "success")
            return redirect(url_for("index"))
        except oracledb.DatabaseError as e:
            err, = e.args
            flash(f"Database error: {err.message}", "danger")
        except Exception as e:
            flash(f"Unexpected error: {str(e)}", "danger")
        finally:
            if cur: cur.close()
            conn.close()
            
    return render_template("register_conference.html")

@app.route("/submit_article", methods=["GET", "POST"])
def submit_article():
    if request.method == "POST":
        article_id    = request.form.get("article_id", "").strip()
        title         = request.form.get("title", "").strip()
        category      = request.form.get("category", "").strip()
        research_area = request.form.get("research_area", "").strip()
        contact_id    = request.form.get("contact_author_id", "").strip()
        conf_acronym  = request.form.get("conference_acronym", "").strip()
        
        conn, conn_err = _conn()
        if not conn:
            flash(f"Database connection failed: {conn_err}", "danger")
            return redirect(url_for("submit_article"))
        
        cur = None
        try:
            cur = conn.cursor()
            cur.callproc("proc_submit_article",
                         [article_id, title, category, research_area, contact_id, conf_acronym])
            conn.commit()
            flash(f"Article {article_id} submitted to {conf_acronym} successfully!", "success")
            return redirect(url_for("index"))
        except oracledb.DatabaseError as e:
            err, = e.args
            flash(f"Database error: {err.message}", "danger")
        except Exception as e:
            flash(f"Unexpected error: {str(e)}", "danger")
        finally:
            if cur: cur.close()
            conn.close()
            
    return render_template("submit_article.html")

@app.route("/assign_reviewer", methods=["GET", "POST"])
def assign_reviewer():
    if request.method == "POST":
        member_id  = request.form.get("member_id", "").strip()
        article_id = request.form.get("article_id", "").strip()
        
        conn, conn_err = _conn()
        if not conn:
            flash(f"Database connection failed: {conn_err}", "danger")
            return redirect(url_for("assign_reviewer"))
        
        cur = None
        try:
            cur = conn.cursor()
            cur.callproc("proc_assign_reviewer", [member_id, article_id])
            conn.commit()
            flash(f"Member {member_id} assigned as reviewer for article {article_id}.", "success")
            return redirect(url_for("index"))
        except oracledb.DatabaseError as e:
            err, = e.args
            flash(f"Database error: {err.message}", "danger")
        except Exception as e:
            flash(f"Unexpected error: {str(e)}", "danger")
        finally:
            if cur: cur.close()
            conn.close()
            
    return render_template("assign_reviewer.html")

@app.route("/view_article_scores", methods=["GET", "POST"])
def view_article_scores():
    avg_score  = None
    article_id = None
    if request.method == "POST":
        article_id = request.form.get("article_id", "").strip()
        conn, conn_err = _conn()
        if not conn:
            flash(f"Database connection failed: {conn_err}", "danger")
            return redirect(url_for("view_article_scores"))
        
        cur = None
        try:
            cur = conn.cursor()
            avg_score = cur.callfunc("func_get_article_scores", oracledb.NUMBER, [article_id])
            if avg_score is None:
                flash(f"No scores found for article {article_id}.", "danger")
            else:
                avg_score = round(avg_score, 2)
                flash(f"Average global score for {article_id}: {avg_score}", "success")
        except oracledb.DatabaseError as e:
            err, = e.args
            flash(f"Database error: {err.message}", "danger")
        except Exception as e:
            flash(f"Unexpected error: {str(e)}", "danger")
        finally:
            if cur: cur.close()
            conn.close()
            
    return render_template("view_article_scores.html", avg_score=avg_score, article_id=article_id)

@app.route("/accepted_articles", methods=["GET", "POST"])
def accepted_articles():
    articles     = []
    conf_acronym = None
    if request.method == "POST":
        conf_acronym = request.form.get("conference_acronym", "").strip()
        conn, conn_err = _conn()
        if not conn:
            flash(f"Database connection failed: {conn_err}", "danger")
            return redirect(url_for("accepted_articles"))
        
        cur = None
        try:
            cur = conn.cursor()
            cursor_var = cur.var(oracledb.CURSOR)
            cur.callproc("proc_get_accepted_articles", [conf_acronym, cursor_var])
            result_cursor = cursor_var.getvalue()
            articles = result_cursor.fetchall()
            result_cursor.close()
            if not articles:
                flash(f"No accepted articles found for {conf_acronym}.", "danger")
        except oracledb.DatabaseError as e:
            err, = e.args
            flash(f"Database error: {err.message}", "danger")
        except Exception as e:
            flash(f"Unexpected error: {str(e)}", "danger")
        finally:
            if cur: cur.close()
            conn.close()
            
    return render_template("accepted_articles.html", articles=articles, conf_acronym=conf_acronym)

@app.route("/conferences")
def list_conferences():
    query = request.args.get('q', '').strip()
    conn, conn_err = _conn()
    if not conn:
        flash(f"Database connection failed: {conn_err}", "danger")
        return redirect(url_for("index"))
    
    cur = None
    try:
        cur = conn.cursor()
        if query:
            sql = """
                SELECT acronym, name, url, venue 
                FROM Conference 
                WHERE UPPER(acronym) LIKE UPPER(:q) OR UPPER(name) LIKE UPPER(:q)
                ORDER BY acronym
            """
            cur.execute(sql, {"q": f"%{query}%"})
        else:
            cur.execute("SELECT acronym, name, url, venue FROM Conference ORDER BY acronym")
            
        conferences = cur.fetchall()
        return render_template("list_conferences.html", conferences=conferences, search_query=query)
    except Exception as e:
        flash(f"Error fetching conferences: {str(e)}", "danger")
        return redirect(url_for("index"))
    finally:
        if cur: cur.close()
        conn.close()

@app.route("/articles")
def list_articles():
    query = request.args.get('q', '').strip()
    conn, conn_err = _conn()
    if not conn:
        flash(f"Database connection failed: {conn_err}", "danger")
        return redirect(url_for("index"))
    
    cur = None
    try:
        cur = conn.cursor()
        if query:
            sql = """
                SELECT id, title, status, is_published, category, research_area 
                FROM Article 
                WHERE UPPER(title) LIKE UPPER(:q) OR UPPER(id) LIKE UPPER(:q)
                ORDER BY id
            """
            cur.execute(sql, {"q": f"%{query}%"})
        else:
            cur.execute("SELECT id, title, status, is_published, category, research_area FROM Article ORDER BY id")
        
        articles = cur.fetchall()
        return render_template("list_articles.html", articles=articles, search_query=query)
    except Exception as e:
        flash(f"Error fetching articles: {str(e)}", "danger")
        return redirect(url_for("index"))
    finally:
        if cur: cur.close()
        conn.close()

@app.route("/members")
def list_members():
    conn, conn_err = _conn()
    if not conn:
        flash(f"Database connection failed: {conn_err}", "danger")
        return redirect(url_for("index"))
    
    cur = None
    try:
        cur = conn.cursor()
        cur.execute("SELECT id, name, affiliation, email, phone, is_organizer FROM Member ORDER BY name")
        members = cur.fetchall()
        return render_template("list_members.html", members=members)
    except Exception as e:
        flash(f"Error fetching members: {str(e)}", "danger")
        return redirect(url_for("index"))
    finally:
        if cur: cur.close()
        conn.close()

@app.route("/authors")
def list_authors():
    conn, conn_err = _conn()
    if not conn:
        flash(f"Database connection failed: {conn_err}", "danger")
        return redirect(url_for("index"))
    
    cur = None
    try:
        cur = conn.cursor()
        cur.execute("SELECT id, name, affiliation, email, phone, is_contact_author FROM Author ORDER BY name")
        authors = cur.fetchall()
        return render_template("list_authors.html", authors=authors)
    except Exception as e:
        flash(f"Error fetching authors: {str(e)}", "danger")
        return redirect(url_for("index"))
    finally:
        if cur: cur.close()
        conn.close()

@app.route("/sponsors")
def list_sponsors():
    conn, conn_err = _conn()
    if not conn:
        flash(f"Database connection failed: {conn_err}", "danger")
        return redirect(url_for("index"))
    
    cur = None
    try:
        cur = conn.cursor()
        cur.execute(
            "SELECT id, name, funding_amount, TO_CHAR(funding_date, 'YYYY-MM-DD') "
            "FROM Sponsor ORDER BY name"
        )
        sponsors = cur.fetchall()
        return render_template("list_sponsors.html", sponsors=sponsors)
    except Exception as e:
        flash(f"Error fetching sponsors: {str(e)}", "danger")
        return redirect(url_for("index"))
    finally:
        if cur: cur.close()
        conn.close()


if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0", port=5050)

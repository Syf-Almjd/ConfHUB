# ConferenceHub

ConferenceHub is a full-stack academic database design and implementation project. It showcases an Object-Relational Database model built directly in **Oracle Database** and a web dashboard powered by **Python Flask**. The project is designed to comprehensively manage conferences, members, authors, sponsors, and article submissions.

## 🌟 Features

- **Dashboard**: A comprehensive overview displaying system-wide statistics and recent conferences.
- **Conference Management**: Register new conferences and list existing ones.
- **Article Submissions**: Submit various categories of articles (e.g., research papers, short papers, industrial papers) to specific conferences.
- **Review System**: Assign program committee members to evaluate and review articles.
- **Scoring & Leaderboards**: View auto-computed average scores and retrieve accepted articles ranked in descending order of their scores.
- **Directory Browsing**: Keep track of and list all members, authors, sponsors, and articles.
- **Rigorous Business Rules enforced via Oracle Triggers**:
  - Reviewers cannot review their own authored articles.
  - Reviewers must organize the conference they are assigned to review.
  - An article has a maximum of 4 reviewers.
  - Articles cannot be submitted to multiple conferences.
  - Automatic `global_score` calculation.

## 🛠️ Technologies Used

- **Web Framework**: Python / Flask
- **Database**: Oracle Database 21c XE (via Docker)
- **Database Driver**: `python-oracledb` (Thin mode)
- **Frontend**: HTML5, custom CSS (styled primarily matching Tailwind aesthetics)

## 📋 Prerequisites

- **Python 3.8+**
- **Docker** (to easily run the local Oracle database)

## 🚀 Getting Started

Follow these steps to get the application running on your local machine.

### 1. Database Setup

To run the application, you'll need an active Oracle database. The easiest method is using the `gvenzl/oracle-xe:21-slim` image via Docker:

```bash
docker run -d -p 1521:1521 \
  -e ORACLE_PASSWORD=password123 \
  --name oracle-xe gvenzl/oracle-xe:21-slim
```
*Note: Wait ~60 seconds for the database service to fully initiate.*

### 2. Environment Setup

It is recommended to run this project inside a Python virtual environment.

```bash
# Create and activate a virtual environment
python3 -m venv venv
source venv/bin/activate  # On Windows, use: venv\Scripts\activate

# Install the necessary dependencies
pip install flask python-oracledb python-dotenv
```

### 3. Configure Variables

Create an environment configuration file from the provided example:

```bash
cp .env.example .env
```
Ensure your `DB_PASSWORD` and `DB_USER` in `.env` match what was specified when setting up the database. The defaults provided will seamlessly connect to the Docker container setup in Step 1.

### 4. Initialize the Database

The database needs to be populated with the correct schema (types, tables, constraints, procedures) and seed data:

```bash
python init_db.py
```
*This command executes `schema.sql` and `test_data.sql`. It will report object compilation success or compile errors directly in the console.*

### 5. Start the Application

Run the Flask web server:

```bash
python app.py
```

The application will be accessible at: **[http://localhost:5050](http://localhost:5050)**.

*To verify database connectivity from the web application, visit [http://localhost:5050/test_connection](http://localhost:5050/test_connection).*

## 📂 Project Structure

- `app.py`: The entry point for the Flask web application handling routing, backend logic, and database connections.
- `init_db.py`: The Python script responsible for resetting and bootstrapping the database schema.
- `schema.sql`: Contains the complete Oracle Object-Relational structure, including `TYPES`, `TABLES`, `TRIGGERS`, and `PL/SQL` procedures.
- `test_data.sql`: Seed data loaded directly into the development database.
- `templates/`: Directory housing the front-end HTML templates.
- **Diagrams**: 
  - `ERDDiagram.png`: The Entity-Relationship diagram mapping the logical data models.
  - `UMLDiagram.png`: The UML class diagram illustrating the object-type hierarchies and methods.
